// F1 — THIÊN TAI ĐÃ XẢY RA quanh một nơi trong một khoảng thời gian (để phát lại trong "lịch sử thời tiết & thiên tai").
//  • NASA EONET (lưu trữ, status=all): bão, lũ, cháy rừng, núi lửa, sạt lở… trong khung ±3° quanh nơi đó.
//  • USGS FDSN (earthquake.usgs.gov): động đất từ 4,5 độ trong bán kính 400 km.
//  • Bộ dữ liệu chuẩn hoá đóng gói sẵn của app (siêu bão Yagi 2024, lũ lịch sử miền Trung 2020): luôn có, không cần mạng.
//  • Danh mục thiên tai Việt Nam có hồ sơ NASA (vn_disasters_nasa.json: NASA GDIS, GLC, EONET kèm DMC, DesInventar,
//    1971–2026, mức nặng 1–10) — đóng gói sẵn, không cần mạng; định vị theo tâm các tỉnh bị ảnh hưởng.
//  Cùng một sự kiện có ở nhiều nguồn (cùng loại, cách nhau ≤ 3 ngày) → giữ bản nặng nhất.
// Mạng lỗi thì trả về phần lấy được (không bao giờ chặn việc phát lại thời tiết).
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../data/nasa_normalized_data.dart';
import '../features/history/history_records.dart';
import 'eonet.dart' show distanceKm, eonetLatLon, eventKindVi;

class HazardHistoryService {
  final http.Client client;
  void Function(String)? log;
  HazardHistoryService(this.client, {this.log});

  final _cache = <String, List<HazardEvent>>{};

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Mọi sự kiện quanh (lat, lon) trong [from, to). Không ném lỗi.
  Future<List<HazardEvent>> around(double lat, double lon, DateTime from, DateTime to) async {
    final key = '${lat.toStringAsFixed(1)}|${lon.toStringAsFixed(1)}|${_d(from)}|${_d(to)}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final parts = await Future.wait([
      _eonet(lat, lon, from, to).catchError((Object e) {
        log?.call('[lịch sử thiên tai] EONET: $e');
        return <HazardEvent>[];
      }),
      _usgs(lat, lon, from, to).catchError((Object e) {
        log?.call('[lịch sử thiên tai] USGS: $e');
        return <HazardEvent>[];
      }),
      _bundled(lat, lon, from, to),
      _catalog(lat, lon, from, to),
    ]);
    final out = dedupeEvents([for (final p in parts) ...p]);
    _cache[key] = out;
    return out;
  }

  Future<List<HazardEvent>> _bundled(double lat, double lon, DateTime from, DateTime to) async {
    try {
      final repo = NasaNormalizedRepo.cached ?? await NasaNormalizedRepo.load();
      return [
        for (final ev in repo.historicalEvents)
          if (_inRange(DateTime.tryParse(ev.startDate), from, to) && distanceKm(lat, lon, ev.lat, ev.lon) <= 350)
            HazardEvent(
              ev.id.contains('flood') ? HazardKind.flood : HazardKind.storm,
              DateTime.parse(ev.peakRainDate.isNotEmpty ? ev.peakRainDate : ev.startDate),
              5,
              '${ev.titleVi.split('—').first.trim()}, tổng mưa ${ev.totalRainMm.round()} mi-li-mét',
              '${ev.titleEn.split('—').first.trim()}, total rain ${ev.totalRainMm.round()} mm',
              source: 'NASA POWER',
              distanceKm: distanceKm(lat, lon, ev.lat, ev.lon),
            )
      ];
    } catch (_) {
      return const [];
    }
  }

  static List<VnDisasterRecord>? _vnCatalog;

  /// Danh mục thiên tai Việt Nam đóng gói sẵn (một lần).
  static Future<List<VnDisasterRecord>> vnCatalog() async {
    final c = _vnCatalog;
    if (c != null) return c;
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/data/vn_disasters_nasa.json')) as Map<String, dynamic>;
      return _vnCatalog = parseVnCatalog(j);
    } catch (_) {
      return _vnCatalog = const [];
    }
  }

  Future<List<HazardEvent>> _catalog(double lat, double lon, DateTime from, DateTime to) async =>
      vnCatalogEvents(await vnCatalog(), lat, lon, from, to);

  static bool _inRange(DateTime? d, DateTime from, DateTime to) => d != null && !d.isBefore(from) && d.isBefore(to);

  Future<List<HazardEvent>> _eonet(double lat, double lon, DateTime from, DateTime to) async {
    final q = {
      'status': 'all',
      'start': _d(from),
      'end': _d(to),
      'bbox': '${(lon - 3).toStringAsFixed(1)},${(lat + 3).toStringAsFixed(1)},${(lon + 3).toStringAsFixed(1)},${(lat - 3).toStringAsFixed(1)}',
      'limit': '300',
    };
    final urls = [
      if (kIsWeb) Uri.base.resolve('/api/eonet').replace(queryParameters: q),
      Uri.https('eonet.gsfc.nasa.gov', '/api/v3/events', q),
    ];
    Object? err;
    for (final u in urls) {
      try {
        final r = await client.get(u).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
        return parseEonetHistory(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>, lat, lon);
      } catch (e) {
        err = e;
      }
    }
    throw Exception('$err');
  }

  Future<List<HazardEvent>> _usgs(double lat, double lon, DateTime from, DateTime to) async {
    final u = Uri.https('earthquake.usgs.gov', '/fdsnws/event/1/query', {
      'format': 'geojson',
      'starttime': _d(from),
      'endtime': _d(to),
      'latitude': lat.toStringAsFixed(2),
      'longitude': lon.toStringAsFixed(2),
      'maxradiuskm': '400',
      'minmagnitude': '4.5',
      'orderby': 'magnitude',
      'limit': '60',
    });
    final r = await client.get(u).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
    return parseUsgs(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>, lat, lon);
  }
}

