// Đọc output của pipeline Python (dữ liệu NASA NEO) từ assets/data/:
//   touchgrid.json  — lưới, mặt nạ đất/biển, vùng, chuẩn khí hậu (clim) và độ lệch chuẩn (sd) theo ô
//   frames/<biến>/<năm>.bin — uint8[12][n_land], 255 = thiếu
//   series.json     — chuỗi tháng và z theo vùng
// Định dạng xem README.md mục "Định dạng dữ liệu cho web".
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';


import '../core/geo.dart';
import 'climate_data.dart';
import 'loader.dart';

const _nodata = 255;

class _VarQ {
  final double min, max;
  final bool sqrtScale;
  final Uint8List clim; // 12 * nLand
  final Uint8List? sd; // 12 * nLand, tuyến tính 0..sdMax
  final double sdMax;
  final String framePattern;
  _VarQ(this.min, this.max, this.sqrtScale, this.clim, this.sd, this.sdMax, this.framePattern);

  double deq(int q) {
    if (q == _nodata) return double.nan;
    final lo = sqrtScale ? math.sqrt(math.max(0.0, min)) : min;
    final hi = sqrtScale ? math.sqrt(math.max(0.0, max)) : max;
    final v = lo + (q / 254) * (hi - lo);
    return sqrtScale ? v * v : v;
  }
}

class AssetData extends ClimateData {
  @override
  final GeoGrid geo;
  @override
  final List<int> years;
  @override
  final Map<String, VarMeta> vars;
  final List<int> _landIdx; // vị trí ô theo thứ tự land
  final Int32List _landPos; // ô -> vị trí trong mảng land, -1 nếu không phải đất
  final Map<String, _VarQ> _q;
  final Map<String, List<RegionSeries?>> _series;
  final Map<String, Uint8List> _frames = {};
  final Map<String, Float32List> _decoded = {};

  final DataLoader loader;
  final String version; // dataset_version trong touchgrid.json
  final List<String> credits;

  AssetData._(this.loader, this.version, this.credits, this.geo, this.years, this.vars, this._landIdx, this._landPos,
      this._q, this._series);

  @override
  String get id => loader is HttpLoader ? 'remote' : 'assets';
  @override
  bool get isSimulated => false;
  @override
  String label(String lang) {
    final where = loader is HttpLoader ? loader.describe() : (lang == 'vi' ? 'đóng gói trong app' : 'bundled');
    return lang == 'vi'
        ? 'Dữ liệu NASA thật ($where, phiên bản $version)'
        : 'Real NASA data ($where, version $version)';
  }

  /// Đọc gói dữ liệu. Với AssetLoader: trả về null nếu chưa có assets/data/touchgrid.json (chưa chạy pipeline).
  /// Với HttpLoader: lỗi mạng/định dạng được ném ra để màn Cài đặt báo cho người dùng.
  static Future<AssetData?> tryLoad([DataLoader loader = const AssetLoader()]) async {
    String tgText;
    try {
      tgText = await loader.text('touchgrid.json');
    } catch (_) {
      if (loader is HttpLoader) rethrow;
      return null;
    }
    final tg = jsonDecode(tgText) as Map<String, dynamic>;
    final w = tg['w'] as int, h = tg['h'] as int;
    if (w != gw || h != gh) {
      throw StateError('touchgrid.json có lưới ${w}x$h, app cần ${gw}x$gh (BBOX/RES phải trùng pipeline/config.py)');
    }
    final land = base64Decode(tg['land'] as String);
    final regionRaw = base64Decode(tg['region'] as String);
    final coastRaw = base64Decode(tg['coast_km'] as String);
    final type = Uint8List(nCells), region = Int8List(nCells), coast = Float32List(nCells);
    final landIdx = <int>[];
    final landPos = Int32List(nCells)..fillRange(0, nCells, -1);
    for (var i = 0; i < nCells; i++) {
      type[i] = land[i];
      region[i] = regionRaw[i] == _nodata ? -1 : regionRaw[i];
      coast[i] = coastRaw[i].toDouble();
      if (land[i] == cellVn) {
        landPos[i] = landIdx.length;
        landIdx.add(i);
      }
    }
    final years = (tg['years'] as List).map((e) => e as int).toList();

    final vars = <String, VarMeta>{};
    final q = <String, _VarQ>{};
    final tvars = tg['vars'] as Map<String, dynamic>;
    for (final entry in tvars.entries) {
      final k = entry.key;
      final m = entry.value as Map<String, dynamic>;
      final unit = (m['unit'] as String?) ?? '';
      final sqrtScale = m['scale'] == 'sqrt';
      final min = (m['min'] as num).toDouble(), max = (m['max'] as num).toDouble();
      vars[k] = VarMeta(
        key: k,
        vi: (m['name_vi'] as String?) ?? k,
        en: (m['name_en'] as String?) ?? k,
        unitVi: unit,
        unitEn: unit.replaceAll('mm/tháng', 'mm/month').replaceAll('chỉ số', 'index').replaceAll('điểm', 'hotspots'),
        spokenVi: _spokenVi(unit),
        spokenEn: _spokenEn(unit),
        min: min,
        max: max,
        decimals: (m['decimals'] as int?) ?? (k == 'temp' ? 1 : (unit.startsWith('mm') || unit == 'điểm' ? 0 : 2)),
        sqrtScale: sqrtScale,
        instrument: (m['instrument'] as String?) ??
            (k == 'rain' ? 'trung' : (k == 'fire' ? 'fire' : 'danbau')),
      );
      q[k] = _VarQ(
        min,
        max,
        sqrtScale,
        base64Decode(m['clim'] as String),
        m['sd'] == null ? null : base64Decode(m['sd'] as String),
        ((m['sd_max'] as num?) ?? 1).toDouble(),
        (m['frames'] as String?) ?? 'frames/${k}_{year}.bin',
      );
    }

    final series = <String, List<RegionSeries?>>{};
    try {
      final se = jsonDecode(await loader.text('series.json')) as Map<String, dynamic>;
      for (final r in (se['regions'] as List)) {
        final rm = r as Map<String, dynamic>;
        final id = rm['id'] as int;
        final rv = rm['vars'] as Map<String, dynamic>;
        for (final e in rv.entries) {
          final list = series.putIfAbsent(e.key, () => List<RegionSeries?>.filled(regions.length, null));
          final d = e.value as Map<String, dynamic>;
          list[id] = RegionSeries.fromValues(_floats(d['values'] as List), _floats(d['z'] as List));
        }
      }
    } catch (_) {
      // series.json thiếu: Dòng thời gian sẽ báo không có dữ liệu
    }
    final version = '${tg['dataset_version'] ?? tg['generated'] ?? '?'}';
    final credits = [for (final c in (tg['sources'] as List? ?? const [])) '$c'];
    return AssetData._(loader, version, credits, GeoGrid(type, region, coast), years, vars, landIdx, landPos, q, series);
  }

