// THỜI TIẾT TRỰC TIẾP: bây giờ, theo giờ, 10 ngày tới — cho người khiếm thị (cần biết thời tiết hôm nay hơn cả).
//
// Nguồn:
//  • Open-Meteo (mặc định): miễn phí, KHÔNG cần khoá API, có cả chất lượng không khí và tìm địa danh.
//    https://open-meteo.com — dữ liệu từ các mô hình dự báo quốc gia (ECMWF, GFS, …).
//  • Google Weather API (tuỳ chọn): cần khoá Google Maps Platform đã bật "Weather API".
//    Lỗi / hết hạn mức → tự quay về Open-Meteo.
// Mỗi chỗ (làm tròn 0,1°) được nhớ 10 phút để hỏi lại không phải chờ mạng.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../core/net_cache.dart';
import 'vn_admin.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class LiveNow {
  final double temp, feels;
  final int humidity;
  final double precip; // mm trong giờ qua
  final String desc;
  final int code; // mã thời tiết kiểu WMO (Google: quy đổi gần đúng), -1 = không rõ
  final double wind; // km/h
  final String? windDir;
  final double? uv;
  const LiveNow({
    required this.temp,
    required this.feels,
    required this.humidity,
    required this.precip,
    required this.desc,
    required this.code,
    required this.wind,
    this.windDir,
    this.uv,
  });
}

class LiveHour {
  final DateTime time;
  final double temp;
  final int? rainProb;
  final int code;
  final String desc;
  final double? uv; // chỉ số UV giờ đó (để báo giờ nên tránh nắng)
  const LiveHour(this.time, this.temp, this.rainProb, this.code, this.desc, {this.uv});
}

class LiveDay {
  final DateTime date;
  final double tmax, tmin;
  final int? rainProb;
  final double? rainMm;
  final int code;
  final String desc;
  final double? uv, windMax;
  final DateTime? sunrise, sunset; // giờ địa phương của nơi đó (null nếu nguồn không có)
  const LiveDay(this.date, this.tmax, this.tmin, this.rainProb, this.rainMm, this.code, this.desc, this.uv, this.windMax,
      {this.sunrise, this.sunset});
}

class LiveWeather {
  final String source; // 'Open-Meteo' | 'Google'
  final DateTime fetched;
  final LiveNow now;
  final List<LiveHour> hours; // từ giờ hiện tại trở đi (tối đa 48 — đủ để hỏi "chiều mai")
  final List<LiveDay> days; // hôm nay là days[0]
  final int? aqi; // chỉ số chất lượng không khí (thang US AQI)
  final double? pm25, pm10;

  /// Độ dày quang học sol khí (aerosol, 550 nm) và bụi (µg/m³) — mô hình Copernicus CAMS.
  final double? aod, dust;
  const LiveWeather(this.source, this.fetched, this.now, this.hours, this.days,
      {this.aqi, this.pm25, this.pm10, this.aod, this.dust});

  /// Gọn cho AI (Gemini) đọc.
  Map<String, Object?> toJson() => {
        'nguon': source,
        'bay_gio': {
          'nhiet_do_C': now.temp.round(),
          'cam_giac_C': now.feels.round(),
          'do_am_phan_tram': now.humidity,
          'mua_mm_gio_qua': now.precip,
          'troi': now.desc,
          'gio_km_h': now.wind.round(),
          if (now.uv != null) 'uv': now.uv!.round(),
        },
        if (aqi != null) 'chat_luong_khong_khi_AQI': aqi,
        if (pm25 != null) 'bui_min_PM2_5': pm25!.round(),
        if (aod != null) 'aerosol_AOD': aod,
        'theo_gio': [
          for (final h in hours.take(12))
            {'gio': h.time.hour, 'nhiet_do_C': h.temp.round(), 'kha_nang_mua_phan_tram': h.rainProb, 'troi': h.desc}
        ],
        'theo_ngay': [
          for (final d in days)
            {
              'ngay': '${d.date.day}/${d.date.month}',
              'cao_nhat_C': d.tmax.round(),
              'thap_nhat_C': d.tmin.round(),
              'kha_nang_mua_phan_tram': d.rainProb,
              'luong_mua_mm': d.rainMm?.round(),
              'troi': d.desc,
              if (d.uv != null) 'uv_cao_nhat': d.uv!.round(),
            }
        ],
      };
}

