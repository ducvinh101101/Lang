// Lưới 0,1° trùng với pipeline Python (config.BBOX, config.RES) và bản web.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

const double lon0 = 102.0, lon1 = 112.0, lat0 = 8.3, lat1 = 23.6, res = 0.1;
final int gw = ((lon1 - lon0) / res).round(); // 100
final int gh = ((lat1 - lat0) / res).round(); // 153
final int nCells = gw * gh;

/// Loại ô: 0 biển, 1 Việt Nam, 2 nước khác (cùng mã với touchgrid.json `land`).
const int cellSea = 0, cellVn = 1, cellForeign = 2;

class Region {
  final String vi, en;
  final double lon; // kinh độ đại diện, dùng cho pan trái/phải
  const Region(this.vi, this.en, this.lon);
  String name(String lang) => lang == 'vi' ? vi : en;
}

/// Cùng thứ tự id với pipeline/config.py REGIONS.
const regions = <Region>[
  Region('Tây Bắc', 'Northwest', 103.6),
  Region('Đông Bắc và đồng bằng sông Hồng', 'Northeast & Red River Delta', 106.2),
  Region('Bắc Trung Bộ', 'North Central Coast', 106.4),
  Region('Nam Trung Bộ', 'South Central Coast', 108.9),
  Region('Tây Nguyên', 'Central Highlands', 108.0),
  Region('Nam Bộ', 'Southern Vietnam', 105.9),
];

class Place {
  final String name;
  final double lon, lat;
  final bool major;
  const Place(this.name, this.lon, this.lat, [this.major = false]);
}

const places = <Place>[
  Place('Hà Nội', 105.85, 21.03, true), Place('Hải Phòng', 106.68, 20.86), Place('Hạ Long', 107.08, 20.95),
  Place('Lào Cai', 103.97, 22.48), Place('Điện Biên Phủ', 103.02, 21.39), Place('Sơn La', 103.91, 21.33),
  Place('Lai Châu', 103.46, 22.4), Place('Hà Giang', 104.98, 22.82), Place('Cao Bằng', 106.25, 22.67),
  Place('Lạng Sơn', 106.76, 21.85), Place('Thái Nguyên', 105.84, 21.59), Place('Nam Định', 106.17, 20.43),
  Place('Thanh Hóa', 105.78, 19.81), Place('Vinh', 105.68, 18.67), Place('Hà Tĩnh', 105.9, 18.34),
  Place('Đồng Hới', 106.6, 17.47), Place('Đông Hà', 107.1, 16.82), Place('Huế', 107.59, 16.46, true),
  Place('Đà Nẵng', 108.2, 16.05, true), Place('Tam Kỳ', 108.47, 15.57), Place('Quảng Ngãi', 108.8, 15.12),
  Place('Kon Tum', 108.0, 14.35), Place('Pleiku', 108.0, 13.98), Place('Quy Nhơn', 109.22, 13.78),
  Place('Tuy Hòa', 109.3, 13.09), Place('Buôn Ma Thuột', 108.04, 12.67), Place('Nha Trang', 109.19, 12.24),
  Place('Đà Lạt', 108.44, 11.94, true), Place('Phan Rang', 108.99, 11.56), Place('Phan Thiết', 108.1, 10.93),
  Place('Gia Nghĩa', 107.69, 12.0), Place('Đồng Xoài', 106.9, 11.53), Place('Tây Ninh', 106.1, 11.31),
  Place('Biên Hòa', 106.82, 10.95), Place('TP. Hồ Chí Minh', 106.66, 10.78, true), Place('Vũng Tàu', 107.08, 10.35),
  Place('Mỹ Tho', 106.36, 10.36), Place('Cần Thơ', 105.78, 10.03, true), Place('Long Xuyên', 105.43, 10.38),
  Place('Rạch Giá', 105.08, 10.01), Place('Phú Quốc', 103.96, 10.23), Place('Sóc Trăng', 105.97, 9.6),
  Place('Cà Mau', 105.15, 9.18), Place('quần đảo Hoàng Sa', 111.5, 16.55), Place('quần đảo Trường Sa', 111.0, 9.45),
];

