// ẢNH THIÊN VĂN HÔM NAY của NASA (APOD — Astronomy Picture of the Day, api.nasa.gov).
// Khoá: --dart-define=NASA_API_KEY=... (đăng ký miễn phí tại api.nasa.gov); không có thì dùng DEMO_KEY (giới hạn lượt).
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:http/http.dart' as http;

import '../core/app_server.dart';

class Apod {
  final String title, explanation, date, mediaType, url;
  final String? copyright;
  const Apod(this.title, this.explanation, this.date, this.mediaType, this.url, this.copyright);
}

class ApodService {
  final http.Client client;
  ApodService(this.client);
  static const _raw = String.fromEnvironment('NASA_API_KEY');
  static const _key = _raw == '' ? 'DEMO_KEY' : _raw;
  Apod? _cache;
  static String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Apod> today() async {
    final c = _cache;
    final now = DateTime.now().toUtc();
    if (c != null && c.date == '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}') return c;
    // bản web: qua máy chủ của app (khoá NASA giữ trên máy chủ, CDN dùng chung 1 giờ cho mọi người)
    final urls = [
      if (kIsWeb) Uri.base.resolve('/api/apod'),
      // app cài trên máy (APK build từ CI không mang khoá NASA): hỏi máy chủ của app trước, khoá nằm trên Vercel
      if (!kIsWeb && _raw == '') Uri.parse('$appServer/api/apod'),
      Uri.https('api.nasa.gov', '/planetary/apod', {'api_key': _key, 'thumbs': 'true'}),
      // NASA đôi khi lỗi với ảnh "hôm nay" (chưa đăng) → ảnh hôm qua
      Uri.https('api.nasa.gov', '/planetary/apod', {'api_key': _key, 'thumbs': 'true', 'date': _ymd(now.subtract(const Duration(hours: 29)))}),
    ];
    http.Response? r;
    Object? err;
    for (final u in urls) {
      try {
        final x = await client.get(u).timeout(const Duration(seconds: 15));
        if (x.statusCode == 200) {
          r = x;
          break;
        }
        err = 'APOD HTTP ${x.statusCode}';
      } catch (e) {
        err = e;
      }
    }
    if (r == null) throw Exception('$err');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return _cache = Apod('${j['title'] ?? ''}', '${j['explanation'] ?? ''}', '${j['date'] ?? ''}', '${j['media_type'] ?? ''}',
        '${j['url'] ?? ''}', j['copyright'] is String ? (j['copyright'] as String).trim() : null);
  }
}
