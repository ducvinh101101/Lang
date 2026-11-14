// QUẢN LÝ BỘ DỮ LIỆU NASA ĐÃ CHUẨN HÓA (F1 Khí hậu & Thiên tai, F2 Vũ trụ & Hỏi đáp, F3 Địa hình đa lớp):
// Đọc trực tiếp từ các tệp JSON/CSV đã qua 7 bước kiểm định chất lượng (Quality Gate) trong assets/data/:
//   - gistemp_global.json       : Dị thường nhiệt độ toàn cầu NASA GISTEMP v4 (1880–2025)
//   - climate_history_nasa.json : Khí hậu 29 điểm (14 VN + 15 Thế giới) NASA POWER (1981–2025),
//                                 số ngày nắng nóng 3 mức (ge35, ge37, ge39), sự kiện Bão Yagi (09/2024),
//                                 Mưa lũ miền Trung (10/2020) và Điểm cháy rừng NASA FIRMS (MODIS C6.1)
//   - planets_nasa.json         : Bảng thông số hành tinh NSSDCA Planetary Fact Sheet (Metric, tính đến 2026)
//   - qa_bank.json              : Ngân hàng 35+ cặp hỏi – đáp kiểm chứng từ nguồn NASA (kèm nhận thức sai)
//   - space_media.json          : Danh mục âm thanh vũ trụ & mô tả trợ năng Section 508 theo 4 quy tắc
//   - dalat_scene.json          : Scene địa hình đa lớp chuẩn Đà Lạt 20×20 km (SRTM, MODIS, JRC, HydroRIVERS)
//   - credits.csv               : Bảng ghi công chuẩn hóa (file,source,url,accessed,credit,audio_kind)
// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../features/voice/commands.dart' show normVi;
import '../live/nasa_power.dart' show NasaClimate;
import 'planet_bodies.dart';

/// Khối метаdata chuẩn bắt buộc ở đầu mỗi tệp dữ liệu (Mục 5.1).
class DataCard {
  final String dataset;
  final String provider;
  final String url;
  final String accessed;
  final String spatial;
  final String temporal;
  final String processing;
  final String limitationVi;
  final String citation;
  final String audioKind; // 'recording' | 'nasa_sonification' | 'app_sonification'

  const DataCard({
    required this.dataset,
    required this.provider,
    required this.url,
    required this.accessed,
    required this.spatial,
    required this.temporal,
    required this.processing,
    required this.limitationVi,
    required this.citation,
    required this.audioKind,
  });

  factory DataCard.fromJson(Map<String, dynamic> j) => DataCard(
        dataset: '${j['dataset'] ?? ''}',
        provider: '${j['provider'] ?? ''}',
        url: '${j['url'] ?? ''}',
        accessed: '${j['accessed'] ?? ''}',
        spatial: '${j['spatial'] ?? ''}',
        temporal: '${j['temporal'] ?? ''}',
        processing: '${j['processing'] ?? ''}',
        limitationVi: '${j['limitation_vi'] ?? ''}',
        citation: '${j['citation'] ?? ''}',
        audioKind: '${j['audio_kind'] ?? 'app_sonification'}',
      );

  /// Lời giới thiệu bắt buộc trước khi phát âm thanh dựa trên phân loại `audio_kind` (Mục 5.3).
  static (String vi, String en) audioKindIntro(String kind, {String? customVi, String? customEn}) {
    if (customVi != null && customVi.isNotEmpty) {
      return (customVi, customEn ?? customVi);
    }
    switch (kind) {
      case 'recording':
        return (
          'Sóng âm hoặc sóng radio do thiết bị trên tàu vũ trụ của NASA thu trực tiếp.',
          'Acoustic or radio waves directly recorded by instruments aboard NASA spacecraft.'
        );
      case 'nasa_sonification':
        return (
          'Nhóm khoa học của NASA đã chuyển dữ liệu quan trắc vũ trụ thành âm thanh.',
          'NASA scientists translated astronomical observation data into sound.'
        );
      default:
        return (
          'Âm thanh này do ứng dụng Lắng tạo trực tiếp từ bảng số liệu của NASA.',
          'This sound is synthesized by the Lắng app directly from NASA data tables.'
        );
    }
  }

  String get sourceName => dataset;
  String get citationSpokenVi => citation;
  String get citationSpokenEn => citation;

  static String audioIntroVi(String kind) => audioKindIntro(kind).$1;
  static String audioIntroEn(String kind) => audioKindIntro(kind).$2;

  /// Lời đọc to khi người dùng hỏi "nguồn dữ liệu" (Mục 5.1).
  (String vi, String en) spokenSummaryRecord() {
    final intro = audioKindIntro(audioKind);
    return (
      'Nguồn dữ liệu: $dataset, do $provider cung cấp. '
          'Phạm vi không gian: $spatial. Thời gian: $temporal. '
          'Cách xử lý: $processing '
          'Lưu ý giới hạn: $limitationVi '
          '${intro.$1}',
      'Data source: $dataset, provided by $provider. '
          'Spatial coverage: $spatial. Temporal coverage: $temporal. '
          '${intro.$2}'
    );
  }

  String spokenSummary({bool en = false}) {
    final r = spokenSummaryRecord();
    return en ? r.$2 : r.$1;
  }
}

