// BỘ NHỚ ĐỆM MẠNG: mọi dịch vụ (thời tiết, thiên tai NASA, ảnh thiên văn, bản đồ quanh ta, khí hậu NASA…)
// dùng chung một http.Client. Lấy được dữ liệu thì cất lại; lần sau mạng lỗi / máy chủ quá tải / hết lượt gọi
// thì trả về bản đã cất, kèm thời điểm cất (NetCache.staleAt) để app nói rõ "số liệu lưu lúc …".
// → Hôm trình diễn mạng yếu vẫn chạy được với những nơi đã hỏi trước đó.
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'net_cache_store_stub.dart' if (dart.library.io) 'net_cache_store_io.dart' as store;

class NetCache {
  /// Lần gần nhất phải dùng bản đã cất (null nếu dữ liệu vừa lấy là mới). App đặt lại null trước mỗi câu hỏi.
  static DateTime? staleAt;
  static bool announced = false;
  static void Function(String)? log;

  /// Gọi trước mỗi câu hỏi mới.
  static void reset() {
    staleAt = null;
    announced = false;
  }
}

/// Bỏ khoá API khỏi địa chỉ khi làm khoá lưu (khoá không bao giờ nằm trong bộ nhớ đệm).
String _keyOf(Uri u) {
  final q = Map<String, String>.of(u.queryParameters)..removeWhere((k, _) => const {'api_key', 'key', 'apikey'}.contains(k));
  final sorted = q.keys.toList()..sort();
  return '${u.host}${u.path}?${[for (final k in sorted) '$k=${q[k]}'].join('&')}';
}

int _h(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h;
}

class CachedClient extends http.BaseClient {
  CachedClient(this._inner);
  final http.Client _inner;
  static const _maxBytes = 6 * 1024 * 1024;

  // cùng một địa chỉ đang được tải (vd bản đồ và câu trả lời cùng hỏi thời tiết một nơi) → dùng chung một lượt tải
  final _inflight = <String, Future<(Uint8List, int, Map<String, String>)>>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // GET, và POST có thân dạng chữ (Overpass gửi câu truy vấn bản đồ bằng POST)
    final body = request is http.Request ? request.body : null;
    if (request.method != 'GET' && body == null) return _inner.send(request);
    final key = '${request.method} ${_keyOf(request.url)}${body == null || body.isEmpty ? '' : ' #${_h(body)}_${body.length}'}';
    final same = _inflight[key];
    if (same != null) {
      final (b, code, h) = await same;
      return _resp(b, code, request, h);
    }
    final done = Completer<(Uint8List, int, Map<String, String>)>();
    _inflight[key] = done.future;
    done.future.ignore();
    try {
      final res = await _fetch(request, key);
      final b = await res.stream.toBytes();
      done.complete((b, res.statusCode, res.headers));
      return _resp(b, res.statusCode, request, res.headers);
    } catch (e, st) {
      done.completeError(e, st);
      rethrow;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<http.StreamedResponse> _fetch(http.BaseRequest request, String key) async {
    try {
      // đã có bản lưu → không bắt người dùng chờ lâu: quá 7 giây thì đọc bản lưu
      final has = await store.has(key);
      final r = has ? await _inner.send(request).timeout(const Duration(seconds: 7)) : await _inner.send(request);
      final bytes = await r.stream.toBytes();
      if (r.statusCode == 200 && bytes.length <= _maxBytes) {
        unawaited(store.save(key, bytes).catchError((Object _) {}));
      } else if (r.statusCode == 429 || r.statusCode >= 500) {
        final old = await _old(key, request);
        if (old != null) return old;
      }
      return _resp(bytes, r.statusCode, request, r.headers);
    } catch (e) {
      final old = await _old(key, request);
      if (old != null) return old;
      rethrow;
    }
  }

  Future<http.StreamedResponse?> _old(String key, http.BaseRequest req) async {
    final hit = await store.load(key);
    if (hit == null) return null;
    NetCache.staleAt = hit.$2;
    NetCache.log?.call('[mạng] lỗi → dùng bản lưu lúc ${hit.$2}: ${req.url.host}${req.url.path}');
    return _resp(hit.$1, 200, req, const {'content-type': 'application/json; charset=utf-8'});
  }

  http.StreamedResponse _resp(Uint8List b, int code, http.BaseRequest req, Map<String, String> h) =>
      http.StreamedResponse(Stream.value(b), code, contentLength: b.length, request: req, headers: h);

  @override
  void close() => _inner.close();
}

/// Câu báo khi vừa phải dùng số liệu cũ (rỗng nếu số liệu mới).
(String, String) staleNote() {
  final t = NetCache.staleAt;
  if (t == null) return ('', '');
  final hm = '${t.hour} giờ ${t.minute.toString().padLeft(2, '0')}';
  final d = DateTime.now().difference(t);
  final day = d.inHours >= 20 ? ' ngày ${t.day}/${t.month}' : '';
  final dayEn = d.inHours >= 20 ? ' on ${t.day}/${t.month}' : '';
  return (
    'Mạng đang lỗi, đây là số liệu lưu lúc $hm$day. ',
    'No connection; this is data saved at ${t.hour}:${t.minute.toString().padLeft(2, '0')}$dayEn. '
  );
}
