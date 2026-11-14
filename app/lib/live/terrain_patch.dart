// BẢN ĐỒ ĐỊA HÌNH THẬT (phần thuần Dart, kiểm thử được): lưới độ cao + lớp phủ đất quanh một điểm,
// đọc độ cao / lớp phủ đúng chỗ ngón tay (nội suy mượt) và tô thành ảnh địa hình có bóng đổ.
// Phần tải ô bản đồ ở terrain_tiles.dart.
import 'dart:math' as math;
import 'dart:typed_data';

/// Lớp phủ đất MODIS IGBP (mã 0..17) → loại địa hình của bản đồ rê tay + tên đọc.
const igbpKinds = <int, (String, String, String)>{
  0: ('water', 'Mặt nước', 'Water'),
  1: ('forest', 'Rừng lá kim thường xanh', 'Evergreen needleleaf forest'),
  2: ('forest', 'Rừng lá rộng thường xanh', 'Evergreen broadleaf forest'),
  3: ('forest', 'Rừng lá kim rụng lá', 'Deciduous needleleaf forest'),
  4: ('forest', 'Rừng lá rộng rụng lá', 'Deciduous broadleaf forest'),
  5: ('forest', 'Rừng hỗn giao', 'Mixed forest'),
  6: ('park', 'Cây bụi rậm', 'Closed shrubland'),
  7: ('park', 'Cây bụi thưa', 'Open shrubland'),
  8: ('park', 'Đồng cỏ có cây', 'Woody savanna'),
  9: ('park', 'Đồng cỏ thưa cây', 'Savanna'),
  10: ('park', 'Đồng cỏ', 'Grassland'),
  11: ('water', 'Đất ngập nước', 'Wetland'),
  12: ('farmland', 'Đồng ruộng', 'Cropland'),
  13: ('residential', 'Khu đô thị, dân cư', 'Built-up area'),
  14: ('farmland', 'Ruộng xen cây', 'Cropland mosaic'),
  15: ('', 'Băng tuyết', 'Snow and ice'),
  16: ('', 'Đất trống', 'Barren land'),
  17: ('water', 'Mặt nước', 'Water'),
};

// Bảng màu GIBS cho lớp IGBP (gibs.earthdata.nasa.gov/colormaps/v1.3/MODIS_IGBP_Land_Cover_Type.xml)
const _igbpRgb = <int, (int, int, int)>{
  1: (33, 138, 33), 2: (49, 204, 49), 3: (152, 204, 49), 4: (150, 250, 150), 5: (141, 186, 141),
  6: (186, 141, 141), 7: (245, 222, 179), 8: (218, 235, 157), 9: (255, 213, 0), 10: (240, 185, 103),
  11: (71, 131, 181), 12: (250, 239, 115), 13: (255, 0, 0), 14: (153, 147, 86), 15: (255, 255, 255),
  16: (191, 191, 189), 17: (134, 202, 227),
};

/// Màu điểm ảnh GIBS → mã IGBP (255 = trong suốt / không rõ).
int igbpFromRgb(int r, int g, int b, int a) {
  if (a < 128) return 255;
  var best = 255, bd = 1 << 30;
  _igbpRgb.forEach((k, c) {
    final d = (c.$1 - r) * (c.$1 - r) + (c.$2 - g) * (c.$2 - g) + (c.$3 - b) * (c.$3 - b);
    if (d < bd) {
      bd = d;
      best = k;
    }
  });
  return bd <= 900 ? best : 255; // lệch quá xa bảng màu (nén ảnh, viền) → không đoán
}

/// Độ cao Terrarium từ một điểm ảnh.
double terrariumElev(int r, int g, int b) => r * 256 + g + b / 256 - 32768;

class TerrainPatch {
  final double lat, lon, radius; // tâm, bán kính khung (m) — khung vuông ±radius
  final int n; // lưới n×n, hàng 0 = phía bắc
  final Float32List elev; // m; NaN = thiếu
  final Uint8List cover; // mã IGBP; 255 = không rõ
  final String source;

