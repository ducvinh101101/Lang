// THỐNG KÊ LƯỢT DÙNG (ẩn danh) — để báo cáo với hội đồng: bao nhiêu lượt mở app, bao nhiêu người dùng khác nhau,
// bao nhiêu lượt dùng chế độ khiếm thị / bạn nhỏ, câu lệnh giọng nói, bài học hoàn thành…
//
//  • Chỉ gửi TÊN SỰ KIỆN + nền tảng + chế độ + một mã ngẫu nhiên của máy (để đếm số người, không biết là ai).
//    Không gửi vị trí, giọng nói, câu hỏi hay bất kỳ nội dung nào.
//  • Bản web gửi về /api/stats của chính trang; app Windows/Android gửi về địa chỉ đặt khi build:
//      --dart-define=STATS_URL=https://<tên-dự-án>.vercel.app/api/stats
//  • Tắt được trong Cài đặt ("Gửi thống kê lượt dùng ẩn danh"). Mất mạng / chưa cài máy chủ: bỏ qua êm, không ảnh hưởng app.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Stats {
  Stats._();
  static final instance = Stats._();

  static const _envUrl = String.fromEnvironment('STATS_URL');

  SharedPreferences? _prefs;
  Uri? _url;
  String _id = '';
  String Function() mode = () => 'standard';
  bool enabled = true;

  final _queue = <String>[];
  final _onceThisSession = <String>{};
  Timer? _flush;
  http.Client client = http.Client();

  /// Sự kiện chỉ đếm MỘT lần mỗi lần mở app (vd đã khám phá bản đồ) — còn lại đếm mỗi lần.
  static const _perSession = {'map', 'today', 'blind', 'kid'};

  String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name;
  bool get configured => _url != null;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    enabled = prefs.getBool('statsOn') ?? true;
    var id = prefs.getString('statsId');
    if (id == null || id.length < 8) {
      final r = math.Random.secure();
      const a = 'abcdefghijklmnopqrstuvwxyz0123456789';
      id = List.generate(24, (_) => a[r.nextInt(a.length)]).join();
      await prefs.setString('statsId', id);
    }
    _id = id;
    if (kIsWeb) {
      _url = Uri.base.resolve('/api/stats');
    } else if (_envUrl.isNotEmpty) {
      _url = Uri.tryParse(_envUrl);
    }
  }

  Future<void> setEnabled(bool on) async {
    enabled = on;
    await _prefs?.setBool('statsOn', on);
    if (!on) _queue.clear();
  }

  /// Ghi một sự kiện (gom lại, gửi sau ~3 giây; "open" gửi ngay).
  void track(String event) {
    if (!enabled || _url == null) return;
    if (_perSession.contains(event) && !_onceThisSession.add(event)) return;
    _queue.add(event);
    // gom ~20 giây rồi gửi một lần (nhiều người dùng cùng lúc → ít lượt gọi máy chủ hơn nhiều); "open" gửi ngay
    if (event == 'open' || _queue.length >= 40) {
      _flush?.cancel();
      _flush = Timer(Duration.zero, _send);
    } else {
      _flush ??= Timer(const Duration(seconds: 20), _send);
    }
  }

  Future<void> _send() async {
    _flush = null;
    final url = _url;
    if (url == null || _queue.isEmpty) return;
    final events = List<String>.from(_queue);
    _queue.clear();
    try {
      final r = await client
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'id': _id, 'platform': platform, 'mode': mode(), 'events': events}))
          .timeout(const Duration(seconds: 8));
      // máy chủ chưa bật thống kê → thôi gửi trong lần dùng này (đỡ gọi máy chủ vô ích)
      if (r.statusCode == 503 || r.body.contains('"off":true')) _url = null;
    } catch (_) {
      // không gửi được (mất mạng…) → bỏ qua, không thử lại cho khỏi tốn pin/mạng
    }
  }
}
