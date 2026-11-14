// Giữ tên file này để `flutter create .` không sinh test mẫu (MyApp) gây lỗi biên dịch.
// Test giao diện cần giả lập plugin (flutter_tts, shared_preferences); xem core_test.dart cho phần logic.
import 'package:earthsense/audio/sound_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SilentBackend không lỗi', () async {
    final b = SilentBackend();
    await b.init();
    expect(await b.play('x'), isNull);
  });
}