/// Một mục trong ngân hàng hỏi – đáp `qa_bank.json` (Mục 3.2).
class QaItem {
  final String id;
  final String category;
  final String questionVi;
  final String questionEn;
  final List<String> keywords;
  final String answerVi;
  final String answerEn;
  final String sourceName;
  final String sourceUrl;
  final String audioKind;

  const QaItem({
    required this.id,
    required this.category,
    required this.questionVi,
    required this.questionEn,
    required this.keywords,
    required this.answerVi,
    required this.answerEn,
    required this.sourceName,
    required this.sourceUrl,
    required this.audioKind,
  });

  factory QaItem.fromJson(Map<String, dynamic> j) => QaItem(
        id: '${j['id'] ?? ''}',
        category: '${j['category'] ?? ''}',
        questionVi: '${j['question_vi'] ?? ''}',
        questionEn: '${j['question_en'] ?? ''}',
        keywords: [for (final k in (j['keywords'] as List? ?? const [])) normVi('$k')],
        answerVi: '${j['answer_vi'] ?? ''}',
        answerEn: '${j['answer_en'] ?? ''}',
        sourceName: '${j['source_name'] ?? ''}',
        sourceUrl: '${j['source_url'] ?? ''}',
        audioKind: '${j['audio_kind'] ?? 'app_sonification'}',
      );

  String get source => sourceName;

  (String vi, String en) spokenWithSource() => (
        '$answerVi Nguồn: $sourceName.',
        '$answerEn Source: $sourceName.',
      );

  String spokenAnswer({bool en = false}) {
    final r = spokenWithSource();
    return en ? r.$2 : r.$1;
  }
}

/// Một mục âm thanh / mô tả hình ảnh trợ năng `space_media.json` (Mục 3.3).
class SpaceMediaItem {
  final String id;
  final String nasaId;
  final String titleVi;
  final String titleEn;
  final String audioKind;
  final String audioIntroVi;
  final String audioIntroEn;
  final String description508En;
  final String accessibleDescriptionVi;
  final String mediaUrl;
  final String sourceName;
  final String sourceUrl;

  const SpaceMediaItem({
    required this.id,
    required this.nasaId,
    required this.titleVi,
    required this.titleEn,
    required this.audioKind,
    required this.audioIntroVi,
    required this.audioIntroEn,
    required this.description508En,
    required this.accessibleDescriptionVi,
    required this.mediaUrl,
    required this.sourceName,
    required this.sourceUrl,
  });

  factory SpaceMediaItem.fromJson(Map<String, dynamic> j) => SpaceMediaItem(
        id: '${j['id'] ?? ''}',
        nasaId: '${j['nasa_id'] ?? ''}',
        titleVi: '${j['title_vi'] ?? ''}',
        titleEn: '${j['title_en'] ?? ''}',
        audioKind: '${j['audio_kind'] ?? 'nasa_sonification'}',
        audioIntroVi: '${j['audio_intro_vi'] ?? ''}',
        audioIntroEn: '${j['audio_intro_en'] ?? ''}',
        description508En: '${j['description_508_en'] ?? ''}',
        accessibleDescriptionVi: '${j['accessible_description_vi'] ?? ''}',
        mediaUrl: '${j['media_url'] ?? ''}',
        sourceName: '${j['source_name'] ?? ''}',
        sourceUrl: '${j['source_url'] ?? ''}',
      );

  (String vi, String en) fullNarration() {
    final intro = DataCard.audioKindIntro(audioKind, customVi: audioIntroVi, customEn: audioIntroEn);
    return (
      '$titleVi. ${intro.$1} $accessibleDescriptionVi Nguồn: $sourceName.',
      '$titleEn. ${intro.$2} $description508En Source: $sourceName.',
    );
  }

  String spokenIntro({bool en = false}) {
    final r = fullNarration();
    return en ? r.$2 : r.$1;
  }
}

/// Ngày trong một sự kiện thiên tai lịch sử (Bộ C - Bão Yagi 09/2024, Mưa lũ miền Trung 10/2020).
class HistoricalEventDay {
  final String date;
  final double tempMeanC;
  final double tempMaxC;
  final double rainMm;
  final double windMeanMs;
  final double windMeanKmh;

  const HistoricalEventDay({
    required this.date,
    required this.tempMeanC,
    required this.tempMaxC,
    required this.rainMm,
    required this.windMeanMs,
    required this.windMeanKmh,
  });

  double get tmaxC => tempMaxC;
  double get ws10mKmh => windMeanKmh;

  factory HistoricalEventDay.fromJson(Map<String, dynamic> j) => HistoricalEventDay(
        date: '${j['date'] ?? ''}',
        tempMeanC: (j['temp_mean_c'] as num).toDouble(),
        tempMaxC: (j['temp_max_c'] as num).toDouble(),
        rainMm: (j['rain_mm'] as num).toDouble(),
        windMeanMs: (j['wind_mean_10m_ms'] as num).toDouble(),
        windMeanKmh: (j['wind_mean_10m_kmh'] as num).toDouble(),
      );
}

class HistoricalDisasterEvent {
  final String id;
  final String titleVi;
  final String titleEn;
  final String placeVi;
  final String placeEn;
  final double lat;
  final double lon;
  final String startDate;
  final String endDate;
  final double totalRainMm;
  final String peakRainDate;
  final double peakRainMm;
  final String peakWindDate;
  final double peakWindMeanMs;
  final double peakWindMeanKmh;
  final String summaryVi;
  final String summaryEn;
  final String windNoteVi;
  final List<HistoricalEventDay> days;

