// Vẽ QUẢ ĐỊA CẦU 3D (phép chiếu trực giao — nhìn quả cầu từ xa), thuần CustomPainter nên chạy giống nhau
// trên Windows, điện thoại và web (không cần WebGL hay gói bản đồ ngoài, không cần khoá API).
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'terrain.dart';
import 'world.dart';

/// Camera nhìn quả cầu: tâm (vĩ độ, kinh độ) và độ phóng (1 = thấy cả quả cầu).
@immutable
class GlobeCamera {
  final double lat, lon, zoom;
  const GlobeCamera(this.lat, this.lon, this.zoom);

  static const start = GlobeCamera(14, 106, 1.0); // mở app: Việt Nam ở giữa

  GlobeCamera copyWith({double? lat, double? lon, double? zoom}) =>
      GlobeCamera(lat ?? this.lat, lon ?? this.lon, zoom ?? this.zoom);

  /// Nội suy theo đường ngắn nhất quanh kinh tuyến; độ phóng nội suy theo log (bay mượt).
  static GlobeCamera lerp(GlobeCamera a, GlobeCamera b, double t) {
    var dl = b.lon - a.lon;
    while (dl > 180) {
      dl -= 360;
    }
    while (dl < -180) {
      dl += 360;
    }
    final lz = math.log(a.zoom) + (math.log(b.zoom) - math.log(a.zoom)) * t;
    return GlobeCamera(a.lat + (b.lat - a.lat) * t, _wrap(a.lon + dl * t), math.exp(lz));
  }

  static double _wrap(double lon) => wrapLon(lon);
}

/// Đưa kinh độ về khoảng −180…180.
double wrapLon(double lon) => ((lon + 180) % 360 + 360) % 360 - 180;

/// Phép chiếu dùng chung cho vẽ và cho chạm (đổi điểm trên màn hình → toạ độ).
class GlobeProjection {
  final GlobeCamera cam;
  final Offset c;
  final double r;
  late final double _sp0 = math.sin(cam.lat * math.pi / 180), _cp0 = math.cos(cam.lat * math.pi / 180);
  late final double _l0 = cam.lon * math.pi / 180;
  GlobeProjection(this.cam, Size size)
      : c = size.center(Offset.zero),
        r = math.min(size.width, size.height) * 0.44 * cam.zoom;

  /// (x, y trên màn hình, có nhìn thấy không). Điểm khuất được kéo về mép quả cầu.
  (double, double, bool) project(double lon, double lat) {
    final p = lat * math.pi / 180, l = lon * math.pi / 180 - _l0;
    final cp = math.cos(p), sp = math.sin(p), cl = math.cos(l);
    final cosc = _sp0 * sp + _cp0 * cp * cl;
    final x = cp * math.sin(l), y = _cp0 * sp - _sp0 * cp * cl;
    if (cosc >= 0) return (c.dx + r * x, c.dy - r * y, true);
    final m = math.sqrt(x * x + y * y);
    final k = m < 1e-9 ? 0.0 : 1 / m;
    return (c.dx + r * x * k, c.dy - r * y * k, false);
  }

  /// Điểm trên màn hình → (kinh độ, vĩ độ), null nếu ngoài quả cầu.
  (double, double)? unproject(Offset o) {
    final x = (o.dx - c.dx) / r, y = -(o.dy - c.dy) / r;
    final rho = math.sqrt(x * x + y * y);
    if (rho > 1) return null;
    if (rho < 1e-9) return (cam.lon, cam.lat);
    final cc = math.asin(rho);
    final sc = math.sin(cc), ccos = math.cos(cc);
    final lat = math.asin(ccos * _sp0 + y * sc * _cp0 / rho);
    final lon = _l0 + math.atan2(x * sc, rho * _cp0 * ccos - y * _sp0 * sc);
    return (GlobeCamera._wrap(lon * 180 / math.pi), lat * 180 / math.pi);
  }
}

/// Điểm đang được nói tới (ghim trên quả cầu).
class GlobePin {
  final double lon, lat;
  final String label;
  const GlobePin(this.lon, this.lat, this.label);
}

