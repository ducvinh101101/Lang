// DỮ LIỆU KHÍ HẬU NASA cho MỌI ĐIỂM trên Trái Đất: NASA POWER (power.larc.nasa.gov, miễn phí, không cần khoá).
// Lấy nhiệt độ 2 m (T2M) và lượng mưa (PRECTOTCORR) theo tháng từ 1981 tới năm ngoái → xu hướng ấm lên,
// năm nóng nhất, một tháng cụ thể so với trung bình.
// XU HƯỚNG DÀI HẠN (xưa – nay) KHÔNG lấy từ POWER mà từ ERA5: xem [NasaPowerService.extremes]. Bản web: nếu trình duyệt bị chặn gọi thẳng (CORS) thì đi qua
// /api/nasa trên Vercel (api/nasa.mjs).
//
// Số liệu MỘT NGÀY bất kỳ (1940 → 15 ngày tới) ở một điểm: Open-Meteo (lưu trữ ERA5 / dự báo).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../data/nasa_normalized_data.dart';
import 'live_weather.dart' show LiveError, wmoText;

class NasaClimate {
  final double lat, lon;
  final int y0, y1; // năm đầu, năm cuối
  final List<double> tempYear; // nhiệt độ trung bình từng năm (°C), NaN nếu thiếu
  final List<double> rainYear; // tổng mưa từng năm (mm)
  final Map<int, List<double>> tempMonth; // năm → 12 tháng (°C)
  final Map<int, List<double>> rainMonth; // năm → 12 tháng (mm cả tháng)
  final List<double> humYear; // độ ẩm tương đối trung bình năm (%), NaN nếu thiếu
  final List<double> uvYear; // chỉ số UV trung bình năm (bức xạ UV bề mặt), NaN nếu thiếu
  NasaClimate(this.lat, this.lon, this.y0, this.y1, this.tempYear, this.rainYear, this.tempMonth, this.rainMonth,
      {this.humYear = const [], this.uvYear = const []});

  /// Trung bình 10 năm đầu của một chuỗi năm (NaN nếu thiếu).
  double early(List<double> xs) => _mean(xs.take(10));

  /// Trung bình 10 năm gần nhất của một chuỗi năm (NaN nếu thiếu).
  double recent(List<double> xs) => _mean(xs.skip(math.max(0, xs.length - 10)));

  double _mean(Iterable<double> xs) {
    final v = xs.where((x) => !x.isNaN).toList();
    return v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
  }

  /// Trung bình 10 năm đầu và 10 năm gần nhất.
  (double, double) tempDecades() => (_mean(tempYear.take(10)), _mean(tempYear.skip(math.max(0, tempYear.length - 10))));
  (double, double) rainDecades() => (_mean(rainYear.take(10)), _mean(rainYear.skip(math.max(0, rainYear.length - 10))));

  /// Năm nóng nhất.
  int hottestYear() {
    var best = y0;
    var bv = -999.0;
    for (var k = 0; k < tempYear.length; k++) {
      if (!tempYear[k].isNaN && tempYear[k] > bv) {
        bv = tempYear[k];
        best = y0 + k;
      }
    }
    return best;
  }

  /// Trung bình của một tháng qua mọi năm (để so sánh).
  double monthNormal(Map<int, List<double>> m, int month) => _mean(m.values.map((v) => v[month]));
}

class DayRecord {
  final DateTime date;
  final double tmax, tmin, rain, wind;
  final String desc;
  const DayRecord(this.date, this.tmax, this.tmin, this.rain, this.wind, this.desc);
}

class NasaPowerService {
  final http.Client client;
  void Function(String)? log;
  NasaPowerService(this.client, {this.log});

  final _cache = <String, NasaClimate>{};

