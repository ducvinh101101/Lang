// Nơi lấy gói dữ liệu (touchgrid.json, series.json, frames/*.bin):
//  • AssetLoader: đóng gói sẵn trong app (assets/data/), chạy offline.
//  • HttpLoader : tải từ một URL (vd GitHub Pages chứa thư mục web/data) — cập nhật dữ liệu NASA mới
//                 cho mọi người dùng mà không phải phát hành lại app.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:http/http.dart' as http;

abstract class DataLoader {
  Future<String> text(String path);
  Future<Uint8List> bytes(String path);
  String describe();
}

class AssetLoader implements DataLoader {
  final String base;
  const AssetLoader([this.base = 'assets/data']);

  static Future<Set<String>?>? _list;

  /// Hỏi danh sách tài nguyên đóng gói trước khi tải: thiếu file (vd chưa chạy pipeline NASA) thì báo ngay,
  /// không gửi yêu cầu đi để rồi nhận lỗi 404 trên web.
  Future<void> _mustHave(String key) async {
    final s = await (_list ??= AssetManifest.loadFromAssetBundle(rootBundle)
        .then<Set<String>?>((m) => m.listAssets().toSet())
        .catchError((Object _) => null));
    if (s != null && !s.contains(key)) throw StateError('Không có $key trong gói app');
  }

  @override
  Future<String> text(String path) async {
    await _mustHave('$base/$path');
    return rootBundle.loadString('$base/$path');
  }

  @override
  Future<Uint8List> bytes(String path) async {
    await _mustHave('$base/$path');
    final bd = await rootBundle.load('$base/$path');
    return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
  }

  @override
  String describe() => 'app';
}

class HttpLoader implements DataLoader {
  final Uri base;
  final http.Client _client;
  final Map<String, Uint8List> _cache = {};

  HttpLoader(String url, {http.Client? client})
      : base = Uri.parse(url.endsWith('/') ? url : '$url/'),
        _client = client ?? http.Client();

  Future<Uint8List> _get(String path) async {
    final hit = _cache[path];
    if (hit != null) return hit;
    final r = await _client.get(base.resolve(path)).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw StateError('Tải ${base.resolve(path)} lỗi HTTP ${r.statusCode}');
    }
    _cache[path] = r.bodyBytes;
    return r.bodyBytes;
  }

  @override
  Future<String> text(String path) async => utf8.decode(await _get(path));

  @override
  Future<Uint8List> bytes(String path) => _get(path);

  @override
  String describe() => base.toString();
}
