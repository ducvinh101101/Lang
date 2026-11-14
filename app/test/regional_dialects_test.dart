import 'package:earthsense/features/globe/world_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Giọng miền Trung: từ địa phương (chi, rứa, răng, mô, chừ, nỏ, hè)', () {
    test('ở huế chừ có mưa chi không → Huế', () {
      final c = parseWorld('ở huế chừ có mưa chi không');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'huế');
    });

    test('chừ đà nẵng mấy độ rứa → Đà Nẵng', () {
      final c = parseWorld('chừ đà nẵng mấy độ rứa');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'đà nẵng');
    });

    test('ở đà lạt có chi đẹp rứa hè → địa danh Đà Lạt', () {
      final c = parseWorld('ở đà lạt có chi đẹp rứa hè');
      expect(c.kind, WKind.landmarks);
      expect(c.target.toLowerCase(), 'đà lạt');
    });

    test('kể tui nghe về vịnh hạ long coi → Vịnh Hạ Long', () {
      final c = parseWorld('kể tui nghe về vịnh hạ long coi');
      expect(c.kind, WKind.landmark);
      expect(c.target, 'Vịnh Hạ Long');
    });

    test('quảng ninh có chi nổi tiếng rứa → Quảng Ninh', () {
      final c = parseWorld('quảng ninh có chi nổi tiếng rứa');
      expect(c.kind, WKind.landmarks);
      expect(c.target.toLowerCase(), 'quảng ninh');
    });

    test('sao hỏa cách trái đất bao xa rứa → Sao Hỏa', () {
      final c = parseWorld('sao hỏa cách trái đất bao xa rứa');
      expect(c.kind, WKind.planet);
      expect(c.target, 'Sao Hỏa');
    });

    test('thời tiết hà nội bữa ni răng rứa → Hà Nội', () {
      final c = parseWorld('thời tiết hà nội bữa ni răng rứa');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'hà nội');
    });
  });

  group('Giọng miền Nam / Tây Nam Bộ: (hông, hổng, nè, nghen, sao ta, coi, nhiêu, dị)', () {
    test('hôm nay sài gòn có mưa hông → Sài Gòn', () {
      final c = parseWorld('hôm nay sài gòn có mưa hông');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), anyOf('sài gòn', 'tp. hồ chí minh'));
    });

    test('thời tiết đà lạt bữa nay sao ta → Đà Lạt', () {
      final c = parseWorld('thời tiết đà lạt bữa nay sao ta');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'đà lạt');
    });

    test('nhiệt độ ở cần thơ nhiêu dị → Cần Thơ', () {
      final c = parseWorld('nhiệt độ ở cần thơ nhiêu dị');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'cần thơ');
    });

    test('ở vũng tàu có gì chơi hông nè → Vũng Tàu', () {
      final c = parseWorld('ở vũng tàu có gì chơi hông nè');
      expect(c.kind, WKind.landmarks);
      expect(c.target.toLowerCase(), 'vũng tàu');
    });

    test('sao mộc có mấy mặt trăng dị → Sao Mộc', () {
      final c = parseWorld('sao mộc có mấy mặt trăng dị');
      expect(c.kind, WKind.planet);
      expect(c.target, 'Sao Mộc');
    });

    test('mai đi chơi hồ tây được hông ta → Hồ Tây', () {
      final c = parseWorld('mai đi chơi hồ tây được hông ta');
      expect(c.kind, WKind.weather);
      expect(c.target, 'Hồ Tây');
    });
  });

  group('Giọng miền Bắc & khẩu ngữ tự nhiên (thế lào, nhể, nhở, xem nào)', () {
    test('thời tiết hà nội hôm nay thế lào → Hà Nội', () {
      final c = parseWorld('thời tiết hà nội hôm nay thế lào');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'hà nội');
    });

    test('hà nội có gì chơi nhể → Hà Nội', () {
      final c = parseWorld('hà nội có gì chơi nhể');
      expect(c.kind, WKind.landmarks);
      expect(c.target.toLowerCase(), 'hà nội');
    });

    test('mai sa pa có rét không nhở → Sa Pa', () {
      final c = parseWorld('mai sa pa có rét không nhở');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'sa pa');
    });

    test('kể về đà lạt xem nào → Đà Lạt', () {
      final c = parseWorld('kể về đà lạt xem nào');
      expect(c.kind, anyOf(WKind.landmark, WKind.landmarks));
      expect(c.target.toLowerCase(), 'đà lạt');
    });
  });

  group('Các trường hợp dễ hiểu lầm / bẫy ngữ nghĩa', () {
    test('bình dương có nóng không (tên chứa chữ "dương")', () {
      final c = parseWorld('bình dương có nóng không');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'bình dương');
    });

    test('đắk nông có mưa không (chứa chữ "nông")', () {
      final c = parseWorld('đắk nông có mưa không');
      expect(c.kind, WKind.weather);
      expect(c.target.toLowerCase(), 'đắk nông');
    });

    test('mặt trăng của sao thổ → Sao Thổ', () {
      final c = parseWorld('mặt trăng của sao thổ');
      expect(c.kind, WKind.planet);
      expect(c.target, 'Sao Thổ');
    });

    test('thời tiết tuần sau không nhầm sang sao hỏa', () {
      final c = parseWorld('thời tiết tuần sau');
      expect(c.kind, anyOf(WKind.weather, WKind.forecast));
      expect(c.kind, isNot(WKind.planet));
    });

    test('ở hoàn kiếm hà nội có gì → Hoàn Kiếm / Hà Nội', () {
      final c = parseWorld('ở hoàn kiếm hà nội có gì');
      expect(c.kind, WKind.landmarks);
      expect(c.target.toLowerCase(), contains('hoàn kiếm'));
    });
  });
}
