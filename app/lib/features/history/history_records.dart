// F1 — LỊCH SỬ THỜI TIẾT & THIÊN TAI: dựng các BẢN GHI để phát lại (thuần Dart, test được).
//
//  • Khoảng thời gian ≤ 3 năm (≤ 36 tháng) → mỗi bản ghi là MỘT THÁNG; dài hơn → mỗi bản ghi là MỘT NĂM.
//  • Mỗi bản ghi có: nhiệt độ, lượng mưa, so với trung bình cùng kỳ; mức "nóng / lạnh / mưa" (0..1) để phối âm,
//    loại chiếm chủ đạo; danh sách thiên tai trong kỳ, xếp từ NHẸ đến NẶNG.
//  • Thiên tai gồm hai nguồn:
//      – suy ra từ số liệu NASA POWER của chính nơi đó (mưa lớn bất thường, thiếu mưa / hạn, nắng nóng, rét đậm);
//      – sự kiện ghi nhận được (NASA EONET: bão, lũ, cháy rừng, núi lửa, sạt lở; USGS: động đất; bộ dữ liệu
//        chuẩn hoá của app: siêu bão Yagi 2024, lũ lịch sử miền Trung 2020) — truyền vào qua [HazardEvent].
import 'dart:math' as math;

import '../../core/format.dart' show fmtNum;

enum HazardKind { cold, heat, drought, heavyRain, wildfire, storm, flood, landslide, volcano, earthquake }

String hazardNameVi(HazardKind k) => switch (k) {
      HazardKind.cold => 'rét đậm',
      HazardKind.heat => 'nắng nóng',
      HazardKind.drought => 'khô hạn',
      HazardKind.heavyRain => 'mưa lớn bất thường',
      HazardKind.wildfire => 'cháy rừng',
      HazardKind.storm => 'bão',
      HazardKind.flood => 'lũ lụt',
      HazardKind.landslide => 'sạt lở đất',
      HazardKind.volcano => 'núi lửa',
      HazardKind.earthquake => 'động đất',
    };

String hazardNameEn(HazardKind k) => switch (k) {
      HazardKind.cold => 'cold spell',
      HazardKind.heat => 'heat',
      HazardKind.drought => 'drought',
      HazardKind.heavyRain => 'unusually heavy rain',
      HazardKind.wildfire => 'wildfire',
      HazardKind.storm => 'storm',
      HazardKind.flood => 'flood',
      HazardKind.landslide => 'landslide',
      HazardKind.volcano => 'volcano',
      HazardKind.earthquake => 'earthquake',
    };

/// Một sự kiện thiên tai đã ghi nhận (từ EONET, USGS, dữ liệu chuẩn hoá…).
class HazardEvent {
  final HazardKind kind;
  final DateTime date;
  final double severity; // 1 (nhẹ) … 5 (rất nặng)
  final String titleVi, titleEn;
  final String source;
  final double? distanceKm;
  final bool yearOnly;
  const HazardEvent(this.kind, this.date, this.severity, this.titleVi, this.titleEn,
      {this.source = '', this.distanceKm, this.yearOnly = false});
}

/// Thiên tai trong một bản ghi (đã gắn vào kỳ của bản ghi).
class Hazard {
  final HazardKind kind;
  final double severity; // 1..5
  final String vi, en; // câu mô tả ngắn để đọc khi giải thích
  final bool observed; // true: sự kiện ghi nhận; false: suy ra từ số liệu
  const Hazard(this.kind, this.severity, this.vi, this.en, {this.observed = false});

  String get nameVi => hazardNameVi(kind);
  String get nameEn => hazardNameEn(kind);
}

/// Mức các yếu tố thời tiết của một bản ghi để phối âm và vẽ hiệu ứng (0..1).
class WeatherMix {
  final double heat, cold, rain;
  const WeatherMix(this.heat, this.cold, this.rain);

