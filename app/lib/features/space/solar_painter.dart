// HỆ MẶT TRỜI (màn "khám phá vũ trụ"): Mặt Trời phát sáng ở giữa, tám hành tinh chạy trên quỹ đạo nghiêng
// (nhìn chếch như sa bàn), Mặt Trăng quay quanh Trái Đất. Hành tinh đang được nói tới / được chọn có vòng vàng
// và tên to hơn. Kích thước và khoảng cách đã "nén" để nhìn được cả hệ trên một màn hình (không theo tỉ lệ thật).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'planets.dart';

class SolarPainter extends CustomPainter {
  final ValueListenable<double> time; // giây
  final int? highlight; // chỉ số thiên thể (0 Mặt Trời … 9 Sao Hải Vương)
  final bool en;
  SolarPainter(this.time, {this.highlight, this.en = false}) : super(repaint: time);

  // (chỉ số, bán kính quỹ đạo 0..1, cỡ hiển thị, chu kỳ giây, pha ban đầu)
  static const _orbits = [
    (1, 0.20, 3.0, 9.0, 0.3),
    (2, 0.28, 4.4, 14.0, 2.1),
    (3, 0.36, 4.8, 20.0, 4.0),
    (5, 0.45, 3.8, 30.0, 1.2),
    (6, 0.59, 10.0, 60.0, 5.1),
    (7, 0.72, 8.6, 90.0, 2.8),
    (8, 0.84, 6.4, 130.0, 0.9),
    (9, 0.96, 6.2, 170.0, 3.7),
  ];

  static final _stars = () {
    final r = math.Random(5);
    return [for (var k = 0; k < 200; k++) (r.nextDouble(), r.nextDouble(), 0.3 + r.nextDouble() * 1.1, r.nextDouble())];
  }();

  static final _labels = <String, TextPainter>{};
  static TextPainter _tp(String s, double size, Color c, FontWeight w) => _labels.putIfAbsent('$s|$size|${c.toARGB32()}|${w.value}', () {
        if (_labels.length > 120) _labels.clear();
        return TextPainter(
          text: TextSpan(
              text: s,
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: size,
                  fontWeight: w,
                  color: c,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)])),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  Planet _p(int i) => planets.firstWhere((p) => p.sound == i);
  String _name(Planet p) => en ? p.en.replaceFirst('the ', '') : p.vi;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF02040A));
    final star = Paint();
    for (final (x, y, s, ph) in _stars) {
      star.color = Colors.white.withValues(alpha: 0.25 + 0.3 * (0.5 + 0.5 * math.sin(t * 1.1 + ph * 6.28)));
      canvas.drawCircle(Offset(x * size.width, y * size.height), s, star);
    }
    // Mặt Trời ở giữa, quỹ đạo là các elip nghiêng (nhìn chếch như sa bàn)
    final sun = Offset(size.width * 0.5, size.height * 0.5);
    final rx = size.width * 0.46, ry = math.min(size.height * 0.40, rx * 0.42);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33C9D6E8);
    for (final (_, a, _, _, _) in _orbits) {
      canvas.drawOval(Rect.fromCenter(center: sun, width: 2 * rx * a, height: 2 * ry * a), orbit);
    }
    // Mặt Trời: quầng sáng "thở"
    final sunR = math.min(size.width, size.height) * 0.055;
    final glow = sunR * (2.6 + 0.12 * math.sin(t * 1.6));
    canvas.drawCircle(
        sun,
        glow,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xAAFFB347), Color(0x33FF7A1A), Color(0x00FF7A1A)], stops: [0.0, 0.45, 1.0])
              .createShader(Rect.fromCircle(center: sun, radius: glow)));
    canvas.drawCircle(
        sun,
        sunR,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFFFFF1B0), Color(0xFFFFB13B), Color(0xFFFF7A1A)])
              .createShader(Rect.fromCircle(center: sun, radius: sunR)));
    _label(canvas, _name(_p(0)), sun - Offset(0, sunR + 26), highlight == 0); // tên Mặt Trời ở trên, không đè hành tinh trong
    if (highlight == 0) _ring(canvas, sun, sunR + 6, t);

    final scale = math.min(size.width, size.height) / 420;
    // vẽ theo thứ tự trên → dưới để hành tinh gần người xem đè lên hành tinh xa
    final placed = <(int, Offset, double)>[];
    for (final (i, a, s, period, ph) in _orbits) {
      final ang = ph + 2 * math.pi * t / period;
      final o = sun + Offset(rx * a * math.cos(ang), ry * a * math.sin(ang));
      placed.add((i, o, s * scale * 1.6));
    }
    placed.sort((x, y) => x.$2.dy.compareTo(y.$2.dy));
    for (final (i, o, r) in placed) {
      final p = _p(i);
      final rect = Rect.fromCircle(center: o, radius: r);
      // chỉ Sao Thổ có vành rõ; Sao Thiên Vương vành rất mờ (thật ra rất mảnh), Sao Hải Vương không vẽ vành
      if (p.rings && (i == 7 || i == 8)) {
        canvas.drawOval(
            Rect.fromCenter(center: o, width: r * 4.2, height: r * 1.3),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = i == 7 ? math.max(1.5, r * 0.35) : 1
              ..color = i == 7 ? const Color(0x99E8D6A8) : const Color(0x449FD8E0));
      }
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(center: const Alignment(-0.6, -0.2), radius: 1.1, colors: [p.color, p.color2])
                .createShader(rect));
      // nửa quay lưng với Mặt Trời tối đi
      final away = (o - sun).direction;
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(-math.cos(away), -math.sin(away)),
              end: Alignment(math.cos(away), math.sin(away)),
              colors: const [Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(rect));
      if (i == 3) {
        // Mặt Trăng quay quanh Trái Đất
        final m = o + Offset.fromDirection(t * 1.8, r * 2.4);
        canvas.drawCircle(m, math.max(1.5, r * 0.32), Paint()..color = const Color(0xFFC9C6C0));
        if (highlight == 4) _ring(canvas, m, r * 0.32 + 5, t);
      }
      final hi = highlight == i;
      if (hi) _ring(canvas, o, r + 6, t);
      _label(canvas, _name(p), o + Offset(0, r + 10), hi);
    }
  }

  void _ring(Canvas canvas, Offset c, double r, double t) {
    canvas.drawCircle(
        c,
        r + 3 * (0.5 + 0.5 * math.sin(t * 4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE4BB63));
  }

  void _label(Canvas canvas, String s, Offset at, bool hi) {
    final tp = _tp(s, hi ? 17 : 12, hi ? const Color(0xFFE4BB63) : const Color(0xCCF1E5CC), hi ? FontWeight.w700 : FontWeight.w500);
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(SolarPainter o) => o.time != time || o.highlight != highlight || o.en != en;
}
