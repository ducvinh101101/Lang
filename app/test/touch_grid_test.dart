import 'dart:io';
import 'dart:typed_data';

import 'package:earthsense/features/terrain_scan/terrain_sense.dart';
import 'package:earthsense/features/terrain_scan/touch_grid.dart';
import 'package:flutter_test/flutter_test.dart';

// Lưới mẫu tạo bởi tests/make_touch_fixture.py (cùng bảng mã với data_nasa/build_f3.py): 4 × 3 ô, mỗi ô 1°,
// góc tây bắc (23° N, 104° E).
const dir = 'test/fixtures/touch/vn';

void main() {
  testWidgets('nạp grid.json + giải mã PNG, tra đúng giá trị từng lớp', (t) async {
    final g = await t.runAsync(() => TouchGrid.load(dir, (p) => File(p).readAsString(), (p) async => File(p).readAsBytesSync()));
    expect(g, isNotNull);
    expect(g!.cols, 4);
    expect(g.rows, 3);
    expect(g.layers.keys.toSet(), {'elev', 'slope', 'water', 'pop'});

    // ô (hàng 0, cột 0): 1000 m, dốc 25°, byte dân số 0 → 10^0 − 1 = 0 người/km²
    final a = g.sample(22.5, 104.5)!;
    expect(a.elev, 1000);
    expect(a.slope, 25);
    expect(a.pop, 0);
    // ô (0, 1): 2000 m, byte dân số 40 → 10^1 − 1 = 9 người/km²
    expect(g.sample(22.5, 105.5)!.elev, 2000);
    expect(g.sample(22.5, 105.5)!.pop, closeTo(9, 1e-9));
    expect(a.sea, isFalse);
    // ô (0, 2): biển
    final sea = g.sample(22.5, 106.5)!;
    expect(sea.sea, isTrue);
    expect(sea.slope, isNull);
    expect(sea.pop, isNull);
    // ô (1, 0): 100 m, dân số 10^4 − 1 = 9999 người/km² (đô thị)
    expect(g.sample(21.5, 104.5)!.pop, closeTo(9999, 1e-6));
    // ô (1, 1): mặt nước 0,8 ≥ ngưỡng 0,5
    expect(g.sample(21.5, 105.5)!.water, closeTo(0.8, 1e-9));
    expect(g.waterThreshold, 0.5);
    // ngoài khung
    expect(g.sample(30, 104.5), isNull);
    expect(g.sample(22.5, 103.9), isNull);
  });

  test('thiếu dữ liệu → null (app dùng ước lượng, không lỗi)', () async {
    final g = await TouchGrid.load('test/fixtures/khong_co', (p) => File(p).readAsString(), (p) async => File(p).readAsBytesSync());
    expect(g, isNull);
  });

  test('lớp có kích thước sai bị bỏ', () {
    final meta = {
      'grid': {'lon0': 0, 'lat_top': 1, 'step': 1, 'cols': 2, 'rows': 1},
      'layers': [
        {'name': 'elev', 'file': 'elev.png', 'scale': 12.5, 'offset': 0},
        {'name': 'pop', 'file': 'pop.png', 'scale': 0.025, 'offset': 0, 'log': true},
      ],
    };
    final g = TouchGrid.fromMeta(meta, {'elev': Uint8List.fromList([8, 255]), 'pop': Uint8List.fromList([1, 2, 3])});
    expect(g.layers.keys, ['elev']);
    expect(g.sample(0.5, 0.5)!.elev, 100);
    expect(g.sample(0.5, 1.5)!.sea, isTrue);
  });

  group('luật âm thanh từ số liệu thật', () {
    test('mật độ dân số → âm lượng và số xe', () {
      expect(trafficVolume(null), 0);
      expect(trafficVolume(30), 0);
      expect(trafficVolume(50), closeTo(0.25, 0.01));
      expect(trafficVolume(10000), closeTo(0.8, 0.01));
      expect(carsPerWindow(40), 0);
      expect(carsPerWindow(100000), 6);
      expect(trafficVolume(2000), greaterThan(trafficVolume(200)));
    });
    test('có số liệu thật thì dùng số liệu thật', () {
      final c = fingerCue(hasReal: true, realSlope: 18, realWater: 0.8, realPop: 5000, urbanEstimate: 0, slopeEstimate: 1);
      expect(c.realData, isTrue);
      expect(c.slopeDeg, 18);
      expect(c.inlandWater, isTrue);
      expect(c.urban, isTrue);
      expect(c.trafficAmp, greaterThan(0.15));
      final rural = fingerCue(hasReal: true, realSlope: 0, realWater: 0.1, realPop: 20, urbanEstimate: 1, slopeEstimate: 30);
      expect(rural.trafficAmp, 0);
      expect(rural.urban, isFalse);
      expect(rural.inlandWater, isFalse);
      expect(rural.slopeDeg, 0); // không lấy ước lượng khi đã có số liệu thật
    });
    test('không có số liệu thật thì ước lượng', () {
      final c = fingerCue(hasReal: false, urbanEstimate: 0.9, slopeEstimate: 7);
      expect(c.realData, isFalse);
      expect(c.urban, isTrue);
      expect(c.slopeDeg, 7);
      expect(c.trafficAmp, closeTo(0.08 + 0.14 * 0.9, 1e-9));
      expect(fingerCue(hasReal: false, urbanEstimate: 0.1, slopeEstimate: double.nan).trafficAmp, 0);
    });
  });
}
