import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/speech/piper_voice.dart';

void main() {
  group('E2E Real-world ASR Speech Parser Tests', () {
    test('Xử lý các câu Whisper nhận diện chuẩn 100%', () {
      // 1. Bay tới Hà Nội
      final c1 = parseWorld('Bay tới Hà Nội');
      expect(c1.kind, equals(WKind.go));
      expect(c1.target, equals('Hà Nội'));

      // 2. Thời tiết ở thành phố Hồ Chí Minh hôm nay thế nào?
      final c2 = parseWorld('Thời tiết ở thành phố Hồ Chí Minh hôm nay thế nào?');
      expect(c2.kind, equals(WKind.weather));
      expect(c2.target.toLowerCase(), equals('thành phố hồ chí minh'));

      // 3. Cho tôi xem thời tiết ở Đà Nẵng.
      final c3 = parseWorld('Cho tôi xem thời tiết ở Đà Nẵng.');
      expect(c3.kind, equals(WKind.weather));
      expect(c3.target, equals('Đà Nẵng'));

      // 4. bay tới quận Ba Đình.
      final c4 = parseWorld('bay tới quận Ba Đình.');
      expect(c4.kind, equals(WKind.go));
      expect(c4.target, contains('Ba Đình'));

      // 5. Đến quần đảo Hoàng Sa
      final c5 = parseWorld('Đến quần đảo Hoàng Sa');
      expect(c5.kind, equals(WKind.go));
      expect(c5.target, contains('Hoàng Sa'));

      // 6. Chiều nay đi làm có cần mang áo mưa không?
      final c6 = parseWorld('Chiều nay đi làm có cần mang áo mưa không?');
      expect(c6.kind, equals(WKind.weather));

      // 7. Ảnh thiên văn hôm nay của NASA
      final c7 = parseWorld('Ảnh thiên văn hôm nay của NASA');
      expect(c7.kind, equals(WKind.apod));

      // 8. Thu nhỏ quả địa cầu
      final c8 = parseWorld('Thu nhỏ quả địa cầu');
      expect(c8.kind, equals(WKind.zoomOut));

      // 9. Dừng mọi âm thanh.
      final c9 = parseWorld('Dừng mọi âm thanh.');
      expect(c9.kind, equals(WKind.stop));

      // 10. Bay tới Tokyo
      final c10 = parseWorld('Bay tới Tokyo');
      expect(c10.kind, equals(WKind.go));
      expect(c10.target, equals('Tokyo'));
    });

    test('Xử lý dung sai khi ASR nghe nhầm dấu hoặc từ đồng âm (Tolerant Cases)', () {
      // 1. "Đến Huế nghe nhạc cũ." -> Phải nhận diện nghe nhạc cụ ở Huế!
      final c1 = parseWorld('Đến Huế nghe nhạc cũ.');
      expect(c1.target, equals('Huế'));
      expect(c1.kind, isIn([WKind.music, WKind.go]));

      // 2. "Thời tiết ở Sapa có lạnh không?" -> Sapa viết liền
      final c2 = parseWorld('Thời tiết ở Sapa có lạnh không?');
      expect(c2.kind, equals(WKind.weather));
      expect(c2.target, equals('Sa Pa'));

      // 3. "Nhà Trang bây giờ bao nhiêu độ?" -> Nha Trang bị nhầm thành Nhà Trang
      final c3 = parseWorld('Nhà Trang bây giờ bao nhiêu độ?');
      expect(c3.kind, equals(WKind.weather));
      expect(c3.target, equals('Nha Trang'));

      // 4. "Thời tiết huyện Cần Giơ" -> Cần Giờ
      final c4 = parseWorld('Thời tiết huyện Cần Giơ');
      expect(c4.kind, equals(WKind.weather));
      expect(c4.target, contains('Cần Giờ'));

      // 5. "Thời tiết ở Côn Đào" -> Côn Đảo
      final c5 = parseWorld('Thời tiết ở Côn Đào');
      expect(c5.kind, equals(WKind.weather));
      expect(c5.target, equals('Côn Đảo'));

      // 6. "Kể chuyện về sao hòa" -> Sao Hỏa
      final c6 = parseWorld('Kể chuyện về sao hòa');
      expect(c6.kind, equals(WKind.planet));
      expect(c6.target, equals('Sao Hỏa'));

      // 7. "Thời tiết ở xã Tân Chiều" -> Tân Triều
      final c7 = parseWorld('Thời tiết ở xã Tân Chiều');
      expect(c7.kind, equals(WKind.weather));
      expect(c7.target, contains('Tân Triều'));
    });

    test('Kiểm tra PiperVoice.chunks: câu ngắn/vừa không bị băm vụn, câu dài chia hợp lý', () {
      const short = 'Xin chào, mình là Lắng. Bạn muốn nghe thời tiết hay khám phá vũ trụ?';
      final cShort = PiperVoice.chunks(short);
      expect(cShort.length, equals(1));
      expect(cShort.first, equals(short));

      const longText = 'Xin chào, mình là Lắng, quả địa cầu biết nói. Bạn không cần bấm gì, cứ nói là mình nghe. '
          'Mình có ba phần. Một: thời tiết khắp thế giới, ví dụ nói: thời tiết Hà Nội. '
          'Hai: địa lý và địa điểm ăn uống, vui chơi quanh bạn, ví dụ nói: phường Hoàn Kiếm có gì chơi, hoặc quanh đây có gì. '
          'Ba: khám phá vũ trụ, ví dụ: kể chuyện Sao Hỏa. '
          'Bạn muốn bắt đầu với phần nào?';
      final cLong = PiperVoice.chunks(longText);
      expect(cLong.length, greaterThanOrEqualTo(1));
      for (final chunk in cLong) {
        expect(chunk.length, greaterThanOrEqualTo(40));
      }
    });

    test('Kiểm tra looksUnfinished: câu lệnh trọn vẹn và câu dở dang', () {
      // Câu dở dang thiếu vế sau
      expect(looksUnfinished('thời tiết ở'), isTrue);
      expect(looksUnfinished('kể về'), isTrue);
      expect(looksUnfinished('dự báo thời tiết'), isTrue);
      expect(looksUnfinished('bay đến'), isTrue);

      // Câu hoàn chỉnh
      expect(looksUnfinished('dừng lại'), isFalse);
      expect(looksUnfinished('thời tiết hà nội'), isFalse);
      expect(looksUnfinished('quanh đây có gì'), isFalse);
    });
  });
}