  Future<Map<String, dynamic>> _get(Uri u) async {
    final r = await client.get(u).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw LiveError('Máy chủ NASA báo lỗi ${r.statusCode}.', 'NASA server error ${r.statusCode}.');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<NasaClimate> climate(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(1)}|${lon.toStringAsFixed(1)}';
    final hit = _cache[key];
    if (hit != null) return hit;

    // Ưu tiên kho dữ liệu chuẩn hóa NASA POWER (1981–2025) đã đóng gói sẵn trong ứng dụng
    final repo = NasaNormalizedRepo.cached ?? await NasaNormalizedRepo.load();
    final normHit = repo.findClimateNear(lat, lon);
    if (normHit != null) {
      _cache[key] = normHit;
      return normHit;
    }

    // Chốt năm cuối <= 2025 theo quy tắc chuẩn hóa NASA POWER (tránh các tháng năm hiện tại bị nhân 24 hoặc -999)
    final end = math.min(DateTime.now().year - 1, 2025);
    Map<String, dynamic>? j;
    Object? err;
    // thử đủ bộ (nhiệt, mưa, độ ẩm, UV); nếu máy chủ không nhận UV thì lấy bộ cơ bản
    for (final (e, params) in [
      (end, 'T2M,PRECTOTCORR,RH2M,ALLSKY_SFC_UV_INDEX'),
      (end - 1, 'T2M,PRECTOTCORR,RH2M,ALLSKY_SFC_UV_INDEX'),
      (end - 1, 'T2M,PRECTOTCORR,RH2M'),
    ]) {
      final q = {
        'parameters': params,
        'community': 'AG',
        'latitude': lat.toStringAsFixed(2),
        'longitude': lon.toStringAsFixed(2),
        'start': '1981',
        'end': '$e',
        'format': 'JSON',
      };
      // bản web: đi qua máy chủ Vercel của app TRƯỚC (CDN giữ bản sao 1 ngày, NASA POWER vốn chậm vài giây);
      // máy chủ lỗi thì gọi thẳng NASA
      final urls = [
        if (kIsWeb) Uri.base.resolve('/api/nasa').replace(queryParameters: q),
        Uri.https('power.larc.nasa.gov', '/api/temporal/monthly/point', q),
      ];
      for (final u in urls) {
        try {
          j = await _get(u);
          break;
        } catch (x) {
          err = x;
          log?.call('[NASA POWER] $u → $x');
        }
      }
      if (j != null) break;
    }
    if (j == null) {
      if (err is LiveError) throw err;
      throw const LiveError('Chưa lấy được dữ liệu NASA. Kiểm tra mạng rồi thử lại.',
          'Could not get NASA data. Check the connection and try again.');
    }
    final par = ((j['properties'] as Map?)?['parameter'] as Map?) ?? const {};
    final t = (par['T2M'] as Map?) ?? const {};
    final p = (par['PRECTOTCORR'] as Map?) ?? const {};
    final rh = (par['RH2M'] as Map?) ?? const {};
    final uv = (par['ALLSKY_SFC_UV_INDEX'] as Map?) ?? const {};
    final hy = <double>[], uy = <double>[];
    double v(Map m, String k) {
      final x = m[k];
      return x is num && x > -900 ? x.toDouble() : double.nan;
    }

    var y0 = 9999, y1 = 0;
    for (final k in t.keys) {
      final y = int.tryParse('$k'.substring(0, 4));
      if (y == null) continue;
      y0 = math.min(y0, y);
      y1 = math.max(y1, y);
    }
    if (y1 == 0) throw const LiveError('NASA không có số liệu ở điểm này.', 'NASA has no data for this point.');
    const days = [31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final ty = <double>[], ry = <double>[];
    final tm = <int, List<double>>{}, rm = <int, List<double>>{};
    for (var y = y0; y <= y1; y++) {
      tm[y] = [for (var m = 1; m <= 12; m++) v(t, '$y${m.toString().padLeft(2, '0')}')];
      rm[y] = [for (var m = 1; m <= 12; m++) v(p, '$y${m.toString().padLeft(2, '0')}') * days[m - 1]];
      ty.add(v(t, '${y}13'));
      final ann = v(p, '${y}13');
      ry.add(ann.isNaN ? double.nan : ann * 365.25);
      hy.add(v(rh, '${y}13'));
      uy.add(v(uv, '${y}13'));
    }
    final c = NasaClimate(lat, lon, y0, y1, ty, ry, tm, rm, humYear: hy, uvYear: uy);
    if (_cache.length > 30) _cache.clear();
    _cache[key] = c;
    return c;
  }

  /// Thời tiết MỘT NGÀY ở một điểm (quá khứ từ 1940, hoặc tối đa 15 ngày tới).
  Future<DayRecord> day(double lat, double lon, DateTime d) async {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final diff = DateTime(d.year, d.month, d.day).difference(t0).inDays;
    if (diff > 15) {
      throw const LiveError('Chỉ dự báo được tối đa 15 ngày tới.', 'Forecasts only go 15 days ahead.');
    }
    final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final host = diff < -80 ? 'archive-api.open-meteo.com' : 'api.open-meteo.com';
    final path = diff < -80 ? '/v1/archive' : '/v1/forecast';
    final j = await _get(Uri.https(host, path, {
      'latitude': lat.toStringAsFixed(3),
      'longitude': lon.toStringAsFixed(3),
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code',
      'timezone': 'auto',
      'start_date': ds,
      'end_date': ds,
    }));
    final dj = (j['daily'] as Map?) ?? const {};
    double at(String k) {
      final l = dj[k];
      return l is List && l.isNotEmpty && l.first is num ? (l.first as num).toDouble() : double.nan;
    }

    final code = at('weather_code');
    if (at('temperature_2m_max').isNaN) {
      throw const LiveError('Chưa có số liệu cho ngày này.', 'No data for that day yet.');
    }
    return DayRecord(d, at('temperature_2m_max'), at('temperature_2m_min'), at('precipitation_sum'),
        at('wind_speed_10m_max'), code.isNaN ? '' : wmoText(code.round()).$1);
  }

  /// XƯA VÀ NAY ở một điểm, TỪ MỘT NGUỒN THỐNG NHẤT: lưu trữ tái phân tích ERA5 (Copernicus/ECMWF, qua Open-Meteo),
  /// từ 1981 tới năm ngoái, theo ngày.
  ///
  /// Vì sao không dùng NASA POWER cho xu hướng dài hạn: kiểm chứng ngày 14/11/2026 với chính API POWER cho thấy chuỗi
  /// PRECTOTCORR / T2M ở Việt Nam KHÔNG ĐỒNG NHẤT theo thời gian: mưa thập niên 1980 chỉ bằng một nửa thực tế
  /// (Hà Nội 844 mm/năm, Đà Lạt năm 1987 chỉ 97 mm), mưa nhảy bậc quanh 2016 (Gia Lai 502 → 2.217 mm/năm), nhiệt độ
  /// thập niên 1980 cao bất thường (Hà Nội 1985 có 88 ngày ≥ 35 °C, cao nhất 44 °C). So xưa–nay bằng POWER sẽ nói sai
  /// "Hà Nội mát đi 1 độ, mưa tăng gấp đôi". ERA5 cùng điểm: ấm lên ~1,0 °C, mưa 1.859 → 2.159 mm, ngày nóng 12 → 23.
  /// POWER vẫn dùng cho giá trị từng tháng / từng năm và cho F1 trong khoảng gần.
  Future<EraTrend> extremes(double lat, double lon) async {
    final y = DateTime.now().year - 1;
    final key = '${lat.toStringAsFixed(1)}|${lon.toStringAsFixed(1)}';
    final hit = _trendCache[key];
    if (hit != null) return hit;
    final j = await _get(Uri.https('archive-api.open-meteo.com', '/v1/archive', {
      'latitude': lat.toStringAsFixed(3),
      'longitude': lon.toStringAsFixed(3),
      'start_date': '1981-01-01',
      'end_date': '$y-12-31',
      'daily': 'temperature_2m_max,temperature_2m_mean,precipitation_sum',
      'timezone': 'auto',
    }));
    final d = (j['daily'] as Map?) ?? const {};
    final time = (d['time'] as List?) ?? const [];
    final tx = (d['temperature_2m_max'] as List?) ?? const [];
    final tm = (d['temperature_2m_mean'] as List?) ?? const [];
    final pr = (d['precipitation_sum'] as List?) ?? const [];
    final n = y - 1981 + 1;
    final tSum = List<double>.filled(n, 0), tN = List<int>.filled(n, 0), rSum = List<double>.filled(n, 0);
    final h35 = List<int>.filled(n, 0), h37 = List<int>.filled(n, 0), h39 = List<int>.filled(n, 0), w50 = List<int>.filled(n, 0);
    for (var i = 0; i < time.length; i++) {
      final k = (int.tryParse('${time[i]}'.substring(0, 4)) ?? 0) - 1981;
      if (k < 0 || k >= n) continue;
      final a = i < tm.length ? tm[i] : null, b = i < tx.length ? tx[i] : null, c = i < pr.length ? pr[i] : null;
      if (a is num) {
        tSum[k] += a;
        tN[k]++;
      }
      if (b is num) {
        if (b >= 35) h35[k]++;
        if (b >= 37) h37[k]++;
        if (b >= 39) h39[k]++;
      }
      if (c is num) {
        rSum[k] += c;
        if (c >= 50) w50[k]++;
      }
    }
    final tY = [for (var k = 0; k < n; k++) tN[k] >= 300 ? tSum[k] / tN[k] : double.nan];
    final rY = [for (var k = 0; k < n; k++) tN[k] >= 300 ? rSum[k] : double.nan];
    if (tY.every((x) => x.isNaN)) {
      throw const LiveError('Chưa lấy được số liệu dài hạn ở điểm này.', 'No long-term data for this point.');
    }
    double avg(List<num> xs, int from, int to) {
      var s = 0.0, c = 0;
      for (var yy = from; yy <= to; yy++) {
        final k = yy - 1981;
        if (k < 0 || k >= n || tN[k] < 300) continue;
        final v = xs[k].toDouble();
        if (v.isNaN) continue;
        s += v;
        c++;
      }
      return c == 0 ? double.nan : s / c;
    }

    final b0 = y - 9;
    final r = EraTrend(
      y0: 1981,
      y1: y,
      tempYear: tY,
      rainYear: rY,
      t0: avg(tY, 1981, 1990),
      t1: avg(tY, b0, y),
      rain0: avg(rY, 1981, 1990),
      rain1: avg(rY, b0, y),
      hot0: avg(h35, 1981, 1990),
      hot1: avg(h35, b0, y),
      hot37_0: avg(h37, 1981, 1990),
      hot37_1: avg(h37, b0, y),
      hot39_0: avg(h39, 1981, 1990),
      hot39_1: avg(h39, b0, y),
      wet0: avg(w50, 1981, 1990),
      wet1: avg(w50, b0, y),
      a0: 1981,
      a1: 1990,
      b0: b0,
      b1: y,
    );
    if (_trendCache.length > 30) _trendCache.clear();
    _trendCache[key] = r;
    return r;
  }

  final _trendCache = <String, EraTrend>{};
}

/// Xu hướng dài hạn ở một điểm từ ERA5 (xem [NasaPowerService.extremes]): trung bình năm 1981–1990 (`…0`) so với
/// 10 năm gần nhất (`…1`), kèm chuỗi từng năm để phát âm thanh.
class EraTrend {
  final int y0, y1, a0, a1, b0, b1;
  final List<double> tempYear, rainYear;
  final double t0, t1, rain0, rain1, hot0, hot1, hot37_0, hot37_1, hot39_0, hot39_1, wet0, wet1;
  const EraTrend({
    required this.y0,
    required this.y1,
    required this.tempYear,
    required this.rainYear,
    required this.t0,
    required this.t1,
    required this.rain0,
    required this.rain1,
    required this.hot0,
    required this.hot1,
    required this.hot37_0,
    required this.hot37_1,
    required this.hot39_0,
    required this.hot39_1,
    required this.wet0,
    required this.wet1,
    required this.a0,
    required this.a1,
    required this.b0,
    required this.b1,
  });

  /// Năm nóng nhất trong chuỗi.
  int hottestYear() {
    var best = y0;
    var bv = -999.0;
    for (var k = 0; k < tempYear.length; k++) {
      if (!tempYear[k].isNaN && tempYear[k] > bv) {
        bv = tempYear[k];
        best = y0 + k;
      }
    }
    return best;
  }

  /// Chuỗi từng năm dưới dạng [NasaClimate] để dùng lại bộ phát âm thanh "mỗi năm một nốt".
  NasaClimate asYears(double lat, double lon) => NasaClimate(lat, lon, y0, y1, tempYear, rainYear, const {}, const {});
}
