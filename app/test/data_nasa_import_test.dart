import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:earthsense/data/planet_bodies.dart';
import 'package:earthsense/features/history/history_records.dart';
import 'package:earthsense/live/hazard_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F1 danh mục thiên tai Việt Nam (data_nasa)', () {
    final cat = parseVnCatalog(jsonDecode(File('assets/data/vn_disasters_nasa.json').readAsStringSync()) as Map<String, dynamic>);

    test('nạp đủ, có vị trí, mức nặng 1..5', () {
      expect(cat.length, greaterThan(250));
      for (final r in cat) {
        expect(r.points, isNotEmpty);
        expect(r.severity, inInclusiveRange(1, 5));
      }
    });
    test('Huế: có thiên tai trong 2016–2021, không lấy sự kiện ở Cao Bằng', () {
      final ev = vnCatalogEvents(cat, 16.46, 107.59, DateTime(2016), DateTime(2022));
      expect(ev, isNotEmpty);
      expect(ev.any((e) => e.titleVi.contains('Cao Bằng') && !e.titleVi.contains('Huế') && !e.titleVi.contains('Quảng')), isFalse);
    });
    test('gộp trùng giữa các nguồn, giữ bản nặng nhất', () {
      final out = dedupeEvents([
        HazardEvent(HazardKind.storm, DateTime(2024, 9, 7), 5, 'Yagi (POWER)', 'Yagi'),
        HazardEvent(HazardKind.storm, DateTime(2024, 9, 6), 2, 'Yagi (EONET)', 'Yagi'),
        HazardEvent(HazardKind.flood, DateTime(2024, 9, 9), 3, 'Lũ', 'Flood'),
      ]);
      expect(out.length, 2);
      expect(out.first.titleVi, 'Yagi (POWER)');
    });
  });

  group('F2 sự thật NASA Space Place', () {
    late List<PlanetBody> bodies;
    setUpAll(() {
      final j = jsonDecode(File('assets/data/planets_nasa.json').readAsStringSync()) as Map<String, dynamic>;
      bodies = [for (final b in j['bodies'] as List) PlanetBody.fromJson(b as Map<String, dynamic>)];
    });
    test('đã thêm sự thật tiếng Việt, không còn đơn vị Mỹ', () {
      final all = [for (final b in bodies) ...b.funFacts];
      expect(all.where((f) => f.en.isEmpty).length, greaterThan(50));
      for (final f in all) {
        expect(RegExp(r'độ F|\bdặm\b').hasMatch(f.vi), isFalse, reason: f.vi);
      }
    });
    test('chế độ tiếng Anh chỉ chọn sự thật có bản tiếng Anh', () {
      final mars = bodies.firstWhere((b) => b.id == 'mars');
      for (var k = 0; k < 30; k++) {
        expect(mars.randomFact(math.Random(k), en: true)!.en, isNotEmpty);
      }
    });
  });
}
