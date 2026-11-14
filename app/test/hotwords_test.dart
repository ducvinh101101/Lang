import 'package:earthsense/features/voice/commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('từ khoá ưu tiên có tỉnh, địa danh, câu thời tiết, trò chơi', () {
    final h = hotwordPhrases().toSet();
    for (final w in ['TÂY NINH', 'LÀO CAI', 'YÊN BÁI', 'VỊNH HẠ LONG', 'XÃ', 'PHƯỜNG', 'MẶT TRỜI MỌC', 'PHƠI ĐỒ', 'ĐỐ VUI', 'TÔI LÀ AI']) {
      expect(h, contains(w));
    }
    // không có dòng rỗng hay ký tự lạ (sherpa-onnx đọc từng dòng)
    for (final w in h) {
      expect(w.trim(), isNotEmpty);
      expect(RegExp(r'^[\p{L}\p{N} ]+$', unicode: true).hasMatch(w), isTrue, reason: w);
    }
  });
}