/// Lớp NỀN của quả cầu: biển, lưới, biên giới, tên nước. Chỉ vẽ lại khi camera / bản đồ / ngôn ngữ đổi
/// (không vẽ lại theo nhịp nhấp nháy của ghim — phần đó ở [GlobeFxPainter]) → mượt hơn nhiều, nhất là trên web.
class GlobePainter extends CustomPainter {
  final World? world;
  final ValueListenable<GlobeCamera> camera;
  final bool en; // nhãn tiếng Anh
  final Terrain? terrain; // độ cao → tô nổi khối núi non, đáy biển (null = phẳng như cũ)
  /// true khi đang kéo / chụm / bay: vẽ nhẹ hơn (bớt điểm biên giới, lưới nổi khối thưa hơn) để giữ 60 hình/giây;
  /// buông tay là vẽ lại bản đầy đủ.
  final ValueListenable<bool>? moving;

  GlobePainter({required this.world, required this.camera, this.en = false, this.terrain, this.moving})
      : super(
            repaint: Listenable.merge([camera, if (terrain != null) terrain.rev, if (moving != null) moving]));

  GlobeCamera get cam => camera.value;
  bool get _fast => moving?.value ?? false;

  // Bảng màu: vũ trụ đêm sâu, biển xanh lam sẫm, đất nâu ấm (gỗ đàn bầu), Việt Nam đỏ son viền vàng (sơn mài)
  static const _space = Color(0xFF03060B);
  static const _ocean1 = Color(0xFF103D5E), _ocean2 = Color(0xFF061524);
  static const _land = Color(0xFF263A29), _landHi = Color(0xFF334B35);
  static const _vn = Color(0xFFB23A2A); // son đỏ
  static const _border = Color(0x99F1E5CC);
  static const _gold = Color(0xFFE4BB63);
  static const _text = Color(0xFFF1E5CC);