/// Sự kiện EONET (lưu trữ) → [HazardEvent]: mỗi sự kiện lấy điểm GẦN NƠI ĐÓ NHẤT và mức nặng lớn nhất.
List<HazardEvent> parseEonetHistory(Map<String, dynamic> j, double lat, double lon) {
  final out = <HazardEvent>[];
  for (final e in (j['events'] as List?) ?? const []) {
    if (e is! Map) continue;
    final cats = (e['categories'] as List?) ?? const [];
    final cat = cats.isNotEmpty && cats.first is Map ? '${(cats.first as Map)['id']}' : '';
    final kind = eonetKind(cat);
    if (kind == null) continue;
    double best = double.infinity;
    DateTime? when;
    double? mag;
    String? unit;
    for (final g in (e['geometry'] as List?) ?? const []) {
      if (g is! Map) continue;
      final co = g['coordinates'];
      double? glat, glon;
      // EONET có lúc ghi ngược [vĩ độ, kinh độ] (lũ từ GDACS/DFO): eonetLatLon tự đổi lại
      if (g['type'] == 'Point') {
        final ll = eonetLatLon(co);
        if (ll != null) (glat, glon) = ll;
      } else if (g['type'] == 'Polygon' && co is List && co.isNotEmpty && co.first is List) {
        final ring = co.first as List;
        final ll = ring.isNotEmpty ? eonetLatLon(ring.first) : null;
        if (ll != null) (glat, glon) = ll;
      }
      final m = g['magnitudeValue'];
      if (m is num && (mag == null || m > mag)) {
        mag = m.toDouble();
        unit = g['magnitudeUnit'] is String ? g['magnitudeUnit'] as String : null;
      }
      if (glat == null || glon == null) continue;
      final d = distanceKm(lat, lon, glat, glon);
      if (d < best) {
        best = d;
        when = DateTime.tryParse('${g['date']}');
      }
    }
    if (when == null || best > 500) continue;
    final title = '${e['title'] ?? ''}'.trim();
    final kmh = mag != null && unit == 'kts' && cat == 'severeStorms' ? ', gió khoảng ${(mag * 1.852).round()} ki-lô-mét một giờ' : '';
    final kmhEn = mag != null && unit == 'kts' && cat == 'severeStorms' ? ', winds about ${(mag * 1.852).round()} km/h' : '';
    out.add(HazardEvent(kind, when.toLocal(), eonetSeverity(cat, mag, unit), '${_cap(eventKindVi(cat))} $title$kmh', '$title$kmhEn',
        source: 'NASA EONET', distanceKm: best));
  }
  return out;
}