class LiveError implements Exception {
  final String vi, en;
  const LiveError(this.vi, this.en);
  @override
  String toString() => vi;
}

/// Mã thời tiết WMO → lời tiếng Việt / tiếng Anh.
(String, String) wmoText(int c) {
  if (c == 0) return ('trời quang', 'clear sky');
  if (c == 1) return ('trời ít mây', 'mostly clear');
  if (c == 2) return ('có mây', 'partly cloudy');
  if (c == 3) return ('nhiều mây', 'overcast');
  if (c == 45 || c == 48) return ('có sương mù', 'fog');
  if (c >= 51 && c <= 57) return ('mưa phùn', 'drizzle');
  if (c == 61 || c == 66) return ('mưa nhỏ', 'light rain');
  if (c == 63) return ('mưa vừa', 'moderate rain');
  if (c == 65 || c == 67) return ('mưa to', 'heavy rain');
  if (c >= 71 && c <= 77) return ('có tuyết', 'snow');
  if (c == 80) return ('mưa rào nhẹ', 'light showers');
  if (c == 81) return ('mưa rào', 'showers');
  if (c == 82) return ('mưa rào rất to', 'violent showers');
  if (c == 95) return ('có dông', 'thunderstorm');
  if (c == 96 || c == 99) return ('dông kèm mưa đá', 'thunderstorm with hail');
  return ('', '');
}

bool isThunder(int code) => code >= 95;
bool isRainy(int code) => (code >= 51 && code <= 67) || (code >= 80 && code <= 99);

class WeatherService {
  /// 'open-meteo' | 'google'
  String provider = 'open-meteo';
  String googleKey = '';
  // dùng chung cho mọi dịch vụ; mạng lỗi thì trả bản đã lưu (core/net_cache.dart)
  http.Client client = CachedClient(http.Client());
  void Function(String)? log;

  final _cache = <String, LiveWeather>{};

  // 'auto': giờ địa phương của nơi được hỏi (app xem thời tiết cả thế giới)
  static const _tz = 'auto';
  static const _timeout = Duration(seconds: 9);

  bool get usingGoogle => provider == 'google' && googleKey.trim().isNotEmpty;

  /// Thời tiết ở (vĩ độ, kinh độ). [lang] 'vi' | 'en' cho mô tả của Google.
  Future<LiveWeather> get(double lat, double lon, {bool force = false, String lang = 'vi'}) async {
    final key = '${(lat * 10).round()}|${(lon * 10).round()}|$provider';
    final hit = _cache[key];
    if (!force && hit != null && DateTime.now().difference(hit.fetched) < const Duration(minutes: 10)) return hit;
    LiveWeather w;
    if (usingGoogle) {
      try {
        w = await _google(lat, lon, lang);
      } catch (e) {
        log?.call('[thời tiết Google] $e → dùng Open-Meteo');
        w = await _openMeteo(lat, lon, lang);
      }
    } else {
      w = await _openMeteo(lat, lon, lang);
    }
    if (_cache.length > 60) _cache.clear();
    _cache[key] = w;
    return w;
  }

  /// Bản đã nhớ (nếu có và còn mới) — để đọc ngay không chờ mạng.
  LiveWeather? cached(double lat, double lon) {
    final hit = _cache['${(lat * 10).round()}|${(lon * 10).round()}|$provider'];
    if (hit == null || DateTime.now().difference(hit.fetched) > const Duration(minutes: 30)) return null;
    return hit;
  }

