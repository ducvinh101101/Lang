import 'dart:io';
import 'dart:math' as math;

import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/space/planet_games.dart' show matchOption;
import 'package:earthsense/live/nasa_sounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<NasaSound> all;
  setUpAll(() {
    all = NasaSound.parseCatalog(File('assets/sounds/nasa/catalog.json').readAsStringSync());
    NasaSound.loaded = all;
  });
  tearDownAll(() => NasaSound.loaded = const []);

  test('10 bản ghi, file mp3 có thật, thời lượng hợp lý, có ghi công', () {
    expect(all.length, 10);
    for (final s in all) {
      final f = File(s.assetPath);
      expect(f.existsSync(), isTrue, reason: s.file);
      final b = f.readAsBytesSync();
      // ID3 hoặc khung MPEG
      expect(String.fromCharCodes(b.take(3)) == 'ID3' || (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0), isTrue, reason: s.file);
      expect(s.durationS, inInclusiveRange(1, 60), reason: s.file);
      // bitrate suy ra 8..320 kbps → thời lượng đo đúng
      final kbps = b.length * 8 / s.durationS / 1000;
      expect(kbps, inInclusiveRange(8, 320), reason: '${s.file}: $kbps kbps');
      expect(s.introVi, isNotEmpty);
      expect(s.introEn, isNotEmpty);
      expect(s.credit, startsWith('NASA'));
    }
  });

  test('pubspec khai báo thư mục bản ghi', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/sounds/nasa/'));
  });

  group('khẩu lệnh', () {
    test('tiếng Việt: một bản ghi cụ thể', () {
      expect(parseWorld('nghe tiếng Sputnik').kind, WKind.nasaSound);
      expect(parseWorld('nghe tiếng Sputnik').target, 'sputnik_beep');
      expect(parseWorld('cho tôi nghe âm thanh Apollo 11').target, 'apollo11_step');
      expect(parseWorld('phát tiếng sấm sét Sao Mộc').target, 'jupiter_lightning');
      expect(parseWorld('nghe âm thanh sóng vô tuyến Sao Thổ').target, 'saturn_radio');
    });
    test('tiếng Việt: danh sách', () {
      final c = parseWorld('âm thanh thật của NASA');
      expect(c.kind, WKind.nasaSound);
      expect(c.target, '');
    });
    test('tiếng Anh', () {
      expect(parseWorldEn('play the Sputnik sound').target, 'sputnik_beep');
      expect(parseWorldEn('NASA sounds').kind, WKind.nasaSound);
    });
    test('không cướp lệnh cũ', () {
      // câu hỏi kiến thức (không có ý muốn nghe) → không phát
      expect(parseWorld('tàu Voyager là gì').kind, isNot(WKind.nasaSound));
      // tiếng tổng hợp của hành tinh vẫn như cũ
      final p = parseWorld('tiếng Sao Mộc');
      expect(p.kind, WKind.planet);
      expect(p.aspect, 'sound');
      expect(parseWorld('kể chuyện Mặt Trăng').kind, WKind.planet);
    });
  });

  group('trò Đố âm thanh NASA', () {
    test('mỗi bản ghi có câu hỏi 2 lựa chọn song ngữ', () {
      for (final x in all) {
        final q = x.quiz!;
        expect(q.optsVi.length, 2);
        expect(q.optsEn.length, 2);
        expect(q.qVi, isNotEmpty);
      }
    });
    test('xáo đáp án vẫn giữ đúng đáp án đúng', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final x in all) {
          final q = x.quiz!, s = q.shuffled(math.Random(seed));
          expect(s.optsVi[s.answer], q.optsVi[q.answer]);
          expect(s.optsEn[s.answer], q.optsEn[q.answer]);
        }
      }
    });
    test('một lượt 3 bản ghi không trùng', () {
      final r = nasaGameRound(math.Random(4), all);
      expect(r.length, 3);
      expect(r.map((e) => e.id).toSet().length, 3);
    });
    test('trả lời bằng số hoặc nói đáp án', () {
      final q = all.firstWhere((e) => e.id == 'enceladus_sound').quiz!;
      expect(matchOption('một', q.optsVi), 0);
      expect(matchOption('hai', q.optsVi), 1);
      expect(matchOption('Sao Thổ', q.optsVi), q.optsVi.indexOf('Sao Thổ'));
    });
    test('khẩu lệnh chơi', () {
      final a = parseWorld('đố âm thanh NASA');
      expect(a.kind, WKind.nasaSound);
      expect(a.aspect, 'game');
      expect(a.target, '');
      final b = parseWorld('chơi trò Enceladus');
      expect(b.target, 'enceladus_sound');
      expect(b.aspect, 'game');
      expect(parseWorld('nghe tiếng Sputnik').aspect, isNull);
      expect(parseWorldEn('NASA sound quiz').aspect, 'game');
    });
  });
}
