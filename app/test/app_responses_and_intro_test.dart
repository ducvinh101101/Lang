import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../lib/features/globe/hanoi_guide.dart';
import '../lib/features/globe/terrain_data.dart';
import '../lib/features/globe/vn_landmarks.dart';
import '../lib/features/globe/world_commands.dart';
import '../lib/features/space/planet_facts.dart';
import '../lib/features/space/planets.dart';
import '../lib/live/live_weather.dart';
import '../lib/live/vn_gazetteer.dart';
import '../lib/live/weather_talk.dart';

void main() {
  late VnGazetteer gaz;

  setUpAll(() async {
    final f = File('assets/data/vn_dvhc.json');
    final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    gaz = VnGazetteer.fromJson(raw);
    vnPlaceNameKnown = gaz.knows;
    vnPlaceNameKnownExact = gaz.knowsExact;
  });

  group('1. Giới thiệu tổng quan & từng phần (helpFor)', () {
    test('Giới thiệu tổng quan (target rỗng) đầy đủ 3 phần và hướng dẫn dùng giọng nói', () {
      final (vi, en) = helpFor('');
      expect(vi, contains('Mình có ba phần'));
      expect(vi, contains('thời tiết khắp thế giới'));
      expect(vi, contains('địa lý và địa điểm quanh bạn'));
      expect(vi, contains('khám phá vũ trụ'));
      expect(vi, contains('Lắng ơi'));
      expect(en, contains('Three parts'));
    });

    test('Giới thiệu phần Thời tiết (weather)', () {
      final (vi, en) = helpFor('weather');
      expect(vi, contains('Phần thời tiết thế giới'));
      expect(vi, contains('dự báo 5 ngày'));
      expect(vi, contains('bản tin'));
      expect(vi, contains('khí hậu Hà Nội'));
      expect(en, contains('Weather around the world'));
    });

    test('Giới thiệu phần Địa lý & khám phá quanh bạn (geo)', () {
      final (vi, en) = helpFor('geo');
      expect(vi, contains('Phần địa lý và khám phá quanh bạn'));
      expect(vi, contains('hỏi bất kỳ xã, phường nào ở Hà Nội để nghe gợi ý địa điểm tham quan, vui chơi và ăn uống đặc sản'));
      expect(vi, contains('phường Hoàn Kiếm có gì chơi'));
      expect(vi, contains('phường Tây Hồ ăn gì ngon'));
      expect(vi, contains('xã Bát Tràng có địa điểm du lịch gì'));
      expect(en, contains('Around you'));
    });

    test('Giới thiệu phần Khám phá vũ trụ (space)', () {
      final (vi, en) = helpFor('space');
      expect(vi, contains('Phần khám phá vũ trụ'));
      expect(vi, contains('mười tập truyện'));
      expect(vi, contains('ảnh thiên văn hôm nay'));
      expect(en, contains('Space. There are ten stories'));
    });

    test('Các câu hỏi giới thiệu phần đều phân giải đúng WKind.help và target', () {
      expect(parseWorld('bạn làm được gì').kind, WKind.help);
      expect(parseWorld('bạn làm được gì').target, '');
      expect(parseWorld('giới thiệu phần thời tiết').kind, WKind.help);
      expect(parseWorld('giới thiệu phần thời tiết').target, 'weather');
      expect(parseWorld('giới thiệu phần địa lý').kind, WKind.help);
      expect(parseWorld('giới thiệu phần địa lý').target, 'geo');
      expect(parseWorld('địa lý quanh bạn').kind, WKind.help);
      expect(parseWorld('địa lý quanh bạn').target, 'geo');
      expect(parseWorld('địa điểm quanh bạn').kind, WKind.help);
      expect(parseWorld('địa điểm quanh bạn').target, 'geo');
      expect(parseWorld('giới thiệu phần vũ trụ').kind, WKind.help);
      expect(parseWorld('giới thiệu phần vũ trụ').target, 'space');
    });

    test('"phần thứ hai", "phần thứ ba" không bị hiểu nhầm thành thứ Hai / thứ Ba trong tuần', () {
      expect(weekdayOffsetVi('phan thu hai'), isNull);
      expect(weekdayOffsetVi('phan thu ba'), isNull);
      expect(weekdayOffsetVi('muc thu hai'), isNull);
      expect(weekdayOffsetVi('muc thu ba'), isNull);
      // Nhưng hỏi thời tiết thứ hai tuần tới vẫn trả về ngày trong tuần
      expect(weekdayOffsetVi('thoi tiet thu hai tuan sau'), isNotNull);
    });
  });

  group('2. Giới thiệu & gợi ý địa điểm ăn uống, vui chơi, du lịch tại Hà Nội (hanoi_guide)', () {
    test('Tất cả 22 cụm khu vực Hà Nội (hanoiZones) có đủ ăn uống, vui chơi, tham quan và phản hồi tiếng Việt / Anh', () {
      expect(hanoiZones.length, 22);
      for (final z in hanoiZones) {
        expect(z.titleVi.trim(), isNotEmpty, reason: '${z.id} thiếu titleVi');
        expect(z.tourVi.trim(), isNotEmpty, reason: '${z.titleVi} thiếu tourVi');
        expect(z.funVi.trim(), isNotEmpty, reason: '${z.titleVi} thiếu funVi');
        expect(z.foodVi.trim(), isNotEmpty, reason: '${z.titleVi} thiếu foodVi');
        expect(z.stayVi.trim(), isNotEmpty, reason: '${z.titleVi} thiếu stayVi');
        expect(z.tourEn.trim(), isNotEmpty, reason: '${z.titleVi} thiếu tourEn');
        expect(z.funEn.trim(), isNotEmpty, reason: '${z.titleVi} thiếu funEn');
        expect(z.foodEn.trim(), isNotEmpty, reason: '${z.titleVi} thiếu foodEn');
        expect(z.stayEn.trim(), isNotEmpty, reason: '${z.titleVi} thiếu stayEn');

        final allGuide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: 'ở ${z.titleVi} có gì');
        expect(allGuide, isNotNull);
        expect(allGuide!.$1, contains('Về du lịch'));
        expect(allGuide.$1, contains('Về vui chơi'));
        // phần quán ăn, chỗ ở có thể đang ẩn (kHanoiFoodStayEnabled) → khi ẩn: không đọc ăn uống, lưu trú
        final fs = kHanoiFoodStayEnabled;
        expect(allGuide.$1, fs ? contains('Về ăn uống') : isNot(contains('Về ăn uống')));
        expect(allGuide.$1, fs ? contains('Về lưu trú') : isNot(contains('Về lưu trú')));

        final stayGuide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: 'khách sạn chỗ ở tại ${z.titleVi}');
        expect(stayGuide, isNotNull);
        expect(stayGuide!.$1, fs ? contains('Về lưu trú') : contains('tạm ẩn'));

        final foodGuide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: '${z.titleVi} ăn gì ngon');
        expect(foodGuide, isNotNull);
        expect(foodGuide!.$1, fs ? contains('Về ăn uống') : contains('tạm ẩn'));
        if (fs) expect(foodGuide.$1, isNot(contains('Về du lịch')));

        final funGuide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: 'địa điểm vui chơi ở ${z.titleVi}');
        expect(funGuide, isNotNull);
        expect(funGuide!.$1, contains('Về vui chơi'));

        final tourGuide = buildHanoiGuide(z.titleVi, z.titleEn, lat: z.lat, lon: z.lon, raw: 'địa điểm tham quan du lịch ở ${z.titleVi}');
        expect(tourGuide, isNotNull);
        expect(tourGuide!.$1, contains('Về du lịch'));
      }
    });

    test('Toàn bộ 126 xã/phường mới của Hà Nội trong vn_dvhc.json đều tra được gợi ý ăn uống, vui chơi, du lịch đúng khu vực', () {
      final hnIdx = gaz.provinces.indexWhere((p) => p.$2 == 'Hà Nội');
      expect(hnIdx, greaterThanOrEqualTo(0));

      var hanoiCount = 0;
      for (final w in gaz.wards) {
        if (w.$4 != hnIdx) continue;
        final type = w.$2; // 'Phường' | 'Xã'
        final name = w.$3;
        final lat = w.$5;
        final lon = w.$6;
        final full = '$type $name';
        hanoiCount++;

        final cmd = parseWorld('$full có địa điểm ăn uống vui chơi gì');
        expect(cmd.kind, WKind.around, reason: 'Câu hỏi cho "$full" phải ra WKind.around');
        expect(cmd.target, isNotEmpty, reason: 'Target cho "$full" không được rỗng');

        final guide = buildHanoiGuide(
          '$full, Hà Nội',
          '$full, Hanoi',
          lat: lat,
          lon: lon,
          raw: '$full có gì hay',
        );
        expect(guide, isNotNull, reason: 'Không tạo được gợi ý cho "$full" ($lat, $lon)');
        expect(guide!.$1, kHanoiFoodStayEnabled ? contains('Về ăn uống') : isNot(contains('Về ăn uống')));
        expect(guide.$1, contains('Về vui chơi'));
        expect(guide.$1, contains('Về du lịch'));
      }
      expect(hanoiCount, 126);
    });

    test('Không lặp cụm "(thuộc khu vực ...)" khi tên phường đã nằm trong tiêu đề vùng', () {
      final hk = buildHanoiGuide(
        'phường Hoàn Kiếm, Hà Nội',
        'Hoan Kiem ward, Hanoi',
        lat: 21.0288,
        lon: 105.8525,
        raw: 'phường Hoàn Kiếm có gì chơi',
      );
      expect(hk, isNotNull);
      expect(hk!.$1, startsWith('Tại phường Hoàn Kiếm, Hà Nội:'));
      expect(hk.$1, isNot(contains('thuộc khu vực Hoàn Kiếm')));
    });

    test('Các câu hỏi giới thiệu / có gì hay ở xã, phường Hà Nội không bị nuốt vào WKind.help hay WKind.landmark', () {
      final queries = [
        'giới thiệu phường Cầu Giấy',
        'tìm hiểu xã Gia Lâm',
        'phường Bách Khoa có gì hay',
        'xã Đông Anh có những gì',
        'Hồ Tây có gì chơi',
        'Hoàn Kiếm có gì chơi',
        'Bát Tràng có gì chơi',
        'phường Tây Hồ ăn gì ngon',
        'xã Sóc Sơn có điểm du lịch nào',
        'xã Ba Vì đi chơi ở đâu',
      ];
      for (final q in queries) {
        final cmd = parseWorld(q);
        expect(cmd.kind, WKind.around, reason: '"$q" phải định tuyến về WKind.around nhưng lại ra $cmd');
        expect(cmd.target, isNotEmpty, reason: '"$q" thiếu target');
      }
    });
  });

  group('3. Giới thiệu địa danh nổi bật Việt Nam (vn_landmarks)', () {
    test('Tất cả địa danh trong vnLandmarks có đầy đủ tên, mô tả tiếng Việt, tiếng Anh và toạ độ hợp lệ', () {
      expect(vnLandmarks.length, greaterThanOrEqualTo(50));
      for (final l in vnLandmarks) {
        expect(l.name.trim(), isNotEmpty);
        expect(l.en.trim(), isNotEmpty);
        expect(l.vi.trim().length, greaterThan(40), reason: '${l.name} mô tả quá ngắn');
        expect(l.enText.trim().length, greaterThan(20), reason: '${l.name} mô tả tiếng Anh quá ngắn');
        expect(l.lat, inInclusiveRange(8.0, 24.0), reason: '${l.name} lat ngoài phạm vi VN');
        expect(l.lon, inInclusiveRange(102.0, 110.0), reason: '${l.name} lon ngoài phạm vi VN');
      }
    });

    test('Tra cứu danh sách địa danh theo tỉnh (kể cả tên tỉnh cũ và mới như Huế, Quảng Bình, Hà Giang, Phú Yên)', () {
      expect(landmarksOfProvinceIn('Huế có địa danh gì nổi tiếng'), isNotEmpty);
      expect(landmarksOfProvinceIn('Thừa Thiên Huế có gì đẹp'), isNotEmpty);
      expect(landmarksOfProvinceIn('Quảng Bình có gì đẹp'), isNotEmpty);
      expect(landmarksOfProvinceIn('Quảng Trị có địa danh gì'), isNotEmpty);
      expect(landmarksOfProvinceIn('Hà Giang có cảnh đẹp gì'), isNotEmpty);
      expect(landmarksOfProvinceIn('Phú Yên có gì đẹp'), isNotEmpty);
      expect(landmarksOfProvinceIn('Quảng Ninh có gì chơi'), isNotEmpty);
      expect(landmarksOfProvinceIn('Đà Nẵng có địa danh nào'), isNotEmpty);
      expect(landmarksOfProvinceIn('Lâm Đồng có gì đẹp'), isNotEmpty);

      final hueList = landmarkListText('Huế', 'Hue', landmarksOfProvinceIn('Huế'));
      expect(hueList.$1, contains('Kinh thành Huế'));
      expect(hueList.$1, contains('Bạn muốn nghe về nơi nào?'));
    });

    test('Hỏi kể về một địa danh cụ thể trả về WKind.landmark', () {
      expect(parseWorld('kể về Vịnh Hạ Long').kind, WKind.landmark);
      expect(parseWorld('kể về Vịnh Hạ Long').target, 'Vịnh Hạ Long');
      expect(parseWorld('giới thiệu Văn Miếu Quốc Tử Giám').kind, WKind.landmark);
      expect(parseWorld('Chùa Một Cột ở đâu').kind, WKind.landmark);
      expect(parseWorld('Phố cổ Hội An có gì đẹp').kind, WKind.landmark);
    });
  });

  group('4. Câu trả lời thời tiết & gợi ý chuẩn bị theo ngữ cảnh (weather_talk)', () {
    final today = DateTime(2026, 6, 1, 10, 0);
    final sampleNow = LiveWeather(
      'Open-Meteo',
      today,
      const LiveNow(
        temp: 35.0,
        feels: 38.5,
        humidity: 68,
        precip: 0.0,
        desc: 'trời nắng',
        code: 1,
        wind: 12,
        windDir: 'Đông Nam',
        uv: 9.0,
      ),
      [
        LiveHour(today.add(const Duration(hours: 1)), 35.0, 10, 1, 'trời nắng', uv: 9.0),
        LiveHour(today.add(const Duration(hours: 2)), 36.0, 15, 1, 'trời nắng', uv: 9.5),
      ],
      [
        LiveDay(today, 36.0, 27.0, 15, 0.0, 1, 'trời nắng', 9.0, 15.0),
        LiveDay(today.add(const Duration(days: 1)), 29.0, 24.0, 85, 18.0, 63, 'mưa vừa', 5.0, 28.0),
      ],
      aqi: 42,
      pm25: 12.0,
    );

    test('nowText và contextualSuggestion phân biệt rõ nơi đang ở (isLocal: true) và nơi sắp đến (isLocal: false)', () {
      final (nowVi, _) = nowText('Hà Nội', 'Hanoi', sampleNow);
      expect(nowVi, contains('Bây giờ ở Hà Nội: 35 độ'));

      final (localSugVi, _) = contextualSuggestion('Hà Nội', 'Hanoi', sampleNow, isLocal: true);
      final (remoteSugVi, _) = contextualSuggestion('Đà Nẵng', 'Da Nang', sampleNow, isLocal: false);

      expect(localSugVi, contains('Khi ra ngoài bạn lưu ý:'));
      expect(remoteSugVi, contains('Nếu đến Đà Nẵng hoặc ra ngoài tại đây, bạn nên chuẩn bị:'));
    });

    test('dayText, rainAnswer, outingAnswer, morningBulletin và compareAnswer tạo câu trả lời tự nhiên', () {
      final (tomorrowVi, _) = dayText('Hà Nội', 'Hanoi', sampleNow.days[1], today: today);
      expect(tomorrowVi, contains('Ngày mai ở Hà Nội'));
      expect(tomorrowVi, contains('khả năng mưa 85 phần trăm'));

      final (rainVi, _) = rainAnswer('Hà Nội', 'Hanoi', sampleNow, 1);
      expect(rainVi, contains('85 phần trăm'));

      final (outingVi, _) = outingAnswer('Hà Nội', 'Hanoi', sampleNow, 1);
      expect(outingVi, isNotEmpty);

      final (bulletinVi, _) = morningBulletin('Hà Nội', 'Hanoi', sampleNow);
      expect(bulletinVi, contains('Bản tin thời tiết hôm nay ở Hà Nội'));

      final colder = LiveWeather(
        'Open-Meteo',
        today,
        const LiveNow(
          temp: 18.0,
          feels: 17.0,
          humidity: 80,
          precip: 0.0,
          desc: 'nhiều mây',
          code: 3,
          wind: 10,
        ),
        const [],
        [
          LiveDay(today, 21.0, 15.0, 10, 0.0, 3, 'nhiều mây', 4.0, 10.0),
          LiveDay(today.add(const Duration(days: 1)), 20.0, 14.0, 10, 0.0, 3, 'nhiều mây', 4.0, 10.0),
        ],
      );
      final (cmpVi, _) = compareAnswer('Hà Nội', 'Hanoi', sampleNow, 'Đà Lạt', 'Da Lat', colder, 0);
      expect(cmpVi, contains('Hà Nội nóng hơn 17 độ'));
    });
  });

  group('5. Câu trả lời địa hình & vũ trụ (terrain_data & planet_facts)', () {
    test('heightAnswer, reliefAnswer, profileSummary và tổng quan địa hình', () {
      final fan = peakIn('đỉnh Phan Xi Păng cao bao nhiêu');
      expect(fan, isNotNull);
      final (hVi, hEn) = heightAnswer(fan!.vi, fan.en, fan.lat, fan.lon, fan.h.toDouble(), peak: fan);
      expect(hVi, contains('3.143 mét'));
      expect(hEn, contains('3,143 metres'));

      final (relVi, _) = reliefAnswer('Đà Lạt', 'Da Lat', 11.94, 108.44, 1500, [1600, 1400, 1200, 1000, 900, 1100, 1300, 1550], 25);
      expect(relVi, contains('Đà Lạt cao khoảng 1.500 mét'));
      expect(relVi, contains('cao nguyên Lâm Viên'));

      final (profVi, _) = profileSummary([15, 200, 650, 1200, 400, 20], 300, fromVi: 'Hà Nội', toVi: 'Sa Pa');
      expect(profVi, contains('Dài khoảng 300 ki lô mét'));
      expect(profVi, contains('Có một lần lên núi lớn'));

      expect(terrainOverviewVn.$1, contains('Phan Xi Păng'));
      expect(terrainOverviewWorld.$1, contains('Everest'));
    });

    test('Tất cả 10 thiên thể trong Hệ Mặt Trời trả lời đầy đủ kích thước, khoảng cách, ngày/năm, mặt trăng, trọng lực, nhiệt độ, sự sống', () {
      expect(planets.length, 10);
      for (final p in planets) {
        expect(p.chapters, isNotEmpty, reason: '${p.vi} thiếu các đoạn truyện');
        expect(p.facts.trim().length, greaterThan(100), reason: '${p.vi} thiếu nội dung truyện');
        for (final q in [
          '${p.vi} to bằng mấy Trái Đất',
          '${p.vi} cách bao xa',
          'một ngày ở ${p.vi} dài bao lâu',
          'một năm ở ${p.vi} dài bao lâu',
          '${p.vi} có mấy mặt trăng',
          'lên ${p.vi} nặng bao nhiêu',
          '${p.vi} nóng hay lạnh',
          '${p.vi} có sự sống không',
          'bay tới ${p.vi} mất bao lâu',
        ]) {
          final ansVi = planetAnswer(p.sound, p.vi, p.en, q, en: false);
          expect(ansVi, isNotNull, reason: 'Không trả lời được "$q" cho ${p.vi}');
          expect(ansVi!.trim(), isNotEmpty);
        }
      }
      expect(planetHint(false), contains('to bằng mấy Trái Đất'));
    });
  });
}
