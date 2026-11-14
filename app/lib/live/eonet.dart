// CẢNH BÁO THIÊN TAI từ NASA EONET (Earth Observatory Natural Event Tracker, eonet.gsfc.nasa.gov — miễn phí, không khoá):
// bão, lũ, cháy rừng, núi lửa, động đất, sạt lở… đang diễn ra. App tìm sự kiện gần một nơi (theo km và hướng)
// để đọc cảnh báo kèm còi và rung riêng. Bản web: nếu bị chặn gọi thẳng thì đi qua /api/eonet (api/eonet.mjs).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class NaturalEvent {
  final String id, title, category; // category: mã EONET (severeStorms, floods, wildfires…)
  final double lat, lon;
  final DateTime? date;
  final double? magnitude; // vd sức gió (kts) của bão
  final String? magUnit;
  const NaturalEvent(this.id, this.title, this.category, this.lat, this.lon, this.date, this.magnitude, this.magUnit);

  String get kindVi => eventKindVi(category);
}

String eventKindVi(String c) => switch (c) {
      'severeStorms' => 'bão',
      'floods' => 'lũ lụt',
      'wildfires' => 'cháy rừng',
      'volcanoes' => 'núi lửa',
      'earthquakes' => 'động đất',
      'landslides' => 'sạt lở đất',
      'drought' => 'hạn hán',
      'dustHaze' => 'bụi mù',
      'tempExtremes' => 'nhiệt độ khắc nghiệt',
      'snow' => 'bão tuyết',
      'seaLakeIce' => 'băng trôi',
      'waterColor' => 'nước biển đổi màu',
      _ => 'sự kiện tự nhiên',
    };

/// Khoảng cách (km) giữa hai điểm trên Trái Đất.
/// Một điểm toạ độ GeoJSON của EONET → (vĩ độ, kinh độ). Chuẩn GeoJSON là [kinh độ, vĩ độ], nhưng một số sự kiện
/// lũ của EONET (nguồn GDACS/DFO) ghi NGƯỢC [vĩ độ, kinh độ] — ví dụ "Flood in Cambodia" có [13,5; 102,3].
/// Số thứ hai vượt ±90 thì chắc chắn bị đảo → đổi lại. Trả null nếu không đọc được.
(double, double)? eonetLatLon(Object? p) {
  if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) return null;
  var lon = (p[0] as num).toDouble(), lat = (p[1] as num).toDouble();
  if (lat.abs() > 90 && lon.abs() <= 90) (lat, lon) = (lon, lat);
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return (lat, lon);
}

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1, dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Hướng từ điểm 1 tới điểm 2: 'phía bắc', 'phía đông nam'…
String bearingVi(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180, dl = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  final deg = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  const names = ['bắc', 'đông bắc', 'đông', 'đông nam', 'nam', 'tây nam', 'tây', 'tây bắc'];
  return 'phía ${names[((deg + 22.5) ~/ 45) % 8]}';
}

class EonetService {
  final http.Client client;
  void Function(String)? log;
  EonetService(this.client, {this.log});

  List<NaturalEvent>? _cache;
  DateTime? _at;

