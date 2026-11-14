// Dữ liệu GIẢ LẬP, chuyển nguyên từ web/index.html để app chạy được khi chưa có dữ liệu NASA.
// Không dùng cho bài nộp; app luôn báo "dữ liệu mô phỏng" khi dùng nguồn này.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/geo.dart';
import '../core/noise.dart';
import 'climate_data.dart';

class _Event {
  final int y, m; // m: 0..11
  final List<int> regs;
  final double f;
  final String vi, en;
  const _Event(this.y, this.m, this.regs, this.f, this.vi, this.en);
}

const _events = <_Event>[
  _Event(2008, 9, [1], 1.9, 'Mưa cực lớn Hà Nội cuối tháng 10/2008', 'Extreme rain in Hà Nội, late Oct 2008'),
  _Event(2016, 11, [2, 3], 1.7, 'Lũ chồng lũ miền Trung tháng 12/2016', 'Repeated floods in Central Vietnam, Dec 2016'),
  _Event(2017, 10, [3], 1.6, 'Bão Damrey tháng 11/2017', 'Typhoon Damrey, Nov 2017'),
  _Event(2020, 9, [2], 1.85, 'Chuỗi bão lũ miền Trung tháng 10/2020', 'Series of storms and floods, Central Vietnam, Oct 2020'),
  _Event(2023, 9, [2], 1.5, 'Mưa lớn Huế – Đà Nẵng tháng 10/2023', 'Heavy rain Huế – Đà Nẵng, Oct 2023'),
  _Event(2024, 8, [0, 1], 2.0, 'Bão Yagi tháng 9/2024', 'Typhoon Yagi, Sep 2024'),
];
const _dryYears = [2010, 2016, 2019, 2024];

double _circ(double m, double c) {
  final d = m - c;
  return ((d + 6) % 12 + 12) % 12 - 6;
}

double _bump(int m, double c, double w) {
  final d = _circ(m.toDouble(), c);
  return math.exp(-0.5 * (d / w) * (d / w));
}

class SyntheticData extends ClimateData {
  final BuiltinGeo _b = builtinGeo();
  late final Float32List _elev = _buildElev();
  final _cache = LinkedHashMap<String, Float32List>();
  final _seriesCache = <String, RegionSeries>{};
  late final List<List<int>> _samples = _buildSamples();

  @override
  String get id => 'synthetic';
  @override
  bool get isSimulated => true;
  @override
  String label(String lang) => lang == 'vi' ? 'Dữ liệu mô phỏng (chưa phải NASA)' : 'Simulated data (not NASA yet)';

  @override
  GeoGrid get geo => _b.grid;

  @override
  final List<int> years = List<int>.generate(25, (k) => 2001 + k);

  @override
  final Map<String, VarMeta> vars = const {
    'temp': VarMeta(
        key: 'temp', vi: 'Nhiệt độ bề mặt', en: 'Surface temperature', unitVi: '°C', unitEn: '°C',
        spokenVi: 'độ C', spokenEn: 'degrees Celsius', min: 10, max: 34, decimals: 1, instrument: 'danbau'),
    'rain': VarMeta(
        key: 'rain', vi: 'Lượng mưa', en: 'Rainfall', unitVi: 'mm', unitEn: 'mm',
        spokenVi: 'mi-li-mét', spokenEn: 'millimetres', min: 0, max: 900, decimals: 0, sqrtScale: true,
        instrument: 'trung'),
    'fire': VarMeta(
        key: 'fire', vi: 'Điểm cháy', en: 'Fire hotspots', unitVi: 'điểm', unitEn: 'hotspots',
        spokenVi: 'điểm cháy', spokenEn: 'hotspots', min: 0, max: 8, decimals: 1, instrument: 'fire'),
  };

  double _lon(int i) => cellLon(i);
  double _lat(int i) => cellLat(i);

