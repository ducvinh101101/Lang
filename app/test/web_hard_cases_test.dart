// CA KHÓ tìm ra khi thử bản web bằng giọng nói giả lập (28/10/2026): mỗi dòng là một câu từng làm app trả lời sai,
// im lặng, hoặc đọc mã lỗi. Giữ lại để không bao giờ sai lại.
import 'package:earthsense/features/globe/vn_landmarks.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/space/planets.dart';
import 'package:earthsense/live/live_weather.dart';
import 'package:earthsense/live/weather_talk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('thời gian đứng đầu / cuối câu không bị lẫn vào tên nơi', () {
    final cases = <String, String>{
      'tuần sau sa pa có lạnh không': 'sa pa',
      'tuần sau Sa Pa có lạnh không': 'Sa Pa',
      'tuần tới đà lạt thế nào': 'đà lạt',
      'cuối tuần này hà nội có mưa không': 'hà nội',
      'cuối tuần ở huế thế nào': 'huế',
      'thời tiết đà nẵng tuần sau': 'đà nẵng',
      'sa pa tuần tới có rét không': 'sa pa',
      'mấy ngày tới cần thơ': 'cần thơ',
      'tối nay hải phòng có mưa không': 'hải phòng',
      'sáng mai vũng tàu thế nào': 'vũng tàu',
    };
    cases.forEach((s, want) {
      test(s, () {
        final c = parseWorld(s);
        expect(c.kind, anyOf(WKind.weather, WKind.forecast, WKind.day), reason: '$c');
        expect(c.target.toLowerCase(), want.toLowerCase(), reason: '$c');
      });
    });
  });

  group('đổi tốc độ đọc bằng câu nói thường ngày', () {
    for (final s in ['nói chậm thôi', 'đọc chậm thôi', 'chậm chút', 'nói chậm một chút', 'chậm lại', 'đọc chậm hơn']) {
      test(s, () => expect(parseWorld(s).kind, WKind.slower));
    }
    for (final s in ['nói nhanh lên', 'đọc nhanh hơn', 'nhanh chút', 'nhanh hơn']) {
      test(s, () => expect(parseWorld(s).kind, WKind.faster));
    }
    // KHÔNG được hiểu nhầm thành đổi tốc độ
    test('gió có nhanh không vẫn là thời tiết', () => expect(parseWorld('gió ở huế có mạnh không').kind, WKind.weather));
  });

  group('tiếng ậm ừ: im lặng chờ, không nói "chưa hiểu"', () {
    for (final s in ['ừm à ờ', 'ờ', 'ừ ừ', 'à', 'uh hmm', 'ờ thì', 'ơ', 'hừm']) {
      test(s, () => expect(isFillerOnly(s), isTrue));
    }
    for (final s in ['ờ thời tiết hà nội', 'à sao hỏa', 'ừ dừng lại', 'trái đất ơi']) {
      test('KHÔNG phải ậm ừ: $s', () => expect(isFillerOnly(s), isFalse));
    }
  });

  group('tên nơi trùng chữ hỏi thời tiết ("Bình Dương" có "đường")', () {
    final cases = {
      'bình dương có nóng không': 'bình dương',
      'thời tiết bình dương': 'bình dương',
      'nghệ an có mưa không': 'nghệ an',
      'thời tiết nghệ an hôm nay': 'nghệ an',
    };
    cases.forEach((s, want) => test(s, () {
          final c = parseWorld(s);
          expect(c.kind, WKind.weather, reason: '$c');
          expect(c.target.toLowerCase(), want, reason: '$c');
        }));
    test('"nghe 24 giờ tới" → nghe theo giờ ở chỗ đang xem (không tìm nơi tên "nghe")', () {
      final c = parseWorld('nghe 24 giờ tới');
      expect(c.kind, WKind.hours);
      expect(c.target, '');
    });
    test('"nghe 24 giờ tới ở huế" vẫn giữ Huế', () => expect(parseWorld('nghe 24 giờ tới ở huế').target.toLowerCase(), 'huế'));
  });

  group('tỉnh cũ (trước 1/7/2025) vẫn là tên nơi', () {
    for (final s in ['thời tiết ở đắk nông', 'thời tiết đắk nông', 'hà giang có mưa không', 'nhiệt độ quảng bình hôm nay']) {
      test(s, () {
        final c = parseWorld(s);
        expect(c.kind, WKind.weather, reason: '$c');
        expect(c.target, isNotEmpty);
      });
    }
  });

  group('hỏi mặt trăng CỦA một hành tinh → hành tinh đó, không phải Mặt Trăng', () {
    final cases = {
      'sao hỏa có mấy mặt trăng': 'Sao Hỏa',
      'sao mộc có bao nhiêu mặt trăng': 'Sao Mộc',
      'mặt trăng của sao thổ': 'Sao Thổ',
      'kể về mặt trăng': 'Mặt Trăng',
      'mặt trăng cách trái đất bao xa': 'Mặt Trăng',
      'trái đất ơi kể về mặt trăng': 'Mặt Trăng',
    };
    cases.forEach((s, want) => test(s, () => expect(planetIn(s)?.vi, want)));
    test('lệnh "sao hỏa có mấy mặt trăng" → hành tinh Sao Hỏa', () {
      final c = parseWorld('sao hỏa có mấy mặt trăng');
      expect(c.kind, WKind.planet);
      expect(c.target, 'Sao Hỏa');
    });
  });

  group('chỉ số UV hỏi lúc tối: nói thêm mức cao nhất ban ngày', () {
    LiveWeather w(double nowUv, double dayUv, double tomorrowUv) {
      final t0 = DateTime(2026, 10, 28);
      return LiveWeather(
        'test',
        t0,
        LiveNow(temp: 26, feels: 28, humidity: 80, precip: 0, desc: 'nhiều mây', code: 3, wind: 5, uv: nowUv),
        const [],
        [
          LiveDay(t0, 32, 24, 10, 0, 3, 'nhiều mây', dayUv, 10),
          LiveDay(t0.add(const Duration(days: 1)), 33, 25, 10, 0, 1, 'nắng', tomorrowUv, 10),
        ],
      );
    }

    test('đêm: UV bây giờ 0 → kèm cao nhất hôm nay và ngày mai', () {
      final (vi, _) = uvAnswer('Thành phố Hồ Chí Minh', 'HCMC', w(0, 11, 9), 0);
      expect(vi, contains('bây giờ 0'));
      expect(vi, contains('Ban ngày hôm nay cao nhất 11, cực kỳ cao'));
      expect(vi, contains('Ngày mai cao nhất 9, rất cao, nên che nắng'));
    });
    test('ban ngày: UV đang cao → không nói thêm', () {
      final (vi, _) = uvAnswer('Huế', 'Hue', w(7, 9, 8), 0);
      expect(vi, contains('bây giờ 7'));
      expect(vi, isNot(contains('Ban ngày hôm nay')));
    });
  });

  group('trả lời câu hỏi của app bằng chính chữ trong câu hỏi KHÔNG bị coi là tiếng vọng', () {
    const greet = 'lang day thoi tiet dia ly quanh ban hay kham pha vu tru ban muon nghe gi';
    const d3 = Duration(seconds: 3);
    for (final s in ['toi muon nghe thoi tiet', 'minh muon kham pha vu tru', 'cho toi nghe thoi tiet ha noi',
        'toi muon nghe dia ly quanh ban', 'muon nghe thoi tiet', 'kham pha vu tru', 'thoi tiet dia ly']) {
      test(s, () => expect(isEchoOf(s, [(greet, d3)], speaking: false), isFalse));
    }
    test('micro thu lại đúng một đoạn câu app đang đọc → tiếng vọng', () {
      expect(isEchoOf('dia ly quanh ban hay kham pha', [(greet, d3)], speaking: true), isTrue);
      expect(isEchoOf('thoi tiet dia ly quanh ban', [(greet, const Duration(seconds: 2))], speaking: false), isTrue);
      // bộ nhận giọng nghe giọng app sai vài chữ ("bạn" → "bang", "lý" → "li") vẫn nhận ra là tiếng vọng
      expect(isEchoOf('dia ly quanh bang hay kham pha', [(greet, d3)], speaking: true), isTrue);
      expect(isEchoOf('thoi tiet dia li quanh ban hay', [(greet, const Duration(seconds: 2))], speaking: false), isTrue);
    });
    test('micro thu lại mấy từ đuôi câu app vừa đọc xong → tiếng vọng đuôi (tránh vòng lặp)', () {
      // 1..4 từ cuối của câu chào / câu hỏi ("bạn muốn nghe gì", "muốn nghe gì", "nghe gì")
      expect(isEchoOf('ban muon nghe gi', [(greet, const Duration(seconds: 1))], speaking: false), isTrue);
      expect(isEchoOf('muon nghe gi', [(greet, const Duration(seconds: 1))], speaking: false), isTrue);
      expect(isEchoOf('nghe gi', [(greet, const Duration(seconds: 1))], speaking: false), isTrue);
      // câu báo lỗi có từ đuôi ("nói lại nhé", "lại nhé")
      const errPrompt = 'co loi ban thu noi lai nhe';
      expect(isEchoOf('noi lai nhe', [(errPrompt, const Duration(seconds: 1))], speaking: false), isTrue);
      expect(isEchoOf('lai nhe', [(errPrompt, const Duration(seconds: 1))], speaking: false), isTrue);
      // câu mô tả thời tiết có từ đuôi ("mưa rào rải rác", "rải rác")
      const weatherPrompt = 'thoi tiet o da nang co mua rao rai rac';
      expect(isEchoOf('mua rao rai rac', [(weatherPrompt, const Duration(seconds: 1))], speaking: false), isTrue);
      expect(isEchoOf('rai rac', [(weatherPrompt, const Duration(seconds: 1))], speaking: false), isTrue);
    });
    test('micro thu lại lúc app đang nói (speaking: true) kể cả 2 từ → tiếng vọng', () {
      expect(isEchoOf('thoi tiet', [(greet, d3)], speaking: true), isTrue);
      expect(isEchoOf('quanh ban', [(greet, d3)], speaking: true), isTrue);
      expect(isEchoOf('vu tru', [(greet, d3)], speaking: true), isTrue);
    });
    test('câu app đọc đã xong từ lâu → không còn là tiếng vọng', () {
      expect(isEchoOf('dia ly quanh ban hay kham pha', [(greet, const Duration(seconds: 30))], speaking: false), isFalse);
    });
  });

  group('tìm hiểu quanh Hà Nội: kể địa danh, không tả bản đồ 1 cây số', () {
    for (final q in ['quanh hà nội có gì', 'hà nội có gì', 'tôi muốn tìm hiểu về hà nội', 'giới thiệu hà nội',
        'hà nội có gì chơi', 'ở hà nội nên đi đâu']) {
      test(q, () => expect(parseWorld(q).kind, WKind.landmarks, reason: '${parseWorld(q)}'));
    }
    test('Hà Nội có đủ các địa danh chính', () {
      final names = landmarksOfProvinceIn('hà nội').map((l) => l.name).toSet();
      for (final n in ['Hồ Hoàn Kiếm', 'Phố cổ Hà Nội', 'Văn Miếu Quốc Tử Giám', 'Hồ Tây', 'Chùa Một Cột', 'Nhà hát Lớn Hà Nội',
          'Cầu Long Biên', 'Thành Cổ Loa', 'Làng gốm Bát Tràng', 'Chùa Hương']) {
        expect(names, contains(n));
      }
      expect(names.length, greaterThanOrEqualTo(15));
    });
    // KHÔNG cướp các câu khác
    test('thời tiết hà nội có gì đặc biệt vẫn là thời tiết', () => expect(parseWorld('thời tiết hà nội hôm nay').kind, WKind.weather));
    test('quanh đây có gì vẫn là tả bản đồ quanh chỗ đứng', () => expect(parseWorld('quanh đây có gì').kind, WKind.around));
    test('quanh hồ hoàn kiếm có gì vẫn là tả bản đồ quanh hồ', () => expect(parseWorld('quanh hồ hoàn kiếm có gì').kind, WKind.around));
    test('kể về hồ tây → một địa danh', () {
      final c = parseWorld('kể về hồ tây');
      expect(c.kind, WKind.landmark);
      expect(c.target, 'Hồ Tây');
    });
    test('đứng ở Hồ Gươm: các địa danh gần đây, gần trước', () {
      final near = landmarksNear(21.0288, 105.8525, km: 3).map((x) => x.$1.name).toList();
      expect(near.first, 'Hồ Hoàn Kiếm');
      expect(near, containsAll(['Phố cổ Hà Nội', 'Nhà hát Lớn Hà Nội', 'Nhà tù Hỏa Lò']));
      expect(near, isNot(contains('Chùa Hương')));
      final (vi, _) = nearbyLandmarksText(21.0288, 105.8525);
      expect(vi, startsWith('Địa danh gần đây: Hồ Hoàn Kiếm, ngay đây'));
    });
  });

  group('người nói ngập ngừng giữa câu: nhận ra câu chưa xong để nghe tiếp', () {
    for (final q in ['thời tiết', 'thời tiết ở', 'nhiệt độ', 'kể về', 'kể chuyện', 'cho mình hỏi', 'tôi muốn nghe',
        'địa hình từ hà nội đến', 'thời tiết xã', 'độ cao', 'dự báo thời tiết']) {
      test('chưa xong: $q', () => expect(looksUnfinished(q), isTrue));
    }
    for (final q in ['thời tiết hà nội', 'dừng lại', 'kể về sao hỏa', 'còn đà nẵng thì sao', 'quanh đây có gì', 'phóng to',
        'thời tiết xã tân lập', 'đọc lại', 'cảm ơn', 'hà nội có gì',
        'hà nội cách huế bao xa', 'thời tiết thứ tư', 'kể chuyện gì hay', 'mai trời có sáng không']) {
      test('đã xong: $q', () => expect(looksUnfinished(q), isFalse));
    }
  });

  group('cảm ơn: đáp ngắn, không tìm nơi tên "cảm ơn"', () {
    for (final q in ['cảm ơn nhé', 'cảm ơn bạn', 'cảm ơn nhiều', 'tuyệt vời']) {
      test(q, () {
        final c = parseWorld(q);
        expect(c.kind, WKind.ignore, reason: '$c');
        expect(c.target, 'thanks');
      });
    }
    for (final q in ['bạn là ai', 'bạn tên gì', 'lắng là gì']) {
      test(q, () => expect(parseWorld(q).target, 'who'));
    }
    test('gió ở vũng tàu mạnh không → Vũng Tàu', () {
      final c = parseWorld('gió ở vũng tàu mạnh không');
      expect(c.aspect, 'wind');
      expect(c.target.toLowerCase(), 'vũng tàu');
    });
  });

  group('câu hỏi tự nhiên nhắc một địa danh: giữ địa danh', () {
    test('mai mình đi chơi hồ tây được không', () {
      final c = parseWorld('mai mình đi chơi hồ tây được không');
      expect(c.kind, WKind.weather);
      expect(c.target, 'Hồ Tây');
      expect(c.liveDay, 1);
    });
    for (final (q, want) in [('Sài Gòn mấy độ rồi', 'sài gòn'), ('huế bao nhiêu độ rồi', 'huế'), ('đà lạt nhiệt độ bao nhiêu', 'đà lạt')]) {
      test(q, () {
        final c = parseWorld(q);
        expect(c.kind, WKind.weather, reason: '$c');
        expect(c.target.toLowerCase(), want, reason: '$c');
      });
    }
  });

  group('nói nốt câu ngay sau khi app vừa bắt đầu trả lời: ghép lại', () {
    const s2 = Duration(seconds: 2);
    test('thời tiết hà nội + ngày mai có mưa không', () {
      final m = mergeAfterthought('thời tiết hà nội', 'ngày mai có mưa không', s2);
      expect(m, 'thời tiết hà nội ngày mai có mưa không');
      final c = parseWorld(m!);
      expect(c.target.toLowerCase(), 'hà nội');
      expect(c.liveDay, 1);
      expect(c.aspect, 'rain');
    });
    test('thời tiết + ở đà nẵng (câu trước chưa có nơi)', () {
      expect(mergeAfterthought('thời tiết', 'ở đà nẵng', s2), 'thời tiết ở đà nẵng');
    });
    test('kể về sao hỏa + có mấy mặt trăng', () {
      final m = mergeAfterthought('kể về sao hỏa', 'có mấy mặt trăng', s2)!;
      expect(planetIn(m)?.vi, 'Sao Hỏa');
    });
    test('KHÔNG ghép: lệnh dừng, câu mới, đổi nơi, quá lâu, tiếng đệm', () {
      expect(mergeAfterthought('thời tiết hà nội', 'dừng lại', s2), isNull);
      expect(mergeAfterthought('thời tiết hà nội', 'kể chuyện sao hỏa', s2), isNull);
      expect(mergeAfterthought('thời tiết hà nội', 'ở đà nẵng', s2), isNull);
      expect(mergeAfterthought('thời tiết hà nội', 'ngày mai có mưa không', const Duration(seconds: 9)), isNull);
      expect(mergeAfterthought('thời tiết hà nội', 'ờ', s2), isNull);
      expect(mergeAfterthought('', 'ngày mai', s2), isNull);
    });
    test('tiếng đệm cuối câu = còn nói tiếp', () {
      expect(looksUnfinished('thời tiết hà nội ừm'), isTrue);
      expect(looksUnfinished('cho mình hỏi là'), isTrue);
      expect(looksUnfinished('kể chuyện sao hỏa cho mình nghe'), isFalse);
    });
  });
}