  /// Các sự kiện đang diễn ra (cập nhật trong 30 ngày qua). Lưu 30 phút.
  Future<List<NaturalEvent>> open() async {
    final c = _cache, at = _at;
    if (c != null && at != null && DateTime.now().difference(at).inMinutes < 30) return c;
    const q = {'status': 'open', 'days': '30', 'limit': '400'};
    // bản web: đi qua máy chủ của app TRƯỚC (CDN giữ bản sao chung cho mọi người → nhanh, không dồn lượt gọi NASA)
    final urls = [
      if (kIsWeb) Uri.base.resolve('/api/eonet').replace(queryParameters: q),
      Uri.https('eonet.gsfc.nasa.gov', '/api/v3/events', q),
    ];
    Object? err;
    for (final u in urls) {
      try {
        final r = await client.get(u).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
        final list = _parse(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
        _cache = list;
        _at = DateTime.now();
        return list;
      } catch (e) {
        err = e;
        log?.call('[EONET] $u → $e');
      }
    }
    throw Exception('EONET: $err');
  }

  static List<NaturalEvent> _parse(Map<String, dynamic> j) {
    final out = <NaturalEvent>[];
    for (final e in (j['events'] as List?) ?? const []) {
      if (e is! Map) continue;
      final cats = (e['categories'] as List?) ?? const [];
      final cat = cats.isNotEmpty && cats.first is Map ? '${(cats.first as Map)['id']}' : '';
      final geos = (e['geometry'] as List?) ?? const [];
      if (geos.isEmpty) continue;
      // vị trí MỚI NHẤT (bão di chuyển: điểm cuối cùng)
      final g = geos.last;
      if (g is! Map) continue;
      double? lat, lon;
      final co = g['coordinates'];
      if (g['type'] == 'Point') {
        final ll = eonetLatLon(co);
        if (ll != null) (lat, lon) = ll;
      } else if (g['type'] == 'Polygon' && co is List && co.isNotEmpty && co.first is List) {
        // tâm đa giác
        var sx = 0.0, sy = 0.0, n = 0;
        for (final p in co.first as List) {
          final ll = eonetLatLon(p);
          if (ll != null) {
            sy += ll.$1;
            sx += ll.$2;
            n++;
          }
        }
        if (n > 0) {
          lon = sx / n;
          lat = sy / n;
        }
      }
      if (lat == null || lon == null) continue;
      final mag = g['magnitudeValue'];
      out.add(NaturalEvent('${e['id']}', '${e['title'] ?? ''}', cat, lat, lon, DateTime.tryParse('${g['date']}'),
          mag is num ? mag.toDouble() : null, g['magnitudeUnit'] is String ? g['magnitudeUnit'] as String : null));
    }
    return out;
  }

  /// Sự kiện trong bán kính [km] quanh một điểm, gần nhất trước.
  Future<List<(NaturalEvent, double)>> near(double lat, double lon, {double km = 600}) async {
    final all = await open();
    final out = <(NaturalEvent, double)>[
      for (final e in all)
        if (distanceKm(lat, lon, e.lat, e.lon) <= km) (e, distanceKm(lat, lon, e.lat, e.lon))
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return out;
  }
}

/// Câu cảnh báo: "Cảnh báo: bão Kalmaegi cách đây khoảng 320 km về phía đông, gió khoảng 65 nút…"
String eventSentence(NaturalEvent e, double km, double lat, double lon) {
  final dist = km < 20 ? 'ngay gần đây' : 'cách khoảng ${km < 100 ? km.round() : (km / 10).round() * 10} ki-lô-mét về ${bearingVi(lat, lon, e.lat, e.lon)}';
  final mag = e.magnitude != null && e.category == 'severeStorms' && e.magUnit == 'kts'
      ? ', sức gió khoảng ${(e.magnitude! * 1.852).round()} ki-lô-mét một giờ'
      : '';
  // tên gốc tiếng Anh của NASA ("Typhoon Fengshen", "Wildfire in X", "Etna Volcano") → bỏ phần chỉ loại, giữ tên riêng
  final name = e.title
      .replaceFirst(
          RegExp(r'^(Super Typhoon|Typhoon|Hurricane|Tropical Storm|Tropical Cyclone|Cyclone|Tropical Depression|Wildfires?|Floods?)\s+(in\s+)?',
              caseSensitive: false),
          '')
      .replaceAll(RegExp(r'\s+Volcano\b', caseSensitive: false), '');
  return '${e.kindVi[0].toUpperCase()}${e.kindVi.substring(1)} $name, $dist$mag.';
}

String _kindEn(String c) => switch (c) {
      'severeStorms' => 'Storm',
      'floods' => 'Flood',
      'wildfires' => 'Wildfire',
      'volcanoes' => 'Volcano',
      'earthquakes' => 'Earthquake',
      'landslides' => 'Landslide',
      'drought' => 'Drought',
      'dustHaze' => 'Dust and haze',
      _ => 'Event',
    };

/// English alert sentence: "Storm Fengshen, about 320 kilometres to the east, winds about 120 kilometres per hour."
String eventSentenceEn(NaturalEvent e, double km, double lat, double lon) {
  final p1 = lat * math.pi / 180, p2 = e.lat * math.pi / 180, dl = (e.lon - lon) * math.pi / 180;
  final deg = (math.atan2(math.sin(dl) * math.cos(p2), math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)) *
              180 /
              math.pi +
          360) %
      360;
  const names = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  final dir = names[((deg + 22.5) ~/ 45) % 8];
  final dist = km < 20 ? 'very close' : 'about ${km < 100 ? km.round() : (km / 10).round() * 10} kilometres to the $dir';
  final mag = e.magnitude != null && e.category == 'severeStorms' && e.magUnit == 'kts'
      ? ', winds about ${(e.magnitude! * 1.852).round()} kilometres per hour'
      : '';
  final title = e.title.toLowerCase().startsWith(_kindEn(e.category).toLowerCase()) ? e.title : '${_kindEn(e.category)}: ${e.title}';
  return '$title, $dist$mag.';
}
