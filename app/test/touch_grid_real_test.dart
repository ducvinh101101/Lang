import 'dart:io';

import 'package:earthsense/features/terrain_scan/terrain_sense.dart';
import 'package:earthsense/features/terrain_scan/touch_grid.dart';
import 'package:flutter_test/flutter_test.dart';

// Dữ liệu THẬT trong app (assets/touch/vn, do data_nasa/build_f3.py xuất: NASA SRTMGL30 + SEDAC GPWv4).
// Chưa nhập thì bỏ qua.
const dir = 'assets/touch/vn';
final hasData = File('$dir/grid.json').existsSync();

void main() {
  testWidgets('lưới thật: độ cao, độ dốc, dân số, biển đúng thực tế', (t) async {
    final g = await t.runAsync(() => TouchGrid.load(dir, (p) => File(p).readAsString(), (p) async => File(p).readAsBytesSync()));
    expect(g, isNotNull);
    expect(g!.layers.keys.toSet(), containsAll(['elev', 'slope', 'water', 'pop']));

    final hoGuom = g.sample(21.0285, 105.8522)!;
    expect(hoGuom.sea, isFalse);
    expect(hoGuom.elev!, lessThan(50));
    expect(hoGuom.pop!, greaterThan(10000)); // nội đô Hà Nội
    expect(fingerCue(hasReal: true, realPop: hoGuom.pop, realSlope: hoGuom.slope, urbanEstimate: 0, slopeEstimate: 0).urban, isTrue);

    final sapa = g.sample(22.336, 103.844)!;
    expect(sapa.elev!, greaterThan(1000));
    expect(sapa.slope!, greaterThan(6)); // vùng núi: máy rung rõ
    expect(slopeLevel(sapa.slope!), greaterThanOrEqualTo(2));

    final daLat = g.sample(11.94, 108.44)!;
    expect(daLat.elev!, inInclusiveRange(1000, 1800));

    // ngoài khơi Biển Đông và vịnh Bắc Bộ là biển
    expect(g.sample(12.0, 109.5)!.sea, isTrue);
    expect(g.sample(12.0, 109.8), isNull); // ngoài khung lưới (102–109,6°E) → app dùng ước lượng
    expect(g.sample(19.5, 107.8)!.sea, isTrue);

    // đồng bằng thấp vẫn là đất (không bị nhận nhầm thành biển)
    expect(g.sample(10.03, 105.78)!.sea, isFalse); // Cần Thơ
  }, skip: !hasData);
}
