// ĐỘ CAO ĐỊA HÌNH cho quả địa cầu nổi khối, chế độ chạm địa hình và các câu hỏi "cao bao nhiêu".
//  • Lưới toàn cầu 0,5° (720 × 360, Int16, ~0,5 MB) đóng gói trong app → chạy offline, có cả độ sâu đáy biển.
//    Nguồn: ETOPO (NOAA, phạm vi công cộng), lấy trung bình theo ô — tool tạo: xem assets/world/NGUON-DO-CAO.txt.
//  • Khi phóng to / hỏi một điểm: tải ô độ cao chi tiết "Terrarium" (dữ liệu mở trên AWS, miễn phí, không cần khoá,
//    chạy cả trên web vì máy chủ cho phép CORS). Mỗi ô 256 × 256 điểm, độ cao = R·256 + G + B/256 − 32768 (mét).
//    Lỗi mạng → vẫn dùng lưới toàn cầu, không báo lỗi.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class Terrain {
  Terrain(this._client, {this.log});
  final http.Client _client;
  final void Function(String)? log;

  /// Tăng mỗi khi có thêm dữ liệu (ô chi tiết tải xong) → quả cầu vẽ lại.
  final rev = ValueNotifier<int>(0);

  static const gw = 720, gh = 360;
  Int16List? _g;
  bool get ready => _g != null;

  Future<void> load() async {
    if (_g != null) return;
    try {
      final b = await rootBundle.load('assets/world/elev_glob.bin');
      // đọc từng số (không dùng asInt16List: trên web vùng nhớ có thể lệch, ném lỗi)
      final n = b.lengthInBytes ~/ 2;
      final g = Int16List(n);
      for (var i = 0; i < n; i++) {
        g[i] = b.getInt16(i * 2, Endian.little);
      }
      setGlobal(g);
      await buildWorld();
    } catch (e) {
      log?.call('terrain: không đọc được lưới độ cao: $e');
    }
  }

  /// Gán lưới toàn cầu (dùng trong kiểm thử). Hàng 0 = vĩ độ 89,75°, cột 0 = kinh độ −179,75°. Little-endian.
  void setGlobal(Int16List g) {
    if (g.length != gw * gh) return;
    if (Endian.host == Endian.big) {
      final bd = ByteData.sublistView(g);
      final c = Int16List(g.length);
      for (var i = 0; i < c.length; i++) {
        c[i] = bd.getInt16(i * 2, Endian.little);
      }
      g = c;
    }
    _g = g;
    rev.value++;
  }

  /// Độ cao từ lưới toàn cầu (nội suy song tuyến), NaN nếu chưa có lưới.
  double globalAt(double lat, double lon) {
    final g = _g;
    if (g == null) return double.nan;
    final fy = ((89.75 - lat) / 0.5).clamp(0.0, gh - 1.0);
    var fx = (lon + 179.75) / 0.5;
    fx = fx % gw;
    final y0 = fy.floor(), x0 = fx.floor();
    final y1 = math.min(gh - 1, y0 + 1), x1 = (x0 + 1) % gw;
    final ty = fy - y0, tx = fx - x0;
    final a = g[y0 * gw + x0] * (1 - tx) + g[y0 * gw + x1] * tx;
    final b = g[y1 * gw + x0] * (1 - tx) + g[y1 * gw + x1] * tx;
    return a * (1 - ty) + b * ty;
  }

  // ---------------- ẢNH NỔI KHỐI (vẽ sẵn một lần, quả cầu chỉ dán ảnh lên → quay mượt) ----------------
  /// Ảnh cả thế giới (phép chiếu kinh–vĩ độ, 1024 × 512): màu theo độ cao + bóng đổ sườn núi.
  ui.Image? world;

  /// Ảnh chi tiết vùng đang xem (từ ô chi tiết), dựng lại khi camera đứng yên. [detailBox]: (vĩ 0, vĩ 1, kinh 0, kinh 1).
  ui.Image? detail;
  (double, double, double, double)? detailBox;
  Timer? _detailTimer;
  String _detailKey = '';
  int _detailGen = 0;

  static const ww = 1024, wh = 512;

  /// Dựng ảnh thế giới từ lưới (chạy từng đoạn để không đứng hình).
  Future<void> buildWorld() async {
    if (_g == null || world != null) return;
    final px = Uint8List(ww * wh * 4);
    const step = 360 / ww;
    for (var y = 0; y < wh; y++) {
      final lat = 90 - (y + 0.5) * 180 / wh;
      final cosl = math.max(0.2, math.cos(lat * math.pi / 180));
      for (var x = 0; x < ww; x++) {
        final lon = -180 + (x + 0.5) * step;
        final e = globalAt(lat, lon);
        final ee = globalAt(lat, lon + step / cosl), en = globalAt(math.min(89.9, lat + step), lon);
        _px(px, (y * ww + x) * 4, e, ee, en, step, 18);
      }
      if (y % 48 == 47) await Future<void>.delayed(Duration.zero);
    }
    world = await _image(px, ww, wh);
    rev.value++;
  }

  /// Xin ảnh chi tiết cho khung đang xem; chỉ dựng khi camera đứng yên ~0,4 giây (đang quay thì không tốn gì).
  void wantDetail(double lat0, double lat1, double lon0, double lon1) {
    final span = math.max(lat1 - lat0, lon1 - lon0);
    final q = math.max(0.05, span / 6);
    double r(double v) => (v / q).round() * q;
    final k = '${r(lat0)}|${r(lat1)}|${r(lon0)}|${r(lon1)}';
    if (k == _detailKey) return;
    _detailTimer?.cancel();
    _detailTimer = Timer(const Duration(milliseconds: 400), () {
      _detailKey = k;
      unawaited(_buildDetail(lat0, lat1, lon0, lon1, ++_detailGen));
    });
  }

  Future<void> _buildDetail(double lat0, double lat1, double lon0, double lon1, int gen) async {
    const n = 384;
    final span = math.max(lat1 - lat0, lon1 - lon0);
    var z = (math.log(360 * n / (256 * span)) / math.ln2).ceil().clamp(3, 11);
    Set<(int, int, int)> need() => {
          for (var i = 0; i <= 8; i++)
            for (var j = 0; j <= 8; j++)
              tileOf((lat0 + (lat1 - lat0) * i / 8).clamp(-84.9, 84.9), _wrap(lon0 + (lon1 - lon0) * j / 8), z)
        };
    var tiles = need();
    while (tiles.length > 30 && z > 3) {
      z--;
      tiles = need();
    }
    dropQueued();
    await ensure(tiles, timeout: const Duration(seconds: 6));
    if (gen != _detailGen) return;
    final px = Uint8List(n * n * 4);
    final dLat = (lat1 - lat0) / n, dLon = (lon1 - lon0) / n;
    final step = math.max(dLat, dLon);
    final ex = (3 + 28 * step).clamp(3.0, 14.0);
    for (var y = 0; y < n; y++) {
      final lat = lat1 - (y + 0.5) * dLat;
      final cosl = math.max(0.2, math.cos(lat * math.pi / 180));
      for (var x = 0; x < n; x++) {
        final lon = _wrap(lon0 + (x + 0.5) * dLon);
        final e = at(lat, lon, preferZ: z);
        final ee = at(lat, _wrap(lon + step / cosl), preferZ: z), en = at(math.min(89.9, lat + step), lon, preferZ: z);
        _px(px, (y * n + x) * 4, e, ee, en, step, ex);
      }
      if (y % 64 == 63) {
        await Future<void>.delayed(Duration.zero);
        if (gen != _detailGen) return;
      }
    }
    final img = await _image(px, n, n);
    if (gen != _detailGen) {
      img.dispose();
      return;
    }
    detail?.dispose();
    detail = img;
    detailBox = (lat0, lat1, lon0, lon1);
    rev.value++;
  }

  static double _wrap(double lon) => ((lon + 540) % 360) - 180;

  static Future<ui.Image> _image(Uint8List px, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Một điểm ảnh: màu theo độ cao, sáng / tối theo sườn (ánh sáng từ tây bắc). [step] độ, [ex] phóng đại dốc.
  static void _px(Uint8List px, int o, double e, double ee, double en, double step, double ex) {
    if (e.isNaN) return;
    final c = hypso(e);
    final m = step * 111320;
    final s = e < 0 ? ex * 0.3 : ex;
    final gx = -s * ((ee.isNaN ? e : ee) - e) / m, gy = -s * ((en.isNaN ? e : en) - e) / m;
    const lx = -0.55, ly = 0.55, lz = 0.63;
    final d = (gx * lx + gy * ly + lz) / math.sqrt(gx * gx + gy * gy + 1) - lz; // < 0 sườn khuất nắng
    final k = (1 + (e < 0 ? 0.9 : 2.4) * d).clamp(0.4, 1.5);
    px[o] = (((c >> 16) & 0xFF) * k).round().clamp(0, 255);
    px[o + 1] = (((c >> 8) & 0xFF) * k).round().clamp(0, 255);
    px[o + 2] = ((c & 0xFF) * k).round().clamp(0, 255);
    final a = (c >> 24) & 0xFF;
    px[o + 3] = (a + (d < 0 && e >= 0 ? math.min(60.0, -d * 260) : 0)).round().clamp(0, 255);
  }

  /// Màu theo độ cao (ARGB): biển sâu xanh thẫm → biển nông xanh ngọc; đồng bằng xanh lục → đồi vàng nâu
  /// → núi nâu đỏ → đá xám → tuyết trắng. Có độ trong để vẫn thấy màu nước, biên giới bên dưới.
  static int hypso(double e) {
    // tuyết chỉ trên ~5.500 m (cao nguyên Tây Tạng là đá nâu xám, không trắng xoá)
    const land = <(double, int, int, int, int)>[
      (0, 0x26, 0x6E, 0x3A, 140),     // đồng bằng / châu thổ: xanh ngọc bích tươi tốt
      (200, 0x36, 0x7A, 0x44, 140),   // thung lũng & đồi thấp: xanh lá tự nhiên
      (600, 0x4D, 0x86, 0x4E, 145),   // rừng nhiệt đới & đồi trung du: xanh rừng rậm
      (1400, 0x6E, 0x88, 0x58, 150),  // cao nguyên & sườn núi: xanh ấm
      (2400, 0x8C, 0x7E, 0x60, 155),  // dốc núi & đá đồi: đất đá ấm
      (3600, 0x7E, 0x74, 0x6E, 165),  // núi cao hiểm trở: đá xám hoa cương
      (5000, 0xAA, 0xAA, 0xB0, 180),  // vách đá cao cằn cỗi
      (6200, 0xF5, 0xF7, 0xFA, 205),  // tuyết trắng đỉnh cao
    ];
    const sea = <(double, int, int, int, int)>[
      (0, 0x1E, 0x86, 0xA8, 90),       // bờ biển nhiệt đới: xanh ngọc lam rực rỡ
      (-150, 0x16, 0x60, 0x8A, 75),    // thềm lục địa: xanh biển sáng
      (-1200, 0x10, 0x42, 0x6E, 60),   // biển sâu
      (-4000, 0x0A, 0x28, 0x4A, 70),   // đáy đại dương: xanh lam sẫm
      (-8000, 0x04, 0x12, 0x2A, 95),   // rãnh đại dương sâu thẳm
    ];
    final stops = e >= 0 ? land : sea;
    var i = 0;
    while (i < stops.length - 2 && (e >= 0 ? e > stops[i + 1].$1 : e < stops[i + 1].$1)) {
      i++;
    }
    final a = stops[i], b = stops[i + 1];
    final t = ((e - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
    int mix(int p, int q) => (p + (q - p) * t).round();
    return (mix(a.$5, b.$5) << 24) | (mix(a.$2, b.$2) << 16) | (mix(a.$3, b.$3) << 8) | mix(a.$4, b.$4);
  }

  // ---------------- ô chi tiết ----------------
  static const maxTileZ = 12;
  final _tiles = <int, Int16List>{}; // LRU (Map mặc định giữ thứ tự thêm)
  final _failed = <int, DateTime>{};
  final _pending = <int>{};
  final _queue = <int>[];
  int _active = 0;
  int _maxZ = -1; // ô có mức phóng lớn nhất đang có trong bộ nhớ
  static const _cap = 96; // ~12 MB

  // không dùng phép dịch bit (trên web chỉ 32 bit): nhân / chia nguyên vẫn đúng tới 2^53
  static const _m = 1048576; // 2^20
  static int key(int z, int x, int y) => (z * _m + x) * _m + y;
  static int keyZ(int k) => k ~/ (_m * _m);

  static double tileX(double lon, int z) => (lon + 180) / 360 * (1 << z);
  static double tileY(double lat, int z) {
    final l = lat.clamp(-85.05, 85.05) * math.pi / 180;
    return (1 - math.log(math.tan(l) + 1 / math.cos(l)) / math.pi) / 2 * (1 << z);
  }

  /// Độ cao tốt nhất đang có: ô chi tiết mức [preferZ] trở xuống, không có thì lưới toàn cầu.
  double at(double lat, double lon, {int? preferZ}) {
    final top = math.min(preferZ ?? _maxZ, _maxZ);
    if (top >= 0 && lat.abs() < 85) {
      for (var z = top; z >= 0; z--) {
        final fx = tileX(lon, z), fy = tileY(lat, z);
        final n = 1 << z;
        final x = fx.floor() % n, y = fy.floor().clamp(0, n - 1);
        final t = _tiles[key(z, x, y)];
        if (t == null) continue;
        final px = ((fx - fx.floor()) * 256).clamp(0.0, 255.0), py = ((fy - fy.floor()) * 256).clamp(0.0, 255.0);
        final x0 = math.min(254, px.floor()), y0 = math.min(254, py.floor());
        final tx = px - x0, ty = py - y0;
        final a = t[y0 * 256 + x0] * (1 - tx) + t[y0 * 256 + x0 + 1] * tx;
        final b = t[(y0 + 1) * 256 + x0] * (1 - tx) + t[(y0 + 1) * 256 + x0 + 1] * tx;
        return a * (1 - ty) + b * ty;
      }
    }
    return globalAt(lat, lon);
  }

  bool hasTile(int z, int x, int y) => _tiles.containsKey(key(z, x, y));

  /// Xin tải các ô (z, x, y) — không chờ; tải xong thì [rev] tăng. Ô mới xin được ưu tiên.
  void want(Iterable<(int, int, int)> tiles) {
    for (final (z, x, y) in tiles) {
      final k = key(z, x, y);
      if (_tiles.containsKey(k) || _pending.contains(k)) continue;
      final f = _failed[k];
      if (f != null && DateTime.now().difference(f).inSeconds < 60) continue;
      _pending.add(k);
      _queue.add(k);
    }
    _pump();
  }

  /// Bỏ các ô đang chờ (chưa bắt đầu tải) — khi camera đã đi chỗ khác.
  void dropQueued() {
    for (final k in _queue) {
      _pending.remove(k);
    }
    _queue.clear();
  }

  void _pump() {
    while (_active < 6 && _queue.isNotEmpty) {
      final k = _queue.removeLast();
      _active++;
      _fetch(k).whenComplete(() {
        _active--;
        _pending.remove(k);
        _pump();
      });
    }
  }

  Future<bool> _fetch(int k) async {
    final z = keyZ(k), x = (k ~/ _m) % _m, y = k % _m;
    try {
      final r = await _client
          .get(Uri.https('s3.amazonaws.com', '/elevation-tiles-prod/terrarium/$z/$x/$y.png'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final t = await decodeTerrarium(r.bodyBytes);
      _tiles.remove(k);
      _tiles[k] = t;
      while (_tiles.length > _cap) {
        _tiles.remove(_tiles.keys.first);
      }
      _maxZ = _tiles.keys.fold(-1, (m, kk) => math.max(m, keyZ(kk)));
      rev.value++;
      return true;
    } catch (e) {
      _failed[k] = DateTime.now();
      log?.call('terrain: ô $z/$x/$y lỗi: $e');
      return false;
    }
  }

  /// Giải mã ảnh PNG Terrarium → độ cao (m) 256 × 256.
  static Future<Int16List> decodeTerrarium(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = img.width, h = img.height;
    img.dispose();
    codec.dispose();
    if (bd == null || w != 256 || h != 256) throw Exception('ảnh độ cao sai cỡ');
    final px = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    return terrariumToElev(px);
  }

  /// RGBA → độ cao (mét, làm tròn). Tách riêng để kiểm thử.
  static Int16List terrariumToElev(Uint8List rgba) {
    final n = rgba.length ~/ 4;
    final out = Int16List(n);
    for (var i = 0; i < n; i++) {
      final v = rgba[i * 4] * 256 + rgba[i * 4 + 1] + rgba[i * 4 + 2] / 256 - 32768;
      out[i] = v.round().clamp(-12000, 9000);
    }
    return out;
  }

  /// Ô chứa điểm ở mức [z].
  static (int, int, int) tileOf(double lat, double lon, int z) {
    final n = 1 << z;
    return (z, tileX(lon, z).floor() % n, tileY(lat, z).floor().clamp(0, n - 1));
  }

  /// Chờ có các ô (tối đa [timeout]); trả về true nếu đủ.
  Future<bool> ensure(Iterable<(int, int, int)> tiles, {Duration timeout = const Duration(seconds: 8)}) async {
    final need = tiles.toSet();
    want(need);
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (need.every((t) => hasTile(t.$1, t.$2, t.$3))) return true;
      // hết hy vọng: tất cả các ô còn thiếu đều đã lỗi
      final missing = need.where((t) => !hasTile(t.$1, t.$2, t.$3));
      if (missing.every((t) => _failed.containsKey(key(t.$1, t.$2, t.$3)) && !_pending.contains(key(t.$1, t.$2, t.$3)))) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return false;
  }

  /// Độ cao chính xác hơn tại một điểm (ô mức [z], mặc định ~75 m/điểm). Lỗi mạng → lưới toàn cầu.
  Future<double> precise(double lat, double lon, {int z = 11}) async {
    if (lat.abs() >= 85) return globalAt(lat, lon);
    final t = tileOf(lat, lon, z);
    await ensure([t]);
    return at(lat, lon, preferZ: z);
  }

  /// Lấy [n] điểm đều nhau trên các chặng [pts] (đường gấp khúc), dùng ô mức [z].
  Future<List<double>> line(List<(double, double)> pts, int n, {int z = 8}) async {
    final s = samplePath(pts, n);
    final need = <(int, int, int)>{for (final (la, lo) in s) if (la.abs() < 85) tileOf(la, lo, z)};
    if (need.length <= 40) await ensure(need, timeout: const Duration(seconds: 10));
    return [for (final (la, lo) in s) at(la, lo, preferZ: z)];
  }

  /// Bản đồ độ cao của một vùng: [rows] × [cols] điểm, hàng 0 ở phía bắc ([lat0]), cột 0 ở phía tây ([lon0]).
  /// Dùng ô mức [z]; quá nhiều ô thì hạ mức cho nhanh (lỗi mạng → lưới toàn cầu).
  Future<List<List<double>>> grid(double lat0, double lat1, double lon0, double lon1, int rows, int cols, {int z = 9}) async {
    double la(int r) => lat0 + (lat1 - lat0) * r / math.max(1, rows - 1);
    double lo(int c) => lon0 + (lon1 - lon0) * c / math.max(1, cols - 1);
    var zz = z;
    Set<(int, int, int)> need() => {
          for (var r = 0; r < rows; r++)
            for (var c = 0; c < cols; c++)
              if (la(r).abs() < 85) tileOf(la(r), lo(c), zz)
        };
    var tiles = need();
    while (tiles.length > 36 && zz > 3) {
      zz--;
      tiles = need();
    }
    await ensure(tiles, timeout: const Duration(seconds: 10));
    return [
      for (var r = 0; r < rows; r++) [for (var c = 0; c < cols; c++) at(la(r), lo(c), preferZ: zz)]
    ];
  }

  /// Độ cao 8 hướng (bắc, đông bắc…) cách [km] km quanh một điểm.
  Future<List<double>> ring(double lat, double lon, double km, {int z = 10}) async {
    final pts = [for (var i = 0; i < 8; i++) _off(lat, lon, km, i * 45.0)];
    final need = <(int, int, int)>{tileOf(lat, lon, z), for (final (la, lo) in pts) if (la.abs() < 85) tileOf(la, lo, z)};
    await ensure(need);
    return [for (final (la, lo) in pts) at(la, lo, preferZ: z)];
  }

  static (double, double) _off(double lat, double lon, double km, double b) {
    const r = 6371.0;
    final d = km / r, br = b * math.pi / 180;
    final p1 = lat * math.pi / 180, l1 = lon * math.pi / 180;
    final p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(br));
    final l2 = l1 + math.atan2(math.sin(br) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2));
    return (p2 * 180 / math.pi, ((l2 * 180 / math.pi + 540) % 360) - 180);
  }
}

/// Lấy [n] điểm cách đều (theo độ dài) trên đường gấp khúc [pts] (vĩ độ, kinh độ).
List<(double, double)> samplePath(List<(double, double)> pts, int n) {
  if (pts.isEmpty || n <= 0) return const [];
  if (pts.length == 1 || n == 1) return [pts.first];
  final seg = <double>[];
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final dl = _dLon(pts[i].$2 - pts[i - 1].$2) * math.cos((pts[i].$1 + pts[i - 1].$1) / 2 * math.pi / 180);
    final d = math.sqrt(math.pow(pts[i].$1 - pts[i - 1].$1, 2) + dl * dl);
    seg.add(d);
    total += d;
  }
  final out = <(double, double)>[];
  for (var k = 0; k < n; k++) {
    var want = total * k / (n - 1);
    var i = 0;
    while (i < seg.length - 1 && want > seg[i]) {
      want -= seg[i];
      i++;
    }
    final t = seg[i] <= 0 ? 0.0 : (want / seg[i]).clamp(0.0, 1.0);
    final a = pts[i], b = pts[i + 1];
    final lon = a.$2 + _dLon(b.$2 - a.$2) * t;
    out.add((a.$1 + (b.$1 - a.$1) * t, ((lon + 540) % 360) - 180));
  }
  return out;
}

double _dLon(double d) {
  while (d > 180) {
    d -= 360;
  }
  while (d < -180) {
    d += 360;
  }
  return d;
}
