// TIẾNG VIỆT DỄ NHẦM NGHĨA: mỗi dòng là một câu từng bị app hiểu sai (tìm ra khi chạy thử 07/11/2026).
import 'dart:io';

import 'package:earthsense/features/globe/hanoi_places.dart';
import 'package:earthsense/features/globe/intent_domain.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/space/planets.dart';
import 'package:earthsense/features/voice/commands.dart' show normVi;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('"thứ ba" là ngày trong tuần, không phải trò chơi số 3', () {
    for (final s in ['đi chơi thứ ba có mưa không', 'chơi thứ hai có nắng không']) {
      test(s, () {
        expect(gameKindVi(normVi(s)), isNull);
        expect(parseWorld(s).kind, WKind.weather);
        expect(parseWorld(s).liveDay, isNotNull);
      });
    }
    test('trong trò chơi vẫn chọn được', () => expect(gameKindVi(normVi('chọn trò thứ ba')), 'sound'));
    test('"thoát trò chơi" là thoát, không mở danh sách trò', () {
      expect(gameKindVi(normVi('thoát trò chơi')), isNull);
      expect(parseWorld('thoát trò chơi').kind, isNot(WKind.game));
    });
  });

  group('"sao" = tại sao / thế nào, không phải ngôi sao', () {
    test('sao hôm nay nóng thế → thời tiết (không phải Sao Hôm)', () {
      expect(planetIn('sao hôm nay nóng thế'), isNull);
      expect(parseWorld('sao hôm nay nóng thế').kind, WKind.weather);
    });
    test('sao mai là sao nào → Sao Kim (Sao Mai là tên gọi Sao Kim)', () => expect(planetIn('sao mai là sao nào')?.vi, 'Sao Kim'));
    test('hà nội sao rồi → Hà Nội', () => expect(parseWorld('hà nội sao rồi').target, 'hà nội'));
  });

  group('tên nơi không dính chữ thừa', () {
    final cases = {
      'còn huế thì sao': 'huế',
      'còn ninh bình thì sao': 'ninh bình',
      'còn tây hồ thì sao': 'tây hồ',
      'còn côn đảo thì sao': 'Côn Đảo', // "Côn" không bị cắt như "còn"
      'an giang có mưa không': 'an giang', // "An" không bị hiểu là "ăn"
      'quận ba sài gòn mấy độ': 'quận 3 sài gòn',
      'tôi muốn biết thời tiết ở quê tôi nghệ an': 'nghệ an',
      'lũ ở miền trung': 'miền trung',
    };
    cases.forEach((s, want) => test(s, () => expect(parseWorld(s).target, want)));
    test('đi ăn phở có mưa không → không có tên nơi "ăn phở"', () => expect(parseWorld('đi ăn phở có mưa không').target, ''));
    test('gió mùa đông bắc về chưa → không có tên nơi', () => expect(parseWorld('gió mùa đông bắc về chưa').target, ''));
    test('quê tôi ở Huế vẫn là đặt nhà', () => expect(parseWorld('quê tôi ở Huế').kind, WKind.setHome));
  });

  group('chữa lời', () {
    test('không phải hà nội mà là hà nam → Hà Nam, hỏi tiếp', () {
      final c = parseWorld('không phải hà nội mà là hà nam');
      expect(c.target, 'hà nam');
      expect(c.followUp, isTrue);
    });
    test('không, ý tôi là đà nẵng → Đà Nẵng', () => expect(parseWorld('không, ý tôi là đà nẵng').target.toLowerCase(), 'đà nẵng'));
  });

  group('bão, lũ', () {
    test('bão có về hà nội không → thiên tai ở Hà Nội', () {
      final c = parseWorld('bão có về hà nội không');
      expect(c.kind, WKind.disasters);
      expect(c.target.toLowerCase(), 'hà nội');
    });
    test('xã Liên Bão (tên xã) vẫn là thời tiết', () => expect(parseWorld('thời tiết xã Liên Bão').kind, WKind.weather));
    test('giông bão hôm nay → thời tiết', () => expect(parseWorld('hôm nay có giông bão không').kind, WKind.weather));
  });

  group('không phải thời tiết', () {
    test('mấy giờ rồi → giờ', () => expect(parseWorld('bây giờ là mấy giờ').target, 'time'));
    test('hôm nay thứ mấy → ngày', () => expect(parseWorld('hôm nay thứ mấy').target, 'date'));
    test('tôi tên là mai → trò chuyện, không tìm nơi', () => expect(parseWorld('tôi tên là mai').kind, WKind.unknown));
    test('chi tiết số 2 (không có danh sách) → không đọc thời tiết', () => expect(parseWorld('chi tiết số 2').kind, WKind.unknown));
    test('thứ hai (trơn) vẫn là ngày thứ Hai', () => expect(parseWorld('thứ hai').kind, WKind.weather));
  });

  group('giọng vùng miền / nghe nhầm', () {
    for (final s in ['rừng lại', 'giừng lại', 'tạm dừng']) {
      test('$s → dừng', () => expect(parseWorld(s).kind, WKind.stop));
    }
    test('nhỏ thôi → nhỏ tiếng', () => expect(parseWorld('nhỏ thôi').kind, WKind.quieter));
    test('ở đó thế nào → thời tiết nơi đang xem', () => expect(parseWorld('ở đó thế nào').kind, WKind.weather));
  });

  group('hỏi ăn / ở NGOÀI Hà Nội: không đọc quán Hà Nội, không bay tới nơi tên lạ', () {
    final db = HanoiPlacesDb.parse(File('assets/data/hanoi_places.json').readAsStringSync());
    for (final s in ['bến tre ăn gì ngon', 'đà lạt có quán cà phê nào đẹp', 'khách sạn ở huế']) {
      test(s, () {
        expect(parsePlaceQuery(s, db), isNull);
        expect(parseWorld(s).kind, WKind.unknown); // để trợ lý AI trả lời
      });
    }
    test('quán phở ở hà nội vẫn dùng dữ liệu Hà Nội', () => expect(parsePlaceQuery('quán phở ở hà nội', db), isNotNull));
  });

  test('chọn phần: thời tiết vs địa điểm vẫn đúng sau các sửa trên', () {
    expect(domainOf('bão có về hà nội không'), Domain.weather);
    expect(domainOf('hà nội có gì chơi'), Domain.places);
  });
}