  /// Loại chiếm chủ đạo: 'heat' | 'cold' | 'rain' | 'mild' (ôn hoà).
  String get dominant {
    final m = math.max(heat, math.max(cold, rain));
    if (m < 0.22) return 'mild';
    if (m == rain) return 'rain';
    return m == heat ? 'heat' : 'cold';
  }

  String get dominantVi => switch (dominant) {
        'heat' => 'nắng nóng',
        'cold' => 'lạnh',
        'rain' => 'mưa',
        _ => 'ôn hoà',
      };
  String get dominantEn => switch (dominant) {
        'heat' => 'heat',
        'cold' => 'cold',
        'rain' => 'rain',
        _ => 'mild weather',
      };
}

class HistoryRecord {
  final int year;
  final int? month; // 1..12; null = bản ghi cả năm
  final double temp; // °C (tháng: trung bình tháng; năm: trung bình năm)
  final double rain; // mm (tháng: tổng tháng; năm: tổng năm)
  final double tempNormal, rainNormal; // trung bình cùng kỳ của cả chuỗi
  final double hotMonth, coldMonth; // bản ghi năm: tháng nóng nhất / lạnh nhất (°C); bản ghi tháng: = temp
  final WeatherMix mix;
  final List<Hazard> hazards; // từ nhẹ đến nặng
  const HistoryRecord({
    required this.year,
    required this.month,
    required this.temp,
    required this.rain,
    required this.tempNormal,
    required this.rainNormal,
    required this.hotMonth,
    required this.coldMonth,
    required this.mix,
    required this.hazards,
  });

  bool get monthly => month != null;
  DateTime get start => DateTime(year, month ?? 1);
  DateTime get end => monthly ? DateTime(year, month! + 1) : DateTime(year + 1);
  bool covers(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  String get labelVi => monthly ? 'Tháng $month/$year' : 'Năm $year';
  String get labelEn => monthly ? '${_monthsEn[month! - 1]} $year' : '$year';
  String get spokenLabelVi => monthly ? 'Tháng $month năm $year' : 'Năm $year';

  /// Câu giải thích đầy đủ (khi người dùng chạm màn hình lúc đang phát).
  String explainVi() {
    final b = StringBuffer('$spokenLabelVi. ');
    if (!temp.isNaN) {
      b.write('Nhiệt độ trung bình ${fmtNum(temp, 1)} độ');
      final d = temp - tempNormal;
      if (!tempNormal.isNaN) {
        b.write(d.abs() < 0.3
            ? ', gần mức thường lệ'
            : ', ${d > 0 ? 'cao' : 'thấp'} hơn trung bình cùng kỳ ${fmtNum(d.abs(), 1)} độ');
      }
      if (!monthly && !hotMonth.isNaN && !coldMonth.isNaN) {
        b.write('; tháng nóng nhất ${fmtNum(hotMonth, 1)} độ, tháng lạnh nhất ${fmtNum(coldMonth, 1)} độ');
      }
      b.write('. ');
    }
    if (!rain.isNaN) {
      b.write('Lượng mưa ${fmtNum(rain, 0)} mi-li-mét');
      if (!rainNormal.isNaN && rainNormal > 1) {
        final r = rain / rainNormal;
        b.write(r > 1.15
            ? ', nhiều hơn trung bình ${((r - 1) * 100).round()} phần trăm'
            : r < 0.85
                ? ', ít hơn trung bình ${((1 - r) * 100).round()} phần trăm'
                : ', gần mức thường lệ');
      }
      b.write('. ');
    }
    b.write('Âm thanh chủ đạo: ${mix.dominantVi}. ');
    if (hazards.isEmpty) {
      b.write('Không ghi nhận thiên tai đáng kể.');
    } else {
      b.write('Thiên tai, từ nhẹ đến nặng: ${hazards.map((h) => h.vi).join('; ')}.');
    }
    return b.toString();
  }

  String explainEn() {
    final b = StringBuffer('$labelEn. ');
    if (!temp.isNaN) {
      b.write('Average temperature ${fmtNum(temp, 1, lang: 'en')} °C');
      final d = temp - tempNormal;
      if (!tempNormal.isNaN) {
        b.write(d.abs() < 0.3 ? ', about normal' : ', ${fmtNum(d.abs(), 1, lang: 'en')} degrees ${d > 0 ? 'above' : 'below'} normal');
      }
      b.write('. ');
    }
    if (!rain.isNaN) {
      b.write('Rainfall ${fmtNum(rain, 0, lang: 'en')} millimetres');
      if (!rainNormal.isNaN && rainNormal > 1) {
        final r = rain / rainNormal;
        b.write(r > 1.15
            ? ', ${((r - 1) * 100).round()} percent above normal'
            : r < 0.85
                ? ', ${((1 - r) * 100).round()} percent below normal'
                : ', about normal');
      }
      b.write('. ');
    }
    b.write('Main sound: ${mix.dominantEn}. ');
    b.write(hazards.isEmpty ? 'No notable hazards.' : 'Hazards, mildest first: ${hazards.map((h) => h.en).join('; ')}.');
    return b.toString();
  }
}

const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Khoảng thời gian đã chốt theo dữ liệu có sẵn.
class HistoryRange {
  final int y0, m0, y1, m1; // tháng 1..12, gồm cả hai đầu
  final bool cutAtDataEnd; // khoảng bị cắt ở tháng cuối có số liệu (người dùng hỏi tới tận bây giờ)
  const HistoryRange(this.y0, this.m0, this.y1, this.m1, {this.cutAtDataEnd = false});
  int get months => (y1 - y0) * 12 + (m1 - m0) + 1;
  bool get monthly => months <= 36;
  int get years => y1 - y0 + 1;

