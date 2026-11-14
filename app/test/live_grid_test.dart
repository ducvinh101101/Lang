import 'package:earthsense/core/geo.dart';
import 'package:earthsense/features/describe.dart';
import 'package:earthsense/live/live_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('điểm lấy mẫu phủ cả nước (~0,5°) và có các thành phố lớn', () {
    final geo = builtinGeo().grid;
    final pts = LiveGridService.samplePoints(geo);
    expect(pts.length, greaterThan(60));
    expect(pts.length, lessThan(400)); // một lần gọi Open-Meteo, URL không quá dài
    bool near(double lat, double lon) => pts.any((p) => (p.$1 - lat).abs() < 0.3 && (p.$2 - lon).abs() < 0.3);
    expect(near(21.03, 105.85), isTrue); // Hà Nội
    expect(near(16.46, 107.59), isTrue); // Huế (miền Trung hẹp)
    expect(near(10.78, 106.66), isTrue); // TP. Hồ Chí Minh
  });

  test('lời mưa theo NGÀY khác theo tháng', () {
    expect(kidWord('rain', 30, 0.5, daily: true).vi, 'mưa to');
    expect(kidWord('rain', 30, 0.5).vi, 'mưa ít'); // 30 mm cả tháng là ít
    expect(kidWord('rain', 0, 0, daily: true).vi, 'không mưa');
    expect(liveVars['rain']!.daily, isTrue);
  });
}
