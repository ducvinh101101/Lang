import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:earthsense/data/planet_bodies.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/space/planet_facts.dart';
import 'package:earthsense/features/space/planet_games.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    final j = jsonDecode(File('assets/data/planets_nasa.json').readAsStringSync()) as Map<String, dynamic>;
    PlanetBody.loaded = [for (final b in j['bodies'] as List) PlanetBody.fromJson(b as Map<String, dynamic>)];
  });

  test('mỗi thiên thể có sự thật thú vị song ngữ', () {
    expect(PlanetBody.loaded.length, 10);
    for (final b in PlanetBody.loaded) {
      expect(b.bilingualFacts.length, greaterThanOrEqualTo(5), reason: b.id); // bộ song ngữ (NASA Science)
      for (final f in b.funFacts) {
        expect(f.vi, isNotEmpty); // bản NASA Space Place chỉ có tiếng Việt
      }
      expect(b.factsSourceUrl, startsWith('https://science.nasa.gov/'));
    }
  });

  test('chọn ngẫu nhiên không lặp liền', () {
    final mars = PlanetBody.bySound(5)!;
    final r = math.Random(1);
    PlanetFact? last;
    for (var k = 0; k < 30; k++) {
      final f = mars.randomFact(r, avoid: last)!;
      expect(f.vi == last?.vi, isFalse);
      last = f;
    }
  });

  group('khẩu lệnh sự thật thú vị', () {
    test('tiếng Việt', () {
      final c = parseWorld('sự thật thú vị về Sao Hỏa');
      expect(c.kind, WKind.planet);
      expect(c.aspect, 'fact');
      expect(c.target, 'Sao Hỏa');
      expect(parseWorld('kể một điều thú vị về Sao Thổ').aspect, 'fact');
      expect(parseWorld('một sự thật nữa').aspect, 'fact');
      expect(parseWorld('một sự thật nữa').target, '');
      expect(parseWorld('sự thật thú vị về các hành tinh').aspect, 'fact');
    });
    test('tiếng Anh', () {
      final c = parseWorldEn('fun fact about Jupiter');
      expect(c.kind, WKind.planet);
      expect(c.aspect, 'fact');
    });
    test('không lấn lệnh kể chuyện', () {
      expect(parseWorld('kể chuyện Sao Kim').aspect, isNull);
    });
  });

  group('trả lời bằng số liệu NASA', () {
    test('mặt trăng, năm, lực hút lấy từ dữ liệu', () {
      final moons = planetAnswer(6, 'Sao Mộc', 'Jupiter', 'Sao Mộc có mấy mặt trăng', en: false)!;
      expect(moons, contains('115'));
      final year = planetAnswer(5, 'Sao Hỏa', 'Mars', 'một năm trên Sao Hỏa dài bao lâu', en: false)!;
      expect(year, contains('687'));
      final g = planetAnswer(4, 'Mặt Trăng', 'the Moon', 'lên Mặt Trăng nặng bao nhiêu', en: false)!;
      expect(g, contains('0,17')); // gravity_vs_earth 0.165 → 0,17 (NASA)
      final dist = planetAnswer(9, 'Sao Hải Vương', 'Neptune', 'cách bao xa', en: false)!;
      expect(dist, contains('4,5 tỉ'));
    });
  });

  group('trò chơi lấy nội dung từ F2', () {
    test('đố vui: có câu sinh từ dữ liệu, đáp án đúng', () {
      for (var seed = 0; seed < 40; seed++) {
        final qs = nasaQuiz(math.Random(seed), PlanetBody.loaded, n: 3);
        expect(qs.length, 3);
        for (final q in qs) {
          expect(q.opts.length, 3);
          expect(q.opts.toSet().length, 3, reason: q.q);
          expect(q.answer, inInclusiveRange(0, 2));
          if (q.q.startsWith('Sự thật này')) {
            // tên đáp án đã bị giấu khỏi câu hỏi
            expect(q.q.contains(q.opts[q.answer]), isFalse, reason: q.q);
          }
        }
      }
      final full = buildQuiz(math.Random(3), n: 5);
      expect(full.length, 5);
    });
    test('câu đố Tôi là ai: giấu tên, gợi ý dễ cuối cùng', () {
      final rs = nasaRiddles(math.Random(2), PlanetBody.loaded, n: 3);
      expect(rs.length, 3);
      for (final r in rs) {
        final b = PlanetBody.bySound(r.sound)!;
        expect(r.clues.length, 3);
        for (final c in r.clues) {
          expect(c.toLowerCase().contains(b.nameVi.toLowerCase()), isFalse, reason: c);
        }
      }
      expect(buildRiddles(math.Random(5), n: 3).length, 3);
    });
  });
}