  const HistoricalDisasterEvent({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.placeVi,
    required this.placeEn,
    required this.lat,
    required this.lon,
    required this.startDate,
    required this.endDate,
    required this.totalRainMm,
    required this.peakRainDate,
    required this.peakRainMm,
    required this.peakWindDate,
    required this.peakWindMeanMs,
    required this.peakWindMeanKmh,
    required this.summaryVi,
    required this.summaryEn,
    required this.windNoteVi,
    required this.days,
  });

  factory HistoricalDisasterEvent.fromJson(Map<String, dynamic> j) => HistoricalDisasterEvent(
        id: '${j['id'] ?? ''}',
        titleVi: '${j['title_vi'] ?? ''}',
        titleEn: '${j['title_en'] ?? ''}',
        placeVi: '${j['place_vi'] ?? ''}',
        placeEn: '${j['place_en'] ?? ''}',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        startDate: '${j['start_date'] ?? ''}',
        endDate: '${j['end_date'] ?? ''}',
        totalRainMm: (j['total_rain_mm'] as num).toDouble(),
        peakRainDate: '${j['peak_rain_date'] ?? ''}',
        peakRainMm: (j['peak_rain_mm'] as num).toDouble(),
        peakWindDate: '${j['peak_wind_date'] ?? ''}',
        peakWindMeanMs: (j['peak_wind_mean_ms'] as num).toDouble(),
        peakWindMeanKmh: (j['peak_wind_mean_kmh'] as num).toDouble(),
        summaryVi: '${j['summary_vi'] ?? ''}',
        summaryEn: '${j['summary_en'] ?? ''}',
        windNoteVi: '${j['wind_note_vi'] ?? ''}',
        days: [for (final d in (j['days'] as List? ?? const [])) HistoricalEventDay.fromJson(d as Map<String, dynamic>)],
      );

  String spokenSummary({bool en = false}) => en
      ? '$titleEn ($startDate to $endDate). $summaryEn ${DataCard.audioIntroEn('app_sonification')} Source: NASA POWER.'
      : '$titleVi ($startDate đến $endDate). $summaryVi $windNoteVi ${DataCard.audioIntroVi('app_sonification')} Nguồn: NASA POWER.';
}

/// Thống kê điểm cháy rừng NASA FIRMS theo vùng khí hậu Việt Nam.
class FirmsRegionSummary {
  final String id;
  final String nameVi;
  final String nameEn;
  final List<int> peakMonths;
  final List<int> monthlyAvgHotspots;
  final String noteVi;
  final String noteEn;

  const FirmsRegionSummary({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.peakMonths,
    required this.monthlyAvgHotspots,
    required this.noteVi,
    required this.noteEn,
  });

  List<int> get monthlyHotspots => monthlyAvgHotspots;

  String spokenSummary({bool en = false}) => en
      ? 'Seasonal wildfire hotspots in $nameEn: $noteEn ${DataCard.audioIntroEn('app_sonification')} Source: NASA FIRMS MODIS Collection 6.1 MCD14ML.'
      : 'Điểm cháy rừng theo mùa tại $nameVi: $noteVi ${DataCard.audioIntroVi('app_sonification')} Nguồn: NASA FIRMS MODIS Collection 6.1 MCD14ML.';

  factory FirmsRegionSummary.fromJson(Map<String, dynamic> j) => FirmsRegionSummary(
        id: '${j['id'] ?? ''}',
        nameVi: '${j['name_vi'] ?? ''}',
        nameEn: '${j['name_en'] ?? ''}',
        peakMonths: [for (final m in (j['peak_months'] as List? ?? const [])) (m as num).toInt()],
        monthlyAvgHotspots: [for (final h in (j['monthly_avg_hotspots'] as List? ?? const [])) (h as num).toInt()],
        noteVi: '${j['note_vi'] ?? ''}',
        noteEn: '${j['note_en'] ?? ''}',
      );
}

/// Số ngày nắng nóng 3 mức (ge35, ge37, ge39 °C) từ NASA POWER Daily.
class HotDaysComparison {
  final String placeId;
  final String nameVi;
  final String nameEn;
  final double lat;
  final double lon;
  final double ge35Early, ge37Early, ge39Early, rain50Early;
  final double ge35Recent, ge37Recent, ge39Recent, rain50Recent;

  const HotDaysComparison({
    required this.placeId,
    required this.nameVi,
    required this.nameEn,
    required this.lat,
    required this.lon,
    required this.ge35Early,
    required this.ge37Early,
    required this.ge39Early,
    required this.rain50Early,
    required this.ge35Recent,
    required this.ge37Recent,
    required this.ge39Recent,
    required this.rain50Recent,
  });

  double get ge35_80s => ge35Early;
  double get ge37_80s => ge37Early;
  double get ge39_80s => ge39Early;
  double get rain50_80s => rain50Early;
  double get ge35_recent => ge35Recent;
  double get ge37_recent => ge37Recent;
  double get ge39_recent => ge39Recent;
  double get rain50_recent => rain50Recent;