/// GeoJSON của USGS → [HazardEvent] động đất.
List<HazardEvent> parseUsgs(Map<String, dynamic> j, double lat, double lon) {
  final out = <HazardEvent>[];
  for (final f in (j['features'] as List?) ?? const []) {
    if (f is! Map) continue;
    final p = f['properties'];
    final g = f['geometry'];
    if (p is! Map || g is! Map) continue;
    final mag = p['mag'];
    final t = p['time'];
    final co = g['coordinates'];
    if (mag is! num || t is! num || co is! List || co.length < 2) continue;
    final d = distanceKm(lat, lon, (co[1] as num).toDouble(), (co[0] as num).toDouble());
    final m = mag.toDouble();
    final place = '${p['place'] ?? ''}';
    out.add(HazardEvent(HazardKind.earthquake, DateTime.fromMillisecondsSinceEpoch(t.toInt()), quakeSeverity(m),
        'Động đất ${m.toStringAsFixed(1).replaceAll('.', ',')} độ richter${place.isEmpty ? '' : ' ($place)'}',
        'Magnitude ${m.toStringAsFixed(1)} earthquake${place.isEmpty ? '' : ' ($place)'}',
        source: 'USGS', distanceKm: d));
  }
  return out;
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';


/// Một bản ghi trong danh mục thiên tai Việt Nam (vn_disasters_nasa.json).
class VnDisasterRecord {
  final String id;
  final HazardKind kind;
  final DateTime date;
  final bool yearOnly;
  final double severity; // 1..5
  final String titleVi, titleEn, source;
  final List<(double, double)> points;
  const VnDisasterRecord(this.id, this.kind, this.date, this.yearOnly, this.severity, this.titleVi, this.titleEn, this.source, this.points);
}

List<VnDisasterRecord> parseVnCatalog(Map<String, dynamic> j) {
  final out = <VnDisasterRecord>[];
  for (final r in (j['records'] as List?) ?? const []) {
    if (r is! Map) continue;
    final kind = HazardKind.values.where((k) => k.name == r['kind']).firstOrNull;
    final date = DateTime.tryParse('${r['date']}');
    if (kind == null || date == null) continue;
    out.add(VnDisasterRecord(
      '${r['id']}',
      kind,
      date,
      r['year_only'] == true,
      (r['severity'] as num?)?.toDouble() ?? 1.5,
      '${r['title_vi'] ?? ''}',
      '${r['title_en'] ?? ''}',
      '${r['source'] ?? ''}',
      [
        for (final p in (r['points'] as List?) ?? const [])
          if (p is List && p.length >= 2) ((p[0] as num).toDouble(), (p[1] as num).toDouble())
      ],
    ));
  }
  return out;
}

/// Các sự kiện trong danh mục ảnh hưởng tới vùng quanh (lat, lon) (tỉnh bị ảnh hưởng cách ≤ [km]) trong [from, to).
List<HazardEvent> vnCatalogEvents(List<VnDisasterRecord> all, double lat, double lon, DateTime from, DateTime to, {double km = 120}) {
  final out = <HazardEvent>[];
  for (final r in all) {
    if (r.date.isBefore(from) || !r.date.isBefore(to) || r.points.isEmpty) continue;
    var best = double.infinity;
    for (final p in r.points) {
      final d = distanceKm(lat, lon, p.$1, p.$2);
      if (d < best) best = d;
    }
    if (best > km) continue;
    out.add(HazardEvent(r.kind, r.date, r.severity, r.titleVi, r.titleEn,
        source: r.source.isEmpty ? 'NASA' : r.source, distanceKm: best < 30 ? null : best, yearOnly: r.yearOnly));
  }
  return out;
}

/// Gộp sự kiện trùng giữa các nguồn: cùng loại, cách nhau ≤ 3 ngày → giữ bản nặng nhất. Kết quả xếp theo thời gian.
List<HazardEvent> dedupeEvents(List<HazardEvent> evs) {
  final sorted = [...evs]..sort((a, b) => b.severity.compareTo(a.severity));
  final kept = <HazardEvent>[];
  for (final e in sorted) {
    final dup = kept.any((k) => k.kind == e.kind && k.date.difference(e.date).inDays.abs() <= 3);
    if (!dup) kept.add(e);
  }
  return kept..sort((a, b) => a.date.compareTo(b.date));
}
