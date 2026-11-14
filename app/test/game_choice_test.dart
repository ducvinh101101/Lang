// Chọn trò chơi khám phá vũ trụ bằng giọng nói: "chọn trò chơi thứ 3" phải vào trò 3 (nghe tiếng đoán hành tinh).
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/voice/commands.dart' show normVi;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chọn trò bằng số thứ tự', () {
    const cases = {
      'chọn trò chơi thứ 3': 'sound',
      'chọn trò chơi thứ ba': 'sound',
      'tôi chọn trò thứ ba': 'sound',
      'cho tôi chơi trò thứ 3': 'sound',
      'trò số 3': 'sound',
      'trò chơi số 3': 'sound',
      'mình chọn số 3': 'sound',
      'chọn cái thứ ba': 'sound',
      'chọn trò chơi thứ 2': 'riddle',
      'trò số hai': 'riddle',
      'chọn trò thứ nhất': 'quiz',
      'trò số 1': 'quiz',
    };
    cases.forEach((s, want) => test(s, () => expect(gameKindVi(normVi(s)), want)));
  });

  test('câu mô tả trò 2 trong lời app đọc ("Hai: tôi là ai…") bị hiểu là trò 2 — vì vậy app phải lọc tiếng loa thu lại', () {
    expect(gameKindVi(normVi('hai tôi là ai nghe gợi ý rồi đoán tên hành tinh')), 'riddle');
  });
}