/// Đường viền giản lược (lon, lat) — trùng pipeline/geo.py VN_OUTLINE.
const vnOutline = <List<double>>[
  [102.14, 22.40], [102.40, 22.65], [102.60, 22.73], [103.00, 22.45], [103.30, 22.80], [103.60, 22.75], [103.95, 22.50],
  [104.10, 22.75], [104.40, 22.70], [104.75, 22.85], [105.10, 23.05], [105.35, 23.38], [105.60, 23.15], [105.90, 22.95],
  [106.30, 22.95], [106.70, 22.85], [106.65, 22.45], [106.80, 22.10], [107.05, 21.80], [107.40, 21.65], [107.75, 21.62],
  [108.05, 21.55], [107.80, 21.40], [107.45, 21.25], [107.10, 20.95], [106.80, 20.75], [106.60, 20.35], [106.20, 19.95],
  [105.95, 19.65], [105.80, 19.25], [105.70, 18.95], [105.85, 18.60], [106.15, 18.25], [106.50, 17.80], [106.75, 17.35],
  [107.10, 16.95], [107.50, 16.65], [107.95, 16.35], [108.25, 16.10], [108.45, 15.80], [108.80, 15.40], [108.95, 15.00],
  [109.10, 14.40], [109.25, 13.80], [109.30, 13.30], [109.45, 12.90], [109.25, 12.40], [109.20, 11.95], [109.05, 11.60],
  [108.85, 11.25], [108.45, 11.00], [108.05, 10.75], [107.55, 10.55], [107.10, 10.35], [106.80, 10.35], [106.75, 10.05],
  [106.55, 9.70], [106.25, 9.45], [105.85, 9.20], [105.40, 8.85], [105.00, 8.60], [104.75, 8.60], [104.85, 9.00],
  [104.85, 9.60], [105.05, 10.00], [104.75, 10.20], [104.45, 10.40], [104.70, 10.55], [105.05, 10.90], [105.45, 10.95],
  [105.85, 10.85], [106.15, 11.10], [105.95, 11.55], [106.40, 11.95], [106.80, 12.10], [107.15, 12.25], [107.45, 12.40],
  [107.55, 12.90], [107.50, 13.45], [107.60, 13.80], [107.45, 14.30], [107.55, 14.70], [107.70, 15.25], [107.40, 15.50],
  [107.20, 15.85], [107.45, 16.10], [106.95, 16.40], [106.70, 16.65], [106.55, 17.00], [106.25, 17.30], [105.85, 17.65],
  [105.60, 18.05], [105.20, 18.40], [104.95, 18.75], [104.55, 18.95], [104.00, 19.30], [104.15, 19.70], [104.65, 19.85],
  [104.45, 20.20], [104.00, 20.45], [103.70, 20.70], [103.25, 20.80], [102.95, 21.10], [102.85, 21.55], [102.70, 21.75],
  [102.45, 21.95],
];
const phuQuoc = <List<double>>[[103.85, 10.42], [104.06, 10.44], [104.10, 10.18], [103.99, 10.00], [103.86, 10.20]];
const hainan = <List<double>>[
  [108.62, 19.15], [108.70, 18.50], [109.50, 18.20], [110.10, 18.40], [110.60, 18.80], [111.00, 19.60],
  [110.70, 20.10], [110.20, 20.10], [109.60, 20.00], [109.20, 19.75], [108.65, 19.40],
];

bool pointInPolygon(double x, double y, List<List<double>> p) {
  var inside = false;
  for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
    final xi = p[i][0], yi = p[i][1], xj = p[j][0], yj = p[j][1];
    if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
  }
  return inside;
}

