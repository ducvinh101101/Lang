// Vẽ một thiên thể khi đang nghe "tập truyện vũ trụ": quả cầu tô màu, có dải mây (Sao Mộc, Sao Thổ), vành đai (Sao Thổ…),
// quầng sáng (Mặt Trời), nền sao. Thuần CustomPainter — chạy giống nhau trên app và web.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'planets.dart';

class PlanetPainter extends CustomPainter {
  final Planet planet;
  final ValueListenable<double> time; // giây, cho chuyển động chậm (quay, lấp lánh)
  final bool en;
  PlanetPainter(this.planet, this.time, {this.en = false}) : super(repaint: time);
  double get t => time.value;

  static final _stars = () {
    final r = math.Random(3);
    return [for (var k = 0; k < 160; k++) (r.nextDouble(), r.nextDouble(), 0.3 + r.nextDouble() * 1.2, r.nextDouble())];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF020409));
    for (final (x, y, s, ph) in _stars) {
      final a = 0.35 + 0.35 * math.sin(t * 1.3 + ph * 6.28);
      canvas.drawCircle(Offset(x * size.width, y * size.height), s, Paint()..color = Colors.white.withValues(alpha: a));
    }
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * (planet.rings ? 0.24 : 0.32);
    final p = planet;
    if (p.sound == 0) {
      // Mặt Trời: quầng sáng nhấp nháy
      final glow = r * (1.5 + 0.05 * math.sin(t * 2));
      canvas.drawCircle(
          c,
          glow,
          Paint()
            ..shader = RadialGradient(colors: [p.color.withValues(alpha: 0.6), p.color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: glow)));
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    // vành đai phía sau
    if (p.rings) _rings(canvas, c, r, back: true);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-0.3, -0.3), radius: 1.0, colors: [p.color, p.color2])
              .createShader(rect));
    if (p.bands) {
      // dải mây trôi theo kinh tuyến (quay)
      for (var k = -6; k <= 6; k++) {
        final y = c.dy + k * r / 6.5;
        final h = r / 14 * (1 + (k % 3) * 0.4);
        final col = (k.isEven ? Colors.white : Colors.brown).withValues(alpha: 0.18);
        canvas.drawRect(Rect.fromLTWH(c.dx - r, y - h / 2, 2 * r, h), Paint()..color = col);
      }
      if (p.sound == 6) {
        // Vết Đỏ Lớn, trôi theo vòng quay
        final x = c.dx + r * 0.9 * math.sin(t * 0.25);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, c.dy + r * 0.32), width: r * 0.32, height: r * 0.18),
            Paint()..color = const Color(0xCCB0442A));
      }
    }
    if (p.sound == 4 || p.sound == 1) {
      // hố va chạm
      final rr = math.Random(p.sound);
      for (var k = 0; k < 14; k++) {
        final a = rr.nextDouble() * 6.28, d = rr.nextDouble() * 0.85 * r;
        canvas.drawCircle(Offset(c.dx + d * math.cos(a), c.dy + d * math.sin(a)), r * (0.04 + rr.nextDouble() * 0.08),
            Paint()..color = Colors.black.withValues(alpha: 0.16));
      }
    }
    if (p.sound == 3) {
      // Trái Đất: vài mảng lục địa và mây
      final rr = math.Random(5);
      for (var k = 0; k < 7; k++) {
        final x = c.dx + (rr.nextDouble() * 2 - 1) * r * 0.7 + r * 0.3 * math.sin(t * 0.2);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, c.dy + (rr.nextDouble() * 2 - 1) * r * 0.7), width: r * 0.5, height: r * 0.3),
            Paint()..color = const Color(0xFF3A7A3A).withValues(alpha: 0.85));
      }
    }
    // bóng tối phía sau (khối cầu)
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.45),
            radius: 1.3,
            colors: [const Color(0x00000000), const Color(0x00000000), const Color(0xAA000000)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect));
    canvas.restore();
    if (p.rings) _rings(canvas, c, r, back: false);
    final name = en ? p.en.replaceFirst('the ', '') : p.vi;
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFF1E5CC))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + r * (p.rings ? 1.9 : 1.15)));
  }

  void _rings(Canvas canvas, Offset c, double r, {required bool back}) {
    final p = planet;
    final saturn = p.sound == 7;
    final tilt = p.sound == 8 ? 1.45 : 0.35; // Thiên Vương: vành gần thẳng đứng
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    // chỉ vẽ nửa sau (trên) hoặc nửa trước (dưới) để vành "ôm" quả cầu
    canvas.clipRect(back ? Rect.fromLTRB(-4 * r, -4 * r, 4 * r, 0) : Rect.fromLTRB(-4 * r, 0, 4 * r, 4 * r));
    for (var k = 0; k < (saturn ? 5 : 2); k++) {
      final w = r * (saturn ? 1.45 + k * 0.17 : 1.5 + k * 0.1);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 2 * w, height: 2 * w * 0.28),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = saturn ? r * 0.09 : 1.5
            ..color = (saturn ? const Color(0xFFE8D8A8) : Colors.white).withValues(alpha: saturn ? 0.55 - k * 0.06 : 0.35));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlanetPainter o) => o.planet != planet || o.time != time || o.en != en;
}
