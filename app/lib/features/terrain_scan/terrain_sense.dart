// F3 — các phép tính dùng khi KHÁM PHÁ ĐỊA LÝ BẰNG TAY (thuần Dart, test được):
//  • độ dốc thật dưới ngón tay (từ 4 điểm độ cao quanh nó) → mức rung;
//  • độ cao → cao độ tiếng sáo (đất càng cao, sáo càng cao);
//  • "khu dân cư": gần trụ sở các PHƯỜNG (đơn vị hành chính đô thị, danh bạ hành chính Việt Nam) hoặc gần các
//    thành phố lớn (bộ dữ liệu khí hậu NASA của app) → tiếng xe cộ.
import 'dart:math' as math;

import '../../audio/audio_engine.dart' show toScale;
import '../globe/terrain_data.dart' show elevTone;
import 'touch_grid.dart' show trafficVolume;

/// Độ dốc (độ) từ độ cao 4 hướng bắc/nam/đông/tây cách điểm giữa [stepKm] km. NaN nếu thiếu số liệu.
double slopeDegrees(double eN, double eS, double eE, double eW, double stepKm) {
  if ([eN, eS, eE, eW].any((x) => x.isNaN) || stepKm <= 0) return double.nan;
  final dzdx = (eE - eW) / (2 * stepKm * 1000);
  final dzdy = (eN - eS) / (2 * stepKm * 1000);
  return math.atan(math.sqrt(dzdx * dzdx + dzdy * dzdy)) * 180 / math.pi;
}

/// Mức rung theo độ dốc: 0 không rung · 1 nhẹ · 2 vừa · 3 mạnh · 4 rất mạnh.
int slopeLevel(double deg) => deg.isNaN || deg < 2 ? 0 : (deg < 6 ? 1 : (deg < 12 ? 2 : (deg < 22 ? 3 : 4)));

/// Cao độ tiếng sáo (Hz) theo độ cao (m): ngũ cung, đất càng cao sáo càng cao; dưới mực nước biển dùng nốt thấp nhất.
double fluteFreq(double elevM) => 2 * toScale(0.06 + 0.9 * elevTone(elevM));

class _Pt {
  final double lat, lon, radiusKm;
  const _Pt(this.lat, this.lon, this.radiusKm);
}

/// Chỉ mục "khu dân cư" tra nhanh theo ô lưới 0,25°.
class UrbanIndex {
  final _cells = <int, List<_Pt>>{};
  int count = 0;

  static int _key(int i, int j) => i * 100000 + j;
  static int _ci(double lat) => ((lat + 90) * 4).floor();
  static int _cj(double lon) => ((lon + 180) * 4).floor();

  /// Thêm một điểm dân cư với bán kính lõi [radiusKm] (mật độ giảm dần tới gấp đôi bán kính).
  void add(double lat, double lon, double radiusKm) {
    final p = _Pt(lat, lon, radiusKm);
    final span = (radiusKm * 2 / 27.0).ceil(); // 0,25° ≈ 27 km
    final i0 = _ci(lat), j0 = _cj(lon);
    for (var di = -span; di <= span; di++) {
      for (var dj = -span; dj <= span; dj++) {
        (_cells[_key(i0 + di, j0 + dj)] ??= []).add(p);
      }
    }
    count++;
  }

  /// Mức dân cư 0..1 tại (lat, lon): 1 trong lõi, giảm dần ra tới 2 lần bán kính.
  double at(double lat, double lon) {
    final ps = _cells[_key(_ci(lat), _cj(lon))];
    if (ps == null) return 0;
    var best = 0.0;
    final kx = 111.32 * math.cos(lat * math.pi / 180);
    for (final p in ps) {
      final dx = (lon - p.lon) * kx, dy = (lat - p.lat) * 110.57;
      final d = math.sqrt(dx * dx + dy * dy);
      final v = d <= p.radiusKm ? 1.0 : (d >= 2 * p.radiusKm ? 0.0 : 1 - (d - p.radiusKm) / p.radiusKm);
      if (v > best) best = v;
      if (best >= 1) break;
    }
    return best;
  }
}

