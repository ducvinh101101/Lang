import 'dart:convert';
import 'dart:io';

import 'package:earthsense/data/nasa_normalized_data.dart';
import 'package:earthsense/features/history/history_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final j = jsonDecode(File('assets/data/climate_34_provinces.json').readAsStringSync()) as Map<String, dynamic>;
  final all = parseClimate34(j);

  test('đủ 34 tỉnh/thành, 1981–2025, đủ 12 tháng mỗi năm', () {
    expect(all.length, 34);
    for (final c in all) {
      expect(c.y0, 1981);
      expect(c.y1, 2025);
      expect(c.tempYear.length, 45);
      for (final m in c.tempMonth.values) {
        expect(m.length, 12);
      }
    }
  });

  test('số liệu hợp lý: Hà Nội tháng 1 lạnh hơn tháng 7, mưa mùa hè nhiều hơn mùa đông', () {
    final hn = all.firstWhere((c) => (c.lat - 21.03).abs() < 0.01 && (c.lon - 105.85).abs() < 0.01);
    expect(hn.tempMonth[2020]![0], lessThan(hn.tempMonth[2020]![6]));
    expect(hn.rainMonth[2020]![7], greaterThan(hn.rainMonth[2020]![0]));
    // năm = trung bình 12 tháng
    final t = hn.tempMonth[2020]!;
    expect(hn.tempYear[2020 - 1981], closeTo(t.reduce((a, b) => a + b) / 12, 1e-9));
  });

  test('dựng được bản ghi lịch sử cho một tỉnh mới (Điện Biên)', () {
    final db = all.firstWhere((c) => c.lat > 21 && c.lon < 103.5);
    final range = resolveRange(spanMonths: 36, dataY0: db.y0, dataY1: db.y1);
    final recs = buildRecords(tempMonth: db.tempMonth, rainMonth: db.rainMonth, range: range);
    expect(recs.length, 36);
    expect(recs.every((r) => !r.temp.isNaN && !r.rain.isNaN), isTrue);
  });

  test('kho NASA của app nạp thêm các tỉnh mới (Điện Biên có số liệu không cần mạng)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = await NasaNormalizedRepo.load();
    final db = all.firstWhere((c) => c.lat > 21 && c.lon < 103.5);
    final hit = repo.findClimateNear(db.lat, db.lon);
    expect(hit, isNotNull);
    expect(hit!.y1, 2025);
    // Hà Nội vẫn dùng bộ 29 điểm cũ (có thêm độ ẩm), không bị bộ mới thay
    expect(repo.findClimateNear(21.03, 105.85)!.humYear, isNotEmpty);
  });
}