  factory HotDaysComparison.fromJson(Map<String, dynamic> j) {
    final d80 = j['decade_1981_1990'] as Map<String, dynamic>;
    final d20 = j['decade_2016_2025'] as Map<String, dynamic>;
    return HotDaysComparison(
      placeId: '${j['place_id'] ?? ''}',
      nameVi: '${j['name_vi'] ?? ''}',
      nameEn: '${j['name_en'] ?? ''}',
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      ge35Early: (d80['ge35_per_year'] as num).toDouble(),
      ge37Early: (d80['ge37_per_year'] as num).toDouble(),
      ge39Early: (d80['ge39_per_year'] as num).toDouble(),
      rain50Early: (d80['heavy_rain_ge50mm_per_year'] as num).toDouble(),
      ge35Recent: (d20['ge35_per_year'] as num).toDouble(),
      ge37Recent: (d20['ge37_per_year'] as num).toDouble(),
      ge39Recent: (d20['ge39_per_year'] as num).toDouble(),
      rain50Recent: (d20['heavy_rain_ge50mm_per_year'] as num).toDouble(),
    );
  }
}

/// Ô lưới trong Scene địa hình chuẩn Đà Lạt (~20×20 km) đa lớp vệ tinh (Mục 4).
class TerrainSceneCell {
  final int row, col;
  final double lat, lon;
  final double elevationM;
  final double slopeDeg;
  final int landCoverIgbp;
  final String landCoverVi;
  final String landCoverEn;
  final double ndvi;
  final double lstDayC;
  final double lstNightC;
  final int waterOccurrencePct;
  final String nearestWaterVi;
  final String nearestWaterEn;
  final double riverDistKm;
  final double dischargeM3s;
  final String soundLayer;

  const TerrainSceneCell({
    required this.row,
    required this.col,
    required this.lat,
    required this.lon,
    required this.elevationM,
    required this.slopeDeg,
    required this.landCoverIgbp,
    required this.landCoverVi,
    required this.landCoverEn,
    required this.ndvi,
    required this.lstDayC,
    required this.lstNightC,
    required this.waterOccurrencePct,
    required this.nearestWaterVi,
    required this.nearestWaterEn,
    required this.riverDistKm,
    required this.dischargeM3s,
    required this.soundLayer,
  });

  factory TerrainSceneCell.fromJson(Map<String, dynamic> j) => TerrainSceneCell(
        row: (j['row'] as num).toInt(),
        col: (j['col'] as num).toInt(),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        elevationM: (j['elevation_m'] as num).toDouble(),
        slopeDeg: (j['slope_deg'] as num).toDouble(),
        landCoverIgbp: (j['land_cover_igbp'] as num).toInt(),
        landCoverVi: '${j['land_cover_vi'] ?? ''}',
        landCoverEn: '${j['land_cover_en'] ?? ''}',
        ndvi: (j['ndvi'] as num).toDouble(),
        lstDayC: (j['lst_day_c'] as num).toDouble(),
        lstNightC: (j['lst_night_c'] as num).toDouble(),
        waterOccurrencePct: (j['water_occurrence_pct'] as num).toInt(),
        nearestWaterVi: '${j['nearest_water_vi'] ?? ''}',
        nearestWaterEn: '${j['nearest_water_en'] ?? ''}',
        riverDistKm: (j['river_dist_km'] as num).toDouble(),
        dischargeM3s: (j['discharge_m3s'] as num).toDouble(),
        soundLayer: '${j['sound_layer'] ?? ''}',
      );

  String spokenSummary({bool en = false}) {
    final ndviDesc = ndvi >= 0.7
        ? 'mật độ cây xanh dày (NDVI ${ndvi.toStringAsFixed(2)})'
        : ndvi >= 0.45
            ? 'cây xanh trung bình (NDVI ${ndvi.toStringAsFixed(2)})'
            : 'ít cây xanh (NDVI ${ndvi.toStringAsFixed(2)})';
    final slopeDesc = slopeDeg >= 15
        ? 'sườn dốc đứng ${slopeDeg.toStringAsFixed(1)} độ'
        : slopeDeg >= 7
            ? 'sườn thoải ${slopeDeg.toStringAsFixed(1)} độ'
            : 'địa hình bằng phẳng (${slopeDeg.toStringAsFixed(1)} độ)';
    final waterDist = riverDistKm < 0.4
        ? 'ngay sát $nearestWaterVi (tần suất nước mặt JRC $waterOccurrencePct%)'
        : 'cách $nearestWaterVi khoảng ${riverDistKm.toStringAsFixed(1).replaceAll('.', ',')} km';
    return en
        ? 'Elevation ${elevationM.round()}m (SRTM), slope ${slopeDeg.toStringAsFixed(1)}°. '
            'MODIS land cover: $landCoverEn, NDVI ${ndvi.toStringAsFixed(2)}, daytime LST ${lstDayC.toStringAsFixed(1)}°C. '
            'Water (non-NASA JRC & HydroRIVERS): ${riverDistKm.toStringAsFixed(1)} km from $nearestWaterEn.'
        : 'Cao ${elevationM.round()} mét (SRTM), $slopeDesc. '
            'Phủ đất MODIS: $landCoverVi, $ndviDesc, nhiệt bề mặt ban ngày khoảng ${lstDayC.toStringAsFixed(1).replaceAll('.', ',')} độ C. '
            'Thủy văn (nguồn ngoài NASA: EC JRC và WWF HydroRIVERS): $waterDist.';
  }
}

class TerrainScene {
  final DataCard dataCard;
  final String sceneId;
  final String nameVi;
  final String nameEn;
  final double centerLat;
  final double centerLon;
  final double sizeKm;
  final int gridSize;
  final List<TerrainSceneCell> cells;

  const TerrainScene({
    required this.dataCard,
    required this.sceneId,
    required this.nameVi,
    required this.nameEn,
    required this.centerLat,
    required this.centerLon,
    required this.sizeKm,
    required this.gridSize,
    required this.cells,
  });