// ======================= Quét mặt cắt địa hình =======================

/// Thời lượng tối đa của MỘT lượt quét (yêu cầu: không quá 8 giây).
const scanMaxMs = 8000;

/// Lưới độ cao [rows] × [cols]: hàng 0 ở phía BẮC, cột 0 ở phía TÂY.
class ElevGrid {
  final List<List<double>> z;
  final double lat0, lat1, lon0, lon1; // lat0 = bắc, lat1 = nam
  const ElevGrid(this.z, this.lat0, this.lat1, this.lon0, this.lon1);
  int get rows => z.length;
  int get cols => z.isEmpty ? 0 : z.first.length;

  /// Lát cắt hàng [r] (tây → đông) — dùng khi quét bắc → nam.
  List<double> row(int r) => z[r];

  /// Lát cắt cột [c] (bắc → nam) — dùng khi quét tây → đông.
  List<double> col(int c) => [for (final row in z) row[c]];

  (double, double) range() {
    var lo = double.infinity, hi = -double.infinity;
    for (final row in z) {
      for (final v in row) {
        if (v.isNaN) continue;
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    return lo.isInfinite ? (0, 1) : (lo, hi);
  }
}

double sliceMean(List<double> xs) {
  final v = xs.where((x) => !x.isNaN).toList();
  return v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
}

/// Thời gian mỗi lát để cả lượt quét [n] lát vừa trong [scanMaxMs] (tối đa 320 ms/lát cho dễ nghe).
int scanStepMs(int n) => n <= 0 ? 0 : math.min(320, scanMaxMs ~/ n);

/// Tóm tắt một lượt quét: lát cao nhất / thấp nhất (chỉ số) và độ cao trung bình của chúng.
({int hi, int lo, double hiMean, double loMean}) scanExtremes(List<double> means) {
  var hi = -1, lo = -1;
  for (var k = 0; k < means.length; k++) {
    if (means[k].isNaN) continue;
    if (hi < 0 || means[k] > means[hi]) hi = k;
    if (lo < 0 || means[k] < means[lo]) lo = k;
  }
  return (
    hi: hi,
    lo: lo,
    hiMean: hi < 0 ? double.nan : means[hi],
    loMean: lo < 0 ? double.nan : means[lo],
  );
}

// ======================= Quyết định âm thanh / rung dưới ngón tay =======================

/// Những gì phát khi ngón tay ở một điểm trên đất liền.
class FingerCue {
  final double trafficAmp; // 0 = không có tiếng xe
  final bool urban; // đọc "khu dân cư"
  final double slopeDeg; // độ dốc dùng để rung (NaN = không biết)
  final bool inlandWater; // sông, hồ lớn → tiếng nước
  final bool realData; // true: số liệu thật NASA (SRTM, GPWv4); false: ước lượng
  const FingerCue(this.trafficAmp, this.urban, this.slopeDeg, this.inlandWater, this.realData);
}

/// Ưu tiên số liệu THẬT (lưới F3 của data_nasa: độ dốc SRTM, mặt nước và mật độ dân số GPWv4) nếu có ở điểm này;
/// không có thì dùng ước lượng (độ dốc tính từ ô độ cao, khu dân cư theo phường / thành phố).
/// [realSlope], [realWater], [realPop]: số liệu thật (null = không có); [hasReal]: điểm nằm trong lưới thật.
FingerCue fingerCue({
  required bool hasReal,
  double? realSlope,
  double? realWater,
  double? realPop,
  double waterThreshold = 0.5,
  required double urbanEstimate,
  required double slopeEstimate,
}) {
  if (hasReal) {
    final vol = trafficVolume(realPop);
    return FingerCue(vol * 0.3, (realPop ?? 0) >= 1000, realSlope ?? slopeEstimate,
        realWater != null && realWater >= waterThreshold, true);
  }
  final u = urbanEstimate;
  return FingerCue(u > 0.35 ? 0.08 + 0.14 * u : 0, u > 0.6, slopeEstimate, false, false);
}
