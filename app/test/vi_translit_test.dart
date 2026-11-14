import 'package:earthsense/speech/vi_translit.dart';
import 'package:flutter_test/flutter_test.dart';

// Giọng tiếng Việt đọc tên nước ngoài: tiếng Việt giữ nguyên, tên nước ngoài viết lại thành tiếng kiểu Việt.
void main() {
  test('nhận ra tiếng Việt', () {
    expect(isVietnameseSyllable('Nẵng'), isTrue);
    expect(isVietnameseSyllable('Vinh'), isTrue);
    expect(isVietnameseSyllable('Hà'), isTrue);
    expect(isVietnameseSyllable('Nội'), isTrue);
    expect(isVietnameseSyllable('Huế'), isTrue);
    expect(isVietnameseSyllable('Thành'), isTrue);
    expect(isVietnameseSyllable('phố'), isTrue);
    expect(isVietnameseSyllable('Quy'), isTrue);
    expect(isVietnameseSyllable('Nhơn'), isTrue);
    expect(isVietnameseSyllable('Nghệ'), isTrue);
    expect(isVietnameseSyllable('Khánh'), isTrue);
    expect(isVietnameseSyllable('Hòa'), isTrue);
    expect(isVietnameseSyllable('Biển'), isTrue);
    expect(isVietnameseSyllable('Đông'), isTrue);
    expect(isVietnameseSyllable('Trường'), isTrue);
    expect(isVietnameseSyllable('Sa'), isTrue);
    expect(isVietnameseSyllable('Paris'), isFalse);
    expect(isVietnameseSyllable('Hanoi'), isFalse);
    expect(isVietnameseSyllable('Berlin'), isFalse);
    expect(isVietnameseSyllable('Stockholm'), isFalse);
    expect(isVietnameseSyllable('Whichello'), isFalse);
  });

  test('phiên âm tên nước ngoài', () {
    expect(phienAm('Albenga'), 'An ben ga');
    expect(phienAm('Whichello'), 'Ui che lô');
    expect(phienAm('Mona'), 'Mô na');
    expect(phienAm('Berlin'), 'Be lin');
    expect(phienAm('Paris'), 'Pa rít');
    expect(phienAm('Texas'), 'Téc xát');
    expect(phienAm('Brazil'), 'Bơ ra din');
    expect(phienAm('Karachi'), 'Ca ra chi');
    expect(phienAm('München'), 'Mun chen');
    expect(phienAm('Frankfurt'), 'Phơ ran cơ phu tơ');
    expect(phienAm('Johannesburg'), 'Giô ha nét bu gơ');
    expect(phienAm('Pretoria'), 'Pơ re tô ria');
    expect(phienAm('Nairobi'), 'Nai rô bi');
    expect(phienAm('Bogota'), 'Bô gô ta');
    expect(phienAm('Santiago'), 'Xan tia gô');
    expect(phienAm('Kathmandu'), 'Cát man đu');
    expect(phienAm('Taipei'), 'Tai pây');
    expect(phienAm('Hong'), 'Hông');
    expect(phienAm('Australia'), 'Ốt tơ ra lia');
    expect(phienAm('Italy'), 'I ta li');
    expect(phienAm('Schleicher'), 'Xơ lây che');
    expect(phienAm('Ireland'), 'I re lan đơ');
    expect(phienAm('Rome'), 'Rôm');
    expect(phienAm('Seattle'), 'Xít lơ');
    expect(phienAm('Houston'), 'Hút tôn');
    expect(phienAm('Boston'), 'Bốt tôn');
    expect(phienAm('Zurich'), 'Du rích');
    expect(phienAm('Budapest'), 'Bu đa pét tơ');
    expect(phienAm('Barcelona'), 'Ba xe lô na');
    expect(phienAm('Hamburg'), 'Ham bu gơ');
    expect(phienAm('Copenhagen'), 'Cô pen ha ghen');
    expect(phienAm('Edinburgh'), 'E đin bu gơ');
    expect(phienAm('Manchester'), 'Man chét te');
    expect(phienAm('Liverpool'), 'Li ve pun');
    expect(phienAm('Abidjan'), 'A bít gian');
    expect(phienAm('Dhaka'), 'Đa ca');
    expect(phienAm('Côte'), 'Cốt');
  });

  test('câu tiếng Việt có tên nước ngoài', () {
    expect(phienAmCau('Albenga, Ý. Bây giờ 17 độ.'), 'An ben ga, Ý. Bây giờ 17 độ.');
    expect(phienAmCau('Cách biển khoảng 30 km, chỉ số UV 4.'), 'Cách biển khoảng 30 km, chỉ số UV 4.');
    expect(phienAmCau('Đà Nẵng, Việt Nam'), 'Đà Nẵng, Việt Nam');
  });
}