  static final _labels = <String, TextPainter>{};
  static TextPainter _tp(String s, double size, Color color, {FontWeight w = FontWeight.w600}) {
    final key = '$s|$size|${color.toARGB32()}|${w.value}';
    return _labels.putIfAbsent(key, () {
      if (_labels.length > 400) _labels.clear();
      return TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: size,
                fontWeight: w,
                color: color,
                shadows: const [Shadow(blurRadius: 3, color: Colors.black)])),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  // sao nền cố định (không đổi giữa các khung hình → không nhấp nháy)
  static final _stars = () {
    final rnd = math.Random(11);
    return [for (var k = 0; k < 220; k++) (rnd.nextDouble(), rnd.nextDouble(), 0.3 + rnd.nextDouble() * 1.1, 0.25 + rnd.nextDouble() * 0.6)];
  }();

  /// Điểm Mặt Trời đang chiếu thẳng đứng (vĩ độ, kinh độ) theo giờ UTC hiện tại — để vẽ ngày / đêm thật.
  static (double, double) subsolar(DateTime utc) {
    final start = DateTime.utc(utc.year);
    final day = utc.difference(start).inMinutes / 1440.0;
    final decl = -23.44 * math.cos(2 * math.pi / 365 * (day + 10));
    final hours = utc.hour + utc.minute / 60 + utc.second / 3600;
    return (decl, wrapLon(-15 * (hours - 12)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pr = GlobeProjection(cam, size);
    final c = pr.c, r = pr.r;
    // ---- vũ trụ: nền đêm, sao, quầng tinh vân rất nhạt ----
    canvas.drawRect(Offset.zero & size, Paint()..color = _space);
    final star = Paint();
    for (final (x, y, rad, a) in _stars) {
      final o = Offset(x * size.width, y * size.height);
      if ((o - c).distance < r * 1.02) continue;
      star.color = Color.fromRGBO(230, 236, 255, a);
      canvas.drawCircle(o, rad, star);
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.7, -0.8),
            radius: 1.2,
            colors: [Color(0x182B4C8C), Color(0x00000000)],
          ).createShader(Offset.zero & size));
    // ---- khí quyển: quầng xanh mềm quanh quả cầu ----
    canvas.drawCircle(
        c,
        r * 1.15,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0x6643A0D8),
            Color(0x2243A0D8),
            Color(0x0043A0D8),
          ], stops: [0.86, 0.92, 1.0])
              .createShader(Rect.fromCircle(center: c, radius: r * 1.12)));
    // ---- biển: sáng ở phía có nắng, tối dần về mép → khối cầu ----
    final disc = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.35),
            radius: 1.1,
            colors: [_ocean1, _ocean2],
          ).createShader(disc));
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));

    _graticule(canvas, pr);

    final w = world;
    Path? vnLine;
    if (w != null) {
      final fill = Paint()..style = PaintingStyle.fill;
      // nhìn xa: biên giới mảnh, mờ (bớt rối); phóng to: rõ dần
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cam.zoom > 6 ? 1.2 : (cam.zoom > 2 ? 0.8 : 0.55)
        ..color = cam.zoom > 2 ? _border : const Color(0x55F1E5CC);
      final view = Rect.fromLTWH(-20, -20, size.width + 40, size.height + 40);
      // chỉ xét những nước có thể lọt vào khung nhìn (bỏ nửa sau quả cầu, bỏ nước ngoài khung khi phóng to)
      final sp0 = math.sin(cam.lat * math.pi / 180), cp0 = math.cos(cam.lat * math.pi / 180);
      final l0 = cam.lon * math.pi / 180;
      final cx = cp0 * math.cos(l0), cy = cp0 * math.sin(l0), cz = sp0;
      final halfDiag = math.sqrt(size.width * size.width + size.height * size.height) / 2;
      final cap = halfDiag >= r ? math.pi / 2 : math.asin(halfDiag / r);
      // bỏ bớt điểm sát nhau dưới ~1 điểm ảnh (nhìn xa có hàng nghìn điểm chồng lên nhau)
      _minStep = _fast ? (cam.zoom > 12 ? 1.4 : 2.4) : (cam.zoom > 12 ? 0.6 : 1.1);
      for (final country in w.countries) {
        final ang = math.acos((country.cx * cx + country.cy * cy + country.cz * cz).clamp(-1.0, 1.0));
        if (ang > cap + country.radius) continue;
        final isVn = country.a3 == 'VNM';
        final fp = Path(), sp = Path();
        var any = false;
        for (final ring in country.rings) {
          if (_ring(pr, ring, fp, sp, view)) any = true;
        }
        if (!any) continue;
        if (isVn) {
          // Nền đỏ son Việt Nam: vẽ tự nhiên cùng bản đồ trước relief và đêm
          fill.color = _vn;
          canvas.drawPath(fp, fill);
          vnLine = sp;
          continue;
        }
        fill.color = country.rank <= 2 ? _landHi : _land;
        canvas.drawPath(fp, fill);
        canvas.drawPath(sp, stroke);
      }
    }
    // ---- địa hình nổi khối: màu theo độ cao + bóng đổ núi (ánh sáng từ tây bắc) ----
    final relief = _relief(pr, size);
    if (relief != null) relief.draw(canvas, 1.0);
    // ---- ngày / đêm theo giờ thật: nửa không có nắng tối đi, có dải hoàng hôn mềm ----
    _night(canvas, pr);
    // Viền vàng kim sắc nét của Việt Nam: vẽ sau bóng đêm để biên giới chủ quyền luôn nổi bật, sắc sảo
    if (vnLine != null) {
      // 1. Quầng sáng vàng kim mềm (không dùng blur để tránh lem sương mù và tối ưu 60 FPS)
      canvas.drawPath(
          vnLine,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cam.zoom < 2 ? 2.2 : 2.8
            ..color = const Color(0x66E4BB63));
      // 2. Viền vàng kim sắc nét (sơn mài viền vàng đặc trưng)
      canvas.drawPath(
          vnLine,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cam.zoom < 2 ? 1.0 : 1.3
            ..color = _gold);
    }
    // ---- ánh sáng khối cầu: viền tối dần, góc trên trái có vệt sáng ----
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.45, -0.5),
            radius: 1.25,
            colors: [Color(0x26FFFFFF), Color(0x00000000), Color(0x80000000)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(disc));
    canvas.restore();
    // viền sáng mảnh ở mép (khí quyển nhìn nghiêng)
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0x77B2E5FC));
    canvas.drawCircle(
        c,
        r + 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0x334DBAE8));
    if (w != null) {
      _islands(canvas, pr);
      _countryLabels(canvas, pr, w, size);
    }
  }

  /// Bóng đêm: lưới tam giác phủ đĩa quả cầu, mỗi đỉnh tô theo góc chiếu của Mặt Trời (mượt, nhẹ, chạy cả trên web).
  void _night(Canvas canvas, GlobeProjection pr) {
    final (slat, slon) = subsolar(DateTime.now().toUtc());
    final sp0 = math.sin(cam.lat * math.pi / 180), cp0 = math.cos(cam.lat * math.pi / 180);
    final p = slat * math.pi / 180, l = (slon - cam.lon) * math.pi / 180;
    // vectơ Mặt Trời trong hệ nhìn (x phải, y lên, z hướng về người xem)
    final sx = math.cos(p) * math.sin(l);
    final sy = cp0 * math.sin(p) - sp0 * math.cos(p) * math.cos(l);
    final sz = sp0 * math.sin(p) + cp0 * math.cos(p) * math.cos(l);
    final pos = _nightPos, cols = _nightCols;
    int shade(double x, double y) {
      final z = math.sqrt(math.max(0.0, 1 - x * x - y * y));
      final d = x * sx + y * sy + z * sz;
      final k = ((0.10 - d) / 0.28).clamp(0.0, 1.0); // 0 = ngày, 1 = đêm; dải hoàng hôn ~ 16°
      final a = (k * k * (3 - 2 * k) * 135).round();
      return (a << 24) | 0x020612; // ARGB(a, 2, 6, 18)
    }

    pos[0] = pr.c.dx;
    pos[1] = pr.c.dy;
    cols[0] = shade(0, 0);
    var v = 1;
    for (var i = 1; i <= _nRings; i++) {
      final rho = math.min(0.999, i / _nRings);
      for (var j = 0; j < _nSegs; j++) {
        final x = rho * _cosT[j], y = rho * _sinT[j];
        pos[v * 2] = pr.c.dx + pr.r * x;
        pos[v * 2 + 1] = pr.c.dy - pr.r * y;
        cols[v] = shade(x, y);
        v++;
      }
    }
    canvas.drawVertices(
        ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: cols, indices: _nightIdx), BlendMode.dst, Paint());
  }

  static const _nRings = 16, _nSegs = 56;
  static final _cosT = Float64List.fromList([for (var j = 0; j < _nSegs; j++) math.cos(2 * math.pi * j / _nSegs)]);
  static final _sinT = Float64List.fromList([for (var j = 0; j < _nSegs; j++) math.sin(2 * math.pi * j / _nSegs)]);
  static final _nightPos = Float32List((1 + _nRings * _nSegs) * 2);
  static final _nightCols = Int32List(1 + _nRings * _nSegs);
  // chỉ số tam giác của lưới bóng đêm không đổi → dựng một lần
  static final _nightIdx = () {
    final idx = <int>[];
    for (var j = 0; j < _nSegs; j++) {
      idx..add(0)..add(1 + j)..add(1 + (j + 1) % _nSegs);
    }
    for (var i = 1; i < _nRings; i++) {
      final a0 = 1 + (i - 1) * _nSegs, b0 = 1 + i * _nSegs;
      for (var j = 0; j < _nSegs; j++) {
        final j1 = (j + 1) % _nSegs;
        idx
          ..add(a0 + j)
          ..add(b0 + j)
          ..add(b0 + j1)
          ..add(a0 + j)
          ..add(b0 + j1)
          ..add(a0 + j1);
      }
    }
    return Uint16List.fromList(idx);
  }();

  /// Địa hình nổi khối: DÁN ẢNH nổi khối (vẽ sẵn trong [Terrain]) lên lưới kinh–vĩ độ của phần quả cầu đang thấy.
  /// Mỗi khung hình chỉ chiếu vài nghìn đỉnh (không tính độ cao) → quay, kéo, bay đều mượt, không nhấp nháy.
  _Relief? _relief(GlobeProjection pr, Size size) {
    final t = terrain;
    final img = t?.world;
    if (t == null || img == null) return null;
    final pxPerDeg = pr.r * math.pi / 180;
    final halfDiag = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final cap = halfDiag >= pr.r ? 90.0 : math.asin(halfDiag / pr.r) * 180 / math.pi;
    // Lưới GẮN CỐ ĐỊNH vào quả cầu: bước lưới là 90 / 2^n độ và mép lưới bám bội số của bước → khi quay, đỉnh lưới
    // đi theo mặt đất (không trượt trên ảnh) nên ảnh không "bơi", không nhấp nháy. Mỗi ô ~14 điểm ảnh.
    var step = 90.0;
    final cell = _fast ? 24.0 : 14.0;
    while (step / 2 * pxPerDeg >= cell && step > 0.006) {
      step /= 2;
    }
    double snapDown(double v) => (v / step).floor() * step;
    double snapUp(double v) => (v / step).ceil() * step;
    var la0 = snapDown(math.max(-90, cam.lat - cap - step)), la1 = snapUp(math.min(90, cam.lat + cap + step));
    final pole = la0 <= -89.9 || la1 >= 89.9;
    la0 = math.max(-90, la0);
    la1 = math.min(90, la1);
    final edge = math.min(89.0, math.max(la0.abs(), la1.abs()));
    final lonHalf = pole ? 180.0 : math.min(180.0, (cap + step) / math.max(0.02, math.cos(edge * math.pi / 180)));
    var lo0 = snapDown(cam.lon - lonHalf), lo1 = snapUp(cam.lon + lonHalf);
    while (((la1 - la0) / step).round() * ((lo1 - lo0) / step).round() > 6000) {
      step *= 2;
      la0 = math.max(-90, snapDown(la0));
      la1 = math.min(90, snapUp(la1));
      lo0 = snapDown(lo0);
      lo1 = snapUp(lo1);
    }
    final world = _mesh(pr, la0, la1, lo0, lo1, step,
        (lat, lon) => ((lon + 180) / 360 * Terrain.ww, (90 - lat) / 180 * Terrain.wh));
    if (world == null) return null;
    final layers = <(ui.Vertices, ui.Image, TileMode)>[(world, img, TileMode.repeated)];
    // ảnh chi tiết khi đã phóng to (xin dựng khi camera đứng yên)
    if (pxPerDeg * 360 / Terrain.ww > 2.5 && cap < 60) {
      if (!_fast) {
        t.wantDetail(math.max(-85, cam.lat - cap), math.min(85, cam.lat + cap), cam.lon - lonHalf, cam.lon + lonHalf);
      }
      final d = t.detail, box = t.detailBox;
      if (d != null && box != null) {
        var (b0, b1, c0, c1) = box;
        // đưa khung về gần kinh độ camera (qua kinh tuyến 180°)
        while ((c0 + c1) / 2 - cam.lon > 180) {
          c0 -= 360;
          c1 -= 360;
        }
        while ((c0 + c1) / 2 - cam.lon < -180) {
          c0 += 360;
          c1 += 360;
        }
        final m0 = math.max(b0, la0), m1 = math.min(b1, la1), n0 = math.max(c0, lo0), n1 = math.min(c1, lo1);
        if (m1 > m0 && n1 > n0) {
          final dv = _mesh(pr, m0, m1, n0, n1, step,
              (lat, lon) => ((lon - c0) / (c1 - c0) * d.width, (b1 - lat) / (b1 - b0) * d.height));
          if (dv != null) layers.add((dv, d, TileMode.clamp));
        }
      }
    }
    return _Relief(layers);
  }

  /// Lưới tam giác trên khung kinh–vĩ độ, toạ độ ảnh do [uv] tính. Bỏ ô nằm hẳn sau quả cầu.
  ui.Vertices? _mesh(GlobeProjection pr, double la0, double la1, double lo0, double lo1, double step,
      (double, double) Function(double lat, double lon) uv) {
    final ny = math.max(1, ((la1 - la0) / step).round()), nx = math.max(1, ((lo1 - lo0) / step).round());
    final n = (nx + 1) * (ny + 1);
    if (n > 65000) return null;
    final needVerts = n * 2;
    if (_meshPos.length < needVerts) {
      _meshPos = Float32List(needVerts + 1024);
      _meshTex = Float32List(needVerts + 1024);
    }
    if (_meshVis.length < n) {
      _meshVis = Uint8List(n + 512);
    }
    final pos = Float32List.sublistView(_meshPos, 0, needVerts);
    final tex = Float32List.sublistView(_meshTex, 0, needVerts);
    final vis = Uint8List.sublistView(_meshVis, 0, n);
    var k = 0;
    for (var j = 0; j <= ny; j++) {
      final lat = la1 - (la1 - la0) * j / ny;
      for (var i = 0; i <= nx; i++) {
        final lon = lo0 + (lo1 - lo0) * i / nx;
        final (x, y, v) = pr.project(lon, lat);
        pos[k * 2] = x;
        pos[k * 2 + 1] = y;
        final (u, w) = uv(lat, lon);
        tex[k * 2] = u;
        tex[k * 2 + 1] = w;
        vis[k] = v ? 1 : 0;
        k++;
      }
    }
    // bộ đệm chỉ số dùng lại giữa các khung hình (không cấp phát danh sách mới mỗi lần kéo → web đỡ khựng do dọn rác)
    final need = nx * ny * 6;
    if (_idx.length < need) _idx = Uint16List(need + 1024);
    final idx = _idx;
    var m = 0;
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final a = j * (nx + 1) + i, b = a + 1, c = a + nx + 1, d = c + 1;
        if (vis[a] + vis[b] + vis[c] + vis[d] == 0) continue;
        idx[m] = a;
        idx[m + 1] = c;
        idx[m + 2] = b;
        idx[m + 3] = b;
        idx[m + 4] = c;
        idx[m + 5] = d;
        m += 6;
      }
    }
    if (m == 0) return null;
    return ui.Vertices.raw(ui.VertexMode.triangles, pos,
        textureCoordinates: tex, indices: Uint16List.sublistView(idx, 0, m));
  }

  static Uint16List _idx = Uint16List(8192);
  static Float32List _meshPos = Float32List(8192);
  static Float32List _meshTex = Float32List(8192);
  static Uint8List _meshVis = Uint8List(4096);
  static Float32List _pts = Float32List(4096);
  static Uint8List _vis = Uint8List(2048);
  static double _minStep = 1.1;

  /// Thêm một vòng biên giới vào đường tô (có điểm mép cầu) và đường viền (ngắt ở phần khuất).
  /// Dùng lại bộ đệm (không cấp phát mỗi khung hình) và bỏ các điểm cách điểm trước dưới [_minStep] điểm ảnh.
  bool _ring(GlobeProjection pr, Float32List ring, Path fp, Path sp, Rect view) {
    final n = ring.length ~/ 2;
    if (n < 2) return false;
    if (_vis.length < n) {
      _vis = Uint8List(n * 2);
      _pts = Float32List(n * 4);
    }
    final pts = _pts, vis = _vis;
    var anyVis = false;
    var m = 0; // số điểm giữ lại
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    double lx = 0, ly = 0;
    var lv = false;
    for (var i = 0; i < n; i++) {
      final (x, y, v) = pr.project(ring[i * 2], ring[i * 2 + 1]);
      if (m > 0 && i < n - 1 && v == lv && (x - lx).abs() + (y - ly).abs() < _minStep) continue;
      pts[m * 2] = x;
      pts[m * 2 + 1] = y;
      vis[m] = v ? 1 : 0;
      m++;
      lx = x;
      ly = y;
      lv = v;
      if (v) {
        anyVis = true;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (!anyVis) return false;
    if (maxX < view.left || minX > view.right || maxY < view.top || minY > view.bottom) return false;
    if (m < 3) return false;
    var penDown = false;
    for (var i = 0; i < m; i++) {
      final x = pts[i * 2], y = pts[i * 2 + 1];
      if (i == 0) {
        fp.moveTo(x, y);
      } else {
        fp.lineTo(x, y);
      }
      if (vis[i] == 1) {
        if (penDown) {
          sp.lineTo(x, y);
        } else {
          sp.moveTo(x, y);
          penDown = true;
        }
      } else {
        penDown = false;
      }
    }
    fp.close();
    if (vis[0] == 1 && vis[m - 1] == 1 && penDown) sp.lineTo(pts[0], pts[1]);
    return true;
  }

  void _graticule(Canvas canvas, GlobeProjection pr) {
    if (_fast && cam.zoom <= 8) return; // khi đang lướt xoay/phóng to: bỏ qua lưới kinh vĩ để khoá 60 FPS
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x2299C8E0);
    final step = cam.zoom > 8 ? 5 : (cam.zoom > 3 ? 10 : 30);
    for (var lon = -180; lon < 180; lon += step) {
      _line(canvas, pr, p, [for (var lat = -88.0; lat <= 88; lat += 2) (lon.toDouble(), lat)]);
    }
    for (var lat = -60; lat <= 60; lat += step) {
      _line(canvas, pr, p, [for (var lon = -180.0; lon <= 180; lon += 2) (lon, lat.toDouble())]);
    }
    // xích đạo rõ hơn
    _line(
        canvas,
        pr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0x4499C8E0),
        [for (var lon = -180.0; lon <= 180; lon += 2) (lon, 0.0)]);
  }

  void _line(Canvas canvas, GlobeProjection pr, Paint p, List<(double, double)> pts) {
    final path = Path();
    var down = false;
    for (final (lon, lat) in pts) {
      final (x, y, v) = pr.project(lon, lat);
      if (!v) {
        down = false;
        continue;
      }
      if (down) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        down = true;
      }
    }
    canvas.drawPath(path, p);
  }

  /// Hoàng Sa, Trường Sa: chấm vàng + tên "(Việt Nam)" — luôn vẽ khi thấy được.
  void _islands(Canvas canvas, GlobeProjection pr) {
    // đảo tô cùng màu Việt Nam, viền vàng
    final dot = Paint()..color = _vn;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gold;
    final rad = cam.zoom < 2 ? 1.5 : (cam.zoom < 8 ? 2.4 : 3.6);
    for (final group in [hoangSa, truongSa]) {
      for (final i in group) {
        final (x, y, v) = pr.project(i.lon, i.lat);
        if (v) {
          canvas.drawCircle(Offset(x, y), rad, dot);
          canvas.drawCircle(Offset(x, y), rad, ring);
        }
        if (v && cam.zoom >= 14) {
          final tp = _tp(en ? i.en : i.vi, 11, _text, w: FontWeight.w500);
          tp.paint(canvas, Offset(x + 5, y - tp.height / 2));
        }
      }
    }
    if (cam.zoom >= 2.2) {
      for (final (name, lon, lat) in [
        (en ? 'Hoang Sa Islands (Viet Nam)' : 'Quần đảo Hoàng Sa (Việt Nam)', 112.0, 17.25),
        (en ? 'Truong Sa Islands (Viet Nam)' : 'Quần đảo Trường Sa (Việt Nam)', 113.6, 11.9),
      ]) {
        final (x, y, v) = pr.project(lon, lat);
        if (!v) continue;
        final tp = _tp(name, cam.zoom < 4 ? 10 : 13, _gold, w: FontWeight.w700);
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height));
      }
    }
    if (cam.zoom >= 3) {
      final (x, y, v) = pr.project(113.0, 14.3);
      if (v) {
        final tp = _tp(en ? 'East Sea' : 'Biển Đông', cam.zoom < 6 ? 12 : 15, const Color(0xAA99C8E0), w: FontWeight.w500);
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  void _countryLabels(Canvas canvas, GlobeProjection pr, World w, Size size) {
    // nhìn xa: chỉ nước lớn; càng phóng to càng hiện nhiều tên
    final maxRank = cam.zoom < 1.4 ? 2 : (cam.zoom < 2.5 ? 3 : (cam.zoom < 5 ? 5 : 9));
    final placed = <Rect>[];
    for (final c in w.countries) {
      if (c.rank > maxRank && c.a3 != 'VNM') continue;
      if (c.a3 == 'VNM' && cam.zoom >= 3.2) continue;
      final (x, y, v) = pr.project(c.lx, c.ly);
      if (!v || x < 0 || y < 0 || x > size.width || y > size.height) continue;
      final big = c.a3 == 'VNM';
      final tp = _tp(en ? c.en : c.vi, big ? 14 : 11, big ? _gold : _text, w: big ? FontWeight.w700 : FontWeight.w500);
      final rect = Rect.fromLTWH(x - tp.width / 2, y - tp.height / 2, tp.width, tp.height);
      if (placed.any((r) => r.overlaps(rect.inflate(2)))) continue;
      placed.add(rect);
      tp.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(GlobePainter o) => o.camera != camera || o.world != world || o.en != en || o.terrain != terrain;
}

class _Relief {
  final List<(ui.Vertices, ui.Image, TileMode)> layers;
  const _Relief(this.layers);

  static final _id = Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  void draw(Canvas canvas, double opacity) {
    for (final (v, img, mode) in layers) {
      canvas.drawVertices(
          v,
          BlendMode.srcOver,
          Paint()
            ..shader = ImageShader(img, mode, TileMode.clamp, _id, filterQuality: FilterQuality.low)
            ..color = Color.fromRGBO(255, 255, 255, opacity));
    }
  }
}

/// Lớp HIỆU ỨNG nhẹ phía trên: ghim nhấp nháy, vòng "đang nghe", chấm thiên tai. Vẽ lại theo nhịp mà không đụng
/// tới lớp nền (hàng nghìn điểm biên giới).
class GlobeFxPainter extends CustomPainter {
  final ValueListenable<GlobeCamera> camera;
  final ValueListenable<double> pulseN;
  final GlobePin? pin;
  final bool listening;
  final List<(double, double, String)> events;
  GlobeFxPainter({required this.camera, required this.pulseN, this.pin, this.listening = false, this.events = const []})
      : super(repaint: Listenable.merge([camera, pulseN]));

  GlobeCamera get cam => camera.value;
  double get pulse => pulseN.value;
  static const _gold = Color(0xFFE4BB63);
  static TextPainter _tp(String s, double size, Color color, {FontWeight w = FontWeight.w600}) =>
      GlobePainter._tp(s, size, color, w: w);

  @override
  void paint(Canvas canvas, Size size) {
    final pr = GlobeProjection(cam, size);
    _events(canvas, pr);
    _pin(canvas, pr);
    if (listening) {
      // app đang nghe: quầng xanh ngọc "thở" quanh quả cầu (mềm, không chói) + một vòng mảnh rõ nét
      final breath = 0.5 - 0.5 * math.cos(2 * math.pi * pulse);
      canvas.drawCircle(
          pr.c,
          pr.r + 8 + 4 * breath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = Color.fromRGBO(67, 216, 160, 0.18 + 0.22 * breath)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(
          pr.c,
          pr.r + 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Color.fromRGBO(67, 216, 160, 0.55 + 0.35 * breath));
    }
  }

  /// Chấm thiên tai: đỏ = bão, cam = cháy rừng, xanh = lũ, tím = núi lửa.
  void _events(Canvas canvas, GlobeProjection pr) {
    for (final (lon, lat, cat) in events) {
      final (x, y, v) = pr.project(lon, lat);
      if (!v) continue;
      final col = switch (cat) {
        'severeStorms' => const Color(0xFFFF4D4D),
        'wildfires' => const Color(0xFFFF9A3C),
        'floods' => const Color(0xFF4DA6FF),
        'volcanoes' => const Color(0xFFC77DFF),
        _ => const Color(0xFFFFE066),
      };
      final r = cat == 'severeStorms' ? 5.0 + 2 * pulse : 3.0;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = col.withValues(alpha: 0.9));
    }
  }

  void _pin(Canvas canvas, GlobeProjection pr) {
    final p = pin;
    if (p == null) return;
    final (x, y, v) = pr.project(p.lon, p.lat);
    if (!v) return;
    final o = Offset(x, y);
    canvas.drawCircle(o, 10 + 14 * pulse, Paint()..color = _gold.withValues(alpha: 0.35 * (1 - pulse)));
    canvas.drawCircle(o, 6, Paint()..color = _gold);
    canvas.drawCircle(
        o,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black);
    if (p.label.isNotEmpty) {
      final tp = _tp(p.label, 16.5, const Color(0xFFFBF4E4), w: FontWeight.w700);
      final box = Rect.fromLTWH(x - tp.width / 2 - 14, y - 48, tp.width + 28, tp.height + 14);
      final rr = RRect.fromRectAndRadius(box, const Radius.circular(14));
      // bóng đổ mượt mà
      canvas.drawRRect(rr.shift(const Offset(0, 4)),
          Paint()..color = const Color(0x99000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // nền hộp ghim sơn mài cao cấp
      canvas.drawRRect(rr, Paint()..color = const Color(0xF20F161E));
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xCCE4BB63));
      // mũi nhọn chỉ xuống ghim
      canvas.drawPath(
          Path()
            ..moveTo(x - 7, box.bottom)
            ..lineTo(x, box.bottom + 9)
            ..lineTo(x + 7, box.bottom)
            ..close(),
          Paint()..color = const Color(0xF20F161E));
      tp.paint(canvas, Offset(box.left + 14, box.top + 7));
    }
  }

  @override
  bool shouldRepaint(GlobeFxPainter o) =>
      o.camera != camera || o.pulseN != pulseN || o.pin != pin || o.listening != listening || o.events.length != events.length;
}
