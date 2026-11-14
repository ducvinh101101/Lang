// F2 — số liệu thiên thể NASA (planets_nasa.json: NSSDCA Planetary Fact Sheet + "sự thật thú vị" của NASA Science).
// Thuần Dart để test được. [PlanetBody.loaded] được kho NasaNormalizedRepo điền khi app mở; các phần trả lời câu hỏi,
// "sự thật thú vị" và trò chơi Hệ Mặt Trời lấy số liệu từ đây làm NỀN TẢNG SỰ THẬT (chưa nạp thì dùng số liệu dự phòng).
import 'dart:math' as math;

class PlanetFact {
  final String vi, en;
  const PlanetFact(this.vi, this.en);
}

class PlanetBody {
  final String id;
  final int sound; // 0 Mặt Trời … 9 Sao Hải Vương (trùng chỉ số âm thanh / Planet.sound)
  final String nameVi, nameEn, typeVi;
  final double diameterKm, sizeVsEarth;
  final String peaVi, peaEn;
  final double distSunMkm; // triệu km
  final double? distEarthMkm;
  final double lightMinutes;
  final double rotationHours, solarDayHours, orbitalDays;
  final double meanTempC;
  final String? tempRangeVi;
  final double gravityVsEarth;
  final int moons;
  final String moonsNoteVi, moonsNoteEn;
  final bool rings;
  final List<PlanetFact> funFacts;
  final String sourceUrl, factsSourceUrl;

  const PlanetBody({
    required this.id,
    required this.sound,
    required this.nameVi,
    required this.nameEn,
    this.typeVi = '',
    required this.diameterKm,
    required this.sizeVsEarth,
    this.peaVi = '',
    this.peaEn = '',
    required this.distSunMkm,
    this.distEarthMkm,
    required this.lightMinutes,
    required this.rotationHours,
    required this.solarDayHours,
    required this.orbitalDays,
    required this.meanTempC,
    this.tempRangeVi,
    required this.gravityVsEarth,
    required this.moons,
    this.moonsNoteVi = '',
    this.moonsNoteEn = '',
    this.rings = false,
    this.funFacts = const [],
    this.sourceUrl = '',
    this.factsSourceUrl = '',
  });

  /// Bộ số liệu NASA đã nạp (rỗng nếu chưa nạp xong).
  static List<PlanetBody> loaded = const [];

  static PlanetBody? bySound(int sound) {
    for (final b in loaded) {
      if (b.sound == sound) return b;
    }
    return null;
  }

  bool get isPlanet => sound != 0 && sound != 4;

  factory PlanetBody.fromJson(Map<String, dynamic> j) {
    double d(String k, [double fb = 0]) => (j[k] as num?)?.toDouble() ?? fb;
    return PlanetBody(
      id: '${j['id']}',
      sound: (j['sound_index'] as num).toInt(),
      nameVi: '${j['name_vi'] ?? ''}',
      nameEn: '${j['name_en'] ?? ''}',
      typeVi: '${j['body_type_vi'] ?? ''}',
      diameterKm: d('diameter_km'),
      sizeVsEarth: d('size_vs_earth', 1),
      peaVi: '${j['pea_model_vi'] ?? ''}',
      peaEn: '${j['pea_model_en'] ?? ''}',
      distSunMkm: d('distance_from_sun_mkm'),
      distEarthMkm: (j['distance_from_earth_mkm'] as num?)?.toDouble(),
      lightMinutes: d('light_time_minutes'),
      rotationHours: d('rotation_period_hours'),
      solarDayHours: d('solar_day_hours'),
      orbitalDays: d('orbital_period_days'),
      meanTempC: d('mean_temp_c'),
      tempRangeVi: j['temp_range_vi'] as String?,
      gravityVsEarth: d('gravity_vs_earth', 1),
      moons: (j['moons_count'] as num?)?.toInt() ?? 0,
      moonsNoteVi: '${j['moons_note_vi'] ?? ''}',
      moonsNoteEn: '${j['moons_note_en'] ?? ''}',
      rings: j['has_rings'] == true,
      funFacts: [
        for (final f in (j['fun_facts'] as List? ?? const []))
          if (f is Map) PlanetFact('${f['vi'] ?? ''}', '${f['en'] ?? ''}')
      ],
      sourceUrl: '${j['source_url'] ?? ''}',
      factsSourceUrl: '${j['fun_facts_source_url'] ?? ''}',
    );
  }