  static Float32List _floats(List l) {
    final out = Float32List(l.length);
    for (var i = 0; i < l.length; i++) {
      final v = l[i];
      out[i] = v == null ? double.nan : (v as num).toDouble();
    }
    return out;
  }

  static String _spokenVi(String unit) {
    if (unit.contains('°C')) return 'độ C';
    if (unit.startsWith('mm')) return 'mi-li-mét';
    if (unit == 'điểm') return 'điểm cháy';
    return unit;
  }

  static String _spokenEn(String unit) {
    if (unit.contains('°C')) return 'degrees Celsius';
    if (unit.startsWith('mm')) return 'millimetres';
    if (unit == 'chỉ số') return '';
    if (unit == 'điểm') return 'hotspots';
    return unit;
  }

  int get nLand => _landIdx.length;

  @override
  Future<void> ensureYear(String v, int year) async {
    final key = '$v/$year';
    if (_frames.containsKey(key)) return;
    final pattern = _q[v]?.framePattern ?? 'frames/${v}_{year}.bin';
    try {
      _frames[key] = await loader.bytes(pattern.replaceAll('{year}', '$year'));
    } catch (_) {
      _frames[key] = Uint8List(0); // năm thiếu: mọi ô NaN
    }
  }

  @override
  Float32List values(String v, int year, int m) {
    final key = '$v/$year/$m';
    final hit = _decoded[key];
    if (hit != null) return hit;
    final out = Float32List(nCells)..fillRange(0, nCells, double.nan);
    final frame = _frames['$v/$year'];
    final vq = _q[v];
    if (frame == null) return out; // năm chưa nạp: KHÔNG lưu đệm, kẻo NaN dính mãi sau khi ensureYear xong
    if (vq != null && frame.length >= 12 * nLand) {
      final off = m * nLand;
      for (var k = 0; k < nLand; k++) {
        out[_landIdx[k]] = vq.deq(frame[off + k]);
      }
    }
    if (_decoded.length > 72) _decoded.remove(_decoded.keys.first);
    _decoded[key] = out;
    return out;
  }

  @override
  double clim(String v, int i, int m) {
    final p = _landPos[i], vq = _q[v];
    if (p < 0 || vq == null) return double.nan;
    return vq.deq(vq.clim[m * nLand + p]);
  }

  @override
  double sd(String v, int i, int m) {
    final p = _landPos[i], vq = _q[v];
    if (p < 0 || vq == null) return double.nan;
    final s = vq.sd;
    if (s == null) {
      // touchgrid.json cũ (trước khi có sd): ước lượng thô 10% dải giá trị
      return (vq.max - vq.min) * 0.1;
    }
    final qv = s[m * nLand + p];
    if (qv == _nodata) return double.nan;
    return math.max(1e-6, qv / 254 * vq.sdMax);
  }

  @override
  RegionSeries series(int region, String v) {
    final s = _series[v]?[region];
    if (s != null) return s;
    final n = monthCount;
    final nan = Float32List(n)..fillRange(0, n, double.nan);
    return RegionSeries.fromValues(nan, Float32List.fromList(nan));
  }
}
