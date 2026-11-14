// BẢN ĐỒ HÔM NAY: số liệu thời tiết THẬT của hôm nay cho từng ô 0,1° — để người khiếm thị rê tay / chạm là nghe
// thời tiết hôm nay (không phải trung bình tháng của các năm trước).
//
//  • Mưa hôm nay (mm, đã mưa + dự báo đến hết ngày) và nhiệt độ bây giờ: Open-Meteo, MỘT lần gọi cho ~120 điểm phủ
//    khắp Việt Nam (lưới 0,5°), rồi nội suy (nghịch đảo khoảng cách) ra mọi ô đất liền. Open-Meteo cập nhật theo giờ
//    từ các mô hình dự báo quốc gia (ECMWF, GFS, ICON…), miễn phí, không cần khoá.
//  • Điểm cháy hôm nay (tuỳ chọn): NASA FIRMS gần thời gian thực (VIIRS, trễ ~3 giờ) — cần MAP_KEY miễn phí.
//  • Dữ liệu NASA các năm trước vẫn giữ nguyên cho bài học, dòng thời gian và so sánh.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/geo.dart';
import '../data/climate_data.dart';
import 'live_weather.dart';

const liveVars = <String, VarMeta>{
  'rain': VarMeta(
      key: 'rain', vi: 'Mưa hôm nay', en: 'Rain today', unitVi: 'mm', unitEn: 'mm',
      spokenVi: 'mi-li-mét', spokenEn: 'millimetres', min: 0, max: 80, decimals: 0, sqrtScale: true,
      instrument: 'trung', daily: true),
  'temp': VarMeta(
      key: 'temp', vi: 'Nhiệt độ bây giờ', en: 'Temperature now', unitVi: '°C', unitEn: '°C',
      spokenVi: 'độ C', spokenEn: 'degrees Celsius', min: 12, max: 40, decimals: 0, instrument: 'danbau'),
  'fire': VarMeta(
      key: 'fire', vi: 'Điểm cháy hôm nay', en: 'Fires today', unitVi: 'điểm', unitEn: 'hotspots',
      spokenVi: 'điểm cháy', spokenEn: 'hotspots', min: 0, max: 5, decimals: 0, instrument: 'fire', daily: true),
};

/// Lớp cho MỘT NGÀY KHÁC (đã qua hoặc dự báo): mưa cả ngày, nhiệt độ trung bình ngày.
const dayVars = <String, VarMeta>{
  'rain': VarMeta(
      key: 'rain', vi: 'Mưa trong ngày', en: 'Daily rain', unitVi: 'mm', unitEn: 'mm',
      spokenVi: 'mi-li-mét', spokenEn: 'millimetres', min: 0, max: 80, decimals: 0, sqrtScale: true,
      instrument: 'trung', daily: true),
  'temp': VarMeta(
      key: 'temp', vi: 'Nhiệt độ trung bình ngày', en: 'Daily mean temperature', unitVi: '°C', unitEn: '°C',
      spokenVi: 'độ C', spokenEn: 'degrees Celsius', min: 8, max: 36, decimals: 0, instrument: 'danbau'),
};

