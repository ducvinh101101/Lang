// Cử chỉ vẽ chữ Z (< 1 giây) để về màn hình chính.
import 'package:earthsense/core/z_gesture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nét vẽ qua các đỉnh [pts], [ms] mili giây, mỗi đoạn [k] điểm.
bool draw(List<(double, double)> pts, int ms, {int k = 12, double jitter = 0}) {
  final z = ZGesture();
  final all = <(double, double)>[];
  for (var i = 0; i < pts.length - 1; i++) {
    for (var j = 0; j < k; j++) {
      final t = j / k;
      final wob = jitter * ((i * k + j) % 3 - 1);
      all.add((pts[i].$1 + (pts[i + 1].$1 - pts[i].$1) * t + wob, pts[i].$2 + (pts[i + 1].$2 - pts[i].$2) * t + wob));
    }
  }
  all.add(pts.last);
  for (var i = 0; i < all.length; i++) {
    final t = (ms * i / (all.length - 1)).round();
    if (i == 0) {
      z.down(1, all[i].$1, all[i].$2, t);
    } else {
      z.move(1, all[i].$1, all[i].$2, t);
    }
  }
  return z.up(1, ms);
}

void main() {
  const zPts = [(100.0, 100.0), (300.0, 100.0), (100.0, 300.0), (300.0, 300.0)];
  test('chữ Z chuẩn, nhanh → nhận', () => expect(draw(zPts, 700), isTrue));
  test('chữ Z hơi nghiêng, rung tay → vẫn nhận', () {
    expect(draw(const [(90.0, 110.0), (290.0, 95.0), (110.0, 290.0), (310.0, 305.0)], 800, jitter: 3), isTrue);
  });
  test('chữ Z nhỏ vừa (≈ 1/3 màn hình điện thoại) → nhận', () {
    expect(draw(const [(50.0, 50.0), (170.0, 50.0), (50.0, 140.0), (170.0, 140.0)], 500), isTrue);
  });
  test('vẽ chậm hơn 1 giây → không nhận', () => expect(draw(zPts, 1400), isFalse));
  test('rê ngang, rê dọc, rê chéo (khám phá bản đồ) → không nhận', () {
    expect(draw(const [(100.0, 200.0), (350.0, 200.0)], 400), isFalse);
    expect(draw(const [(200.0, 100.0), (200.0, 400.0)], 400), isFalse);
    expect(draw(const [(300.0, 100.0), (100.0, 300.0)], 400), isFalse);
  });
  test('chữ N, chữ S ngược, đi qua lại → không nhận', () {
    expect(draw(const [(100.0, 300.0), (100.0, 100.0), (300.0, 300.0), (300.0, 100.0)], 700), isFalse); // N
    expect(draw(const [(100.0, 100.0), (300.0, 100.0), (100.0, 100.0), (300.0, 100.0)], 700), isFalse); // ngang qua lại
    expect(draw(const [(300.0, 100.0), (100.0, 100.0), (300.0, 300.0), (100.0, 300.0)], 700), isFalse); // Z ngược
  });
  test('chữ Z quá nhỏ (chạm, nhích tay) → không nhận', () {
    expect(draw(const [(100.0, 100.0), (130.0, 100.0), (100.0, 130.0), (130.0, 130.0)], 300), isFalse);
  });
  test('hai ngón (chụm, xoay) → không nhận', () {
    final z = ZGesture();
    z.down(1, 100, 100, 0);
    z.down(2, 200, 200, 10);
    z.move(1, 300, 100, 200);
    z.move(1, 100, 300, 400);
    z.move(1, 300, 300, 600);
    expect(z.up(1, 650), isFalse);
  });
}
