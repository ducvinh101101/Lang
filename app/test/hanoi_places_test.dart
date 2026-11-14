// Hỏi chỗ ĂN / chỗ Ở ở Hà Nội: hiểu câu → lọc dữ liệu assets/data/hanoi_places.json → câu trả lời.
import 'dart:io';

import 'package:earthsense/features/globe/hanoi_places.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = HanoiPlacesDb.parse(File('assets/data/hanoi_places.json').readAsStringSync());
  PlaceQuery q(String s) => parsePlaceQuery(s, db)!;
  List<String> ids(String s, {double? lat, double? lon, DateTime? now}) =>
      [for (final (p, _) in searchPlaces(db, q(s), lat: lat, lon: lon, now: now)) p.id];

  group('dữ liệu hợp lệ', () {
    test('mỗi nơi có tên, địa chỉ, toạ độ trong Hà Nội, mã không trùng', () {
      final seen = <String>{};
      for (final p in db.places) {
        expect(seen.add(p.id), isTrue, reason: 'trùng ${p.id}');
        expect(p.name, isNotEmpty);
        expect(p.address, isNotEmpty);
        expect(p.lat, inInclusiveRange(20.53, 21.39), reason: p.id);
        expect(p.lon, inInclusiveRange(105.28, 106.03), reason: p.id);
        expect(db.categories.containsKey(p.category), isTrue, reason: '${p.id}: ${p.category}');
        if (p.isStay) expect(db.bands.containsKey(p.priceBand), isTrue, reason: p.id);
        // MỘT địa chỉ ngắn để đọc dễ nghe: không ghép nhiều số / nhiều phố
        expect(p.address, isNot(matches(RegExp(r'[,–;]|\d+\s*-\s*\d+'))), reason: '${p.id}: ${p.address}');
      }
      expect(db.places.where((p) => p.isFood).length, greaterThanOrEqualTo(25));
      expect(db.places.where((p) => p.isStay).length, greaterThanOrEqualTo(15));
    });
  });

  group('hiểu câu hỏi', () {
    test('không phải hỏi ăn / ở → null (để phần khác trả lời)', () {
      for (final s in ['thời tiết hà nội', 'quanh phố cổ có gì', 'kể chuyện sao hỏa', 'quận hoàn kiếm có gì chơi', 'chợ ở đâu']) {
        expect(parsePlaceQuery(s, db), isNull, reason: s);
      }
    });
    test('"phố" (phố cổ) không bị hiểu là "phở"', () {
      expect(q('quán ăn ngon ở phố cổ').want, isNot(contains('pho')));
      expect(q('quán phở ngon ở phố cổ').want, contains('pho'));
    });
    test('món + khu vực', () {
      final x = q('quán bún chả nào ngon ở hoàn kiếm');
      expect(x.type, 'food');
      expect(x.want, contains('bun cha'));
      expect(x.zoneId, 'hoan_kiem');
    });
    test('chỗ ở: sao, rẻ, hostel, giá tối đa', () {
      expect(q('khách sạn 5 sao ở hà nội').stars, 5);
      expect(q('khách sạn năm sao gần hồ tây').zoneId, 'tay_ho');
      expect(q('chỗ ở giá rẻ cho dân ba lô').stayKind, 'hostel');
      expect(q('nhà nghỉ dưới 500 nghìn').maxPrice, 500000);
      expect(q('khách sạn dưới 1,5 triệu').maxPrice, 1500000);
    });
    test('gần đây dùng vị trí; nhắc tên khu thì dùng khu', () {
      expect(q('quán cà phê gần đây').near, isTrue);
      expect(q('xung quanh hồ tây có quán ăn nào ngon').near, isFalse);
    });
    test('hỏi riêng một nơi', () {
      expect(q('phở thìn ở đâu').named?.id, 'pho-thin-lo-duc');
      expect(q('khách sạn metropole mấy sao').named?.id, 'sofitel-metropole');
    });
  });

  group('lọc đúng', () {
    test('phở ở phố cổ → chỉ quán phở khu Hoàn Kiếm', () {
      final r = ids('quán phở ngon ở phố cổ');
      expect(r, containsAll(['pho-bat-dan', 'pho-ly-quoc-su']));
      expect(r, isNot(contains('pho-thin-lo-duc'))); // Hai Bà Trưng
      expect(r, isNot(contains('bun-cha-dac-kim')));
    });
    test('cà phê gần Hồ Gươm (đứng ở Hồ Gươm) → gần trước', () {
      final r = ids('quán cà phê gần đây', lat: 21.0288, lon: 105.8525);
      expect(r.first, 'ca-phe-dinh');
    });
    test('ăn đêm → chỉ nơi mở khuya', () {
      final r = ids('ăn đêm ở đâu');
      expect(r, containsAll(['pho-ta-hien', 'xoi-yen']));
      expect(r, isNot(contains('pho-bat-dan')));
    });
    test('đang mở lúc 9 giờ tối → không có quán chỉ bán sáng', () {
      final r = ids('quán phở nào đang mở', now: DateTime(2026, 11, 7, 21, 0));
      expect(r, contains('pho-ly-quoc-su'));
      expect(r, isNot(contains('pho-bat-dan')));
    });
    test('khách sạn 4 sao, hostel, giá rẻ, sang trọng', () {
      expect(ids('khách sạn 4 sao ở hà nội'), containsAll(['la-siesta-hang-be', 'silk-path-hanoi', 'mercure-la-gare', 'peridot-grand']));
      expect(ids('hostel cho dân ba lô'), ['hanoi-backpackers', 'little-charm-hostel']);
      expect(ids('khách sạn giá rẻ'), containsAll(['hanoi-backpackers', 'little-charm-hostel']));
      expect(ids('khách sạn sang trọng ở tây hồ'), containsAll(['intercontinental-westlake', 'sheraton-hanoi']));
    });
    test('khu không có quán trong dữ liệu → rỗng (app nhường cẩm nang theo khu)', () {
      expect(ids('ba vì ăn bún chả'), isEmpty);
    });
  });

  group('câu trả lời', () {
    test('danh sách: đếm, 3 nơi đầu, gợi ý "còn nữa"', () {
      final x = q('quán phở ngon ở phố cổ');
      final (vi, _) = placesAnswer(db, x, searchPlaces(db, x));
      expect(vi, startsWith('Mình có 3 quán phở ở khu vực Hoàn Kiếm'));
      expect(vi, contains('Một: Phở Bát Đàn'));
      expect(vi, contains('ở 49 Bát Đàn'));
      expect(vi, contains('khoảng 50 đến 70 nghìn'));
      expect(vi, contains('chi tiết số 1'));
    });
    test('chi tiết một nơi: địa chỉ, giá, giờ mở cửa', () {
      final x = q('phở thìn ở đâu');
      final (vi, _) = placesAnswer(db, x, searchPlaces(db, x));
      expect(vi, contains('13 Lò Đúc'));
      expect(vi, contains('khoảng 60 đến 80 nghìn'));
      expect(vi, contains('mở cửa từ 6 giờ đến 20 giờ 30'));
    });
    test('chưa biết giờ mở cửa → nói rõ là chưa có', () {
      final p = db.places.firstWhere((p) => p.id == 'pho-suong');
      expect(placeDetail(db, p).$1, contains('chưa có giờ mở cửa'));
    });
    test('không có kết quả → nói thật là dữ liệu chưa có', () {
      final x = q('quán bún chả ở sóc sơn');
      final (vi, _) = placesAnswer(db, x, searchPlaces(db, x));
      expect(vi, startsWith('Trong dữ liệu của mình chưa có'));
    });
    test('khoảng cách khi có vị trí', () {
      final x = q('quán cà phê gần đây');
      final (vi, _) = placesAnswer(db, x, searchPlaces(db, x, lat: 21.0288, lon: 105.8525), hasLoc: true);
      expect(vi, contains('gần bạn'));
      expect(vi, contains('cách khoảng'));
    });
  });

  group('hỏi tiếp danh sách', () {
    test('còn nữa / chi tiết số N', () {
      expect(placeFollowUp('còn nữa'), ('more', 0));
      expect(placeFollowUp('còn quán nào nữa không'), ('more', 0));
      expect(placeFollowUp('chi tiết số 2'), ('detail', 1));
      expect(placeFollowUp('quán số ba ở đâu'), ('detail', 2));
      expect(placeFollowUp('thời tiết thứ hai'), isNull);
      expect(placeFollowUp('kể chuyện sao hỏa'), isNull);
    });
  });
}
