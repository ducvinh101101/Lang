import 'dart:io';

import 'package:earthsense/data/nasa_normalized_data.dart';
import 'package:earthsense/features/space/planet_facts.dart';
import 'package:earthsense/live/earth_rag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NasaNormalizedRepo nạp đầy đủ 6 bộ dữ liệu chuẩn hóa và đạt 7/7 điểm Quality Gate', () async {
    final r = await NasaNormalizedRepo.load();

    // Gate 2: Mọi tệp JSON đều có khối data_card đầy đủ
    for (final card in [
      r.gistempCard,
      r.climateCard,
      r.firmsCard,
      r.planetCard,
      r.qaCard,
      r.spaceMediaCard,
      r.dalatScene.dataCard,
    ]) {
      expect(card.sourceName, isNotEmpty);
      expect(card.provider, isNotEmpty);
      expect(card.url, startsWith('https://'));
      expect(card.citationSpokenVi, isNotEmpty);
      expect(card.citationSpokenEn, isNotEmpty);
      expect(card.spokenSummary(en: false), contains('Nguồn dữ liệu'));
    }

    // Gate 3: credits.csv đủ 6 cột chuẩn và nhãn audio_kind hợp lệ
    final csvFile = File('assets/data/credits.csv');
    expect(csvFile.existsSync(), isTrue);
    final csvLines = csvFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    expect(csvLines.first, 'file,source,url,accessed,credit,audio_kind');
    expect(csvLines.length, greaterThanOrEqualTo(8));

    // Gate 4: Chuỗi khí hậu NASA POWER chốt đến năm 2025, không có giá trị thiếu (-999) hoặc mưa tháng > 2500 mm
    expect(r.climateLocations.length, 29);
    for (final c in r.climateLocations.values) {
      expect(c.y0, 1981);
      expect(c.y1, 2025);
      for (final mList in c.rainMonth.values) {
        for (final v in mList) {
          expect(v.isNaN, isFalse);
          expect(v, inInclusiveRange(0.0, 2500.0));
        }
      }
    }
    final hanoiClimate = r.findClimateNear(21.0285, 105.8542);
    expect(hanoiClimate, isNotNull);
    final hanoiHot = r.findHotDaysNear(21.0285, 105.8542);
    expect(hanoiHot, isNotNull);
    expect(hanoiHot!.ge35_recent, greaterThan(0));

    // GISTEMP 1880–2025
    expect(r.gistempSeries.length, 146);
    expect(r.gistempSeries.first.$1, 1880);
    expect(r.gistempSeries.last.$1, 2025);
    expect(r.gistempSummaryText(en: false), contains('NASA GISTEMP'));

    // Sự kiện thiên tai lịch sử (Siêu bão Yagi 09/2024 & Mưa lũ miền Trung 10/2020)
    final yagi = r.matchHistoricalEvent('Siêu bão Yagi ở Quảng Ninh năm 2024');
    expect(yagi, isNotNull);
    expect(yagi!.days.length, 15);
    expect(yagi.spokenSummary(en: false), contains('50 km'));

    final hueFlood = r.matchHistoricalEvent('Mưa lũ lịch sử miền Trung năm 2020 ở Huế');
    expect(hueFlood, isNotNull);
    expect(hueFlood!.days.length, 15);

    // Điểm cháy rừng NASA FIRMS (MODIS Collection 6.1 MCD14ML)
    final firmsTn = r.findFirmsRegion('mùa cháy rừng ở Tây Nguyên');
    expect(firmsTn.monthlyHotspots.length, 12);
    expect(firmsTn.spokenSummary(en: false), contains('NASA FIRMS'));

    // Gate 5: Lưới địa hình đa lớp Đà Lạt 12x12 (144 ô) + ghi rõ nguồn ngoài NASA (EC JRC, WWF HydroRIVERS)
    expect(r.dalatScene.cells.length, 144);
    for (final cell in r.dalatScene.cells) {
      expect(cell.elevationM, inInclusiveRange(900, 2200));
      expect(cell.ndvi, inInclusiveRange(0.0, 1.0));
      expect(cell.lstDayC, inInclusiveRange(10.0, 35.0));
    }
    final centerCell = r.dalatScene.cellAt(11.9404, 108.4583);
    expect(centerCell, isNotNull);
    expect(centerCell!.spokenSummary(en: false), contains('ngoài NASA'));

    // Gate 6: Ngân hàng Hỏi – Đáp kiểm chứng (35 cặp, gồm 12 câu đính chính nhận thức sai) & số mặt trăng tính đến năm 2026
    expect(r.qaBank.length, greaterThanOrEqualTo(35));
    final flatEarthQa = r.matchQa('Trái Đất phẳng hay hình cầu');
    expect(flatEarthQa, isNotNull);
    expect(flatEarthQa!.spokenAnswer(), contains('Nguồn:'));

    final saturnQa = r.matchQa('Hành tinh nào có nhiều mặt trăng nhất Hệ Mặt Trời');
    expect(saturnQa, isNotNull);
    expect(saturnQa!.answerVi, contains('2026'));
    expect(saturnQa.answerVi, contains('293'));
    expect(planetAnswer(7, 'Sao Thổ', 'Saturn', 'Sao Thổ có mấy mặt trăng', en: false), contains('293'));
    expect(planetAnswer(7, 'Sao Thổ', 'Saturn', 'Sao Thổ có mấy mặt trăng', en: false), contains('2026'));

    // Gate 7: Phân biệt rõ 3 nhãn audio_kind (recording | nasa_sonification | app_sonification)
    expect(DataCard.audioIntroVi('recording'), contains('thu trực tiếp'));
    expect(DataCard.audioIntroVi('nasa_sonification'), contains('chuyển dữ liệu'));
    expect(DataCard.audioIntroVi('app_sonification'), contains('ứng dụng Lắng tạo trực tiếp'));

    final perseus = r.matchSpaceMedia('âm thanh lỗ đen Perseus');
    expect(perseus, isNotNull);
    expect(perseus!.audioKind, 'nasa_sonification');
    expect(perseus.spokenIntro(en: false), contains('NASA'));

    final marsWind = r.matchSpaceMedia('tiếng gió Sao Hỏa từ micro Perseverance');
    expect(marsWind, isNotNull);
    expect(marsWind!.audioKind, 'recording');
    expect(marsWind.spokenIntro(en: false), contains('thu trực tiếp'));

    // Kiểm tra tích hợp EarthRag
    final rag = EarthRag.extractContext('Siêu bão Yagi và điểm cháy rừng Tây Nguyên', lat: 11.9404, lon: 108.4583);
    expect(rag, contains('Yagi'));
    expect(rag, contains('FIRMS'));
    expect(rag, contains('SRTM'));
  });
}
