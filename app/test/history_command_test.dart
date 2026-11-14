import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:earthsense/features/history/history_command.dart';
import 'package:earthsense/features/history/history_records.dart';
import 'package:earthsense/live/hazard_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F1 khẩu lệnh lịch sử thời tiết / thiên tai', () {
    WCmd p(String s) => parseWorld(s);

    test('vị trí + N năm qua', () {
      final c = p('lịch sử thời tiết Hà Nội 3 năm qua');
      expect(c.kind, WKind.weatherHistory);
      expect(c.target, 'Hà Nội');
      expect(c.aspect, 'weather');
      expect(c.spanMonths, 36);
    });
    test('thiên tai từ năm đến năm', () {
      final c = p('cho tôi nghe lịch sử thiên tai ở Quảng Ninh từ 2015 đến 2020');
      expect(c.kind, WKind.weatherHistory);
      expect(c.target, 'Quảng Ninh');
      expect(c.aspect, 'disaster');
      expect(c.from, DateTime(2015, 1));
      expect(c.to, DateTime(2020, 12));
    });
    test('cả hai, một năm', () {
      final c = p('lịch sử thời tiết và thiên tai Huế năm 2020');
      expect(c.aspect, 'both');
      expect(c.target, 'Huế');
      expect(c.from, DateTime(2020, 1));
      expect(c.to, DateTime(2020, 12));
    });
    test('trong vòng N tháng, số bằng chữ, thập niên', () {
      expect(p('nhìn lại thời tiết Đà Nẵng trong vòng 6 tháng').spanMonths, 6);
      expect(p('nhìn lại thời tiết Đà Nẵng trong vòng 6 tháng').target, 'Đà Nẵng');
      final c = p('lịch sử thời tiết Nghệ An hai mươi năm qua');
      expect(c.target, 'Nghệ An');
      expect(c.spanMonths, 240);
      final d = p('lịch sử thời tiết Quảng Nam thập niên 90');
      expect(d.target, 'Quảng Nam');
      expect(d.from, DateTime(1990, 1));
      expect(d.to, DateTime(1999, 12));
    });
    test('thiên tai + khoảng đã qua (không có "lịch sử")', () {
      final c = p('thiên tai ở Huế 10 năm qua');
      expect(c.kind, WKind.weatherHistory);
      expect(c.aspect, 'disaster');
      expect(c.spanMonths, 120);
    });
    test('ở đây → không có tên nơi', () {
      expect(p('lịch sử thời tiết ở đây').target, '');
    });
    test('không lấn các lệnh cũ', () {
      expect(p('thời tiết năm 2020').kind, WKind.climate);
      expect(p('Hà Nội xưa và nay').kind, WKind.history);
      expect(p('thời tiết Hà Nội ngày mai').kind, isNot(WKind.weatherHistory));
      expect(p('có bão không').kind, WKind.disasters);
      expect(p('thời tiết phường Điện Biên Phủ').kind, isNot(WKind.weatherHistory));
    });
    test('Điện Biên (tên tỉnh) ≠ diễn biến', () {
      expect(p('lịch sử thời tiết Điện Biên 3 năm qua').target, 'Điện Biên');
      final c = p('diễn biến thời tiết Hà Nội 2 năm qua');
      expect(c.kind, WKind.weatherHistory);
      expect(c.target, 'Hà Nội');
    });
    test('tiếng Anh', () {
      final e = parseWorldEn('weather history of Hanoi over the last 3 years');
      expect(e.kind, WKind.weatherHistory);
      expect(e.target, 'hanoi');
      expect(e.spanMonths, 36);
    });
    test('numVi', () {
      expect(numVi('ba'), 3);
      expect(numVi('muoi lam'), 15);
      expect(numVi('hai muoi'), 20);
      expect(numVi('12'), 12);
    });
  });

  group('F1 bản ghi', () {
    // dữ liệu giả: 2000–2005, tháng 6 nóng, tháng 9 mưa nhiều
    final tm = <int, List<double>>{
      for (var y = 2000; y <= 2005; y++) y: [for (var m = 0; m < 12; m++) 17.0 + 12 * (m < 6 ? m / 5 : (11 - m) / 5)]
    };
    final rm = <int, List<double>>{
      for (var y = 2000; y <= 2005; y++) y: [for (var m = 0; m < 12; m++) m == 8 ? 300.0 : 60.0]
    };
    rm[2004]![8] = 900; // tháng 9/2004 mưa gấp 3 lần
    tm[2005]![5] = 33; // tháng 6/2005 nóng bất thường

    test('≤ 3 năm → theo tháng; > 3 năm → theo năm', () {
      final r1 = resolveRange(spanMonths: 36, dataY0: 2000, dataY1: 2005);
      expect(r1.monthly, isTrue);
      expect((r1.y0, r1.m0, r1.y1, r1.m1), (2003, 1, 2005, 12));
      final recs = buildRecords(tempMonth: tm, rainMonth: rm, range: r1);
      expect(recs.length, 36);
      expect(recs.first.month, 1);
      final r2 = resolveRange(spanMonths: 48, dataY0: 2000, dataY1: 2005);
      expect(r2.monthly, isFalse);
      final y = buildRecords(tempMonth: tm, rainMonth: rm, range: r2);
      expect(y.length, 4);
      expect(y.first.month, isNull);
      expect(y.first.year, 2002);
    });
    test('khoảng ngoài dữ liệu được chốt lại', () {
      final r = resolveRange(from: DateTime(1970, 1), to: DateTime(2030, 12), dataY0: 2000, dataY1: 2005);
      expect((r.y0, r.y1), (2000, 2005));
    });
    test('thiên tai suy ra + sự kiện ghi nhận, xếp từ nhẹ đến nặng', () {
      final range = resolveRange(from: DateTime(2004, 9), to: DateTime(2004, 9), dataY0: 2000, dataY1: 2005);
      final recs = buildRecords(tempMonth: tm, rainMonth: rm, range: range, events: [
        HazardEvent(HazardKind.earthquake, DateTime(2004, 9, 3), 4, 'Động đất 6,1 độ', 'M6.1 quake'),
        HazardEvent(HazardKind.wildfire, DateTime(2004, 9, 20), 2.2, 'Cháy rừng', 'Wildfire'),
        HazardEvent(HazardKind.storm, DateTime(2004, 10, 2), 5, 'Bão ngoài kỳ', 'Out of range'),
      ]);
      expect(recs.length, 1);
      final hs = recs.single.hazards;
      expect(hs.map((h) => h.kind), contains(HazardKind.heavyRain));
      expect(hs.any((h) => h.vi.contains('ngoài kỳ')), isFalse);
      for (var k = 1; k < hs.length; k++) {
        expect(hs[k].severity >= hs[k - 1].severity, isTrue);
      }
      expect(hs.last.kind, HazardKind.earthquake);
      expect(recs.single.mix.dominant, 'rain');
      expect(recs.single.explainVi(), contains('Tháng 9 năm 2004'));
    });
    test('nắng nóng bất thường → chủ đạo nóng', () {
      final range = resolveRange(from: DateTime(2005, 6), to: DateTime(2005, 6), dataY0: 2000, dataY1: 2005);
      final r = buildRecords(tempMonth: tm, rainMonth: rm, range: range).single;
      expect(r.mix.dominant, 'heat');
      expect(r.hazards.map((h) => h.kind), contains(HazardKind.heat));
    });
    test('bản ghi năm gộp thiên tai theo loại', () {
      final range = resolveRange(from: DateTime(2004, 1), to: DateTime(2005, 12), dataY0: 2000, dataY1: 2005);
      expect(range.monthly, isTrue); // đúng 24 tháng
      final yr = buildRecords(
          tempMonth: tm, rainMonth: rm, range: resolveRange(from: DateTime(2000, 1), to: DateTime(2005, 12), dataY0: 2000, dataY1: 2005));
      final y2004 = yr.firstWhere((r) => r.year == 2004);
      expect(y2004.hazards.where((h) => h.kind == HazardKind.heavyRain).length, 1);
      expect(y2004.explainVi(), contains('Năm 2004'));
    });
  });

  group('F1 dữ liệu thiên tai trực tuyến', () {
    test('EONET lưu trữ: lấy điểm gần nhất, sức gió → mức nặng', () {
      final j = {
        'events': [
          {
            'title': 'Typhoon Yagi',
            'categories': [
              {'id': 'severeStorms'}
            ],
            'geometry': [
              {'type': 'Point', 'coordinates': [120.0, 15.0], 'date': '2024-09-03T00:00:00Z', 'magnitudeValue': 70, 'magnitudeUnit': 'kts'},
              {'type': 'Point', 'coordinates': [106.5, 21.0], 'date': '2024-09-07T06:00:00Z', 'magnitudeValue': 120, 'magnitudeUnit': 'kts'},
            ]
          }
        ]
      };
      final ev = parseEonetHistory(j, 21.03, 105.85);
      expect(ev.single.kind, HazardKind.storm);
      expect(ev.single.date.day, 7);
      expect(ev.single.severity, 5);
    });
    test('USGS động đất', () {
      final j = {
        'features': [
          {
            'properties': {'mag': 5.3, 'time': DateTime.utc(2020, 3, 1).millisecondsSinceEpoch, 'place': 'Lao PDR'},
            'geometry': {'coordinates': [103.0, 21.5, 10]}
          }
        ]
      };
      final ev = parseUsgs(j, 21.0, 104.0);
      expect(ev.single.kind, HazardKind.earthquake);
      expect(ev.single.severity, 3);
    });
  });
}