  /// Tỉ lệ (0..1) từng loại phủ đất quanh mỗi ô, đã làm mượt (water, forest, farmland, residential, park).
  /// Ô MODIS 500 m to hơn nhiều so với ô bản đồ (~19 m) → không tô thành khối vuông mà tô chuyển dần theo tỉ lệ.
  final Map<String, Float32List> frac;
  TerrainPatch(this.lat, this.lon, this.radius, this.n, this.elev, this.cover, this.source, {this.frac = const {}});

  double _fx(double x) => ((x + radius) / (2 * radius) * (n - 1)).clamp(0.0, n - 1.0);
  double _fy(double y) => ((radius - y) / (2 * radius) * (n - 1)).clamp(0.0, n - 1.0);

  /// Độ cao tại (x, y) mét so với tâm (đông +x, bắc +y), nội suy hai chiều.
  double? elevAt(double x, double y) {
    final fx = _fx(x), fy = _fy(y);
    final x0 = fx.floor(), y0 = fy.floor();
    final x1 = math.min(n - 1, x0 + 1), y1 = math.min(n - 1, y0 + 1);
    final tx = fx - x0, ty = fy - y0;
    double v(int r, int c) => elev[r * n + c];
    final e = (v(y0, x0) * (1 - tx) + v(y0, x1) * tx) * (1 - ty) + (v(y1, x0) * (1 - tx) + v(y1, x1) * tx) * ty;
    return e.isNaN ? null : e;
  }

  /// Lớp phủ IGBP gần nhất tại (x, y) mét; null nếu không rõ.
  int? coverAt(double x, double y) {
    final c = cover[_fy(y).round() * n + _fx(x).round()];
    return c == 255 ? null : c;
  }

  /// Khoảng độ cao dùng để TÔ MÀU và ĐỔI RA TIẾNG SÁO: bỏ 2% điểm thấp/cao nhất (nhà cao tầng, cây, nhiễu radar,
  /// mặt sông) và luôn giãn tối thiểu [minSpan] mét — vùng phẳng như nội thành Hà Nội (chênh vài mét) không bị
  /// phóng đại thành "đồi núi", tiếng sáo cũng không nhảy lung tung.
  (double, double) relief({double minSpan = 60}) {
    final v = [for (final e in elev) if (!e.isNaN) e]..sort();
    if (v.isEmpty) return (0, minSpan);
    final lo = v[(v.length * 0.02).floor()], hi = v[((v.length - 1) * 0.98).floor()];
    if (hi - lo >= minSpan) return (lo, hi);
    final mid = (lo + hi) / 2;
    final a = math.max(math.min(lo, 0.0), mid - minSpan / 2); // gần mực nước biển thì không kéo xuống dưới 0
    return (a, a + minSpan);
  }

  /// Chênh cao thật (bỏ 2% hai đầu), mét — nhỏ hơn ~15 m là vùng bằng phẳng.
  double get reliefSpan {
    final v = [for (final e in elev) if (!e.isNaN) e]..sort();
    if (v.length < 2) return 0;
    return v[((v.length - 1) * 0.98).floor()] - v[(v.length * 0.02).floor()];
  }

  /// Tỉ lệ một loại phủ đất tại (x, y) mét (0..1); 0 nếu không có dữ liệu.
  double fracAt(String kind, double x, double y) {
    final f = frac[kind];
    if (f == null) return 0;
    return f[_fy(y).round() * n + _fx(x).round()];
  }

  (double, double) get minMax {
    var lo = double.infinity, hi = -double.infinity;
    for (final e in elev) {
      if (e.isNaN) continue;
      if (e < lo) lo = e;
      if (e > hi) hi = e;
    }
    return lo.isFinite ? (lo, math.max(lo + 1, hi)) : (0, 1);
  }
}