/// Quy tắc 6 vùng — trùng pipeline/geo.py region_of và bản web.
int regionOf(double lon, double lat) {
  if (lat >= 20.0) return (lon < 104.75 && lat >= 20.4) ? 0 : 1;
  if (lat >= 16.0) return 2;
  if (lat >= 11.4 && lat < 15.3 && lon < 108.55 && (lat >= 12.4 || lon >= 107.35)) return 4;
  if (lat >= 14.0 || (lat >= 10.5 && lon >= 107.35 && (lat >= 11.4 || lon >= 107.6))) return 3;
  return 5;
}

double cellLon(int i) => lon0 + (i % gw + 0.5) * res;
double cellLat(int i) => lat1 - (i ~/ gw + 0.5) * res;
int cellIndex(int col, int row) => row * gw + col;

/// Pan stereo: tây (trái) → đông (phải).
double panOfLon(double lon) => math.max(-1.0, math.min(1.0, (lon - 102) / 8 * 2 - 1));

/// Các lớp địa lý mà UI cần, dù nguồn dữ liệu là giả lập hay pipeline.
class GeoGrid {
  final Uint8List type; // cellSea / cellVn / cellForeign
  final Int8List region; // 0..5, -1 ngoài Việt Nam
  final Float32List coastKm; // khoảng cách tới biển (km), chỉ có nghĩa với ô đất
  GeoGrid(this.type, this.region, this.coastKm);

  /// Lưới dựng sẵn từ đường viền giản lược (giống bản web), kèm WEST dùng cho mô hình độ cao giả.
  factory GeoGrid.builtin() => builtinGeo().grid;

