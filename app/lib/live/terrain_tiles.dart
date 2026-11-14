// BẢN ĐỒ ĐỊA HÌNH THẬT cho "rê tay khám phá": độ cao + lớp phủ đất (rừng, nước, ruộng, đô thị) quanh một điểm.
//
// Nguồn (tải theo ô bản đồ, độ phân giải vừa phải để mở nhanh):
//   • Độ cao: ô "Terrarium" (AWS Open Data, dựng chủ yếu từ SRTM của NASA), mức 13 ≈ 18 m mỗi điểm ảnh ở Việt Nam.
//     Mã hoá trong ảnh PNG: độ cao (m) = R·256 + G + B/256 − 32768 (biển có số âm = độ sâu).
//   • Lớp phủ: NASA GIBS, MODIS MCD12Q1 phân loại IGBP (500 m, năm mới nhất): 17 lớp → rừng, ruộng, đô thị, mặt nước…
// Cả hai đều cho phép trình duyệt tải trực tiếp (bản web) và tải được trên điện thoại. Lỗi mạng → trả null, app dùng
// lưới độ cao cũ (không lỗi).
//
// Kết quả là một lưới n×n MƯỢT (nội suy hai chiều), không phải các ô vuông: vẽ thành ảnh địa hình thật có bóng đổ,
// và đọc độ cao / lớp phủ đúng chỗ ngón tay.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'terrain_patch.dart';

export 'terrain_patch.dart';

// ---- toạ độ ô bản đồ Web Mercator ----
double _px(double lon, int z) => (lon + 180) / 360 * 256 * (1 << z);
double _py(double lat, int z) {
  final s = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
  return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * 256 * (1 << z);
}

class _Tiles {
  final int z;
  final Map<(int, int), (Uint8List, int, int)> rgba = {}; // (cột, hàng) → (RGBA, rộng, cao)
  _Tiles(this.z);

  /// RGBA của điểm ảnh toàn cục (px, py) ở mức z; null nếu ô chưa có.
  (int, int, int, int)? at(int px, int py) {
    final t = rgba[(px >> 8, py >> 8)];
    if (t == null) return null;
    final (b, w, h) = t;
    final x = (px & 255) * w ~/ 256, y = (py & 255) * h ~/ 256;
    final i = (y * w + x) * 4;
    if (i < 0 || i + 3 >= b.length) return null;
    return (b[i], b[i + 1], b[i + 2], b[i + 3]);
  }
}

final _cache = <String, Uint8List>{}; // url → bytes (giữ trong phiên)
Future<Uint8List?> _get(String url, http.Client client) async {
  final c = _cache[url];
  if (c != null) return c;
  try {
    final r = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
    if (_cache.length > 64) _cache.remove(_cache.keys.first);
    return _cache[url] = r.bodyBytes;
  } catch (_) {
    return null;
  }
}

Future<(Uint8List, int, int)?> _decode(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final f = await codec.getNextFrame();
    final img = f.image;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = img.width, h = img.height;
    img.dispose();
    return bd == null ? null : (bd.buffer.asUint8List(), w, h);
  } catch (_) {
    return null;
  }
}

Future<_Tiles> _fetchTiles(double lat, double lon, double radius, int z, String Function(int z, int x, int y) url,
    http.Client client) async {
  final t = _Tiles(z);
  final dLat = radius / 110540.0, dLon = radius / (111320.0 * math.cos(lat * math.pi / 180));
  final x0 = _px(lon - dLon, z).floor() >> 8, x1 = _px(lon + dLon, z).floor() >> 8;
  final y0 = _py(lat + dLat, z).floor() >> 8, y1 = _py(lat - dLat, z).floor() >> 8;
  final jobs = <Future<void>>[];
  for (var x = x0; x <= x1; x++) {
    for (var y = y0; y <= y1; y++) {
      jobs.add(() async {
        final b = await _get(url(z, x, y), client);
        if (b == null) return;
        final d = await _decode(b);
        if (d != null) t.rgba[(x, y)] = d;
      }());
    }
  }
  await Future.wait(jobs);
  return t;
}

String terrariumUrl(int z, int x, int y) => 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$z/$x/$y.png';
String gibsCoverUrl(int z, int x, int y) =>
    'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual/default/default/'
    'GoogleMapsCompatible_Level8/$z/$y/$x.png';

/// Tải bản đồ địa hình thật quanh (lat, lon), khung ±[radius] mét, lưới [n]×[n]. null nếu không tải được độ cao.
/// [elevZoom] 13 ≈ 18 m/điểm ảnh ở Việt Nam (đủ mịn cho khung 2–5 km mà chỉ 1–4 ô ảnh, mở nhanh).
Future<TerrainPatch?> loadTerrainPatch(double lat, double lon, double radius,
    {int n = 128, int elevZoom = 13, http.Client? client}) async {
  final cl = client ?? http.Client();
  try {
    final results = await Future.wait([
      _fetchTiles(lat, lon, radius, elevZoom, terrariumUrl, cl),
      _fetchTiles(lat, lon, radius, 8, gibsCoverUrl, cl), // MODIS: mức 8 là mức cao nhất GIBS có cho lớp này
    ]);
    final dem = results[0], lc = results[1];
    if (dem.rgba.isEmpty) return null;
    final elev = Float32List(n * n), cover = Uint8List(n * n);
    final cosLat = math.cos(lat * math.pi / 180);
    for (var r = 0; r < n; r++) {
      final y = radius - r * 2 * radius / (n - 1);
      final la = lat + y / 110540.0;
      for (var c = 0; c < n; c++) {
        final x = -radius + c * 2 * radius / (n - 1);
        final lo = lon + x / (111320.0 * cosLat);
        // độ cao: nội suy hai chiều giữa 4 điểm ảnh gần nhất (mượt, không thành bậc)
        final gx = _px(lo, elevZoom) - 0.5, gy = _py(la, elevZoom) - 0.5;
        final ix = gx.floor(), iy = gy.floor();
        final tx = gx - ix, ty = gy - iy;
        double? e(int px, int py) {
          final p = dem.at(px, py);
          return p == null ? null : terrariumElev(p.$1, p.$2, p.$3);
        }
        final a = e(ix, iy), b = e(ix + 1, iy), cc = e(ix, iy + 1), d = e(ix + 1, iy + 1);
        elev[r * n + c] = (a == null || b == null || cc == null || d == null)
            ? (a ?? b ?? cc ?? d ?? double.nan)
            : (a * (1 - tx) + b * tx) * (1 - ty) + (cc * (1 - tx) + d * tx) * ty;
        final p = lc.at(_px(lo, 8).floor(), _py(la, 8).floor());
        cover[r * n + c] = p == null ? 255 : igbpFromRgb(p.$1, p.$2, p.$3, p.$4);
      }
    }
    return finishPatch(lat, lon, radius, n, elev, cover,
        lc.rgba.isEmpty ? 'SRTM (Terrarium)' : 'SRTM (Terrarium) + NASA MODIS IGBP');
  } finally {
    if (client == null) cl.close();
  }
}

/// Ảnh Flutter từ bản đồ địa hình.
Future<ui.Image> terrainImage(TerrainPatch p) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(renderTerrainRgba(p), p.n, p.n, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

