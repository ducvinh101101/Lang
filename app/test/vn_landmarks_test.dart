import 'package:earthsense/features/globe/vn_landmarks.dart';
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/globe/world_commands_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tìm địa danh, vùng, tỉnh', () {
    expect(landmarkIn('kể về vịnh hạ long')!.name, 'Vịnh Hạ Long');
    expect(landmarkIn('Sapa ở đâu')!.name, 'Sa Pa');
    expect(landmarkIn('phố cổ Hội An có gì')!.name, 'Phố cổ Hội An');
    expect(regionIn('miền trung có gì đẹp'), 'trung');
    expect(regionIn('Tây Nguyên có địa danh gì'), 'taynguyen');
    expect(landmarksOfProvinceIn('ở Quảng Ninh có gì nổi tiếng').map((l) => l.name), contains('Vịnh Hạ Long'));
    expect(landmarksOfProvinceIn('thành phố Hồ Chí Minh có gì').length, greaterThan(3));
    for (final r in regionNamesVi.keys) {
      expect(landmarksOfRegion(r), isNotEmpty);
    }
    final names = <String>{};
    for (final l in vnLandmarks) {
      expect(names.add(l.name), isTrue, reason: 'trùng ${l.name}');
      expect(l.lat, inInclusiveRange(8, 24));
      expect(l.lon, inInclusiveRange(102, 110));
    }
  });

  test('lệnh địa danh', () {
    var c = parseWorld('kể về Vịnh Hạ Long');
    expect(c.kind, WKind.landmark);
    expect(c.target, 'Vịnh Hạ Long');
    expect(parseWorld('giới thiệu phố cổ Hội An').kind, WKind.landmark);
    expect(parseWorld('Fansipan ở đâu').kind, WKind.landmark);
    expect(parseWorld('miền Trung có địa danh gì nổi tiếng').kind, WKind.landmarks);
    expect(parseWorld('Quảng Ninh có gì nổi tiếng').kind, WKind.landmarks);
    expect(parseWorld('kể về đây').kind, WKind.landmark);
    c = parseWorld('thời tiết Sa Pa');
    expect(c.kind, WKind.weather);
    expect(parseWorld('quanh Hồ Hoàn Kiếm có gì').kind, WKind.around);
    expect(parseWorld('khám phá Hồ Tây').kind, WKind.explore);
    expect(parseWorldEn('tell me about Ha Long Bay').kind, WKind.landmark);
    expect(parseWorldEn('famous places in central vietnam').kind, WKind.landmarks);
  });

  test('câu kể tên', () {
    final t = landmarkListText('Miền Bắc', 'Northern Viet Nam', landmarksOfRegion('bac')).$1;
    expect(t, startsWith('Miền Bắc có các địa danh nổi bật: Vịnh Hạ Long'));
    expect(landmarkOverviewText().$1, contains('Tây Nguyên có'));
  });
}