  String? nearestPlace(double lon, double lat) {
    final inBox = lon >= lon0 && lon < lon1 && lat > lat0 && lat <= lat1;
    var reg = -1;
    if (inBox) {
      final r = math.min(gh - 1, ((lat1 - lat) / res).floor());
      final c = math.min(gw - 1, ((lon - lon0) / res).floor());
      reg = region[r * gw + c];
    }
    Place? best;
    var bd = 1e9;
    for (final p in places) {
      final pr = (p.lat > 23.6 || p.lon > 110.5) ? -1 : regionOf(p.lon, p.lat);
      if (reg >= 0 && pr != reg) continue;
      final d = math.sqrt(math.pow(p.lon - lon, 2) + math.pow(p.lat - lat, 2));
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return (best != null && bd < 0.7) ? best.name : null;
  }
}

class BuiltinGeo {
  final GeoGrid grid;
  final Float32List west; // khoảng cách (độ) tới mép tây của hàng, cho mô hình độ cao giả
  final Float32List coastCells;
  BuiltinGeo(this.grid, this.west, this.coastCells);
}

BuiltinGeo? _builtinCache;
BuiltinGeo builtinGeo() => _builtinCache ??= _buildBuiltin();

BuiltinGeo _buildBuiltin() {
  final type = Uint8List(nCells);
  final reg = Int8List(nCells)..fillRange(0, nCells, -1);
  final west = Float32List(nCells);
  final coast = Float32List(nCells)..fillRange(0, nCells, -1);
  for (var r = 0; r < gh; r++) {
    final lat = lat1 - (r + 0.5) * res;
    var rowMin = double.infinity;
    for (var c = 0; c < gw; c++) {
      final i = r * gw + c, lon = lon0 + (c + 0.5) * res;
      final main = pointInPolygon(lon, lat, vnOutline);
      if (main || pointInPolygon(lon, lat, phuQuoc)) {
        type[i] = cellVn;
        reg[i] = regionOf(lon, lat);
        if (main && lon < rowMin) rowMin = lon;
      }
    }
    for (var c = 0; c < gw; c++) {
      final i = r * gw + c, lon = lon0 + (c + 0.5) * res;
      if (type[i] == cellVn) {
        west[i] = rowMin.isFinite ? math.max(0.0, lon - rowMin) : 5.0;
        continue;
      }
      if (lat > 21.62 || (lat > 20.2 && lon > 109.55) || pointInPolygon(lon, lat, hainan) ||
          (lat >= 10.42 && rowMin.isFinite && lon < rowMin)) {
        type[i] = cellForeign;
      }
    }
  }
  // BFS khoảng cách (số ô) tới biển
  final q = Queue<int>();
  for (var i = 0; i < nCells; i++) {
    if (type[i] == cellSea) {
      coast[i] = 0;
      q.add(i);
    }
  }
  const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  while (q.isNotEmpty) {
    final i = q.removeFirst(), r = i ~/ gw, c = i % gw;
    for (final d in dirs) {
      final rr = r + d[0], cc = c + d[1];
      if (rr < 0 || cc < 0 || rr >= gh || cc >= gw) continue;
      final j = rr * gw + cc;
      if (type[j] == cellVn && coast[j] < 0) {
        coast[j] = coast[i] + 1;
        q.add(j);
      }
    }
  }
  final km = Float32List(nCells);
  for (var i = 0; i < nCells; i++) {
    if (coast[i] < 0) coast[i] = 99;
    km[i] = coast[i] * 11.1;
  }
  return BuiltinGeo(GeoGrid(type, reg, km), west, coast);
}

// ---------------- Quần đảo Hoàng Sa và Trường Sa (Việt Nam) ----------------
// Lưới 0,1° (102–112°Đ) không chứa hết hai quần đảo, nên vẽ như bản web: Hoàng Sa bằng các chấm đảo ở đúng
// vùng biển phía đông Đà Nẵng; Trường Sa trong một khung thu nhỏ ở góc dưới bên phải (phần lớn quần đảo
// nằm xa hơn về phía đông). Rê ngón tay vào hai vùng này app đọc tên quần đảo và "thuộc Việt Nam".

/// Các chấm đảo Hoàng Sa (kinh độ, vĩ độ) — trùng HOANGSA của web/ban-do.html.
const hoangSaDots = <List<double>>[
  [111.2, 16.55], [111.6, 16.85], [111.75, 16.45], [111.4, 16.3], [111.9, 16.0],
];

/// Khung thu nhỏ quần đảo Trường Sa: (kinh tây, vĩ bắc, kinh đông, vĩ nam) — trùng bản web.
const truongSaBox = (110.15, 10.6, 111.9, 8.5);

/// Chấm đảo trong khung Trường Sa, theo tỉ lệ (0..1, 0..1) của khung.
const truongSaDots = <List<double>>[
  [0.25, 0.42], [0.38, 0.6], [0.52, 0.45], [0.66, 0.72], [0.30, 0.82],
  [0.72, 0.5], [0.45, 0.9], [0.58, 0.62], [0.78, 0.86],
];

/// 'Hoàng Sa' | 'Trường Sa' | null tại toạ độ (lon, lat).
String? islandAt(double lon, double lat) {
  if (lon >= 110.85 && lon <= 112.0 && lat >= 15.75 && lat <= 17.15) return 'Hoàng Sa';
  final (w, n, e, s) = truongSaBox;
  if (lon >= w && lon <= e && lat >= s && lat <= n) return 'Trường Sa';
  return null;
}

/// Tỉ lệ rộng/cao của bản đồ khi chiếu như bản web: kinh độ co lại theo cos(vĩ độ giữa) ≈ 0,96.
final double mapAspect = (lon1 - lon0) * math.cos((lat0 + lat1) / 2 * math.pi / 180) / (lat1 - lat0);

/// Ranh giới 6 vùng (vẽ nét đứt) — trùng RBOUND của web/ban-do.html.
const regionBorders = <List<double>>[
  [102, 20.4, 104.75, 20.4], [104.75, 20.4, 104.75, 23.6], [102, 20.0, 110, 20.0], [102, 16.0, 110, 16.0],
  [102, 15.3, 108.55, 15.3], [108.55, 15.3, 108.55, 11.4], [107.35, 11.4, 108.55, 11.4], [102, 12.4, 107.35, 12.4],
  [107.35, 12.4, 107.35, 11.4], [107.6, 11.4, 107.6, 10.5], [107.6, 10.5, 110, 10.5],
];