  Float32List _buildElev() {
    final e = Float32List(nCells);
    for (var i = 0; i < nCells; i++) {
      if (geo.type[i] != cellVn) continue;
      final lon = _lon(i), lat = _lat(i), reg = geo.region[i];
      double v;
      if (reg == 0) {
        v = 0.7 + 0.7 * vnoise(lon * 1.3, lat * 1.3, 7);
      } else if (reg == 1) {
        v = lat > 21.2 ? 0.25 + 0.5 * vnoise(lon * 1.3, lat * 1.3, 8) : 0.02;
      } else if (reg == 4) {
        v = 0.45 + 0.45 * vnoise(lon * 1.5, lat * 1.5, 9);
      } else if (reg == 2 || reg == 3) {
        v = 0.9 * math.exp(-_b.west[i] / 0.45) * (0.6 + 0.6 * vnoise(lon * 2, lat * 2, 10));
      } else {
        v = 0.03;
      }
      if (reg != 5) {
        v += 1.0 * math.exp(-((lon - 108.44) * (lon - 108.44) + (lat - 11.94) * (lat - 11.94)) / 0.06);
      }
      e[i] = v;
    }
    return e;
  }

  List<List<int>> _buildSamples() {
    final s = List<List<int>>.generate(regions.length, (_) => <int>[]);
    for (var i = 0; i < nCells; i++) {
      if (geo.type[i] != cellVn) continue;
      final r = i ~/ gw, c = i % gw;
      if (r % 2 == 0 && c % 2 == 0) s[geo.region[i]].add(i);
    }
    return s;
  }

  double _tempClim(int i, int m) {
    final lat = _lat(i);
    final n = math.min(1.0, math.max(0.0, (lat - 10.5) / 11.5));
    final tm = 27.4 - 0.24 * math.max(0.0, lat - 11);
    return tm +
        n * 6.6 * math.cos(2 * math.pi * (m - 6.2) / 12) +
        (1 - n) * 1.1 * math.cos(2 * math.pi * (m - 3.6) / 12) -
        5.8 * _elev[i];
  }

  double _rainClim(int i, int m) {
    final lon = _lon(i), lat = _lat(i), reg = geo.region[i];
    double r;
    switch (reg) {
      case 0:
        r = 15 + 290 * _bump(m, 6.6, 1.9);
      case 1:
        r = 20 + 290 * _bump(m, 7.1, 1.8);
      case 2:
        final k = math.min(1.0, math.max(0.0, (lat - 16) / 3.9));
        r = 45 + (720 - 300 * k) * _bump(m, 9.4 - 1.3 * k, 1.25) + 90 * _bump(m, 4.8, 0.8);
      case 3:
        final f = math.min(1.0, math.max(0.12, (lat - 10.9) / 4.6));
        r = 18 + 620 * f * _bump(m, 9.8, 1.15) + 40 * _bump(m, 5, 1);
      case 4:
        r = 8 + 300 * _bump(m, 7.6, 2.2);
      default:
        r = (6 + 290 * _bump(m, 8.3, 2.3)) * (lat < 9.8 ? 1.25 : 1.0);
    }
    r *= 0.8 + 0.4 * vnoise(lon * 1.2, lat * 1.2, 11);
    if (reg == 2 || reg == 3) r *= 0.8 + 0.35 * math.exp(-_b.coastCells[i] / 5);
    return r;
  }

  double _fireClim(int i, int m) {
    final lon = _lon(i), lat = _lat(i);
    double f;
    switch (geo.region[i]) {
      case 0:
        f = 3.2 * _bump(m, 2.4, 0.85);
      case 1:
        f = 0.9 * _bump(m, 2.3, 1) + 0.3 * _bump(m, 9.5, 0.8);
      case 2:
        f = 0.9 * _bump(m, 4.6, 1.1);
      case 3:
        f = 0.6 * _bump(m, 2.8, 1.2);
      case 4:
        f = 1.9 * _bump(m, 1.6, 1);
      default:
        f = 1.5 * _bump(m, 1.8, 1) + 0.5 * _bump(m, 5.5, 0.6);
    }
    return f * (0.25 + 1.5 * vnoise(lon * 2.2, lat * 2.2, 23));
  }