  factory TerrainScene.fromJson(Map<String, dynamic> j) => TerrainScene(
        dataCard: DataCard.fromJson(j['data_card'] as Map<String, dynamic>),
        sceneId: '${j['scene_id'] ?? ''}',
        nameVi: '${j['name_vi'] ?? ''}',
        nameEn: '${j['name_en'] ?? ''}',
        centerLat: (j['center_lat'] as num).toDouble(),
        centerLon: (j['center_lon'] as num).toDouble(),
        sizeKm: (j['size_km'] as num).toDouble(),
        gridSize: (j['grid_size'] as num).toInt(),
        cells: [for (final c in (j['cells'] as List? ?? const [])) TerrainSceneCell.fromJson(c as Map<String, dynamic>)],
      );

  /// Kiểm tra xem (lat, lon) có nằm trong vùng scene (~12 km quanh tâm) không.
  bool contains(double lat, double lon) {
    final dLat = (lat - centerLat).abs() * 110.54;
    final dLon = (lon - centerLon).abs() * 111.32 * math.cos(centerLat * math.pi / 180);
    return dLat <= sizeKm * 0.65 && dLon <= sizeKm * 0.65;
  }

  /// Lấy ô lưới gần (lat, lon) nhất.
  TerrainSceneCell nearestCell(double lat, double lon) {
    var best = cells.first;
    var bestDist = double.infinity;
    for (final c in cells) {
      final d = (c.lat - lat) * (c.lat - lat) + (c.lon - lon) * (c.lon - lon);
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  TerrainSceneCell? cellAt(double lat, double lon) => cells.isEmpty ? null : nearestCell(lat, lon);

  /// Mô tả đa lớp vệ tinh khi chạm vào một điểm trên bản đồ (Mục 4.3).
  (String vi, String en) describeCellAt(double lat, double lon) {
    final c = nearestCell(lat, lon);
    final ndviDesc = c.ndvi >= 0.7
        ? 'mật độ cây xanh dày (NDVI ${c.ndvi.toStringAsFixed(2)})'
        : c.ndvi >= 0.45
            ? 'cây xanh trung bình (NDVI ${c.ndvi.toStringAsFixed(2)})'
            : 'ít cây xanh (NDVI ${c.ndvi.toStringAsFixed(2)})';
    final slopeDesc = c.slopeDeg >= 15
        ? 'sườn dốc đứng ${c.slopeDeg.toStringAsFixed(1)} độ'
        : c.slopeDeg >= 7
            ? 'sườn thoải ${c.slopeDeg.toStringAsFixed(1)} độ'
            : 'địa hình bằng phẳng (${c.slopeDeg.toStringAsFixed(1)} độ)';
    final waterDist = c.riverDistKm < 0.4
        ? 'ngay sát ${c.nearestWaterVi} (tần suất nước mặt JRC ${c.waterOccurrencePct}%)'
        : 'cách ${c.nearestWaterVi} khoảng ${c.riverDistKm.toStringAsFixed(1).replaceAll('.', ',')} km';
    return (
      'Cao ${c.elevationM.round()} mét (SRTM), $slopeDesc. '
          'Phủ đất MODIS: ${c.landCoverVi}, $ndviDesc, nhiệt bề mặt ban ngày khoảng ${c.lstDayC.toStringAsFixed(1).replaceAll('.', ',')} độ C. '
          'Thủy văn (nguồn ngoài NASA: JRC và HydroRIVERS): $waterDist.',
      'Elevation ${c.elevationM.round()}m (SRTM), slope ${c.slopeDeg.toStringAsFixed(1)}°. '
          'MODIS land cover: ${c.landCoverEn}, NDVI ${c.ndvi.toStringAsFixed(2)}, daytime LST ${c.lstDayC.toStringAsFixed(1)}°C. '
          'Water (non-NASA JRC & HydroRIVERS): ${c.riverDistKm.toStringAsFixed(1)} km from ${c.nearestWaterEn}.'
    );
  }
}

/// Trung tâm nạp & truy vấn dữ liệu chuẩn hóa NASA trong ứng dụng.
class NasaNormalizedRepo {
  static NasaNormalizedRepo? _instance;
  static Future<NasaNormalizedRepo>? _loading;

  final DataCard gistempCard;
  final Map<String, dynamic> gistempSummary;
  final List<(int year, double anomalyC)> gistempSeries;

  final DataCard climateCard;
  final DataCard firmsCard;
  final List<Map<String, dynamic>> rawPlaces;
  final List<NasaClimate> normalizedClimates;
  final List<HotDaysComparison> hotDaysExtremes;
  final List<HistoricalDisasterEvent> historicalEvents;
  final List<FirmsRegionSummary> firmsRegions;

  final DataCard planetsCard;
  final List<Map<String, dynamic>> planetsBodies;

  final DataCard qaCard;
  final List<QaItem> qaItems;

  final DataCard spaceMediaCard;
  final List<SpaceMediaItem> spaceMediaItems;

  final TerrainScene dalatScene;

  NasaNormalizedRepo._({
    required this.gistempCard,
    required this.gistempSummary,
    required this.gistempSeries,
    required this.climateCard,
    required this.firmsCard,
    required this.rawPlaces,
    required this.normalizedClimates,
    required this.hotDaysExtremes,
    required this.historicalEvents,
    required this.firmsRegions,
    required this.planetsCard,
    required this.planetsBodies,
    required this.qaCard,
    required this.qaItems,
    required this.spaceMediaCard,
    required this.spaceMediaItems,
    required this.dalatScene,
  });

  static NasaNormalizedRepo? get cached => _instance;

  DataCard get planetCard => planetsCard;
  List<QaItem> get qaBank => qaItems;
  Map<String, NasaClimate> get climateLocations => {
        for (var i = 0; i < rawPlaces.length && i < normalizedClimates.length; i++)
          '${rawPlaces[i]['id'] ?? i}': normalizedClimates[i],
      };

  String gistempSummaryText({bool en = false}) {
    final r = gistempNarration();
    return en ? r.$2 : r.$1;
  }

  static Future<NasaNormalizedRepo> load() {
    if (_instance != null) return Future.value(_instance!);
    return _loading ??= _loadInternal();
  }

  static Future<NasaNormalizedRepo> _loadInternal() async {
    Future<Map<String, dynamic>> readJson(String name) async {
      final txt = await rootBundle.loadString('assets/data/$name');
      return jsonDecode(txt) as Map<String, dynamic>;
    }

    final results = await Future.wait([
      readJson('gistemp_global.json'),
      readJson('climate_history_nasa.json'),
      readJson('planets_nasa.json'),
      readJson('qa_bank.json'),
      readJson('space_media.json'),
      readJson('dalat_scene.json'),
    ]);

    final gJson = results[0];
    final cJson = results[1];
    final pJson = results[2];
    final qJson = results[3];
    final mJson = results[4];
    final dJson = results[5];

    final gSeries = <(int, double)>[
      for (final r in (gJson['series'] as List? ?? const []))
        (((r as Map)['year'] as num).toInt(), (r['anomaly_c'] as num).toDouble())
    ];

    final rawPlaces = <Map<String, dynamic>>[
      for (final p in (cJson['places'] as List? ?? const [])) p as Map<String, dynamic>
    ];
    final climates = <NasaClimate>[];
    for (final p in rawPlaces) {
      final lat = (p['lat'] as num).toDouble();
      final lon = (p['lon'] as num).toDouble();
      final y0 = (p['start_year'] as num).toInt();
      final y1 = (p['end_year'] as num).toInt();
      final ty = <double>[];
      final ry = <double>[];
      final hy = <double>[];
      final tm = <int, List<double>>{};
      final rm = <int, List<double>>{};
      for (final yr in (p['yearly'] as List? ?? const [])) {
        final ym = yr as Map<String, dynamic>;
        final y = (ym['year'] as num).toInt();
        ty.add((ym['temp_c'] as num).toDouble());
        ry.add((ym['rain_annual_mm'] as num).toDouble());
        hy.add((ym['rh_pct'] as num).toDouble());
        tm[y] = [for (final x in (ym['temp_months_c'] as List)) (x as num).toDouble()];
        rm[y] = [for (final x in (ym['rain_months_mm'] as List)) (x as num).toDouble()];
      }
      climates.add(NasaClimate(lat, lon, y0, y1, ty, ry, tm, rm, humYear: hy));
    }
    // F1: 34 tỉnh/thành (NASA POWER tháng 1981–2025, bộ a_34 của data_nasa) → lịch sử thời tiết chạy không cần mạng
    // ở mọi tỉnh; điểm trùng (≤ 0,05°) với bộ 29 điểm ở trên thì giữ bộ cũ.
    try {
      final c34 = jsonDecode(await rootBundle.loadString('assets/data/climate_34_provinces.json')) as Map<String, dynamic>;
      for (final c in parseClimate34(c34)) {
        if (climates.any((x) => (x.lat - c.lat).abs() <= 0.05 && (x.lon - c.lon).abs() <= 0.05)) continue;
        climates.add(c);
      }
    } catch (_) {}

    final firmsMap = cJson['fire_firms'] as Map<String, dynamic>;

    final repo = NasaNormalizedRepo._(
      gistempCard: DataCard.fromJson(gJson['data_card'] as Map<String, dynamic>),
      gistempSummary: (gJson['summary'] as Map<String, dynamic>?) ?? const {},
      gistempSeries: gSeries,
      climateCard: DataCard.fromJson(cJson['data_card'] as Map<String, dynamic>),
      firmsCard: DataCard.fromJson(firmsMap['data_card'] as Map<String, dynamic>),
      rawPlaces: rawPlaces,
      normalizedClimates: climates,
      hotDaysExtremes: [
        for (final h in (cJson['hot_days_extremes'] as List? ?? const []))
          HotDaysComparison.fromJson(h as Map<String, dynamic>)
      ],
      historicalEvents: [
        for (final ev in (cJson['historical_events'] as List? ?? const []))
          HistoricalDisasterEvent.fromJson(ev as Map<String, dynamic>)
      ],
      firmsRegions: [
        for (final r in (firmsMap['regions'] as List? ?? const []))
          FirmsRegionSummary.fromJson(r as Map<String, dynamic>)
      ],
      planetsCard: DataCard.fromJson(pJson['data_card'] as Map<String, dynamic>),
      planetsBodies: [
        for (final b in (pJson['bodies'] as List? ?? const [])) b as Map<String, dynamic>
      ],
      qaCard: DataCard.fromJson(qJson['data_card'] as Map<String, dynamic>),
      qaItems: [
        for (final item in (qJson['items'] as List? ?? const []))
          QaItem.fromJson(item as Map<String, dynamic>)
      ],
      spaceMediaCard: DataCard.fromJson(mJson['data_card'] as Map<String, dynamic>),
      spaceMediaItems: [
        for (final item in (mJson['items'] as List? ?? const []))
          SpaceMediaItem.fromJson(item as Map<String, dynamic>)
      ],
      dalatScene: TerrainScene.fromJson(dJson),
    );
    // F2: số liệu thiên thể làm nền tảng sự thật cho trả lời, "sự thật thú vị" và trò chơi Hệ Mặt Trời
    PlanetBody.loaded = [for (final b in repo.planetsBodies) PlanetBody.fromJson(b)];
    _instance = repo;
    return repo;
  }

  /// Tìm dữ liệu khí hậu NASA POWER đã chuẩn hóa gần tọa độ (lat, lon) nhất (trong bán kính ~0.38 độ ~ 40 km).
  NasaClimate? findClimateNear(double lat, double lon, {double maxDeg = 0.38}) {
    NasaClimate? best;
    var bestD = maxDeg * maxDeg;
    for (final c in normalizedClimates) {
      final d = (c.lat - lat) * (c.lat - lat) + (c.lon - lon) * (c.lon - lon);
      if (d <= bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  /// Tìm thống kê ngày nắng nóng 3 mức (ge35, ge37, ge39 °C) gần tọa độ (lat, lon) nhất.
  HotDaysComparison? findHotDaysNear(double lat, double lon, {double maxDeg = 1.2}) {
    HotDaysComparison? best;
    var bestD = maxDeg * maxDeg;
    for (final h in hotDaysExtremes) {
      final d = (h.lat - lat) * (h.lat - lat) + (h.lon - lon) * (h.lon - lon);
      if (d <= bestD) {
        bestD = d;
        best = h;
      }
    }
    return best;
  }

  /// Khớp câu hỏi với ngân hàng hỏi – đáp chuẩn `qa_bank.json`.
  QaItem? matchQa(String query) {
    final q = ' ${normVi(query)} ';
    if (q.trim().length < 4) return null;
    QaItem? best;
    var bestScore = 0;
    for (final item in qaItems) {
      var score = 0;
      for (final kw in item.keywords) {
        if (kw.isNotEmpty && q.contains(' $kw ')) {
          score += kw.split(' ').length * 3;
        } else if (kw.length >= 6 && q.contains(kw)) {
          score += 2;
        }
      }
      final qNormVi = normVi(item.questionVi);
      final qNormEn = normVi(item.questionEn);
      if (q.trim() == qNormVi || q.trim() == qNormEn) {
        score += 20;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 3 ? best : null;
  }

  /// Tìm bản âm thanh vũ trụ / mô tả trợ năng `space_media.json` theo câu hỏi.
  SpaceMediaItem? matchSpaceMedia(String query) {
    final q = normVi(query);
    if (RegExp(r'\b(perseus|lo den|ho den|black hole sound)\b').hasMatch(q) &&
        RegExp(r'\b(am thanh|tieng|nghe|sound|audio|sonification)\b').hasMatch(q)) {
      return spaceMediaItems.where((x) => x.id == 'perseus_black_hole').firstOrNull;
    }
    if (RegExp(r'\b(gio sao hoa|am thanh sao hoa|perseverance|tieng sao hoa|mars wind|sound on mars)\b').hasMatch(q)) {
      return spaceMediaItems.where((x) => x.id == 'perseverance_mars_wind').firstOrNull;
    }
    if (RegExp(r'\b(voyager|song plasma|khong gian lien sao|interstellar plasma)\b').hasMatch(q)) {
      return spaceMediaItems.where((x) => x.id == 'voyager_interstellar_plasma').firstOrNull;
    }
    if (RegExp(r'\b(cot tru sang tao|tinh van dai bang|pillars of creation)\b').hasMatch(q)) {
      return spaceMediaItems.where((x) => x.id == 'pillars_of_creation_sonification').firstOrNull;
    }
    if (RegExp(r'\b(tinh van con cua|crab nebula|sao xung)\b').hasMatch(q)) {
      return spaceMediaItems.where((x) => x.id == 'crab_nebula_sonification').firstOrNull;
    }
    return null;
  }

  /// Tìm sự kiện lịch sử (Bão Yagi 09/2024, Mưa lũ miền Trung 10/2020) theo câu nói.
  HistoricalDisasterEvent? matchHistoricalEvent(String query) {
    final q = normVi(query);
    if (RegExp(r'\b(yagi|bao so 3 nam 2024|sieu bao yagi|bao thang 9 nam 2024|typhoon yagi)\b').hasMatch(q)) {
      if (q.contains('quang ninh') || q.contains('ha long')) {
        return historicalEvents.where((x) => x.id == 'yagi_2024_quangninh').firstOrNull ??
            historicalEvents.where((x) => x.id == 'yagi_2024_hanoi').firstOrNull;
      }
      return historicalEvents.where((x) => x.id == 'yagi_2024_hanoi').firstOrNull;
    }
    if ((q.contains('2020') &&
            (q.contains('mien trung') || q.contains('hue') || q.contains('mua lu') || q.contains('lu lich su'))) ||
        RegExp(r'\b(lu mien trung 2020|mua lu thang 10 nam 2020|lu lich su 2020|lu hue 2020|lu lich su mien trung)\b')
            .hasMatch(q)) {
      return historicalEvents.where((x) => x.id == 'central_flood_2020_hue').firstOrNull;
    }
    return null;
  }

  /// Tìm vùng cháy rừng NASA FIRMS theo câu hỏi hoặc tọa độ.
  FirmsRegionSummary findFirmsRegion(String query, {double? lat, double? lon}) {
    final q = normVi(query);
    if (q.contains('tay bac') || q.contains('son la') || q.contains('dien bien') || q.contains('lai chau')) {
      return firmsRegions.firstWhere((r) => r.id == 'tay_bac');
    }
    if (q.contains('bac trung bo') || q.contains('nghe an') || q.contains('ha tinh') || q.contains('quang binh') || q.contains('thanh hoa')) {
      return firmsRegions.firstWhere((r) => r.id == 'bac_trung_bo');
    }
    if (q.contains('nam trung bo') || q.contains('da nang') || q.contains('nha trang') || q.contains('binh thuan') || q.contains('ninh thuan')) {
      return firmsRegions.firstWhere((r) => r.id == 'nam_trung_bo');
    }
    if (q.contains('nam bo') || q.contains('ho chi minh') || q.contains('sai gon') || q.contains('can tho') || q.contains('ca mau') || q.contains('u minh')) {
      return firmsRegions.firstWhere((r) => r.id == 'nam_bo');
    }
    if (q.contains('dong bac') || q.contains('ha noi') || q.contains('hai phong') || q.contains('quang ninh')) {
      return firmsRegions.firstWhere((r) => r.id == 'dong_bac');
    }
    if (lat != null && lon != null) {
      if (lat >= 20.5 && lon < 105.0) return firmsRegions.firstWhere((r) => r.id == 'tay_bac');
      if (lat >= 20.0) return firmsRegions.firstWhere((r) => r.id == 'dong_bac');
      if (lat >= 16.0) return firmsRegions.firstWhere((r) => r.id == 'bac_trung_bo');
      if (lat >= 11.5 && lon < 108.6) return firmsRegions.firstWhere((r) => r.id == 'tay_nguyen');
      if (lat >= 11.5) return firmsRegions.firstWhere((r) => r.id == 'nam_trung_bo');
      return firmsRegions.firstWhere((r) => r.id == 'nam_bo');
    }
    return firmsRegions.firstWhere((r) => r.id == 'tay_nguyen');
  }

  /// Tóm tắt xu hướng ấm lên toàn cầu NASA GISTEMP v4 (1880–2025).
  (String vi, String en) gistempNarration() {
    final s = gistempSummary;
    final warm = (s['warming_since_preindustrial_c'] as num?)?.toDouble() ?? 1.35;
    final hotY = s['hottest_year'] ?? 2024;
    final hotA = (s['hottest_anomaly_c'] as num?)?.toDouble() ?? 1.29;
    final intro = DataCard.audioKindIntro(gistempCard.audioKind);
    return (
      'Theo bộ dữ liệu nhiệt độ bề mặt toàn cầu NASA GISTEMP v4 từ năm 1880 đến năm 2025: '
          'nhiệt độ trung bình Trái Đất thập niên gần đây đã ấm lên khoảng ${warm.toStringAsFixed(2).replaceAll('.', ',')} độ C '
          'so với thời kỳ 1880–1900. Năm nóng nhất là năm $hotY, cao hơn kỳ chuẩn 1951–1980 là '
          '${hotA.toStringAsFixed(2).replaceAll('.', ',')} độ C. ${intro.$1}',
      'According to NASA GISTEMP v4 global surface temperature records (1880–2025), '
          'Earth has warmed by about ${warm.toStringAsFixed(2)}°C compared to 1880–1900, '
          'with $hotY reaching +${hotA.toStringAsFixed(2)}°C above the 1951–1980 baseline. ${intro.$2}'
    );
  }
}


/// Bộ khí hậu 34 tỉnh/thành (climate_34_provinces.json): mỗi tỉnh hai chuỗi tháng liên tục từ tháng 1 năm y0
/// (nhiệt độ °C, mưa mm/tháng; null = thiếu) → [NasaClimate].
List<NasaClimate> parseClimate34(Map<String, dynamic> j) {
  final out = <NasaClimate>[];
  for (final p in (j['places'] as List? ?? const [])) {
    if (p is! Map) continue;
    final y0 = (p['y0'] as num).toInt(), y1 = (p['y1'] as num).toInt();
    final t = [for (final x in (p['t'] as List)) (x as num?)?.toDouble() ?? double.nan];
    final r = [for (final x in (p['r'] as List)) (x as num?)?.toDouble() ?? double.nan];
    final tm = <int, List<double>>{}, rm = <int, List<double>>{};
    final ty = <double>[], ry = <double>[];
    for (var y = y0; y <= y1; y++) {
      final k = (y - y0) * 12;
      if (k + 12 > t.length || k + 12 > r.length) break;
      tm[y] = t.sublist(k, k + 12);
      rm[y] = r.sublist(k, k + 12);
      final vt = tm[y]!.where((v) => !v.isNaN).toList(), vr = rm[y]!.where((v) => !v.isNaN).toList();
      ty.add(vt.length == 12 ? vt.reduce((a, b) => a + b) / 12 : double.nan);
      ry.add(vr.length == 12 ? vr.reduce((a, b) => a + b) : double.nan);
    }
    out.add(NasaClimate((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble(), y0, y0 + ty.length - 1, ty, ry, tm, rm));
  }
  return out;
}