/// "ngày 15 tháng 10 năm 2024" / "15 October 2024"
String dayLabel(DateTime d, String lang) {
  const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return lang == 'vi' ? 'ngày ${d.day} tháng ${d.month} năm ${d.year}' : '${d.day} ${en[d.month - 1]} ${d.year}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số liệu hôm nay (hoặc một ngày [day]), dùng được như mọi nguồn dữ liệu bản đồ khác (ClimateData).
/// Năm/tháng bỏ qua (luôn là hôm nay); lưới, vùng, chuỗi năm lấy từ dữ liệu NASA.
class LiveGridData extends ClimateData {
  LiveGridData(this.base, this._vals, this.updated, {this.day});
  final ClimateData base;
  final Map<String, Float32List> _vals;
  final DateTime updated;

  /// null = hôm nay (bây giờ); khác null = một ngày cụ thể (đã qua hoặc dự báo).
  final DateTime? day;
  bool get isToday => day == null;
  bool get isForecast => day != null && day!.isAfter(_dateOnly(DateTime.now()));

  static final _nan = Float32List(nCells)..fillRange(0, nCells, double.nan);

  @override
  String get id => 'live-${day?.toIso8601String() ?? 'now'}-${updated.millisecondsSinceEpoch}';
  @override
  bool get isSimulated => false;
  @override
  String label(String lang) => day != null
      ? (lang == 'vi' ? 'Thời tiết ${dayLabel(day!, 'vi')}${isForecast ? ' (dự báo)' : ''} — Open-Meteo' : 'Weather on ${dayLabel(day!, 'en')}${isForecast ? ' (forecast)' : ''} — Open-Meteo')
      : lang == 'vi'
      ? 'Thời tiết hôm nay (Open-Meteo${_vals.containsKey('fire') ? ', NASA FIRMS' : ''}), cập nhật lúc ${updated.hour} giờ ${updated.minute.toString().padLeft(2, '0')}'
      : 'Today\'s weather (Open-Meteo${_vals.containsKey('fire') ? ', NASA FIRMS' : ''}), updated ${updated.hour}:${updated.minute.toString().padLeft(2, '0')}';

  @override
  GeoGrid get geo => base.geo;
  @override
  List<int> get years => base.years;
  @override
  Map<String, VarMeta> get vars {
    final src = day == null ? liveVars : dayVars;
    return {for (final k in src.keys) if (_vals.containsKey(k)) k: src[k]!};
  }

  @override
  Future<void> ensureYear(String v, int year) async {}

  @override
  Float32List values(String v, int year, int m) => _vals[v] ?? _nan;

  // Một ngày không so được với trung bình cả tháng → không so sánh (câu đọc tự bỏ phần "cao hơn trung bình")
  @override
  double clim(String v, int i, int m) => double.nan;
  @override
  double sd(String v, int i, int m) => double.nan;

  @override
  RegionSeries series(int region, String v) => base.series(region, base.vars.containsKey(v) ? v : base.vars.keys.first);
}

class LiveGridService {
  LiveGridService(this.client, {this.log});
  final http.Client client;
  final void Function(String)? log;

  /// MAP_KEY của NASA FIRMS (để trống = không có lớp cháy hôm nay).
  String firmsKey = '';

  /// Các điểm lấy mẫu: ô đất liền Việt Nam cách nhau 0,5° (+ địa danh lớn cho chắc vùng hẹp như miền Trung).
  static List<(double, double)> samplePoints(GeoGrid geo) {
    final pts = <(double, double)>[];
    for (var i = 0; i < nCells; i++) {
      if (geo.type[i] != cellVn) continue;
      final r = i ~/ gw, c = i % gw;
      if (r % 5 == 2 && c % 5 == 2) pts.add((cellLat(i), cellLon(i)));
    }
    for (final p in places) {
      if (p.name.startsWith('quần đảo')) continue;
      if (pts.every((q) => (q.$1 - p.lat).abs() + (q.$2 - p.lon).abs() > 0.25)) pts.add((p.lat, p.lon));
    }
    return pts;
  }

  /// Bản đồ một ngày khác: đã qua (kho lưu trữ ERA5 từ 1940, hoặc 3 tháng gần đây) hoặc dự báo (tối đa 15 ngày tới).
  Future<LiveGridData> fetchDay(ClimateData base, DateTime day) async {
    final d = _dateOnly(day), today = _dateOnly(DateTime.now());
    final diff = d.difference(today).inDays;
    if (diff > 15) {
      throw const LiveError('Chỉ có dự báo cho 15 ngày tới.', 'Forecasts only go 15 days ahead.');
    }
    if (d.year < 1940) throw const LiveError('Chỉ có số liệu từ năm 1940.', 'Data is only available from 1940.');
    final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final geo = base.geo;
    final pts = samplePoints(geo);
    // 3 tháng gần đây và tương lai: API dự báo; xa hơn: kho lưu trữ (ERA5, trễ khoảng 5 ngày)
    final archive = diff < -85;
    final u = Uri.https(archive ? 'archive-api.open-meteo.com' : 'api.open-meteo.com', archive ? '/v1/archive' : '/v1/forecast', {
      'latitude': pts.map((p) => p.$1.toStringAsFixed(2)).join(','),
      'longitude': pts.map((p) => p.$2.toStringAsFixed(2)).join(','),
      'daily': 'precipitation_sum,temperature_2m_mean',
      'start_date': ds,
      'end_date': ds,
      'timezone': 'Asia/Ho_Chi_Minh',
    });
    final list = await _getList(u);
    final temp = <(double, double, double)>[], rain = <(double, double, double)>[];
    for (var k = 0; k < list.length && k < pts.length; k++) {
      final o = list[k];
      final daily = o is Map ? o['daily'] : null;
      if (daily is! Map) continue;
      Object? first(String key) => daily[key] is List && (daily[key] as List).isNotEmpty ? (daily[key] as List).first : null;
      final t = first('temperature_2m_mean'), pr = first('precipitation_sum');
      if (t is num) temp.add((pts[k].$1, pts[k].$2, t.toDouble()));
      if (pr is num) rain.add((pts[k].$1, pts[k].$2, pr.toDouble()));
    }
    if (temp.isEmpty && rain.isEmpty) {
      throw const LiveError('Chưa có số liệu cho ngày này (ngày quá gần thì kho lưu trữ chưa cập nhật).',
          'No data for this day yet.');
    }
    log?.call('[bản đồ ngày $ds] ${pts.length} điểm ${archive ? 'kho lưu trữ' : 'dự báo'} Open-Meteo');
    return LiveGridData(base, {'temp': _idw(geo, temp), 'rain': _idw(geo, rain)}, DateTime.now(), day: d);
  }

  Future<List<Object?>> _getList(Uri u) async {
    final http.Response r;
    try {
      r = await client.get(u).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const LiveError('Máy chưa kết nối mạng nên chưa tải được bản đồ.', 'No internet, so the map could not load.');
    }
    if (r.statusCode != 200) {
      throw LiveError('Dịch vụ thời tiết báo lỗi ${r.statusCode}.', 'Weather service error ${r.statusCode}.');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is List ? j : [j];
  }

  Future<LiveGridData> fetch(ClimateData base) async {
    final geo = base.geo;
    final pts = samplePoints(geo);
    final u = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': pts.map((p) => p.$1.toStringAsFixed(2)).join(','),
      'longitude': pts.map((p) => p.$2.toStringAsFixed(2)).join(','),
      'current': 'temperature_2m',
      'daily': 'precipitation_sum',
      'forecast_days': '1',
      'timezone': 'Asia/Ho_Chi_Minh',
    });
    final http.Response r;
    try {
      r = await client.get(u).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const LiveError('Máy chưa kết nối mạng nên chưa có bản đồ hôm nay.', 'No internet, so today\'s map is unavailable.');
    }
    if (r.statusCode != 200) {
      throw LiveError('Dịch vụ thời tiết báo lỗi ${r.statusCode}.', 'Weather service error ${r.statusCode}.');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final list = j is List ? j : [j];
    final temp = <(double, double, double)>[], rain = <(double, double, double)>[];
    for (var k = 0; k < list.length && k < pts.length; k++) {
      final o = list[k];
      if (o is! Map) continue;
      final cur = o['current'], day = o['daily'];
      final t = cur is Map ? cur['temperature_2m'] : null;
      final pr = day is Map && day['precipitation_sum'] is List && (day['precipitation_sum'] as List).isNotEmpty
          ? (day['precipitation_sum'] as List).first
          : null;
      if (t is num) temp.add((pts[k].$1, pts[k].$2, t.toDouble()));
      if (pr is num) rain.add((pts[k].$1, pts[k].$2, pr.toDouble()));
    }
    if (temp.isEmpty) throw const LiveError('Dịch vụ thời tiết trả về dữ liệu trống.', 'The weather service returned no data.');
    final vals = <String, Float32List>{
      'temp': _idw(geo, temp),
      'rain': _idw(geo, rain),
    };
    final fire = await _firms(geo);
    if (fire != null) vals['fire'] = fire;
    log?.call('[bản đồ hôm nay] ${pts.length} điểm Open-Meteo${fire != null ? ' + NASA FIRMS' : ''}');
    return LiveGridData(base, vals, DateTime.now());
  }

  /// Nội suy nghịch đảo khoảng cách ra mọi ô đất liền: 8 điểm gần nhất, trọng số 1/khoảng cách
  /// (trước đây 4 điểm, 1/khoảng cách² → loang thành đốm quanh từng điểm lấy mẫu).
  static Float32List _idw(GeoGrid geo, List<(double, double, double)> pts) {
    final out = Float32List(nCells)..fillRange(0, nCells, double.nan);
    if (pts.isEmpty) return out;
    const kN = 8;
    final best = List<double>.filled(kN, 0), bestD = List<double>.filled(kN, 0);
    for (var i = 0; i < nCells; i++) {
      if (geo.type[i] != cellVn) continue;
      final lat = cellLat(i), lon = cellLon(i);
      final k = math.cos(lat * math.pi / 180);
      var n = 0;
      for (final p in pts) {
        final dx = (p.$2 - lon) * k, dy = p.$1 - lat;
        final d = dx * dx + dy * dy;
        if (n < kN) {
          best[n] = p.$3;
          bestD[n] = d;
          n++;
        } else {
          var worst = 0;
          for (var q = 1; q < kN; q++) {
            if (bestD[q] > bestD[worst]) worst = q;
          }
          if (d < bestD[worst]) {
            best[worst] = p.$3;
            bestD[worst] = d;
          }
        }
      }
      var sw = 0.0, sv = 0.0;
      var exact = double.nan;
      for (var q = 0; q < n; q++) {
        if (bestD[q] < 1e-6) exact = best[q];
        final w = 1 / math.sqrt(bestD[q]);
        sw += w;
        sv += w * best[q];
      }
      out[i] = exact.isNaN ? sv / sw : exact;
    }
    return out;
  }

  /// NASA FIRMS gần thời gian thực: số điểm cháy VIIRS trong 24 giờ qua, theo ô.
  Future<Float32List?> _firms(GeoGrid geo) async {
    final key = firmsKey.trim();
    if (key.isEmpty) return null;
    try {
      final u = Uri.parse('https://firms.modaps.eosdis.nasa.gov/api/area/csv/$key/VIIRS_SNPP_NRT/'
          '$lon0,$lat0,$lon1,$lat1/1');
      final r = await client.get(u).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        log?.call('[FIRMS] lỗi ${r.statusCode}');
        return null;
      }
      final lines = const LineSplitter().convert(utf8.decode(r.bodyBytes));
      if (lines.isEmpty || !lines.first.contains('latitude')) {
        log?.call('[FIRMS] trả lời lạ: ${lines.isEmpty ? '' : lines.first}');
        return null;
      }
      final head = lines.first.split(',');
      final la = head.indexOf('latitude'), lo = head.indexOf('longitude');
      final out = Float32List(nCells);
      for (var i = 0; i < nCells; i++) {
        if (geo.type[i] != cellVn) out[i] = double.nan;
      }
      for (final l in lines.skip(1)) {
        final f = l.split(',');
        if (f.length <= math.max(la, lo)) continue;
        final lat = double.tryParse(f[la]), lon = double.tryParse(f[lo]);
        if (lat == null || lon == null) continue;
        final c = ((lon - lon0) / res).floor(), rr = ((lat1 - lat) / res).floor();
        if (c < 0 || rr < 0 || c >= gw || rr >= gh) continue;
        final i = cellIndex(c, rr);
        if (geo.type[i] == cellVn) out[i] += 1;
      }
      return out;
    } catch (e) {
      log?.call('[FIRMS] $e');
      return null;
    }
  }
}