  /// Số liệu NASA chỉ có đến hết năm [y1] mà người dùng hỏi "N năm qua" vào năm sau đó → nói rõ, kẻo tưởng app sai năm.
  bool get _endsBeforeNow => cutAtDataEnd && y1 < DateTime.now().year;
  String describeVi() => (monthly
          ? 'từ tháng $m0 năm $y0 đến tháng $m1 năm $y1'
          : 'từ năm $y0 đến năm $y1') +
      (_endsBeforeNow ? ' (số liệu NASA mới có đến hết năm $y1)' : '') +
      (monthly ? ', mỗi bản ghi là một tháng' : ', mỗi bản ghi là một năm');
  String describeEn() => (monthly ? 'from $m0/$y0 to $m1/$y1' : 'from $y0 to $y1') +
      (_endsBeforeNow ? ' (NASA data currently ends in $y1)' : '') +
      (monthly ? ', one record per month' : ', one record per year');

  @override
  String toString() => 'HistoryRange($m0/$y0 → $m1/$y1)';
}

/// Chốt khoảng thời gian theo lệnh và dữ liệu có sẵn ([dataY0]..[dataY1], đủ 12 tháng mỗi năm).
///  • [spanMonths]: "3 năm qua" = 36, "6 tháng gần đây" = 6 — tính lùi từ tháng cuối cùng có số liệu.
///  • [from]/[to]: khoảng tuyệt đối ("từ 2015 đến 2020", "năm 2020").
///  • không nói gì: 5 năm gần nhất.
HistoryRange resolveRange({int? spanMonths, DateTime? from, DateTime? to, required int dataY0, required int dataY1}) {
  final lastIdx = dataY1 * 12 + 11; // tháng 12 năm cuối
  final firstIdx = dataY0 * 12;
  int a, b;
  if (from != null || to != null) {
    a = from != null ? from.year * 12 + from.month - 1 : firstIdx;
    b = to != null ? to.year * 12 + to.month - 1 : lastIdx;
  } else {
    final n = (spanMonths ?? 60).clamp(1, 12 * 200);
    b = lastIdx;
    a = b - n + 1;
  }
  if (a > b) (a, b) = (b, a);
  a = a.clamp(firstIdx, lastIdx);
  b = b.clamp(firstIdx, lastIdx);
  // hỏi "N năm qua" / "đến nay" (không có năm kết thúc cụ thể trước số liệu cuối) → khoảng kết thúc ở số liệu cuối
  final toNow = (from == null && to == null) || (to == null) || (to.year * 12 + to.month - 1 > lastIdx);
  return HistoryRange(a ~/ 12, a % 12 + 1, b ~/ 12, b % 12 + 1, cutAtDataEnd: toNow && b == lastIdx);
}

double _clamp01(double x) => x.isNaN ? 0 : x.clamp(0.0, 1.0).toDouble();

double _mean(Iterable<double> xs) {
  final v = xs.where((x) => !x.isNaN).toList();
  return v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
}

/// Mức nóng / lạnh / mưa của một tháng (0..1).
WeatherMix monthMix(double temp, double rain, double tempNormal) {
  final anom = tempNormal.isNaN || temp.isNaN ? 0.0 : temp - tempNormal;
  final heat = _clamp01((temp - 25) / 7 + 0.15 * anom);
  final cold = _clamp01((18 - temp) / 12 - 0.1 * anom);
  final wet = _clamp01(math.sqrt(math.max(0.0, rain.isNaN ? 0.0 : rain) / 420));
  return WeatherMix(heat, cold, wet);
}

/// Thiên tai suy ra từ số liệu của MỘT tháng.
List<Hazard> derivedMonthHazards(double temp, double rain, double tNorm, double rNorm) {
  final out = <Hazard>[];
  if (!rain.isNaN && !rNorm.isNaN && rNorm > 5) {
    final r = rain / rNorm;
    if (r >= 1.8 && rain >= 250) {
      final sev = (2 + (r - 1.8) * 0.9 + (rain >= 500 ? 0.6 : 0)).clamp(2.0, 4.2);
      out.add(Hazard(HazardKind.heavyRain, sev,
          'mưa lớn bất thường ${fmtNum(rain, 0)} mi-li-mét, gấp ${fmtNum(r, 1)} lần trung bình, nguy cơ lũ và ngập',
          'unusually heavy rain, ${fmtNum(rain, 0, lang: 'en')} mm, ${fmtNum(r, 1, lang: 'en')} times normal, flood risk'));
    } else if (rNorm >= 80 && rain <= 0.25 * rNorm) {
      final sev = (1.5 + (1 - rain / (0.25 * rNorm)) * 1.3).clamp(1.5, 2.8);
      out.add(Hazard(HazardKind.drought, sev,
          'thiếu mưa nghiêm trọng, chỉ ${fmtNum(rain, 0)} mi-li-mét so với thường lệ ${fmtNum(rNorm, 0)}, nguy cơ khô hạn',
          'severe rain deficit, only ${fmtNum(rain, 0, lang: 'en')} mm against a usual ${fmtNum(rNorm, 0, lang: 'en')}, drought risk'));
    }
  }
  if (!temp.isNaN && !tNorm.isNaN) {
    final d = temp - tNorm;
    if (d >= 1.5 && temp >= 28) {
      out.add(Hazard(HazardKind.heat, (1 + (d - 1.5) * 0.9).clamp(1.0, 3.2),
          'nắng nóng bất thường, trung bình ${fmtNum(temp, 1)} độ, cao hơn thường lệ ${fmtNum(d, 1)} độ',
          'unusual heat, averaging ${fmtNum(temp, 1, lang: 'en')} °C, ${fmtNum(d, 1, lang: 'en')} degrees above normal'));
    } else if (d <= -1.8 && temp <= 15) {
      out.add(Hazard(HazardKind.cold, (1 + (-d - 1.8) * 0.8).clamp(1.0, 3.0),
          'rét đậm bất thường, trung bình ${fmtNum(temp, 1)} độ, thấp hơn thường lệ ${fmtNum(-d, 1)} độ',
          'unusual cold, averaging ${fmtNum(temp, 1, lang: 'en')} °C, ${fmtNum(-d, 1, lang: 'en')} degrees below normal'));
    }
  }
  return out;
}

Hazard _fromEvent(HazardEvent e) {
  final when = '${e.date.day}/${e.date.month}/${e.date.year}';
  final far = e.distanceKm == null || e.distanceKm! < 30 ? '' : ', cách khoảng ${(e.distanceKm! / 10).round() * 10} ki-lô-mét';
  final farEn = e.distanceKm == null || e.distanceKm! < 30 ? '' : ', about ${(e.distanceKm! / 10).round() * 10} km away';
  final vi = e.yearOnly ? '${e.titleVi}$far' : '${e.titleVi} ngày $when$far';
  final en = e.yearOnly ? '${e.titleEn}$farEn' : '${e.titleEn}, ${e.date.year}-${e.date.month}-${e.date.day}$farEn';
  return Hazard(e.kind, e.severity, vi, en, observed: true);
}

/// Dựng các bản ghi phát lại.
///  [tempMonth]/[rainMonth]: năm → 12 tháng (°C, mm cả tháng), NaN nếu thiếu.
///  [events]: sự kiện thiên tai đã ghi nhận ở gần nơi đó (bất kỳ thời điểm nào; hàm tự lọc theo khoảng).
List<HistoryRecord> buildRecords({
  required Map<int, List<double>> tempMonth,
  required Map<int, List<double>> rainMonth,
  required HistoryRange range,
  List<HazardEvent> events = const [],
}) {
  // trung bình cùng tháng của cả chuỗi (để so sánh)
  final tN = List<double>.generate(12, (m) => _mean(tempMonth.values.map((v) => v.length > m ? v[m] : double.nan)));
  final rN = List<double>.generate(12, (m) => _mean(rainMonth.values.map((v) => v.length > m ? v[m] : double.nan)));
  double tAt(int y, int m) => (tempMonth[y]?.length ?? 0) > m ? tempMonth[y]![m] : double.nan;
  double rAt(int y, int m) => (rainMonth[y]?.length ?? 0) > m ? rainMonth[y]![m] : double.nan;

  final out = <HistoryRecord>[];
  if (range.monthly) {
    var y = range.y0, m = range.m0;
    for (var k = 0; k < range.months; k++) {
      final t = tAt(y, m - 1), r = rAt(y, m - 1);
      final rec = HistoryRecord(
        year: y,
        month: m,
        temp: t,
        rain: r,
        tempNormal: tN[m - 1],
        rainNormal: rN[m - 1],
        hotMonth: t,
        coldMonth: t,
        mix: monthMix(t, r, tN[m - 1]),
        hazards: const [],
      );
      out.add(_withHazards(rec, derivedMonthHazards(t, r, tN[m - 1], rN[m - 1]), events));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }
  final tYearNorm = _mean(tN), rYearNorm = rN.any((x) => x.isNaN) ? double.nan : rN.reduce((a, b) => a + b);
  for (var y = range.y0; y <= range.y1; y++) {
    final ts = [for (var m = 0; m < 12; m++) tAt(y, m)];
    final rs = [for (var m = 0; m < 12; m++) rAt(y, m)];
    final t = _mean(ts);
    final rainOk = rs.where((x) => !x.isNaN).length;
    final r = rainOk == 0 ? double.nan : rs.where((x) => !x.isNaN).reduce((a, b) => a + b) * 12 / rainOk;
    final vt = ts.where((x) => !x.isNaN).toList();
    final hot = vt.isEmpty ? double.nan : vt.reduce(math.max), cold = vt.isEmpty ? double.nan : vt.reduce(math.min);
    // mức của năm: nóng theo tháng nóng nhất, lạnh theo tháng lạnh nhất, mưa theo trung bình tháng
    final hotMix = monthMix(hot, double.nan, double.nan).heat;
    final coldMix = monthMix(cold, double.nan, double.nan).cold;
    final anom = t.isNaN || tYearNorm.isNaN ? 0.0 : t - tYearNorm;
    final mix = WeatherMix(_clamp01(hotMix + 0.2 * anom), _clamp01(coldMix - 0.15 * anom),
        _clamp01(math.sqrt(math.max(0.0, r.isNaN ? 0.0 : r / 12) / 420)));
    // thiên tai suy ra của 12 tháng → gộp theo loại (giữ tháng nặng nhất, đếm số tháng)
    final byKind = <HazardKind, (Hazard, int, int)>{}; // loại → (nặng nhất, số tháng, tháng nặng nhất)
    for (var m = 0; m < 12; m++) {
      for (final h in derivedMonthHazards(ts[m], rs[m], tN[m], rN[m])) {
        final prev = byKind[h.kind];
        if (prev == null) {
          byKind[h.kind] = (h, 1, m + 1);
        } else {
          byKind[h.kind] = h.severity > prev.$1.severity ? (h, prev.$2 + 1, m + 1) : (prev.$1, prev.$2 + 1, prev.$3);
        }
      }
    }
    final derived = [
      for (final e in byKind.entries)
        Hazard(e.key, math.min(5.0, e.value.$1.severity + 0.25 * (e.value.$2 - 1)),
            e.value.$2 > 1
                ? '${e.value.$2} tháng ${hazardNameVi(e.key)}, nặng nhất tháng ${e.value.$3}: ${e.value.$1.vi}'
                : 'tháng ${e.value.$3}: ${e.value.$1.vi}',
            e.value.$2 > 1
                ? '${e.value.$2} months of ${hazardNameEn(e.key)}, worst in ${_monthsEn[e.value.$3 - 1]}: ${e.value.$1.en}'
                : '${_monthsEn[e.value.$3 - 1]}: ${e.value.$1.en}')
    ];
    final rec = HistoryRecord(
      year: y,
      month: null,
      temp: t,
      rain: r,
      tempNormal: tYearNorm,
      rainNormal: rYearNorm,
      hotMonth: hot,
      coldMonth: cold,
      mix: mix,
      hazards: const [],
    );
    out.add(_withHazards(rec, derived, events));
  }
  return out;
}

HistoryRecord _withHazards(HistoryRecord r, List<Hazard> derived, List<HazardEvent> events) {
  final hs = <Hazard>[
    ...derived,
    for (final e in events)
      if (r.covers(e.date)) _fromEvent(e),
  ];
  // bản ghi năm có thể rất nhiều sự kiện: giữ tối đa 6, ưu tiên nặng nhất, rồi xếp lại từ nhẹ đến nặng
  hs.sort((a, b) => b.severity.compareTo(a.severity));
  final kept = hs.take(6).toList()..sort((a, b) => a.severity.compareTo(b.severity));
  return HistoryRecord(
    year: r.year,
    month: r.month,
    temp: r.temp,
    rain: r.rain,
    tempNormal: r.tempNormal,
    rainNormal: r.rainNormal,
    hotMonth: r.hotMonth,
    coldMonth: r.coldMonth,
    mix: r.mix,
    hazards: kept,
  );
}

/// Mức nặng cho sự kiện EONET (bão theo sức gió knots).
double eonetSeverity(String category, double? magnitude, String? unit) {
  switch (category) {
    case 'severeStorms':
      if (magnitude == null || unit != 'kts') return 3;
      return magnitude < 34 ? 2 : (magnitude < 64 ? 3 : (magnitude < 96 ? 4 : 5));
    case 'floods':
      return 3.5;
    case 'landslides':
      return 3.2;
    case 'volcanoes':
      return 4;
    case 'wildfires':
      return 2.2;
    case 'drought':
      return 2.5;
    case 'tempExtremes':
      return 2.5;
    default:
      return 2;
  }
}

/// Mức nặng của động đất theo độ lớn.
double quakeSeverity(double mag) => mag < 5 ? 2 : (mag < 6 ? 3 : (mag < 7 ? 4 : 5));

HazardKind? eonetKind(String category) => switch (category) {
      'severeStorms' => HazardKind.storm,
      'floods' => HazardKind.flood,
      'wildfires' => HazardKind.wildfire,
      'volcanoes' => HazardKind.volcano,
      'earthquakes' => HazardKind.earthquake,
      'landslides' => HazardKind.landslide,
      'drought' => HazardKind.drought,
      'tempExtremes' => HazardKind.heat,
      _ => null,
    };
