import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/features/globe/asr_fix_vi.dart';

void main() {
  group('fixVietnameseAsr - Sửa lỗi ngữ âm tiếng Việt do ASR nghe nhầm', () {
    test('Sửa tên đỉnh núi và địa hình', () {
      expect(fixVietnameseAsr('độ cao đỉnh phang xi pang'), contains('Phan Xi Păng'));
      expect(fixVietnameseAsr('đỉnh phan si pan ở đâu'), contains('Phan Xi Păng'));
      expect(fixVietnameseAsr('núi e vo ret cao bao nhiêu'), contains('Everest'));
      expect(fixVietnameseAsr('kể về nui ba den'), contains('núi Bà Đen'));
      expect(fixVietnameseAsr('ranh mariana sâu bao nhiêu'), contains('rãnh Mariana'));
    });

    test('Sửa tên danh lam thắng cảnh', () {
      expect(fixVietnameseAsr('thời tiết ở vinh ha nong'), contains('Vịnh Hạ Long'));
      expect(fixVietnameseAsr('kể về vinh ha long'), contains('Vịnh Hạ Long'));
      expect(fixVietnameseAsr('quanh ho guom có gì'), contains('Hồ Gươm'));
      expect(fixVietnameseAsr('phố cổ hoi an'), contains('Hội An'));
      expect(fixVietnameseAsr('đến yen tu'), contains('Yên Tử'));
    });

    test('Sửa tên hành tinh vũ trụ', () {
      expect(fixVietnameseAsr('kể chuyện sao chim'), contains('Sao Kim'));
      expect(fixVietnameseAsr('nhiệt độ sao hoa thế nào'), contains('Sao Hỏa'));
      expect(fixVietnameseAsr('khoảng cách sao thuy'), contains('Sao Thủy'));
    });

    test('Sửa tên tỉnh thành hay nhầm lẫn', () {
      expect(fixVietnameseAsr('thời tiết ở nao cai'), contains('Lào Cai'));
      expect(fixVietnameseAsr('nhiệt độ ở da nang'), contains('Đà Nẵng'));
    });

    test('Giữ nguyên các câu đã nói chuẩn', () {
      expect(fixVietnameseAsr('thời tiết Hà Nội hôm nay'), equals('thời tiết Hà Nội hôm nay'));
      expect(fixVietnameseAsr('Huế ngày mai có mưa không'), equals('Huế ngày mai có mưa không'));
    });
  });
}
