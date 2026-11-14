// Vuốt hai ngón: xuống = quay lại, trái / phải = đổi phần. Không nhầm với chụm, xoay, vuốt chậm hay ba ngón.
import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/core/two_finger_swipe.dart';

Swipe2? run(List<(double, double)> a, List<(double, double)> b, {int ms = 300}) {
  final g = TwoFingerSwipe();
  g.down(1, a.first.$1, a.first.$2, 0);
  g.down(2, b.first.$1, b.first.$2, 10);
  for (var i = 1; i < a.length; i++) {
    g.move(1, a[i].$1, a[i].$2, 10 + i * 20);
    g.move(2, b[i].$1, b[i].$2, 10 + i * 20);
  }
  final r = g.up(1, 10 + ms);
  g.up(2, 20 + ms);
  return r;
}

void main() {
  test('hai ngón vuốt xuống = quay lại', () {
    expect(run([(100, 100), (102, 200), (104, 260)], [(180, 100), (182, 200), (185, 262)]), Swipe2.down);
  });
  test('hai ngón vuốt trái / phải', () {
    expect(run([(300, 200), (200, 202), (150, 204)], [(300, 280), (200, 282), (150, 285)]), Swipe2.left);
    expect(run([(100, 200), (200, 202), (260, 204)], [(100, 280), (200, 282), (262, 285)]), Swipe2.right);
  });
  test('chụm hai ngón (phóng to / thu nhỏ) không phải vuốt', () {
    expect(run([(100, 200), (40, 200)], [(200, 200), (330, 200)]), isNull);
  });
  test('hai ngón đi ngược chiều (xoay) không phải vuốt', () {
    expect(run([(100, 100), (100, 230)], [(200, 230), (200, 100)]), isNull);
  });
  test('vuốt chậm (kéo quả cầu) không tính', () {
    expect(run([(100, 100), (104, 260)], [(180, 100), (185, 262)], ms: 1500), isNull);
  });
  test('vuốt quá ngắn không tính', () {
    expect(run([(100, 100), (100, 150)], [(180, 100), (180, 150)]), isNull);
  });
  test('ba ngón không tính', () {
    final g = TwoFingerSwipe();
    g.down(1, 100, 100, 0);
    g.down(2, 180, 100, 5);
    g.down(3, 260, 100, 8);
    g.move(1, 100, 260, 100);
    g.move(2, 180, 260, 100);
    expect(g.up(1, 200), isNull);
  });
}
