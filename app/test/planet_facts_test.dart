import 'package:earthsense/features/space/planet_facts.dart';
import 'package:flutter_test/flutter_test.dart';

// Hỏi về hành tinh không cần AI: nhận đúng ý hỏi, kể cả khi tên hành tinh có chữ trùng ý hỏi.
void main() {
  test('tiếng Việt', () {
    expect(planetAnswer(5, 'Sao Hỏa', 'Mars', 'Sao Hỏa có mấy mặt trăng', en: false), contains('2 mặt trăng'));
    expect(planetAnswer(5, 'Sao Hỏa', 'Mars', 'to bằng mấy Trái Đất', en: false), contains('một nửa'));
    expect(planetAnswer(5, 'Sao Hỏa', 'Mars', 'lên đó mình nặng bao nhiêu', en: false), contains('19 ki-lô-gam'));
    expect(planetAnswer(7, 'Sao Thổ', 'Saturn', 'Sao Thổ to bằng mấy Trái Đất', en: false), contains('rộng gấp'));
    expect(planetAnswer(4, 'Mặt Trăng', 'the Moon', 'Mặt Trăng cách bao xa', en: false), contains('384 nghìn'));
    expect(planetAnswer(6, 'Sao Mộc', 'Jupiter', 'kể chuyện đi', en: false), isNull);
  });

  test('English', () {
    expect(planetAnswer(5, 'Sao Hỏa', 'Mars', 'how big is it compared to earth', en: true), contains('half'));
    expect(planetAnswer(1, 'Sao Thủy', 'Mercury', 'how big is it', en: true), contains('a third'));
    expect(planetAnswer(6, 'Sao Mộc', 'Jupiter', 'how many moons does it have', en: true), contains('115 moons'));
    expect(planetAnswer(2, 'Sao Kim', 'Venus', 'is it hot there', en: true), contains('465'));
  });
}