/// Ảnh bản đồ địa hình n×n (RGBA): màu theo độ cao (thấp xanh rêu → cao nâu vàng), mặt nước xanh lam, rừng tô
/// xanh lá, ruộng vàng nhạt, đô thị xám — nhân bóng đổ theo hướng nắng tây bắc để thấy rõ núi, thung lũng.
Uint8List renderTerrainRgba(TerrainPatch p) {
  final n = p.n;
  final out = Uint8List(n * n * 4);
  final (lo, hi) = p.relief();
  final range = math.max(1.0, hi - lo);
  double fr(String k, int i) => p.frac[k]?[i] ?? 0;
  double ramp(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
  // vùng phẳng (chênh < 30 m, như nội thành Hà Nội): bóng đổ nhẹ đi một nửa — gồ ghề còn lại chủ yếu là nóc nhà,
  // tán cây trong dữ liệu radar SRTM, không phải đồi thật
  final gain = p.reliefSpan < 30 ? 0.8 : 1.6;
  final cellM = 2 * p.radius / (n - 1);
  double ev(int r, int c) {
    final v = p.elev[r.clamp(0, n - 1) * n + c.clamp(0, n - 1)];
    return v.isNaN ? lo : v;
  }
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final e = ev(r, c);
      final k = ((e - lo) / range).clamp(0.0, 1.0);
      // độ cao → màu
      var (cr, cg, cb) = k < 0.5
          ? _mix((36, 58, 46), (110, 96, 64), k / 0.5)
          : _mix((110, 96, 64), (196, 168, 104), (k - 0.5) / 0.5);
      // lớp phủ đất: tô CHUYỂN DẦN theo tỉ lệ đã làm mượt (ô MODIS 500 m → không thành khối vuông, bậc thang)
      final i0 = r * n + c;
      (cr, cg, cb) = _mix((cr, cg, cb), (34, 110, 56), 0.55 * fr('forest', i0));
      (cr, cg, cb) = _mix((cr, cg, cb), (90, 130, 70), 0.35 * fr('park', i0));
      (cr, cg, cb) = _mix((cr, cg, cb), (176, 168, 92), 0.45 * fr('farmland', i0));
      (cr, cg, cb) = _mix((cr, cg, cb), (128, 116, 106), 0.5 * fr('residential', i0));
      // mặt nước: lớp phủ nói là nước (từ ~nửa ô trở lên), hoặc độ cao thấp hơn mực biển rõ rệt
      final raw = p.elev[i0];
      final w = math.max(ramp(fr('water', i0), 0.35, 0.65), raw.isNaN ? 0.0 : ramp(-raw, 0.5, 3));
      (cr, cg, cb) = _mix((cr, cg, cb), (38, 110, 170), 0.85 * w);
      // bóng đổ (nắng từ tây bắc), độ dốc tính theo mét thật
      final dzdx = (ev(r, c + 1) - ev(r, c - 1)) / (2 * cellM);
      final dzdy = (ev(r - 1, c) - ev(r + 1, c)) / (2 * cellM);
      final shade = (1.0 + (dzdx - dzdy) * gain).clamp(0.55, 1.35);
      final i = (r * n + c) * 4;
      out[i] = (cr * shade).round().clamp(0, 255);
      out[i + 1] = (cg * shade).round().clamp(0, 255);
      out[i + 2] = (cb * shade).round().clamp(0, 255);
      out[i + 3] = 255;
    }
  }
  return out;
}

/// Làm mờ hộp tách hai chiều (bỏ qua NaN), bán kính [rad] ô — chạy [passes] lần ≈ làm mờ Gauss.
Float32List boxBlur(Float32List a, int n, int rad, {int passes = 2}) {
  if (rad <= 0) return a;
  var src = Float32List.fromList(a);
  final tmp = Float32List(n * n);
  for (var pass = 0; pass < passes; pass++) {
    for (var horiz = 0; horiz < 2; horiz++) {
      final from = horiz == 0 ? src : tmp, to = horiz == 0 ? tmp : src;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          var sum = 0.0, cnt = 0;
          for (var k = math.max(0, j - rad); k <= math.min(n - 1, j + rad); k++) {
            final v = horiz == 0 ? from[i * n + k] : from[k * n + i];
            if (v.isNaN) continue;
            sum += v;
            cnt++;
          }
          final idx = horiz == 0 ? i * n + j : j * n + i;
          to[idx] = cnt == 0 ? double.nan : sum / cnt;
        }
      }
    }
  }
  return src;
}

