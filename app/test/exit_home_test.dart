// Không bị KẸT trong rê tay: các câu thoát / về màn hình chính.
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/voice/commands.dart' show normVi;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đang ở rê tay: câu ngắn "quay lại", "trở về"… là thoát', () {
    for (final s in [
      'quay lại', 'quay lại đi', 'trở về', 'trở lại nhé', 'về thôi', 'đi về', 'đóng', 'đóng lại', 'ra ngoài',
      'xong rồi', 'đủ rồi', 'thoát', 'tôi muốn thoát', 'cho tôi quay lại', 'thôi xong rồi', 'quay về quả địa cầu',
      'về màn hình chính', 'go back', 'exit',
    ]) {
      expect(isBackPhrase(normVi(s)), isTrue, reason: s);
    }
  });
  test('không nhầm các câu khác thành thoát', () {
    for (final s in ['về hà nội', 'quay lại sao hỏa', 'thời tiết hà nội', 'chỗ này cao bao nhiêu', 'thôi', 'trở về đà lạt',
      'nói lại', 'ra sao']) {
      expect(isBackPhrase(normVi(s)), isFalse, reason: s);
    }
  });
  test('"về màn hình chính" ở mọi nơi', () {
    expect(isHomePhrase(normVi('về màn hình chính')), isTrue);
    expect(isHomePhrase(normVi('cho tôi về trang chủ')), isTrue);
    expect(isHomePhrase(normVi('màn hình chính')), isTrue);
    expect(isHomePhrase(normVi('thời tiết hà nội')), isFalse);
  });
  test('lệnh thoát rê tay qua parseWorld', () {
    for (final s in ['thoát', 'tôi muốn thoát', 'thoát rê tay', 'tắt rê tay', 'đóng bản đồ', 'tắt bản đồ', 'về quả địa cầu']) {
      expect(parseWorld(s).kind, WKind.exitLocal, reason: s);
    }
  });
  test('"chạm địa hình" vẫn hiểu (giờ mở rê tay), "tắt chạm địa hình" là tắt', () {
    expect(parseWorld('chạm địa hình').aspect, 'touch');
    expect(parseWorld('tắt chạm địa hình').aspect, 'off');
  });
  test('ngoài rê tay "quay lại" vẫn là thu nhỏ quả cầu', () {
    expect(parseWorld('quay lại').kind, WKind.zoomOut);
  });
}
