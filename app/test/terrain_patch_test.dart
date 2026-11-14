// Bản đồ địa hình thật cho rê tay: giải mã độ cao Terrarium, lớp phủ MODIS IGBP, nội suy mượt, ảnh có bóng đổ.
import 'dart:typed_data';

import 'package:earthsense/live/terrain_patch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('độ cao Terrarium: R·256 + G + B/256 − 32768', () {
    expect(terrariumElev(128, 0, 0), 0);
    expect(terrariumElev(128, 10, 128), 10.5);
    expect(terrariumElev(137, 24, 0), 2328); // ≈ đỉnh Langbiang
    expect(terrariumElev(127, 236, 0), -20); // đáy biển nông
  });

  test('màu GIBS → lớp phủ IGBP, kể cả lệch màu do nén ảnh', () {
    expect(igbpFromRgb(49, 204, 49, 255), 2); // rừng lá rộng thường xanh
    expect(igbpFromRgb(250, 239, 115, 255), 12); // đồng ruộng
    expect(igbpFromRgb(255, 0, 0, 255), 13); // đô thị
    expect(igbpFromRgb(134, 202, 227, 255), 17); // mặt nước
    expect(igbpFromRgb(253, 236, 118, 255), 12); // lệch vài đơn vị vẫn là ruộng
    expect(igbpFromRgb(0, 0, 0, 0), 255); // trong suốt = không rõ
    expect(igbpFromRgb(0, 0, 0, 255), 255); // màu lạ = không đoán
    expect(igbpKinds[2]!.$1, 'forest');
    expect(igbpKinds[17]!.$1, 'water');
    expect(igbpKinds[13]!.$1, 'residential');
    expect(igbpKinds[12]!.$1, 'farmland');
  });

  // núi hình nón giữa khung, bờ tây là mặt nước
  TerrainPatch cone() {
    const n = 33, r = 1200.0;
    final e = Float32List(n * n), c = Uint8List(n * n);
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        final x = -r + col * 2 * r / (n - 1), y = r - row * 2 * r / (n - 1);
        final d = (x * x + y * y);
        e[row * n + col] = 1500 - d / 4000;
        c[row * n + col] = col < 4 ? 17 : 2;
      }
    }
    return finishPatch(11.95, 108.44, r, n, e, c, 'thử');
  }

  test('đọc độ cao đúng chỗ ngón tay, mượt giữa các điểm lưới', () {
    final p = cone();
    expect(p.elevAt(0, 0), closeTo(1500, 10)); // làm mượt nhẹ đỉnh
    final a = p.elevAt(30, 0)!, b = p.elevAt(60, 0)!, c = p.elevAt(45, 0)!;
    expect(c, lessThan(a));
    expect(c, greaterThan(b)); // giữa hai điểm thì ở giữa (không nhảy bậc như ô vuông)
    expect(p.elevAt(1100, 0)!, lessThan(1300));
    expect(p.elevAt(5000, 0), isNotNull); // ngoài khung: lấy mép
    final (lo, hi) = p.minMax;
    expect(lo, lessThan(hi));
  });

  test('lớp phủ đúng chỗ: bờ tây là nước, giữa là rừng', () {
    final p = cone();
    expect(igbpKinds[p.coverAt(-1190, 0)]!.$1, 'water');
    expect(igbpKinds[p.coverAt(0, 0)]!.$1, 'forest');
  });

  test('ảnh địa hình: đủ điểm ảnh, nước xanh lam, sườn đón nắng sáng hơn sườn khuất', () {
    final p = cone();
    final img = renderTerrainRgba(p);
    expect(img.length, p.n * p.n * 4);
    int px(int row, int col, int ch) => img[(row * p.n + col) * 4 + ch];
    expect(px(16, 1, 2), greaterThan(px(16, 1, 0))); // nước: xanh lam > đỏ
    // nắng tây bắc: sườn tây bắc sáng hơn sườn đông nam
    final nw = px(10, 10, 0) + px(10, 10, 1) + px(10, 10, 2);
    final se = px(22, 22, 0) + px(22, 22, 1) + px(22, 22, 2);
    expect(nw, greaterThan(se));
  });

  test('vùng phẳng (nội thành): nhiễu vài mét KHÔNG bị phóng to thành đồi núi', () {
    const n = 64, r = 1200.0;
    final e = Float32List(n * n), c = Uint8List(n * n)..fillRange(0, n * n, 13);
    for (var i = 0; i < n * n; i++) {
      e[i] = 12 + ((i * 7919) % 13) - 6; // 6–18 m, nhiễu nóc nhà / cây
    }
    e[5] = 60; // một toà nhà cao
    final p = finishPatch(21.03, 105.85, r, n, e, c, 'thử');
    final (lo, hi) = p.relief();
    expect(hi - lo, greaterThanOrEqualTo(60)); // giãn tối thiểu 60 m → màu, tiếng sáo gần như đều
    expect(p.reliefSpan, lessThan(15));
    // làm mượt: chênh lệch giữa hai ô cạnh nhau nhỏ hơn nhiều so với dữ liệu thô
    var maxStep = 0.0;
    for (var i = 1; i < n; i++) {
      maxStep = maxStep > (p.elev[32 * n + i] - p.elev[32 * n + i - 1]).abs() ? maxStep : (p.elev[32 * n + i] - p.elev[32 * n + i - 1]).abs();
    }
    expect(maxStep, lessThan(4));
  });

  test('ô MODIS 500 m: ranh giới nước mềm, không đọc "mặt nước" khi còn cách xa', () {
    const n = 128, r = 1200.0; // ô ≈ 19 m
    final e = Float32List(n * n)..fillRange(0, n * n, 10);
    final c = Uint8List(n * n);
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        c[row * n + col] = col >= 100 ? 17 : 13; // khối nước vuông ở mép đông
      }
    }
    final p = finishPatch(21.03, 105.85, r, n, e, c, 'thử');
    final x = (int col) => -r + col * 2 * r / (n - 1);
    expect(p.fracAt('water', x(127), 0), greaterThan(0.9));
    final edge = p.fracAt('water', x(100), 0);
    expect(edge, greaterThan(0.2)); // ngay ranh giới: chuyển dần
    expect(edge, lessThan(0.8));
    expect(p.fracAt('water', x(80), 0), lessThan(0.05));
    expect(igbpKinds[p.coverAt(x(80), 0)]!.$1, 'residential');
    expect(igbpKinds[p.coverAt(x(120), 0)]!.$1, 'water');
  });

  test('dự phòng từ lưới thô: vẫn mượt, không có lớp phủ', () {
    final g = Float32List.fromList([0, 10, 20, 30]);
    final p = patchFromGrid(21, 105.8, 1000, g, 2, n: 11)!;
    expect(p.elevAt(0, 0), closeTo(15, 0.01));
    expect(p.coverAt(0, 0), isNull);
    expect(patchFromGrid(21, 105.8, 1000, null, 0), isNull);
  });
}