  // ---------- câu nói từ số liệu ----------

  /// Một năm (vòng quanh Mặt Trời) nói thành lời.
  String yearVi() {
    if (orbitalDays <= 0) return '';
    if (orbitalDays < 1000) return '${_n(orbitalDays, 0)} ngày Trái Đất';
    return '${_n(orbitalDays / 365.25, orbitalDays / 365.25 < 20 ? 1 : 0)} năm Trái Đất';
  }

  String yearEn() {
    if (orbitalDays <= 0) return '';
    if (orbitalDays < 1000) return '${_n(orbitalDays, 0, en: true)} Earth days';
    return '${_n(orbitalDays / 365.25, orbitalDays / 365.25 < 20 ? 1 : 0, en: true)} Earth years';
  }

  /// Một ngày (mặt trời mọc → mọc lại) nói thành lời.
  String dayVi() {
    final h = solarDayHours.abs();
    if (h <= 0) return '';
    if (h < 48) {
      final hh = h.floor(), mm = ((h - hh) * 60).round();
      return mm >= 5 ? '$hh giờ $mm phút' : '$hh giờ';
    }
    return '${_n(h / 24, h / 24 < 10 ? 1 : 0)} ngày Trái Đất';
  }

  String dayEn() {
    final h = solarDayHours.abs();
    if (h <= 0) return '';
    if (h < 48) return '${_n(h, 1, en: true)} hours';
    return '${_n(h / 24, h / 24 < 10 ? 1 : 0, en: true)} Earth days';
  }

  /// Khoảng cách tới Mặt Trời.
  String distVi() => distSunMkm >= 1000
      ? '${_n(distSunMkm / 1000, 1)} tỉ ki-lô-mét'
      : '${_n(distSunMkm, 0)} triệu ki-lô-mét';
  String distEn() => distSunMkm >= 1000
      ? '${_n(distSunMkm / 1000, 1, en: true)} billion kilometres'
      : '${_n(distSunMkm, 0, en: true)} million kilometres';

  /// Chọn ngẫu nhiên một sự thật thú vị (tránh lặp lại [avoid] nếu có thể).
  /// [en]: chỉ chọn sự thật có bản tiếng Anh (bản NASA Space Place chỉ có tiếng Việt).
  PlanetFact? randomFact(math.Random r, {PlanetFact? avoid, bool en = false}) {
    final pool = en ? funFacts.where((f) => f.en.isNotEmpty).toList() : funFacts;
    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;
    PlanetFact f;
    do {
      f = pool[r.nextInt(pool.length)];
    } while (identical(f, avoid) || (avoid != null && f.vi == avoid.vi));
    return f;
  }

  /// Sự thật có đủ hai thứ tiếng (dùng cho trò chơi: câu hỏi phải đọc được ở cả hai chế độ).
  List<PlanetFact> get bilingualFacts => [for (final f in funFacts) if (f.en.isNotEmpty && f.vi.isNotEmpty) f];
}

/// Số kiểu Việt (dấu phẩy thập phân, chấm ngăn nghìn) hoặc kiểu Anh.
String _n(double x, int dec, {bool en = false}) {
  final s = x.abs().toStringAsFixed(dec);
  final parts = s.split('.');
  final ip = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) b.write(en ? ',' : '.');
    b.write(ip[i]);
  }
  var out = b.toString();
  if (parts.length > 1 && int.parse(parts[1]) != 0) out += (en ? '.' : ',') + parts[1];
  return x < 0 ? '-$out' : out;
}