  Future<Map<String, dynamic>> _getJson(Uri u, {Map<String, String>? headers}) async {
    http.Response r;
    try {
      r = await client.get(u, headers: headers).timeout(_timeout);
      // máy chủ thời tiết bận nhất thời (429/5xx, gặp khi dùng thử: 503) → chờ chút rồi thử lại một lần
      if (r.statusCode == 429 || r.statusCode >= 500) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        r = await client.get(u, headers: headers).timeout(_timeout);
      }
    } on TimeoutException {
      throw const LiveError('Mạng chậm, chưa lấy được thời tiết.', 'The network is slow; could not get the weather.');
    } catch (_) {
      throw const LiveError('Máy chưa kết nối mạng nên chưa lấy được thời tiết bây giờ.',
          'No internet connection, so live weather is unavailable.');
    }
    if (r.statusCode != 200) {
      throw LiveError('Máy chủ thời tiết đang bận (mã ${r.statusCode}). Bạn nói lại sau ít giây nhé.',
          'The weather service is busy (code ${r.statusCode}). Please ask again in a few seconds.');
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static double _d(Object? v, [double or = double.nan]) => v is num ? v.toDouble() : or;
  static int? _i(Object? v) => v is num ? v.round() : null;

  // ---------- Open-Meteo ----------
  Future<LiveWeather> _openMeteo(double lat, double lon, String lang) async {
    final u = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(3),
      'longitude': lon.toStringAsFixed(3),
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,'
          'wind_speed_10m,wind_direction_10m,uv_index',
      'hourly': 'temperature_2m,precipitation_probability,weather_code,uv_index',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,'
          'uv_index_max,wind_speed_10m_max,sunrise,sunset',
      'timezone': _tz,
      'forecast_days': '11', // hôm nay + 10 ngày tới
    });
    final aqiF = _airQuality(lat, lon);
    final j = await _getJson(u);
    final cur = (j['current'] as Map?) ?? const {};
    final code = _i(cur['weather_code']) ?? -1;
    final t = wmoText(code);
    final now = LiveNow(
      temp: _d(cur['temperature_2m']),
      feels: _d(cur['apparent_temperature'], _d(cur['temperature_2m'])),
      humidity: _i(cur['relative_humidity_2m']) ?? 0,
      precip: _d(cur['precipitation'], 0),
      desc: lang == 'vi' ? t.$1 : t.$2,
      code: code,
      wind: _d(cur['wind_speed_10m'], 0),
      windDir: _compass(_d(cur['wind_direction_10m'])),
      uv: cur['uv_index'] is num ? _d(cur['uv_index']) : null,
    );
    final hours = <LiveHour>[];
    final hj = (j['hourly'] as Map?) ?? const {};
    final ht = (hj['time'] as List?) ?? const [];
    // giờ trả về là giờ địa phương của NƠI ĐÓ → so với "bây giờ" theo giờ nơi đó, không theo giờ của máy
    final off = j['utc_offset_seconds'] is num ? (j['utc_offset_seconds'] as num).round() : 7 * 3600;
    final lt = DateTime.now().toUtc().add(Duration(seconds: off));
    final nowH = DateTime(lt.year, lt.month, lt.day, lt.hour, lt.minute).subtract(const Duration(minutes: 59));
    for (var k = 0; k < ht.length && hours.length < 48; k++) {
      final tm = DateTime.tryParse('${ht[k]}');
      if (tm == null || tm.isBefore(nowH)) continue;
      final c = _i((hj['weather_code'] as List?)?[k]) ?? -1;
      final tx = wmoText(c);
      final uvH = (hj['uv_index'] as List?)?[k];
      hours.add(LiveHour(tm, _d((hj['temperature_2m'] as List?)?[k]), _i((hj['precipitation_probability'] as List?)?[k]), c,
          lang == 'vi' ? tx.$1 : tx.$2,
          uv: uvH is num ? uvH.toDouble() : null));
    }
    final days = <LiveDay>[];
    final dj = (j['daily'] as Map?) ?? const {};
    final dt = (dj['time'] as List?) ?? const [];
    Object? at(String k, int i) => (dj[k] as List?)?[i];
    for (var k = 0; k < dt.length; k++) {
      final dd = DateTime.tryParse('${dt[k]}');
      if (dd == null) continue;
      final c = _i(at('weather_code', k)) ?? -1;
      final tx = wmoText(c);
      days.add(LiveDay(
        dd,
        _d(at('temperature_2m_max', k)),
        _d(at('temperature_2m_min', k)),
        _i(at('precipitation_probability_max', k)),
        at('precipitation_sum', k) is num ? _d(at('precipitation_sum', k)) : null,
        c,
        lang == 'vi' ? tx.$1 : tx.$2,
        at('uv_index_max', k) is num ? _d(at('uv_index_max', k)) : null,
        at('wind_speed_10m_max', k) is num ? _d(at('wind_speed_10m_max', k)) : null,
        sunrise: DateTime.tryParse('${at('sunrise', k) ?? ''}'),
        sunset: DateTime.tryParse('${at('sunset', k) ?? ''}'),
      ));
    }
    if (now.temp.isNaN) throw const LiveError('Dịch vụ thời tiết trả về dữ liệu trống.', 'The weather service returned no data.');
    final air = await aqiF;
    return LiveWeather('Open-Meteo', DateTime.now(), now, hours, days,
        aqi: air.aqi, pm25: air.pm25, pm10: air.pm10, aod: air.aod, dust: air.dust);
  }

  /// Chất lượng không khí, bụi mịn, bụi và aerosol (Open-Meteo, mô hình Copernicus CAMS).
  Future<({int? aqi, double? pm25, double? pm10, double? aod, double? dust})> _airQuality(double lat, double lon) async {
    try {
      final j = await _getJson(Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        'latitude': lat.toStringAsFixed(3),
        'longitude': lon.toStringAsFixed(3),
        'current': 'us_aqi,pm2_5,pm10,aerosol_optical_depth,dust',
        'timezone': _tz,
      }));
      final c = (j['current'] as Map?) ?? const {};
      double? n(String k) => c[k] is num ? _d(c[k]) : null;
      return (aqi: _i(c['us_aqi']), pm25: n('pm2_5'), pm10: n('pm10'), aod: n('aerosol_optical_depth'), dust: n('dust'));
    } catch (_) {
      return (aqi: null, pm25: null, pm10: null, aod: null, dust: null); // không có thì thôi
    }
  }

  static String? _compass(double deg) {
    if (deg.isNaN) return null;
    const names = ['bắc', 'đông bắc', 'đông', 'đông nam', 'nam', 'tây nam', 'tây', 'tây bắc'];
    return names[((deg % 360) / 45).round() % 8];
  }

  /// Tìm toạ độ một địa danh bất kỳ ở Việt Nam (cho câu hỏi AI về nơi không có trong danh sách của app).
  Future<(String, double, double)?> geocode(String name) async {
    try {
      final j = await _getJson(Uri.https('geocoding-api.open-meteo.com', '/v1/search',
          {'name': name, 'count': '5', 'language': 'vi', 'format': 'json'}));
      final res = (j['results'] as List?) ?? const [];
      Map? best;
      for (final r in res) {
        if (r is Map && r['country_code'] == 'VN') {
          best = r;
          break;
        }
      }
      best ??= res.isNotEmpty && res.first is Map ? res.first as Map : null;
      if (best == null) return null;
      final admin = best['admin1'] is String && best['admin1'] != best['name'] ? ', ${best['admin1']}' : '';
      return ('${best['name']}$admin', _d(best['latitude']), _d(best['longitude']));
    } catch (_) {
      return null;
    }
  }

  /// Tìm một địa danh BẤT KỲ trên thế giới (quả địa cầu): thử tên tiếng Việt rồi tiếng Anh.
  /// Trả về (tên, nước, mã nước ISO2, vĩ độ, kinh độ, dân số) — null nếu không thấy.
  Future<({String name, String country, String cc, double lat, double lon, int pop})?> geocodeWorld(String name,
      {bool preferEnglish = false}) async {
    for (final lang in preferEnglish ? const ['en', 'vi'] : const ['vi', 'en']) {
      try {
        final j = await _getJson(Uri.https('geocoding-api.open-meteo.com', '/v1/search',
            {'name': name, 'count': '8', 'language': lang, 'format': 'json'}));
        final res = [for (final r in (j['results'] as List?) ?? const []) if (r is Map) r];
        if (res.isEmpty) continue;
        // ưu tiên nơi ở Việt Nam trùng tên; không có thì nơi đông dân nhất trong các kết quả đầu
        Map best = res.firstWhere((r) => r['country_code'] == 'VN', orElse: () => const {});
        if (best.isEmpty) {
          best = res.first;
          for (final r in res.take(4)) {
            if ((_i(r['population']) ?? 0) > (_i(best['population']) ?? 0)) best = r;
          }
        }
        return (
          name: '${best['name']}',
          country: '${best['country'] ?? ''}',
          cc: '${best['country_code'] ?? ''}',
          lat: _d(best['latitude']),
          lon: _d(best['longitude']),
          pop: _i(best['population']) ?? 0,
        );
      } catch (_) {}
    }
    return null;
  }

  /// ĐỊA ĐIỂM CỤ THỂ (hồ, chùa, công viên, phố, trường…): dịch vụ tìm thành phố ở trên không có → hỏi bản đồ mở
  /// OpenStreetMap qua Photon (komoot), không được thì Nominatim. Lấy vài kết quả rồi chọn cái GẦN nơi đang xem
  /// ([nearLat], [nearLon]) nhất, ưu tiên mạnh kết quả ở Việt Nam ("Hồ Tây" là hồ ở Hà Nội, không phải ở Đài Loan).
  /// Loại địa điểm được nhận khi tìm "hồ, chùa, núi, công viên, phố…": cảnh quan, di tích, nơi thờ tự, trường, bệnh viện,
  /// chợ, ga, sân bay, đường phố. KHÔNG nhận cửa hàng, salon, công ty, nhà xưởng, cảng hàng hoá… (người khiếm thị hỏi
  /// thời tiết / địa lý một nơi, không cần một quán trùng tên).
  static bool poiAllowed(String key, String value) {
    switch (key) {
      case 'natural':
      case 'water':
      case 'waterway':
      case 'tourism':
      case 'historic':
      case 'place':
      case 'boundary':
      case 'mountain_pass':
        return true;
      case 'leisure':
        return const {'park', 'garden', 'nature_reserve', 'stadium', 'beach_resort'}.contains(value);
      case 'amenity':
        return const {'place_of_worship', 'university', 'college', 'school', 'hospital', 'marketplace', 'theatre', 'library',
          'townhall'}.contains(value);
      case 'aeroway':
        return value == 'aerodrome';
      case 'railway':
        return value == 'station';
      case 'highway':
        return const {'primary', 'secondary', 'tertiary', 'residential', 'trunk', 'pedestrian', 'unclassified'}.contains(value);
      case 'bridge':
        return true;
      case 'man_made':
        return const {'bridge', 'tower', 'lighthouse'}.contains(value);
      case 'building':
        return const {'cathedral', 'church', 'temple', 'pagoda', 'shrine', 'yes', 'commercial', 'public'}.contains(value);
      case 'landuse':
        return const {'forest', 'reservoir', 'meadow'}.contains(value);
      default:
        return false;
    }
  }

  Future<({String name, String country, String cc, double lat, double lon})?> geocodePoi(String name,
      {double? nearLat, double? nearLon}) async {
    final ua = kIsWeb ? null : {'User-Agent': 'Lang/1.0 (NASA Space Apps 2026 app for blind users)'};
    final cands = <({String name, String country, String cc, double lat, double lon})>[];
    try {
      final u = Uri.https('photon.komoot.io', '/api/', {
        'q': name,
        'limit': '6',
        if (nearLat != null && nearLon != null) ...{'lat': nearLat.toStringAsFixed(3), 'lon': nearLon.toStringAsFixed(3)},
      });
      final r = await client.get(u, headers: ua).timeout(_timeout);
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      for (final f in (j is Map ? (j['features'] as List?) : null) ?? const []) {
        if (f is! Map) continue;
        final c = (f['geometry'] as Map)['coordinates'] as List;
        final p = (f['properties'] as Map?) ?? const {};
        if (!poiAllowed('${p['osm_key'] ?? ''}', '${p['osm_value'] ?? ''}')) continue;
        cands.add((
          name: '${p['name'] ?? name}',
          country: '${p['country'] ?? ''}',
          cc: '${p['countrycode'] ?? ''}'.toUpperCase(),
          lat: _d(c[1]),
          lon: _d(c[0]),
        ));
      }
    } catch (e) {
      log?.call('[tìm địa điểm Photon] $e');
    }
    // Photon không có kết quả nào đúng tên → hỏi thêm Nominatim
    final q0 = _fold(name);
    if (!cands.any((c) => _fold(c.name) == q0 || _fold(c.name).startsWith('$q0 '))) {
      try {
        final u = Uri.https('nominatim.openstreetmap.org', '/search',
            {'q': name, 'format': 'json', 'limit': '6', 'accept-language': 'vi', 'addressdetails': '1'});
        final r = await client.get(u, headers: ua).timeout(_timeout);
        if (r.statusCode == 200) {
          final list = jsonDecode(utf8.decode(r.bodyBytes));
          for (final m in list is List ? list : const []) {
            if (m is! Map) continue;
            if (!poiAllowed('${m['class'] ?? ''}', '${m['type'] ?? ''}')) continue;
            final addr = (m['address'] as Map?) ?? const {};
            cands.add((
              name: '${m['name'] ?? '${m['display_name']}'.split(',').first}',
              country: '${addr['country'] ?? ''}',
              cc: '${addr['country_code'] ?? ''}'.toUpperCase(),
              lat: double.tryParse('${m['lat']}') ?? double.nan,
              lon: double.tryParse('${m['lon']}') ?? double.nan,
            ));
          }
        }
      } catch (e) {
        log?.call('[tìm địa điểm Nominatim] $e');
      }
    }
    cands.removeWhere((c) => c.lat.isNaN || c.lon.isNaN);
    if (cands.isEmpty) return null;
    // chưa đứng ở đâu → giữ thứ tự của dịch vụ (đã xếp theo độ nổi tiếng: "Hồ Tây" ở Hà Nội trước Hồ Tây ở tỉnh khác)
    final order = {for (var i = 0; i < cands.length; i++) cands[i]: i};
    double score(({String name, String country, String cc, double lat, double lon}) c) {
      if (nearLat == null || nearLon == null) {
        final cn = _fold(c.name), q = _fold(name);
        final k = cn == q ? 0.05 : (cn.startsWith('$q ') || cn.endsWith(' $q')) ? 0.2 : ' $cn '.contains(' $q ') ? 0.5 : 3.0;
        return (order[c]! + 1) * 100 * k * (c.cc == 'VN' ? 0.2 : 1);
      }
      final dLat = (c.lat - nearLat) * math.pi / 180, dLon = (c.lon - nearLon) * math.pi / 180;
      final h = math.pow(math.sin(dLat / 2), 2) +
          math.cos(c.lat * math.pi / 180) * math.cos(nearLat * math.pi / 180) * math.pow(math.sin(dLon / 2), 2);
      final km = 12742 * math.asin(math.sqrt(h.clamp(0, 1))) + 1;
      // tên phải khớp câu hỏi: "Hồ Tây" ≠ "Đường Hồ Chí Minh nhánh Tây"
      final cn = _fold(c.name), q = _fold(name);
      final k = cn == q
          ? 0.05
          : (cn.startsWith('$q ') || cn.endsWith(' $q') || q.endsWith(' $cn'))
              ? 0.2
              : ' $cn '.contains(' $q ')
                  ? 0.5
                  : 3.0;
      return km * k * (c.cc == 'VN' ? 0.2 : 1);
    }
    cands.sort((x, y) => score(x).compareTo(score(y)));
    return cands.first;
  }

  /// XÃ / PHƯỜNG / THỊ TRẤN / LÀNG ở Việt Nam (dịch vụ tìm thành phố không có các đơn vị nhỏ này).
  /// Tìm trên OpenStreetMap (Nominatim), chỉ trong Việt Nam. Hiểu cả tên tỉnh kèm theo ("xã Tân Lập, Tây Ninh",
  /// kể cả tên tỉnh cũ trước sáp nhập) để lọc. Trả về MỌI nơi khớp tên (nhiều tỉnh có xã trùng tên) — nơi gọi tự chọn / hỏi lại.
  Future<List<VnPlace>> geocodeVnAll(String name) async {
    final ua = kIsWeb ? null : {'User-Agent': 'Lang/1.0 (NASA Space Apps 2026 app for blind users)'};
    final sp = splitProvince(name);
    final place = sp.place;
    final plain = stripAdminPrefix(place);
    final want = foldVi(plain);
    if (want.length < 2) return const [];
    const goodTypes = {
      'administrative', 'historic', 'village', 'hamlet', 'suburb', 'town', 'quarter', 'neighbourhood', 'city', 'municipality',
      'island', 'residential', 'isolated_dwelling', 'locality',
    };
    final out = <VnPlace>[];
    for (final q in {place, plain}) {
      try {
        final u = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': q,
          'format': 'json',
          'limit': '10',
          'countrycodes': 'vn',
          'accept-language': 'vi',
          'addressdetails': '1',
        });
        final r = await client.get(u, headers: ua).timeout(_timeout);
        if (r.statusCode != 200) continue;
        final list = jsonDecode(utf8.decode(r.bodyBytes));
        for (final m in list is List ? list : const []) {
          if (m is! Map || !goodTypes.contains('${m['type']}')) continue;
          final n = '${m['name'] ?? ''}';
          // tên phải khớp (bỏ "Xã", "Phường"…): không lấy nghĩa trang, công ty… trùng chữ
          if (foldVi(stripAdminPrefix(n)) != want) continue;
          final addr = (m['address'] as Map?) ?? const {};
          final prov = '${addr['state'] ?? addr['province'] ?? addr['city'] ?? ''}'
              .replaceFirst(RegExp(r'^(Tỉnh|Thành phố|Thành Phố)\s+'), '');
          final lat = double.tryParse('${m['lat']}'), lon = double.tryParse('${m['lon']}');
          if (lat == null || lon == null) continue;
          final current = '${m['type']}' != 'historic'; // "historic" = đơn vị cũ đã bỏ / sáp nhập
          final dup = out.indexWhere((x) => foldVi(x.province) == foldVi(prov) && foldVi(stripAdminPrefix(x.name)) == want);
          final v = VnPlace(n, prov, lat, lon, current);
          if (dup < 0) {
            out.add(v);
          } else if (!out[dup].current && current) {
            out[dup] = v;
          }
        }
      } catch (e) {
        log?.call('[tìm xã/phường] $e');
      }
      if (out.isNotEmpty) break;
    }
    if (sp.province != null) {
      final inProv = out.where((x) => sameProvince(x.province, sp.province!)).toList();
      return inProv;
    }
    // đơn vị đang dùng trước, đơn vị cũ sau
    out.sort((a, b) => (b.current ? 1 : 0).compareTo(a.current ? 1 : 0));
    return out;
  }

  /// Một nơi (nơi đầu tiên) — giữ cho mã cũ.
  Future<({String name, String province, double lat, double lon})?> geocodeVn(String name) async {
    final all = await geocodeVnAll(name);
    if (all.isEmpty) return null;
    final v = all.first;
    return (name: v.name, province: v.province, lat: v.lat, lon: v.lon);
  }

  static String _fold(String s) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  // ---------- Google Weather API ----------
  Future<LiveWeather> _google(double lat, double lon, String lang) async {
    Map<String, String> q([Map<String, String> more = const {}]) => {
          'key': googleKey.trim(),
          'location.latitude': lat.toStringAsFixed(4),
          'location.longitude': lon.toStringAsFixed(4),
          'languageCode': lang,
          ...more,
        };
    final res = await Future.wait([
      _getJson(Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', q())),
      _getJson(Uri.https('weather.googleapis.com', '/v1/forecast/hours:lookup', q({'hours': '48', 'pageSize': '48'}))),
      _getJson(Uri.https('weather.googleapis.com', '/v1/forecast/days:lookup', q({'days': '10', 'pageSize': '10'}))),
    ]);
    final aqiF = _airQuality(lat, lon);
    final c = res[0];
    double deg(Object? m) => m is Map ? _d(m['degrees']) : double.nan;
    String desc(Object? wc) => wc is Map && wc['description'] is Map ? '${(wc['description'] as Map)['text'] ?? ''}' : '';
    int code(Object? wc) => _googleToWmo(wc is Map ? '${wc['type']}' : '');
    int? prob(Object? p) => p is Map && p['probability'] is Map ? _i((p['probability'] as Map)['percent']) : null;
    final wind = c['wind'] is Map ? c['wind'] as Map : const {};
    final now = LiveNow(
      temp: deg(c['temperature']),
      feels: deg(c['feelsLikeTemperature']),
      humidity: _i(c['relativeHumidity']) ?? 0,
      precip: c['precipitation'] is Map && (c['precipitation'] as Map)['qpf'] is Map
          ? _d(((c['precipitation'] as Map)['qpf'] as Map)['quantity'], 0)
          : 0,
      desc: desc(c['weatherCondition']).toLowerCase(),
      code: code(c['weatherCondition']),
      wind: wind['speed'] is Map ? _d((wind['speed'] as Map)['value'], 0) : 0,
      windDir: wind['direction'] is Map ? _compass(_d((wind['direction'] as Map)['degrees'])) : null,
      uv: c['uvIndex'] is num ? _d(c['uvIndex']) : null,
    );
    if (now.temp.isNaN) throw const LiveError('Google Weather không có dữ liệu chỗ này.', 'Google Weather has no data here.');
    final hours = <LiveHour>[];
    for (final h in (res[1]['forecastHours'] as List?) ?? const []) {
      if (h is! Map) continue;
      final st = h['interval'] is Map ? DateTime.tryParse('${(h['interval'] as Map)['startTime']}')?.toLocal() : null;
      if (st == null) continue;
      hours.add(LiveHour(st, deg(h['temperature']), prob(h['precipitation']), code(h['weatherCondition']),
          desc(h['weatherCondition']).toLowerCase()));
    }
    final days = <LiveDay>[];
    for (final d in (res[2]['forecastDays'] as List?) ?? const []) {
      if (d is! Map) continue;
      final dd = d['displayDate'] is Map ? d['displayDate'] as Map : const {};
      final day = d['daytimeForecast'] is Map ? d['daytimeForecast'] as Map : const {};
      final night = d['nighttimeForecast'] is Map ? d['nighttimeForecast'] as Map : const {};
      final pd = prob(day['precipitation']), pn = prob(night['precipitation']);
      double? qpf(Map m) => m['precipitation'] is Map && (m['precipitation'] as Map)['qpf'] is Map
          ? _d(((m['precipitation'] as Map)['qpf'] as Map)['quantity'], 0)
          : null;
      final qd = qpf(day), qn = qpf(night);
      days.add(LiveDay(
        DateTime(_i(dd['year']) ?? 2000, _i(dd['month']) ?? 1, _i(dd['day']) ?? 1),
        deg(d['maxTemperature']),
        deg(d['minTemperature']),
        pd == null && pn == null ? null : ((pd ?? 0) > (pn ?? 0) ? pd : pn),
        qd == null && qn == null ? null : (qd ?? 0) + (qn ?? 0),
        code(day['weatherCondition']),
        desc(day['weatherCondition']).toLowerCase(),
        day['uvIndex'] is num ? _d(day['uvIndex']) : null,
        day['wind'] is Map && (day['wind'] as Map)['speed'] is Map ? _d(((day['wind'] as Map)['speed'] as Map)['value']) : null,
      ));
    }
    final air = await aqiF;
    return LiveWeather('Google', DateTime.now(), now, hours, days,
        aqi: air.aqi, pm25: air.pm25, pm10: air.pm10, aod: air.aod, dust: air.dust);
  }

  /// Loại thời tiết của Google → mã WMO gần đúng (để dùng chung lời khuyên).
  static int _googleToWmo(String t) {
    if (t.contains('HAIL')) return 96;
    if (t.contains('THUNDER')) return 95;
    if (t.contains('HEAVY_RAIN')) return 65;
    if (t.contains('SHOWER')) return 81;
    if (t.contains('LIGHT_RAIN') || t == 'RAIN_PERIODICALLY_HEAVY') return 61;
    if (t.contains('RAIN')) return 63;
    if (t.contains('DRIZZLE')) return 53;
    if (t.contains('SNOW')) return 73;
    if (t.contains('FOG') || t.contains('HAZE')) return 45;
    if (t == 'CLEAR') return 0;
    if (t == 'MOSTLY_CLEAR') return 1;
    if (t == 'PARTLY_CLOUDY') return 2;
    if (t.contains('CLOUDY')) return 3;
    return -1;
  }
}

/// Một xã / phường / làng ở Việt Nam tìm được trên bản đồ mở.
class VnPlace {
  final String name, province;
  final double lat, lon;
  final bool current; // false = đơn vị cũ (trước sáp nhập 2025)
  const VnPlace(this.name, this.province, this.lat, this.lon, this.current);
}

