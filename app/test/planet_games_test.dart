import 'dart:math' as math;

import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/space/planet_games.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ngân hàng câu hỏi hợp lệ', () {
    for (final q in quizBank) {
      expect(q.opts.length, 3, reason: q.q);
      expect(q.optsEn.length, 3, reason: q.q);
      expect(q.answer, inInclusiveRange(0, 2));
      // đáp án đúng phải tự nhận ra được khi người chơi nói đúng nội dung của nó
      expect(matchOption(q.opts[q.answer], q.opts), q.answer, reason: q.q);
    }
    for (final r in riddleBank) {
      expect(r.clues.length, 3);
      expect(r.cluesEn.length, 3);
      expect(soundWhy[r.sound], isNotNull);
    }
  });

  test('hiểu câu trả lời', () {
    const o = ['Sao Thủy', 'Sao Kim', 'Sao Hỏa'];
    expect(matchOption('một', o), 0);
    expect(matchOption('số hai', o), 1);
    expect(matchOption('đáp án ba', o), 2);
    expect(matchOption('sao kim', o), 1);
    expect(matchOption('mình nghĩ là sao hỏa', o), 2);
    expect(matchOption('sao thổ', o), isNull);
    expect(matchOption('the second', o), 1);
    expect(matchOption('tây', ['Hướng đông', 'Hướng tây', 'Hướng bắc']), 1);
    expect(matchOption('tám phút', ['8 giây', '8 phút', '8 giờ']), 1);
    expect(matchOption('năm ký', ['5 ki-lô-gam', '30 ki-lô-gam', '60 ki-lô-gam']), 0);
    expect(matchOption('69', ['1969', '1975', '1957']), 0);
    expect(matchOption('hai', ['Một', 'Hai', 'Không có']), 1);
    expect(matchOption('không có', ['Một', 'Hai', 'Không có']), 2);
    expect(matchBody('sao thổ'), 7);
    expect(gameControl('nhắc lại đi'), 'repeat');
    expect(gameControl('cho mình gợi ý'), 'hint');
    expect(gameControl('chịu'), 'skip');
    expect(gameControl('thôi không chơi nữa'), 'stop');
  });

  test('dựng lượt chơi', () {
    final r = math.Random(1);
    expect(buildQuiz(r).length, 5);
    expect(buildRiddles(r).length, 3);
    final g = buildSoundGame(r);
    expect(g.learn.length, 3);
    expect(g.asks.length, 4);
    for (var k = 1; k < g.asks.length; k++) {
      expect(g.asks[k], isNot(g.asks[k - 1]));
      expect(g.learn, contains(g.asks[k]));
    }
    expect(finalWords(5, 5).$1, contains('tuyệt đối'));
  });

  test('lệnh chơi', () {
    expect(parseWorld('chơi trò chơi').kind, WKind.game);
    expect(parseWorld('chơi trò chơi').target, '');
    expect(parseWorld('đố vui hành tinh').target, 'quiz');
    expect(parseWorld('chơi tôi là ai').target, 'riddle');
    expect(parseWorld('nghe tiếng đoán hành tinh').target, 'sound');
    expect(parseWorld('nhiệt độ tối nay').kind, isNot(WKind.game));
    expect(parseWorld('kể chuyện sao thổ').kind, WKind.planet);
    expect(parseWorldEn('play a game').kind, WKind.game);
    expect(parseWorldEn('space quiz').target, 'quiz');
  });
}
