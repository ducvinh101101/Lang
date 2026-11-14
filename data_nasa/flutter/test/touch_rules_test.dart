// Chạy trong app (sau khi chép lib/touch/ và file này vào test/): flutter test test/touch_rules_test.dart
// Import tương đối để không phụ thuộc tên package của app.
// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/touch/profile_scan.dart';
import '../lib/touch/touch_rules.dart';

void main() {
  test('nốt sáo cao dần theo độ cao và nằm trong ngũ cung', () {
    final notes = [for (final m in <double>[0, 300, 800, 1500, 2000, 3000]) elevToMidi(m)];
    expect(notes.first, 60);
    expect(notes.last, elevToMidi(2000)); // từ 2 000 m trở lên giữ nốt cao nhất
    for (var i = 1; i < notes.length; i++) {
      expect(notes[i] >= notes[i - 1], isTrue);
    }
    expect(notes.every((n) => pentaSteps.contains(n % 12)), isTrue);
  });

  test('rung theo độ dốc: phẳng không rung, càng dốc càng mạnh và dài nhưng ngắn hơn rung biên giới', () {
    expect(slopePulse(null), isNull);
    expect(slopePulse(1.5), isNull);
    final gentle = slopePulse(3)!, steep = slopePulse(15)!, cliff = slopePulse(40)!;
    expect(gentle.level, 1);
    expect(steep.level, 2);
    expect(cliff.level, 3);
    expect(gentle.amplitude < steep.amplitude && steep.amplitude < cliff.amplitude, isTrue);
    expect(cliff.ms, 60);
    expect(cliff.amplitude, 255);
    expect(cliff.ms < 150, isTrue);
  });

  test('tiếng xe: thưa dân thì im, đông dân nhiều xe hơn, tối đa 6', () {
    expect(carsPerWindow(null), 0);
    expect(carsPerWindow(20), 0);
    expect(trafficVolume(20), 0);
    expect(carsPerWindow(100) < carsPerWindow(5000), isTrue);
    expect(carsPerWindow(1e6), 6);
    expect(trafficVolume(100) < trafficVolume(5000), isTrue);
  });

  test('âm nước: biển, sông hồ theo ngưỡng, hoặc không', () {
    expect(waterKind(sea: true), WaterKind.sea);
    expect(waterKind(sea: false, waterFraction: 0.7), WaterKind.inland);
    expect(waterKind(sea: false, waterFraction: 0.3), WaterKind.none);
    expect(waterKind(sea: false, waterFraction: 0.3, threshold: 0.25), WaterKind.inland);
    expect(waterKind(sea: false), WaterKind.none);
  });

  test('mỗi lượt quét không quá 8 giây và đi hết các lát', () {
    for (final n in [5, 152, 256, 306, 1024]) {
      final d = sweepDuration(n);
      expect(d <= const Duration(seconds: 8), isTrue, reason: '$n lát');
      expect(sliceAt(Duration.zero, d, n), 0);
      expect(sliceAt(d, d, n), n - 1);
      expect(sliceAt(d * 0.5, d, n), n ~/ 2);
    }
  });

  test('mặt cắt: trung bình chỉ tính đất liền, lát toàn biển là null, tìm được lát cao nhất', () {
    final data = ScanData(ScanAxis.northSouth, [
      [null, null, null], // toàn biển
      [100, null, 300], // ven biển: trung bình 200
      [1000, 2000, 3000],
    ], [
      22.5,
      21.5,
      20.5
    ]);
    expect(data.means, [null, 200, 2000]);
    expect(data.maxElev, 3000);
    expect(data.highestSlice, 2);
    expect(data.summary(), contains('20 phẩy 5 độ Bắc'));
    expect(data.summary(), contains('2000 mét'));
    expect(ScanData(ScanAxis.westEast, [
      [null]
    ], [
      105
    ]).summary(), 'Khu vực này không có đất liền.');
  });
}
