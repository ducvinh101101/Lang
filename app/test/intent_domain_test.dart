// Tách phần THỜI TIẾT và phần ĐỊA ĐIỂM (ăn, ở, chơi quanh Hà Nội): cùng tên nơi không bị hiểu nhầm.
import 'package:earthsense/features/globe/intent_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('câu thuộc phần nào', () {
    final cases = <String, Domain?>{
      // thời tiết
      'thời tiết hồ tây': Domain.weather,
      'hồ tây có mưa không': Domain.weather,
      'mai đi chơi hồ tây được không': Domain.weather, // hỏi trời có hợp đi chơi không
      'sài gòn mấy độ rồi': Domain.weather,
      'gió ở vũng tàu mạnh không': Domain.weather,
      'trời hôm nay thế nào': Domain.weather,
      'hôm nay nóng không': Domain.weather,
      'thoi tiet ha noi': Domain.weather, // không dấu
      // địa điểm
      'hồ tây có gì chơi': Domain.places,
      'quán ăn ở tây hồ': Domain.places,
      'khách sạn gần hồ gươm': Domain.places,
      'mai đi chơi đâu ở hà nội': Domain.places,
      'chè lạnh ở đâu ngon': Domain.places, // "lạnh" là món, không phải trời
      'phở nóng ở đâu': Domain.places,
      'quán ăn ngoài trời ở hồ tây': Domain.places,
      'chỗ mua sắm ở hà nội': Domain.places, // "mua" ≠ "mưa"
      'quan an ngon': Domain.places,
      // chỉ tên nơi → theo phần đang dùng
      'tây hồ': null,
      'còn ba đình thì sao': null,
      'hà nội': null,
      'trung quốc': null, // "ốc" trong "Quốc" không phải món ốc
      'kể chuyện mặt trời': null, // "trời" trong "Mặt Trời"
    };
    cases.forEach((s, want) => test(s, () => expect(domainOf(s), want)));
  });

  group('chuyển phần / chữa lại', () {
    test('chuyển hẳn', () {
      expect(domainSwitch('phần địa điểm'), ('switch', Domain.places));
      expect(domainSwitch('chế độ địa điểm'), ('switch', Domain.places));
      expect(domainSwitch('chuyển sang phần thời tiết'), ('switch', Domain.weather));
      expect(domainSwitch('phần thời tiết'), ('switch', Domain.weather));
    });
    test('chữa lại câu vừa rồi', () {
      expect(domainSwitch('ý tôi là thời tiết'), ('fix', Domain.weather));
      expect(domainSwitch('không phải, hỏi địa điểm cơ'), ('fix', Domain.places));
      expect(domainSwitch('tôi hỏi quán ăn mà'), ('fix', Domain.places));
      expect(domainSwitch('ý tôi là chỗ ăn chơi'), ('fix', Domain.places));
    });
    test('không phải chuyển phần', () {
      expect(domainSwitch('thời tiết'), isNull); // chọn phần ở lời chào: phần hướng dẫn sẵn có lo
      expect(domainSwitch('phần thứ hai'), isNull);
      expect(domainSwitch('thời tiết hà nội'), isNull);
      expect(domainSwitch('quán phở ở phố cổ'), isNull);
    });
  });
}
