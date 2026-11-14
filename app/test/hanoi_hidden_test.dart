// Phần QUÁN ĂN – CHỖ Ở ở Hà Nội đang ẨN (kHanoiFoodStayEnabled = false): cẩm nang chỉ kể tham quan, vui chơi.
import 'package:earthsense/features/globe/hanoi_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cờ đang tắt', () => expect(kHanoiFoodStayEnabled, isFalse));
  test('hỏi ăn uống / chỗ ở ở một khu → nói phần này tạm ẩn, kể tham quan', () {
    for (final q in ['tây hồ ăn gì ngon', 'khách sạn ở tây hồ', 'quán cà phê ở hồ tây']) {
      final g = buildHanoiGuide('Tây Hồ', 'Tay Ho', raw: q)!;
      expect(g.$1, contains('tạm ẩn'), reason: q);
      expect(g.$1, isNot(contains('Về ăn uống')), reason: q);
      expect(g.$1, isNot(contains('Về lưu trú')), reason: q);
      expect(g.$1, isNot(contains('bánh tôm')), reason: q);
    }
  });
  test('"có gì chơi", "quanh đây có gì" → chỉ tham quan, vui chơi, không có quán ăn, khách sạn', () {
    for (final q in ['tây hồ có gì chơi', 'quanh tây hồ có gì', 'tây hồ có địa điểm du lịch gì']) {
      final g = buildHanoiGuide('Tây Hồ', 'Tay Ho', raw: q)!;
      expect(g.$1, isNot(contains('tạm ẩn')), reason: q);
      expect(g.$1, isNot(contains('Về ăn uống')), reason: q);
      expect(g.$1, isNot(contains('Về lưu trú')), reason: q);
      expect(g.$1, contains('Về du lịch tham quan'), reason: q);
    }
  });
}