/// Hoàn thiện bản đồ từ dữ liệu thô vừa tải:
///  • độ cao: làm mượt ~40 m — SRTM là bề mặt RADAR (nóc nhà, tán cây, nhiễu ±5–10 m); ở nội thành phẳng các
///    nhiễu đó trông như "gò đồi" giả. Núi, thung lũng thật (hàng trăm mét) vẫn giữ nguyên dáng.
///  • lớp phủ: tính tỉ lệ từng loại quanh mỗi ô (làm mượt ~250 m = nửa ô MODIS) → ranh giới mềm; loại để ĐỌC TÊN
///    là loại chiếm nhiều nhất quanh chỗ ngón tay (không còn đọc "mặt nước" khi còn cách sông vài trăm mét).
TerrainPatch finishPatch(double lat, double lon, double radius, int n, Float32List elevRaw, Uint8List coverRaw,
    String source) {
  final cell = 2 * radius / (n - 1);
  final elev = boxBlur(elevRaw, n, math.max(1, (20 / cell).round()));
  const kinds = ['water', 'forest', 'farmland', 'residential', 'park'];
  final known = Float32List(n * n);
  final raw = {for (final k in kinds) k: Float32List(n * n)};
  for (var i = 0; i < n * n; i++) {
    final c = coverRaw[i];
    if (c == 255) {
      known[i] = double.nan;
      for (final k in kinds) {
        raw[k]![i] = double.nan;
      }
      continue;
    }
    known[i] = 1;
    final k = igbpKinds[c]?.$1 ?? '';
    for (final kk in kinds) {
      raw[kk]![i] = kk == k ? 1 : 0;
    }
  }
  final rad = math.max(1, (125 / cell).round());
  final frac = <String, Float32List>{};
  final hasCover = coverRaw.any((c) => c != 255);
  if (hasCover) {
    for (final k in kinds) {
      final f = boxBlur(raw[k]!, n, rad);
      for (var i = 0; i < n * n; i++) {
        if (f[i].isNaN) f[i] = 0;
      }
      frac[k] = f;
    }
  }
  // loại chiếm nhiều nhất quanh mỗi ô → mã IGBP đại diện (giữ mã gốc nếu cùng loại, để đọc đúng tên rừng / ruộng…)
  const rep = {'water': 17, 'forest': 2, 'farmland': 12, 'residential': 13, 'park': 10};
  final cover = Uint8List.fromList(coverRaw);
  if (hasCover) {
    for (var i = 0; i < n * n; i++) {
      var best = '', bv = 0.0;
      for (final k in kinds) {
        final v = frac[k]![i];
        if (v > bv) {
          bv = v;
          best = k;
        }
      }
      final own = igbpKinds[coverRaw[i]]?.$1 ?? '';
      if (bv < 0.5) {
        // không loại nào chiếm quá nửa → giữ mã gốc, trừ khi mã gốc là nước (tránh khối nước vuông lấn ra bờ)
        if (own == 'water') cover[i] = rep[best] ?? 255;
      } else if (best != own) {
        cover[i] = rep[best]!;
      }
    }
  }
  return TerrainPatch(lat, lon, radius, n, elev, cover, source, frac: frac);
}

(int, int, int) _mix((int, int, int) a, (int, int, int) b, double t) =>
    ((a.$1 + (b.$1 - a.$1) * t).round(), (a.$2 + (b.$2 - a.$2) * t).round(), (a.$3 + (b.$3 - a.$3) * t).round());

/// Dự phòng khi không tải được ô bản đồ: dựng bản đồ từ lưới độ cao thô sẵn có (vẽ bằng nội suy → vẫn mượt).
TerrainPatch? patchFromGrid(double lat, double lon, double radius, Float32List? grid, int gridN, {int n = 96}) {
  if (grid == null || gridN < 2) return null;
  final elev = Float32List(n * n);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final fx = c / (n - 1) * (gridN - 1), fy = r / (n - 1) * (gridN - 1);
      final x0 = fx.floor(), y0 = fy.floor();
      final x1 = math.min(gridN - 1, x0 + 1), y1 = math.min(gridN - 1, y0 + 1);
      final tx = fx - x0, ty = fy - y0;
      double v(int rr, int cc) => grid[rr * gridN + cc];
      elev[r * n + c] = (v(y0, x0) * (1 - tx) + v(y0, x1) * tx) * (1 - ty) + (v(y1, x0) * (1 - tx) + v(y1, x1) * tx) * ty;
    }
  }
  return TerrainPatch(lat, lon, radius, n, elev, Uint8List(n * n)..fillRange(0, n * n, 255), 'lưới độ cao');
}
