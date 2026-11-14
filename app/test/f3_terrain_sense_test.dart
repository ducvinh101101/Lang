import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/terrain_scan/terrain_sense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F3 độ dốc → rung', () {
    test('mặt phẳng: 0 độ, không rung', () {
      expect(slopeDegrees(100, 100, 100, 100, 0.1), closeTo(0, 1e-9));
      expect(slopeLevel(0), 0);
    });
    test('dốc 45 độ', () {
      // lên 100 m trên mỗi 100 m ngang theo hướng đông
      expect(slopeDegrees(0, 0, 100, -100, 0.1), closeTo(45, 1e-6));
      expect(slopeLevel(45), 4);
    });
    test('mức rung tăng dần theo độ dốc', () {
      expect(slopeLevel(3), 1);
      expect(slopeLevel(8), 2);
      expect(slopeLevel(15), 3);
      expect(slopeLevel(30), 4);
      expect(slopeDegrees(double.nan, 0, 0, 0, 1).isNaN, isTrue);
    });
  });

  test('F3 sáo: đất càng cao, sáo càng cao', () {
    expect(fluteFreq(3000), greaterThan(fluteFreq(500)));
    expect(fluteFreq(500), greaterThan(fluteFreq(0)));
    expect(fluteFreq(-2000), fluteFreq(0));
  });

  group('F3 khu dân cư', () {
    final u = UrbanIndex()
      ..add(21.0386, 105.838, 2.2) // phường Ba Đình
      ..add(10.776, 106.70, 9);
    test('trong lõi = 1, xa = 0, giữa giảm dần', () {
      expect(u.at(21.0386, 105.838), 1);
      expect(u.at(21.0386 + 0.03, 105.838), greaterThan(0)); // ~3,3 km
      expect(u.at(21.0386 + 0.03, 105.838), lessThan(1));
      expect(u.at(22.5, 104.0), 0);
      expect(u.at(10.80, 106.72), 1);
    });
  });

  group('F3 quét mặt cắt', () {
    test('mỗi lượt quét không quá 8 giây', () {
      for (final n in [5, 20, 26, 40, 100]) {
        expect(scanStepMs(n) * n, lessThanOrEqualTo(scanMaxMs));
      }
    });
    test('lát cắt hàng / cột và trung bình', () {
      final g = ElevGrid([
        [0, 10, 20],
        [100, 200, 300],
        [-50, -50, -50],
      ], 22, 21, 105, 106);
      expect(g.row(1), [100, 200, 300]);
      expect(g.col(0), [0, 100, -50]);
      expect(sliceMean(g.row(1)), 200);
      final ex = scanExtremes([for (var r = 0; r < g.rows; r++) sliceMean(g.row(r))]);
      expect(ex.hi, 1);
      expect(ex.lo, 2);
    });
    test('khẩu lệnh', () {
      final a = parseWorld('quét mặt cắt địa hình Đà Lạt');
      expect(a.kind, WKind.terrain);
      expect(a.aspect, 'scan');
      expect(a.target, 'Đà Lạt');
      expect(parseWorld('tôi muốn nghe âm thanh địa hình').aspect, 'scan');
      expect(parseWorld('nghe âm thanh địa hình Sa Pa').target, 'Sa Pa');
      expect(parseWorld('lát cắt địa hình Huế từ bắc xuống nam').aspect, 'profile');
      final e = parseWorldEn('scan the terrain of Hanoi');
      expect(e.aspect, 'scan');
      expect(e.target.toLowerCase(), 'hanoi');
    });
  });
}
