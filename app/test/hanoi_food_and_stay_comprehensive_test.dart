// TEST TOÀN DIỆN DỮ LIỆU VÀ CÂU HỎI VỀ ĐỊA ĐIỂM ĂN UỐNG & LƯU TRÚ TẠI HÀ NỘI
import 'dart:io';

import 'package:earthsense/features/globe/hanoi_guide.dart';
import 'package:earthsense/features/globe/hanoi_places.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = HanoiPlacesDb.parse(File('assets/data/hanoi_places.json').readAsStringSync());
  PlaceQuery q(String s) => parsePlaceQuery(s, db)!;
  List<HnPlace> search(String s, {double? lat, double? lon, DateTime? now}) =>
      [for (final (p, _) in searchPlaces(db, q(s), lat: lat, lon: lon, now: now)) p];

  group('1. Kiểm tra bao phủ dữ liệu HanoiPlacesDb (assets/data/hanoi_places.json)', () {
    test('Số lượng địa điểm ăn uống và lưu trú phong phú, vượt trội', () {
      final foodPlaces = db.places.where((p) => p.isFood).toList();
      final stayPlaces = db.places.where((p) => p.isStay).toList();

      expect(foodPlaces.length, greaterThanOrEqualTo(45), reason: 'Phải có ít nhất 45 địa điểm ẩm thực');
      expect(stayPlaces.length, greaterThanOrEqualTo(35), reason: 'Phải có ít nhất 35 địa điểm lưu trú');
      expect(db.places.length, greaterThanOrEqualTo(80), reason: 'Tổng số địa điểm phải trên 80');
    });

    test('Toàn bộ 22 zones của Hà Nội đều có địa điểm trong cơ sở dữ liệu', () {
      final coveredZones = db.places.map((p) => p.zone).toSet();
      for (final z in hanoiZones) {
        expect(coveredZones.contains(z.id), isTrue, reason: 'Zone ${z.id} (${z.titleVi}) chưa có địa điểm nào trong db');
      }
    });

    test('Mọi địa điểm đều có toạ độ hợp lệ, địa chỉ sạch không lỗi cú pháp', () {
      for (final p in db.places) {
        expect(p.name, isNotEmpty);
        expect(p.address, isNotEmpty);
        expect(p.address, isNot(matches(RegExp(r'[,–;]|\d+\s*-\s*\d+'))), reason: 'Địa chỉ ${p.id} không được chứa dấu phẩy/gạch ngang');
        expect(p.lat, inInclusiveRange(20.53, 21.39), reason: '${p.id} toạ độ vĩ độ ngoài Hà Nội');
        expect(p.lon, inInclusiveRange(105.28, 106.03), reason: '${p.id} toạ độ kinh độ ngoài Hà Nội');

        if (p.isStay) {
          expect(p.priceBand, isNotNull, reason: 'Chỗ ở ${p.id} phải có priceBand');
          expect(db.bands.containsKey(p.priceBand), isTrue);
          expect(['hotel', 'resort', 'homestay', 'hostel'].contains(p.category), isTrue);
        }
      }
    });
  });

  group('2. Kiểm tra truy vấn hỏi về địa điểm LƯU TRÚ ở Hà Nội', () {
    test('Hỏi khách sạn 5 sao sang trọng ở các khu vực', () {
      // 5 sao Hoàn Kiếm / trung tâm
      final luxuryCentral = search('khách sạn 5 sao ở hoàn kiếm');
      expect(luxuryCentral.map((p) => p.id), contains('sofitel-metropole'));

      // 5 sao Tây Hồ (InterContinental, Sheraton, Pan Pacific)
      final tayHo5Stars = search('khách sạn 5 sao ở hồ tây');
      expect(tayHo5Stars.map((p) => p.id), containsAll(['intercontinental-westlake', 'sheraton-hanoi']));

      // 5 sao Cầu Giấy (Grand Plaza)
      final cauGiay5Stars = search('khách sạn 5 sao ở cầu giấy');
      expect(cauGiay5Stars.map((p) => p.id), contains('grand-plaza-hanoi'));

      // 5 sao Nam Từ Liêm (JW Marriott, Landmark72)
      final namTuLiem5Stars = search('khách sạn 5 sao ở mỹ đình');
      expect(namTuLiem5Stars.map((p) => p.id), containsAll(['jw-marriott-hanoi', 'intercontinental-landmark72']));
    });

    test('Hỏi khu nghỉ dưỡng / Resort ngoại thành', () {
      // Resort Ba Vì
      final baviResort = search('resort nghỉ dưỡng ở ba vì');
      expect(baviResort.map((p) => p.id), containsAll(['melia-ba-vi-mountain-retreat', 'tan-da-spa-resort-ba-vi']));

      // Resort Sóc Sơn
      final socsonResort = search('resort ở sóc sơn');
      expect(socsonResort.map((p) => p.id), contains('amaya-home-lodge-soc-son'));

      // Resort Sơn Tây
      final sontayResort = search('resort ở sơn tây');
      expect(sontayResort.map((p) => p.id), contains('tomodachi-retreat-lang-mit'));

      // Resort Thạch Thất (Asean Resort)
      final thachthatResort = search('resort ở thạch thất');
      expect(thachthatResort.map((p) => p.id), contains('asean-resort-shisa'));
    });

    test('Hỏi Homestay view đẹp & làng nghề', () {
      // Homestay Ocean Park Gia Lâm
      final oceanHomestay = search('homestay ở gia lâm');
      expect(oceanHomestay.map((p) => p.id), contains('homestay-ocean-park-gia-lam'));

      // Homestay Bát Tràng
      final battrangHomestay = search('homestay ở bát tràng');
      expect(battrangHomestay.map((p) => p.id), contains('gom-homestay-bat-trang'));

      // Homestay Sóc Sơn (U Lesa Nhà Bên Rừng)
      final ulesaHomestay = search('homestay nhà bên rừng sóc sơn');
      expect(ulesaHomestay.map((p) => p.id), contains('u-lesa-nha-ben-rung-soc-son'));

      // Homestay Royal City / Seasons Avenue
      final cityHomestay = search('homestay ở hà đông');
      expect(cityHomestay.map((p) => p.id), contains('seasons-avenue-homestay'));
    });

    test('Hỏi khách sạn giá rẻ / bình dân / gần sân bay', () {
      // Khách sạn gần sân bay Nội Bài
      final airportHotel = search('khách sạn gần sân bay nội bài');
      expect(airportHotel.map((p) => p.id), contains('dragon-airport-hotel-noi-bai'));

      // Chùa Hương
      final chuaHuongStay = search('nhà nghỉ khách sạn ở chùa hương');
      expect(chuaHuongStay.map((p) => p.id), contains('khach-san-cong-doan-chua-huong'));

      // Khách sạn giá rẻ
      final cheapHotels = search('khách sạn giá rẻ bình dân');
      expect(cheapHotels, isNotEmpty);
      for (final p in cheapHotels) {
        expect(p.priceBand, isIn(['budget', 'mid']));
      }
    });
  });

  group('3. Kiểm tra truy vấn hỏi về địa điểm ĂN UỐNG & ĐẶC SẢN ở Hà Nội', () {
    test('Hỏi các món ăn truyền thống nội thành', () {
      // Phở bò
      final phoList = search('quán phở bò ngon ở hoàn kiếm');
      expect(phoList.map((p) => p.id), containsAll(['pho-bat-dan', 'pho-ly-quoc-su']));

      // Bún chả
      final bunChaList = search('quán bún chả ở cầu giấy');
      expect(bunChaList.map((p) => p.id), contains('bun-cha-sinh-tu-cau-giay'));

      // Bánh tôm Hồ Tây & Bún ốc
      final tayHoFood = search('bánh tôm ở hồ tây');
      expect(tayHoFood.map((p) => p.id), contains('banh-tom-ho-tay'));

      final bunOcFood = search('bún ốc ở phủ tây hồ');
      expect(bunOcFood.map((p) => p.id), contains('bun-oc-phu-tay-ho'));

      // Phở cuốn
      final phoCuon = search('phở cuốn ở cầu giấy');
      expect(phoCuon.map((p) => p.id), contains('pho-cuon-huong-mai-to-hieu'));

      // Phở gà
      final phoGa = search('phở gà ở thanh xuân');
      expect(phoGa.map((p) => p.id), contains('pho-ga-ban-nguyen-trai'));
    });

    test('Hỏi các phố ẩm thực & ẩm thực sinh viên / quốc tế', () {
      // K-Town Hàn Quốc Đình Thôn
      final ktown = search('thịt nướng hàn quốc ở mỹ đình');
      expect(ktown.map((p) => p.id), contains('am-thuc-k-town-dinh-thon'));

      // Chợ Nghĩa Tân
      final nghiaTan = search('ăn vặt ở nghĩa tân');
      expect(nghiaTan.map((p) => p.id), contains('am-thuc-nghia-tan'));

      // Phố Ao Sen Hà Đông
      final aoSen = search('phố ẩm thực ao sen ở hà đông');
      expect(aoSen.map((p) => p.id), contains('pho-am-thuc-ao-sen'));

      // Phố Ngọc Lâm Long Biên
      final ngocLam = search('ăn vặt phố ngọc lâm long biên');
      expect(ngocLam.map((p) => p.id), contains('am-thuc-ngoc-lam'));
    });

    test('Hỏi đặc sản truyền thống ngoại thành Hà Nội', () {
      // Vịt cỏ Vân Đình
      final vitVanDinh = search('vịt cỏ vân đình ở ứng hòa');
      expect(vitVanDinh.map((p) => p.id), contains('vit-co-van-dinh-chinh-goc'));

      // Bò tơ Ba Vì
      final boBaVi = search('bò tơ ba vì');
      expect(boBaVi.map((p) => p.id), contains('bo-to-tay-hung-ba-vi'));

      // Gà đồi Sóc Sơn
      final gaSocSon = search('gà đồi nướng ở sóc sơn');
      expect(gaSocSon.map((p) => p.id), contains('ga-doi-nuong-soc-son'));

      // Thịt quay đòn gánh Đường Lâm
      final duongLam = search('đặc sản làng cổ đường lâm');
      expect(duongLam.map((p) => p.id), contains('am-thuc-lang-co-duong-lam'));

      // Giò chả Ước Lễ
      final gioUocLe = search('giò chả ước lễ ở thanh oai');
      expect(gioUocLe.map((p) => p.id), contains('gio-cha-uoc-le-thanh-oai'));

      // Cỗ truyền thống Bát Tràng (canh măng mực)
      final coBatTrang = search('cỗ truyền thống bát tràng');
      expect(coBatTrang.map((p) => p.id), contains('am-thuc-lang-gom-bat-trang'));

      // Bún Mạch Tràng Cổ Loa
      final bunMachTrang = search('bún mạch tràng ở cổ loa đông anh');
      expect(bunMachTrang.map((p) => p.id), contains('bun-mach-trang-co-loa'));

      // Chè lam Thạch Xá
      final cheLam = search('chè lam thạch xá ở thạch thất');
      expect(cheLam.map((p) => p.id), contains('che-lam-thach-xa'));

      // Nem Phùng
      final nemPhung = search('nem phùng ở đan phượng');
      expect(nemPhung.map((p) => p.id), contains('nem-phung-dan-phuong'));

      // Bánh chưng Tranh Khúc
      final banhChung = search('bánh chưng tranh khúc thanh trì');
      expect(banhChung.map((p) => p.id), contains('banh-chung-tranh-khuc'));
    });
  });

  // Phần quán ăn, chỗ ở đang tạm ẩn (kHanoiFoodStayEnabled = false): bỏ qua nhóm 4, hành vi khi ẩn kiểm ở hanoi_hidden_test.dart.
  // Bật lại cờ thì nhóm này tự chạy.
  const hiddenSkip = kHanoiFoodStayEnabled ? false : 'Phần quán ăn, chỗ ở đang tạm ẩn (kHanoiFoodStayEnabled = false)';

  group('4. Kiểm tra Cẩm nang địa phương tổng hợp (buildHanoiGuide)', skip: hiddenSkip, () {
    test('Câu hỏi về lưu trú (stay) trả về thông tin khách sạn/homestay và gợi ý ăn uống', () {
      for (final z in hanoiZones) {
        final guide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: 'chỗ nghỉ lưu trú khách sạn ở ${z.titleVi}');
        expect(guide, isNotNull);
        expect(guide!.$1, contains('Về lưu trú:'), reason: 'Khu vực ${z.titleVi} thiếu Về lưu trú');
        expect(guide.$1, contains('món ngon'), reason: 'Khu vực ${z.titleVi} phải gợi ý thêm món ngon');
      }
    });

    test('Câu hỏi về ăn uống (food) trả về món ngon và gợi ý lưu trú', () {
      final guide = buildHanoiGuide('Cầu Giấy', 'Cau Giay', raw: 'Cầu Giấy có món gì ngon');
      expect(guide, isNotNull);
      expect(guide!.$1, contains('Về ăn uống:'));
      expect(guide.$1, contains('Về chỗ nghỉ:'));
    });

    test('Câu hỏi tổng hợp (all) có đầy đủ 4 phần: tham quan, vui chơi, ăn uống, lưu trú', () {
      final guide = buildHanoiGuide('Tây Hồ', 'Tay Ho', raw: 'Tây Hồ có gì hay');
      expect(guide, isNotNull);
      expect(guide!.$1, contains('Về du lịch tham quan:'));
      expect(guide.$1, contains('Về vui chơi'));
      expect(guide.$1, contains('Về ăn uống:'));
      expect(guide.$1, contains('Về lưu trú:'));
    });
  });
}