  double _valueAt(String v, int i, int y, int m) {
    final reg = geo.region[i], lon = _lon(i), lat = _lat(i);
    if (v == 'temp') {
      var t = _tempClim(i, m) +
          0.027 * (y - 2013) +
          0.55 * gauss3(reg, y, m + 100) +
          0.6 * (vnoise(lon * 1.5, lat * 1.5, y * 12 + m) - 0.5);
      if ((y == 2016 && m < 6) || (y == 2024 && m < 7) || (y == 2019 && m > 3 && m < 7)) t += 0.6;
      return t;
    }
    if (v == 'rain') {
      var r = _rainClim(i, m) *
          math.max(0.08, 1 + 0.3 * gauss3(reg, y, m + 300) + 0.4 * (vnoise(lon * 1.5, lat * 1.5, y * 12 + m + 7) - 0.5));
      for (final e in _events) {
        if (e.y == y && e.m == m && e.regs.contains(reg)) {
          r *= e.f * (0.85 + 0.3 * vnoise(lon * 2, lat * 2, e.y));
        }
      }
      return r;
    }
    var f = _fireClim(i, m) * math.max(0.0, 1 + 0.4 * gauss3(reg, y, m + 500));
    if (_dryYears.contains(y) && m <= 4) f *= 1.75;
    return f;
  }

  @override
  Future<void> ensureYear(String v, int year) async {}

  @override
  Float32List values(String v, int year, int m) {
    final k = '$v$year-$m';
    final hit = _cache.remove(k);
    if (hit != null) {
      _cache[k] = hit; // đưa lên cuối (LRU)
      return hit;
    }
    final a = Float32List(nCells)..fillRange(0, nCells, double.nan);
    for (var i = 0; i < nCells; i++) {
      if (geo.type[i] == cellVn) a[i] = _valueAt(v, i, year, m);
    }
    if (_cache.length > 60) _cache.remove(_cache.keys.first);
    _cache[k] = a;
    return a;
  }

  @override
  double clim(String v, int i, int m) =>
      v == 'temp' ? _tempClim(i, m) - 0.07 : (v == 'rain' ? _rainClim(i, m) : _fireClim(i, m));

  @override
  double sd(String v, int i, int m) {
    final c = clim(v, i, m);
    return v == 'temp' ? 0.62 : (v == 'rain' ? 0.33 * c + 5 : 0.42 * c + 0.15);
  }

  @override
  RegionSeries series(int region, String v) {
    final key = '$region$v';
    final hit = _seriesCache[key];
    if (hit != null) return hit;
    final n = monthCount;
    final s = Float32List(n);
    final cells = _samples[region];
    for (var y = 0; y < years.length; y++) {
      for (var m = 0; m < 12; m++) {
        var t = 0.0;
        for (final i in cells) {
          t += _valueAt(v, i, years[y], m);
        }
        s[y * 12 + m] = v == 'fire' ? t * 4 : t / cells.length;
      }
    }
    // chuẩn 2001–2020 (20 năm đầu)
    final baseYears = math.min(20, years.length);
    final mean = List<double>.filled(12, 0.0), sdv = List<double>.filled(12, 1.0);
    for (var m = 0; m < 12; m++) {
      var a = 0.0, b = 0.0;
      for (var y = 0; y < baseYears; y++) {
        a += s[y * 12 + m];
      }
      a /= baseYears;
      for (var y = 0; y < baseYears; y++) {
        final d = s[y * 12 + m] - a;
        b += d * d;
      }
      mean[m] = a;
      final sdm = math.sqrt(b / math.max(1, baseYears - 1));
      sdv[m] = sdm == 0 ? 1.0 : sdm;
    }
    final z = Float32List(n);
    for (var k = 0; k < n; k++) {
      z[k] = (s[k] - mean[k % 12]) / sdv[k % 12];
    }
    final out = RegionSeries.fromValues(s, z);
    _seriesCache[key] = out;
    return out;
  }

  @override
  String? eventLabel(int region, String v, int year, int m, String lang) {
    if (v != 'rain') return null;
    for (final e in _events) {
      if (e.y == year && e.m == m && e.regs.contains(region)) return lang == 'vi' ? e.vi : e.en;
    }
    return null;
  }
}
