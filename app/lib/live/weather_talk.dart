// Nói thời tiết trực tiếp thành câu NGẮN, DỄ NGHE (thuần Dart → test được), và lời khuyên "nên làm gì".
// Lời khuyên viết cho người khiếm thị: có lưu ý đi lại (đường trơn, gió mạnh, dông) chứ không chỉ "mang ô".
// Chạy được không cần AI; khi có Gemini, app có thể nhờ Gemini trả lời tự nhiên hơn.
import 'dart:math' as math;

import 'live_weather.dart';

typedef Say = (String, String); // (tiếng Việt, tiếng Anh)

const _dowVi = ['thứ hai', 'thứ ba', 'thứ tư', 'thứ năm', 'thứ sáu', 'thứ bảy', 'chủ nhật'];
const _dowEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

int _r(double x) => x.isNaN ? 0 : x.round();

/// Tên ngày: hôm nay / ngày mai / thứ … ngày d/m.
Say dayName(LiveDay d, DateTime today) {
  final t0 = DateTime(today.year, today.month, today.day);
  final diff = DateTime(d.date.year, d.date.month, d.date.day).difference(t0).inDays;
  if (diff == 0) return ('Hôm nay', 'Today');
  if (diff == 1) return ('Ngày mai', 'Tomorrow');
  if (diff == 2) return ('Ngày kia', 'The day after tomorrow');
  final w = d.date.weekday - 1;
  return ('${_cap(_dowVi[w])} ngày ${d.date.day} tháng ${d.date.month}', _dowEn[w]);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _uvVi(double uv) => uv >= 11
    ? 'cực kỳ cao'
    : uv >= 8
        ? 'rất cao'
        : uv >= 6
            ? 'cao'
            : uv >= 3
                ? 'trung bình'
                : 'thấp';

String _aqiVi(int a) => a > 200
    ? 'rất xấu'
    : a > 150
        ? 'xấu'
        : a > 100
            ? 'kém, không tốt cho người nhạy cảm'
            : a > 50
                ? 'trung bình'
                : 'tốt';

/// "Bây giờ ở Huế: 29 độ, có mây…"
Say nowText(String placeVi, String placeEn, LiveWeather w, {bool kid = false}) {
  final n = w.now;
  final vi = StringBuffer('Bây giờ ở $placeVi: ${_r(n.temp)} độ');
  final en = StringBuffer('Now in $placeEn: ${_r(n.temp)} degrees');
  final wmoEn = wmoText(n.code).$2;
  final descEn = wmoEn.isNotEmpty ? wmoEn : n.desc;
  if (n.desc.isNotEmpty) vi.write(', ${n.desc}');
  if (descEn.isNotEmpty) en.write(', $descEn');
  if ((n.feels - n.temp).abs() >= 2) {
    vi.write(', cảm giác như ${_r(n.feels)} độ');
    en.write(', feels like ${_r(n.feels)}');
  }
  vi.write('.');
  en.write('.');
  if (!kid) {
    vi.write(' Độ ẩm ${n.humidity} phần trăm, gió ${_r(n.wind)} ki-lô-mét một giờ.');
    en.write(' Humidity ${n.humidity} percent, wind ${_r(n.wind)} kilometres per hour.');
  }
  final r = rainNext(w, hours: 6);
  vi.write(' ${r.$1}');
  en.write(' ${r.$2}');
  if (w.aqi != null && w.aqi! > 100) {
    vi.write(' Không khí ${_aqiVi(w.aqi!)}.');
    en.write(' Air quality is poor.');
  }
  return (vi.toString(), en.toString());
}

/// Mưa trong vài giờ tới.
Say rainNext(LiveWeather w, {int hours = 12}) {
  final hs = w.hours.take(hours).toList();
  if (hs.isEmpty) return ('', '');
  final first = hs.where((h) => (h.rainProb ?? 0) >= 50 || isRainy(h.code) && (h.rainProb ?? 60) >= 40).firstOrNull;
  final maxP = hs.map((h) => h.rainProb ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
  if (first == null) {
    return maxP >= 30
        ? ('Trong $hours giờ tới có thể có mưa, khả năng $maxP phần trăm.', 'Possible rain in the next $hours hours, $maxP percent.')
        : ('Trong $hours giờ tới ít khả năng mưa.', 'Rain is unlikely in the next $hours hours.');
  }
  final now = DateTime.now();
  final soon = first.time.difference(now).inMinutes < 60;
  final thunder = hs.any((h) => isThunder(h.code));
  final kindVi = thunder ? 'mưa dông' : 'mưa';
  return soon
      ? ('Sắp có $kindVi, khả năng ${first.rainProb ?? maxP} phần trăm.', 'Rain is likely soon, ${first.rainProb ?? maxP} percent.')
      : ('Có thể $kindVi từ khoảng ${first.time.hour} giờ, khả năng ${first.rainProb ?? maxP} phần trăm.',
          'Rain is likely from about ${first.time.hour} o\'clock, ${first.rainProb ?? maxP} percent.');
}

/// Một ngày: "Ngày mai ở Huế: mưa rào, từ 24 đến 30 độ, khả năng mưa 80 phần trăm, khoảng 15 mi-li-mét."
Say dayText(String placeVi, String placeEn, LiveDay d, {DateTime? today, bool kid = false}) {
  final n = dayName(d, today ?? DateTime.now());
  final vi = StringBuffer('${n.$1} ở $placeVi: ');
  final en = StringBuffer('${n.$2} in $placeEn: ');
  final wmoEn = wmoText(d.code).$2;
  final descEn = wmoEn.isNotEmpty ? wmoEn : d.desc;
  if (d.desc.isNotEmpty) vi.write('${d.desc}, ');
  if (descEn.isNotEmpty) en.write('$descEn, ');
  vi.write('từ ${_r(d.tmin)} đến ${_r(d.tmax)} độ');
  en.write('${_r(d.tmin)} to ${_r(d.tmax)} degrees');
  if (d.rainProb != null) {
    vi.write(', khả năng mưa ${d.rainProb} phần trăm');
    en.write(', ${d.rainProb} percent chance of rain');
  }
  if (!kid && d.rainMm != null && d.rainMm! >= 1) {
    vi.write(', khoảng ${_r(d.rainMm!)} mi-li-mét');
    en.write(', about ${_r(d.rainMm!)} millimetres');
  }
  if (!kid && d.uv != null && d.uv! >= 6) {
    vi.write(', tia UV ${_uvVi(d.uv!)}');
    en.write(', high UV');
  }
  vi.write('.');
  en.write('.');
  return (vi.toString(), en.toString());
}

/// Mấy ngày tới, mỗi ngày một câu ngắn. [from]: 0 = bắt đầu từ hôm nay, 1 = từ ngày mai ("3 ngày tới").
/// Có tối đa 10 ngày dự báo; hỏi nhiều hơn thì nói rõ là chỉ có 10 ngày.
Say weekText(String placeVi, String placeEn, LiveWeather w, {int days = 5, int from = 0, DateTime? today}) {
  final t = today ?? DateTime.now();
  final avail = (w.days.length - from).clamp(0, 10);
  final n = days.clamp(1, avail == 0 ? 1 : avail);
  final vi = StringBuffer(), en = StringBuffer();
  if (days > avail) {
    vi.write('Mình chỉ có dự báo tối đa $avail ngày tới. ');
    en.write('I only have a forecast for the next $avail days. ');
  }
  vi.write(from == 1 && n == 1 ? '' : 'Dự báo $n ngày ${from == 1 ? 'tới ' : ''}ở $placeVi. ');
  en.write(from == 1 && n == 1 ? '' : '$n-day forecast for $placeEn. ');
  for (final d in w.days.skip(from).take(n)) {
    final dn = dayName(d, t);
    final dWmoEn = wmoText(d.code).$2;
    final dDescEn = dWmoEn.isNotEmpty ? dWmoEn : d.desc;
    vi.write('${dn.$1}${from == 1 && n == 1 ? ' ở $placeVi' : ''}: ${d.desc.isEmpty ? '' : '${d.desc}, '}${_r(d.tmin)} đến ${_r(d.tmax)} độ'
        '${d.rainProb != null && d.rainProb! >= 30 ? ', mưa ${d.rainProb} phần trăm' : ''}'
        '${d.rainMm != null && d.rainMm! >= 5 && (d.rainProb ?? 0) >= 50 ? ', khoảng ${_r(d.rainMm!)} mi-li-mét' : ''}. ');
    en.write('${dn.$2}: ${dDescEn.isEmpty ? '' : '$dDescEn, '}${_r(d.tmin)} to ${_r(d.tmax)}'
        '${d.rainProb != null && d.rainProb! >= 30 ? ', rain ${d.rainProb} percent' : ''}. ');
  }
  return (vi.toString().trim(), en.toString().trim());
}

/// Lời khuyên cho một ngày (0 = hôm nay, dùng cả số liệu "bây giờ"). Trả về danh sách câu.
List<Say> adviceFor(LiveWeather w, {int day = 0, bool kid = false}) {
  final d = w.days.length > day ? w.days[day] : null;
  final today = day == 0;
  final tmax = d?.tmax ?? w.now.temp;
  final tmin = d?.tmin ?? w.now.temp;
  final feels = today ? w.now.feels : tmax;
  final prob = [
    d?.rainProb ?? 0,
    if (today) ...w.hours.take(12).map((h) => h.rainProb ?? 0),
  ].fold<int>(0, (a, b) => a > b ? a : b);
  final mm = d?.rainMm ?? 0;
  final thunder = (d != null && isThunder(d.code)) || (today && w.hours.take(12).any((h) => isThunder(h.code)));
  final uv = d?.uv ?? (today ? w.now.uv : null) ?? 0;
  final wind = d?.windMax ?? (today ? w.now.wind : 0);
  final fog = today && (w.now.code == 45 || w.now.code == 48);
  final out = <Say>[];

  if (mm >= 50) {
    out.add(kid
        ? ('Mưa rất to. Con nên ở trong nhà và nghe lời người lớn.', 'Very heavy rain. Stay indoors and listen to grown-ups.')
        : ('Mưa rất to, có thể ngập. Hạn chế đi xa và theo dõi tin cảnh báo của cơ quan khí tượng.',
            'Very heavy rain, possible flooding. Avoid long trips and follow official warnings.'));
  }
  if (thunder) {
    out.add(kid
        ? ('Có dông sét. Con ở trong nhà, đừng đứng dưới gốc cây.', 'Thunderstorms. Stay inside and never shelter under a tree.')
        : ('Có dông sét: ở trong nhà khi có sấm, không trú dưới gốc cây hay cột điện.',
            'Thunderstorms: stay indoors during thunder, not under trees or power poles.'));
  }
  if (prob >= 50 || mm >= 5) {
    out.add(kid
        ? ('Nhớ mang áo mưa hoặc ô nhé.', 'Remember a raincoat or umbrella.')
        : ('Nên mang ô hoặc áo mưa. Đường có thể trơn, đi chậm và dò đường cẩn thận.',
            'Take an umbrella or raincoat. Paths may be slippery; walk slowly and carefully.'));
  } else if (prob >= 30) {
    out.add(('Có thể mưa rải rác, mang theo áo mưa mỏng cho chắc.', 'Scattered showers possible; a light raincoat is a good idea.'));
  }
  if (tmax >= 35 || feels >= 38) {
    out.add(kid
        ? ('Trời nắng nóng. Uống nhiều nước, đội mũ, chơi trong bóng râm.', 'Hot weather. Drink water, wear a hat, play in the shade.')
        : ('Nắng nóng: uống đủ nước, tránh ra ngoài từ 11 giờ đến 15 giờ, mặc đồ thoáng.',
            'Hot: drink plenty of water, avoid going out from 11 to 3, wear light clothes.'));
  }
  final sun = sunHours(w, day);
  if (sun != null) {
    out.add(sun);
  } else if (uv >= 8 && tmax < 35) {
    out.add(('Tia UV ${_uvVi(uv)}: đội mũ rộng vành, đeo kính và bôi kem chống nắng khi ra ngoài.',
        'Very high UV: wear a wide hat, sunglasses and sunscreen outdoors.'));
  }
  if (tmin <= 12) {
    out.add(kid
        ? ('Trời rét. Mặc áo ấm, đội mũ len, đeo tất nhé.', 'Cold. Wear a warm coat, hat and socks.')
        : ('Trời rét: mặc nhiều lớp áo ấm, giữ ấm cổ, tay và chân; người già và trẻ nhỏ hạn chế ra ngoài sáng sớm.',
            'Cold: dress in warm layers; elderly people and children should avoid early mornings outside.'));
  } else if (tmin <= 17) {
    out.add(('Trời se lạnh, nên mang thêm áo khoác.', 'Chilly; bring a jacket.'));
  }
  if (wind >= 40) {
    out.add(('Gió mạnh: cẩn thận khi đi bộ ngoài trời, tránh đi biển và chỗ có cây to.',
        'Strong wind: take care outdoors, avoid the sea and big trees.'));
  }
  if (fog) {
    out.add(('Có sương mù, xe cộ khó thấy người đi bộ: đi sát lề và cẩn thận khi qua đường.',
        'Fog: drivers may not see pedestrians; keep to the side and cross carefully.'));
  }
  final aqi = w.aqi;
  // bụi mịn PM2.5 vượt ngưỡng (35 µg/m³ ≈ mức "không tốt cho người nhạy cảm") dù AQI chưa quá 100
  if (today && (aqi == null || aqi <= 100) && (w.pm25 ?? 0) >= 35) {
    // nói rõ để không mâu thuẫn với câu "không khí trung bình" đọc trước đó
    out.add(('Chỉ số không khí chung chưa xấu, nhưng riêng bụi mịn PM2.5 khá cao, khoảng ${_r(w.pm25!)} micro-gam: nên đeo khẩu trang khi ra đường.',
        'The overall air index is not bad, but fine dust PM2.5 is high: wear a mask outdoors.'));
  }
  if (today && (w.dust ?? 0) >= 100) {
    out.add(('Nhiều bụi trong không khí: đeo khẩu trang, bảo vệ mắt.', 'Lots of dust in the air: wear a mask, protect your eyes.'));
  } else if (today && (w.aod ?? 0) >= 0.8) {
    out.add(('Trời mù do khói bụi (sol khí dày): người hen suyễn nên hạn chế ra ngoài.',
        'Hazy with smoke or dust: people with asthma should limit time outdoors.'));
  }
  if (today && aqi != null && aqi > 100) {
    out.add(kid
        ? ('Không khí không tốt. Đeo khẩu trang và chơi trong nhà nhé.', 'The air is not clean. Wear a mask and play indoors.')
        : ('Không khí ${_aqiVi(aqi)}: đeo khẩu trang, hạn chế tập thể dục ngoài trời.',
            'Poor air quality: wear a mask, limit outdoor exercise.'));
  }
  if (out.isEmpty) {
    out.add(kid
        ? ('Thời tiết dễ chịu, hợp để ra ngoài chơi.', 'Nice weather, good for playing outside.')
        : ('Thời tiết dễ chịu, thuận lợi để ra ngoài.', 'Pleasant weather, good for going out.'));
  }
  return out;
}

/// Gộp lời khuyên thành một đoạn để đọc.
/// Nếu [isLocal] = true (khu vực người dùng đang ở): nhấn mạnh lời khuyên khi ra ngoài.
/// Nếu [isLocal] = false (nơi khác): gợi ý hành trang/lưu ý khi đến nơi đó hoặc ra ngoài tại đó.
Say adviceText(String placeVi, String placeEn, LiveWeather w, {int day = 0, bool kid = false, bool isLocal = false}) {
  final tips = adviceFor(w, day: day, kid: kid);
  final lbl = day == 0
      ? ('Hôm nay', 'Today')
      : day == 1
          ? ('Ngày mai', 'Tomorrow')
          : ('Ngày đó', 'That day');
  if (isLocal) {
    return (
      '${lbl.$1} ở chỗ bạn ($placeVi), khi ra ngoài lưu ý: ${tips.map((t) => t.$1).join(' ')}',
      '${lbl.$2} where you are ($placeEn), when going out: ${tips.map((t) => t.$2).join(' ')}',
    );
  }
  return (
    '${lbl.$1} ở $placeVi: ${tips.map((t) => t.$1).join(' ')}',
    '${lbl.$2} in $placeEn: ${tips.map((t) => t.$2).join(' ')}',
  );
}

/// Câu gợi ý chủ động đính kèm sau thông tin thời tiết cơ bản:
/// - Nếu là khu vực người dùng đang ở ([isLocal] = true): gợi ý người dùng cần chuẩn bị gì khi ra ngoài.
/// - Nếu là một địa phương/điểm đến khác ([isLocal] = false): gợi ý người dùng cần chuẩn bị gì khi đến nơi này.
Say contextualSuggestion(String placeVi, String placeEn, LiveWeather w, {int day = 0, bool isLocal = false, bool kid = false}) {
  final tips = adviceFor(w, day: day, kid: kid);
  final isPleasantOnly = tips.length == 1 && tips.first.$1.contains('dễ chịu');
  if (isLocal) {
    if (isPleasantOnly) {
      return (
        kid
            ? 'Thời tiết dễ chịu, rất hợp để con ra ngoài chơi.'
            : 'Thời tiết dễ chịu, rất thuận lợi nếu bạn muốn ra ngoài đi dạo hay đi công việc.',
        kid ? 'Nice weather, great for playing outside.' : 'Pleasant weather, great if you plan to head outside.',
      );
    }
    return (
      'Khi ra ngoài bạn lưu ý: ${tips.map((t) => t.$1).join(' ')}',
      'When going out: ${tips.map((t) => t.$2).join(' ')}',
    );
  } else {
    if (isPleasantOnly) {
      return (
        kid
            ? 'Thời tiết ở $placeVi rất dễ chịu, hợp để đến chơi.'
            : 'Thời tiết ở $placeVi khá dễ chịu, rất thuận lợi nếu bạn muốn đến tham quan hoặc ra ngoài dạo chơi.',
        'Weather in $placeEn is pleasant, great for visiting or going out.',
      );
    }
    return (
      'Nếu đến $placeVi hoặc ra ngoài tại đây, bạn nên chuẩn bị: ${tips.map((t) => t.$1).join(' ')}',
      'If visiting or going out in $placeEn: ${tips.map((t) => t.$2).join(' ')}',
    );
  }
}


String _lbl(int day) => day == 0
    ? 'Hôm nay'
    : (day == 1 ? 'Ngày mai' : (day == 2 ? 'Ngày kia' : _cap(_dowVi[DateTime.now().add(Duration(days: day)).weekday - 1])));
String _lblEn(int day) =>
    day == 0 ? 'Today' : (day == 1 ? 'Tomorrow' : 'On ${_dowEn[DateTime.now().add(Duration(days: day)).weekday - 1]}');

/// Mức mưa theo giờ (mm/giờ): nhỏ < 2,5 · vừa < 8 · to.
String _rateVi(double mmH) => mmH < 2.5 ? 'mưa nhỏ' : (mmH < 8 ? 'mưa vừa' : 'mưa to');
String _rateEn(double mmH) => mmH < 2.5 ? 'light' : (mmH < 8 ? 'moderate' : 'heavy');

/// Mức mưa cả ngày (mm/24 giờ, cách phân cấp của khí tượng Việt Nam): nhỏ < 16 · vừa ≤ 50 · to ≤ 100 · rất to.
String _dayRainVi(double mm) => mm < 16 ? 'mưa nhỏ' : (mm <= 50 ? 'mưa vừa' : (mm <= 100 ? 'mưa to' : 'mưa rất to'));
String _dayRainEn(double mm) => mm < 16 ? 'light' : (mm <= 50 ? 'moderate' : (mm <= 100 ? 'heavy' : 'very heavy'));

/// "lúc 15 giờ" / "lúc 2 giờ sáng mai"
(String, String) _at(DateTime t) {
  final now = DateTime.now();
  final tomorrow = t.day != now.day;
  final h = t.hour;
  final part = h < 11 ? 'sáng' : (h < 13 ? 'trưa' : (h < 18 ? 'chiều' : 'tối'));
  final hh = h > 12 ? h - 12 : h;
  final vi = h == 0 ? '12 giờ đêm' : '$hh giờ $part';
  return (tomorrow ? (h == 0 ? 'nửa đêm nay' : '$vi mai') : vi, tomorrow ? '$h:00 tomorrow' : '$h:00');
}

/// "Hà Nội có mưa không?" → trả lời THẲNG: đang mưa / có / có thể / không, tỉ lệ, lúc nào, lượng mưa.
/// Chỉ nói về mưa (không kèm nhiệt độ, độ ẩm…): muốn đủ thì hỏi "thời tiết".
Say rainAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  final d = w.days.length > day ? w.days[day] : null;
  final mm = d?.rainMm ?? 0;
  final l = _lbl(day), le = _lblEn(day);
  final vi = StringBuffer(), en = StringBuffer();
  if (day == 0) {
    final n = w.now;
    final hs = w.hours.take(12).toList();
    final thunder = isThunder(n.code) || hs.take(6).any((h) => isThunder(h.code));
    final kind = thunder ? 'mưa dông' : 'mưa';
    final rainingNow = isRainy(n.code) || n.precip >= 0.2;
    if (rainingNow) {
      vi.write('Có. Ở $placeVi đang $kind');
      en.write('Yes. It is raining in $placeEn now');
      if (n.precip >= 0.1) {
        vi.write(', ${_rateVi(n.precip)}, khoảng ${n.precip < 1 ? 'dưới 1' : _r(n.precip)} mi-li-mét một giờ');
        en.write(', ${_rateEn(n.precip)}, about ${n.precip.toStringAsFixed(1)} millimetres per hour');
      }
      vi.write('.');
      en.write('.');
      // bao giờ tạnh: giờ đầu tiên khả năng mưa dưới 30 phần trăm và không còn mã mưa
      final stop = hs.skip(1).where((h) => (h.rainProb ?? 0) < 30 && !isRainy(h.code)).firstOrNull;
      if (stop != null) {
        final at = _at(stop.time);
        vi.write(' Có thể tạnh khoảng ${at.$1}.');
        en.write(' It may stop around ${at.$2}.');
      } else {
        vi.write(' Mưa có thể còn kéo dài vài giờ nữa.');
        en.write(' It may continue for several hours.');
      }
    } else {
      final maxP = hs.map((h) => h.rainProb ?? 0).fold<int>(d?.rainProb ?? 0, (a, b) => a > b ? a : b);
      final first = hs.where((h) => (h.rainProb ?? 0) >= 50 || isRainy(h.code) && (h.rainProb ?? 60) >= 40).firstOrNull;
      final at = first == null ? null : _at(first.time);
      if (maxP >= 60) {
        vi.write('Có. $placeVi hiện chưa mưa nhưng nhiều khả năng sẽ $kind, khoảng $maxP phần trăm'
            '${at != null ? ', từ khoảng ${at.$1}' : ''}.');
        en.write('Yes. Not raining yet in $placeEn, but rain is likely, about $maxP percent'
            '${at != null ? ', from around ${at.$2}' : ''}.');
      } else if (maxP >= 30) {
        vi.write('Có thể. $placeVi hiện không mưa, khả năng $kind khoảng $maxP phần trăm'
            '${at != null ? ', dễ mưa nhất khoảng ${at.$1}' : ' trong 12 giờ tới'}.');
        en.write('Maybe. Not raining in $placeEn now, about a $maxP percent chance of rain in the next 12 hours.');
      } else {
        vi.write('Không. $placeVi hiện không mưa, 12 giờ tới ít khả năng mưa, chỉ khoảng $maxP phần trăm.');
        en.write('No. It is not raining in $placeEn, and rain is unlikely in the next 12 hours, about $maxP percent.');
      }
    }
    if (mm >= 1) {
      vi.write(' Lượng mưa cả ngày khoảng ${_r(mm)} mi-li-mét, ${_dayRainVi(mm)}.');
      en.write(' About ${_r(mm)} millimetres for the day, ${_dayRainEn(mm)}.');
    }
    if (rainingNow || hs.any((h) => (h.rainProb ?? 0) >= 50)) {
      vi.write(' Nhớ mang ô hoặc áo mưa.');
      en.write(' Take an umbrella.');
    }
    return (vi.toString(), en.toString());
  }
  if (d == null) return ('Chưa có dự báo mưa cho ngày đó ở $placeVi.', 'No rain forecast for that day in $placeEn yet.');
  final prob = d.rainProb ?? 0;
  final thunder = isThunder(d.code);
  final kind = thunder ? 'mưa dông' : 'mưa';
  if (prob >= 60 || mm >= 5) {
    vi.write('Có. $l ở $placeVi nhiều khả năng $kind, khoảng $prob phần trăm');
    en.write('Yes. $le in $placeEn rain is likely, about $prob percent');
  } else if (prob >= 30) {
    vi.write('Có thể. $l ở $placeVi có khả năng $kind khoảng $prob phần trăm');
    en.write('Maybe. $le in $placeEn there is a $prob percent chance of rain');
  } else {
    vi.write('Không. $l ở $placeVi ít khả năng mưa, chỉ khoảng $prob phần trăm');
    en.write('No. $le in $placeEn rain is unlikely, about $prob percent');
  }
  if (mm >= 1 && prob >= 30) {
    vi.write(', lượng mưa khoảng ${_r(mm)} mi-li-mét, ${_dayRainVi(mm)}');
    en.write(', about ${_r(mm)} millimetres, ${_dayRainEn(mm)}');
  }
  vi.write('.');
  en.write('.');
  return (vi.toString(), en.toString());
}

/// "Nhiệt độ Hà Nội bây giờ?" → chỉ nhiệt độ. [period]: "chiều nay bao nhiêu độ" → nhiệt độ các giờ của buổi đó.
Say tempAnswer(String placeVi, String placeEn, LiveWeather w, int day, {String? period}) {
  final d = w.days.length > day ? w.days[day] : null;
  if (period != null) {
    final hs = hoursOf(w, day, period);
    if (hs.isNotEmpty) {
      final lo = hs.map((h) => h.temp).reduce(math.min), hi = hs.map((h) => h.temp).reduce(math.max);
      final when = _dayWord(day, period);
      final range = _r(lo) == _r(hi) ? 'khoảng ${_r(lo)} độ' : 'khoảng ${_r(lo)} đến ${_r(hi)} độ';
      final feel = hi >= 35 ? ', nóng, nên tránh ra nắng' : (lo <= 15 ? ', lạnh, nhớ mặc ấm' : (lo <= 20 ? ', hơi se lạnh' : ''));
      return ('$when ở $placeVi $range$feel.', '${_r(lo)} to ${_r(hi)} degrees in $placeEn.');
    }
  }
  if (day == 0) {
    final n = w.now;
    final vi = StringBuffer('Bây giờ ở $placeVi ${_r(n.temp)} độ');
    final en = StringBuffer('It is ${_r(n.temp)} degrees in $placeEn now');
    if ((n.feels - n.temp).abs() >= 2) {
      vi.write(', cảm giác như ${_r(n.feels)} độ');
      en.write(', feels like ${_r(n.feels)}');
    }
    vi.write('.');
    en.write('.');
    if (d != null) {
      vi.write(' Hôm nay thấp nhất ${_r(d.tmin)}, cao nhất ${_r(d.tmax)} độ.');
      en.write(' Today ${_r(d.tmin)} to ${_r(d.tmax)} degrees.');
    }
    return (vi.toString(), en.toString());
  }
  if (d == null) return ('Chưa có dự báo nhiệt độ cho ngày đó ở $placeVi.', 'No temperature forecast for that day in $placeEn yet.');
  return ('${_lbl(day)} ở $placeVi thấp nhất ${_r(d.tmin)}, cao nhất ${_r(d.tmax)} độ.',
      '${_lblEn(day)} in $placeEn ${_r(d.tmin)} to ${_r(d.tmax)} degrees.');
}

/// Độ ẩm (chỉ có số liệu hiện tại).
Say humidAnswer(String placeVi, String placeEn, LiveWeather w) {
  final h = w.now.humidity;
  final word = h >= 85 ? 'rất ẩm, dễ nồm và oi' : (h >= 70 ? 'khá ẩm' : (h >= 40 ? 'dễ chịu' : 'khô, nên uống đủ nước'));
  return ('Độ ẩm ở $placeVi bây giờ $h phần trăm, $word.', 'Humidity in $placeEn is $h percent now.');
}

/// Gió: hôm nay theo hiện tại, ngày khác theo gió mạnh nhất.
Say windAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  final d = w.days.length > day ? w.days[day] : null;
  final v = day == 0 ? w.now.wind : (d?.windMax ?? double.nan);
  if (v.isNaN) return ('Chưa có dự báo gió cho ngày đó ở $placeVi.', 'No wind forecast for that day in $placeEn yet.');
  final word = v < 12
      ? 'gió nhẹ'
      : v < 30
          ? 'gió vừa'
          : v < 50
              ? 'gió mạnh, cẩn thận khi đi xe máy'
              : 'gió rất mạnh, nên hạn chế ra ngoài';
  final dir = day == 0 && w.now.windDir != null ? ', hướng ${w.now.windDir}' : '';
  return (
    day == 0
        ? 'Gió ở $placeVi bây giờ ${_r(v)} ki-lô-mét một giờ$dir, $word.'
        : '${_lbl(day)} ở $placeVi gió mạnh nhất khoảng ${_r(v)} ki-lô-mét một giờ, $word.',
    day == 0 ? 'Wind in $placeEn is ${_r(v)} kilometres per hour now.' : '${_lblEn(day)} in $placeEn wind up to ${_r(v)} km/h.'
  );
}

/// Chỉ số UV.
Say uvAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  final d = w.days.length > day ? w.days[day] : null;
  final uv = day == 0 ? (w.now.uv ?? d?.uv) : d?.uv;
  if (uv == null) return ('Chưa có số liệu tia UV ở $placeVi.', 'No UV data for $placeEn.');
  final sun = sunHours(w, day);
  // hỏi lúc tối / đêm ("chỉ số UV hôm nay"): UV bây giờ là 0 — nói thêm mức cao nhất ban ngày hôm nay và ngày mai
  var peakVi = '', peakEn = '';
  final dayUv = d?.uv;
  if (day == 0 && uv < 1 && dayUv != null && dayUv >= 1) {
    final next = w.days.length > 1 ? w.days[1].uv : null;
    peakVi = ' Ban ngày hôm nay cao nhất ${_r(dayUv)}, ${_uvVi(dayUv)}.'
        '${next != null ? ' Ngày mai cao nhất ${_r(next)}, ${_uvVi(next)}${next >= 6 ? ', nên che nắng' : ''}.' : ''}';
    peakEn = " Today's peak is ${_r(dayUv)}.${next != null ? ' Tomorrow up to ${_r(next)}.' : ''}";
  }
  return (
    '${day == 0 ? 'Chỉ số UV ở $placeVi bây giờ' : '${_lbl(day)} chỉ số UV ở $placeVi cao nhất'} ${_r(uv)}, ${_uvVi(uv)}.'
        '${uv >= 6 ? ' Nên che nắng.' : ''}$peakVi${peakVi.isEmpty && sun != null ? ' ${sun.$1}' : ''}',
    'UV index in $placeEn is ${_r(uv)}.$peakEn${peakEn.isEmpty && sun != null ? ' ${sun.$2}' : ''}'
  );
}

/// Chất lượng không khí.
Say airAnswer(String placeVi, String placeEn, LiveWeather w) {
  final a = w.aqi;
  if (a == null) return ('Chưa có số liệu chất lượng không khí ở $placeVi.', 'No air quality data for $placeEn.');
  final pm = w.pm25 != null ? ', bụi mịn PM2.5 khoảng ${_r(w.pm25!)} micro-gam mỗi mét khối' : '';
  return ('Không khí ở $placeVi ${_aqiVi(a)}, chỉ số AQI $a$pm.${a > 100 ? ' Nên đeo khẩu trang khi ra ngoài.' : ''}',
      'Air quality index in $placeEn is $a.${a > 100 ? ' Consider a mask outdoors.' : ''}');
}

/// "Mai tôi đi chơi có phù hợp không?" → nhận xét PHÙ HỢP / KHÁ PHÙ HỢP / KHÔNG PHÙ HỢP kèm lý do.
Say outingAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  final d = w.days.length > day ? w.days[day] : null;
  final l = _lbl(day), le = _lblEn(day);
  if (d == null) return ('Mình chưa có dự báo cho ngày đó.', 'No forecast for that day yet.');
  final prob = d.rainProb ?? 0;
  final bad = <String>[], minor = <String>[];
  if (isThunder(d.code)) bad.add('có dông sét');
  if (prob >= 60 || (d.rainMm ?? 0) >= 10) {
    bad.add('dễ mưa, khoảng $prob phần trăm');
  } else if (prob >= 30) {
    minor.add('có thể mưa $prob phần trăm');
  }
  if (d.tmax >= 36) {
    bad.add('nắng nóng tới ${_r(d.tmax)} độ');
  } else if (d.tmax >= 33) {
    minor.add('khá nóng, ${_r(d.tmax)} độ');
  }
  if (d.tmin <= 10) {
    bad.add('rét, thấp nhất ${_r(d.tmin)} độ');
  } else if (d.tmin <= 15) {
    minor.add('se lạnh buổi sáng');
  }
  if ((d.windMax ?? 0) >= 45) {
    bad.add('gió mạnh');
  } else if ((d.windMax ?? 0) >= 30) {
    minor.add('gió khá mạnh');
  }
  if ((d.uv ?? 0) >= 8) minor.add('tia UV rất cao');
  if (day == 0 && (w.aqi ?? 0) > 150) {
    bad.add('không khí xấu');
  } else if (day == 0 && (w.aqi ?? 0) > 100) {
    minor.add('không khí kém');
  }
  final summary = '${d.desc.isEmpty ? '' : '${d.desc}, '}từ ${_r(d.tmin)} đến ${_r(d.tmax)} độ, khả năng mưa $prob phần trăm';
  if (bad.isNotEmpty) {
    return (
      'Không thật phù hợp. $l ở $placeVi ${bad.join(', ')}. $summary. Nếu vẫn đi, nên chọn chỗ có mái che và đi cùng người quen.',
      'Not ideal. $le in $placeEn the weather is poor for an outing. ${_r(d.tmin)} to ${_r(d.tmax)} degrees, $prob percent rain.'
    );
  }
  if (minor.isNotEmpty) {
    return (
      'Khá phù hợp, nhưng lưu ý ${minor.join(', ')}. $l ở $placeVi $summary.',
      'Fairly good, with some caveats. $le in $placeEn ${_r(d.tmin)} to ${_r(d.tmax)} degrees, $prob percent rain.'
    );
  }
  return (
    'Phù hợp. $l ở $placeVi $summary, thuận lợi để đi chơi.',
    'Yes, a good day. $le in $placeEn ${_r(d.tmin)} to ${_r(d.tmax)} degrees, $prob percent rain.'
  );
}


// ======================= Theo buổi, giờ tránh nắng, bản tin sáng =======================

/// Buổi trong ngày → (giờ bắt đầu, giờ kết thúc). 'dem' kéo sang sáng hôm sau.
(int, int) periodHours(String p) => switch (p) {
      'sang' => (5, 11),
      'trua' => (11, 14),
      'chieu' => (13, 18),
      'toi' => (18, 22),
      'dem' => (22, 30),
      _ => (0, 24),
    };

String periodVi(String p) => switch (p) {
      'sang' => 'sáng',
      'trua' => 'trưa',
      'chieu' => 'chiều',
      'toi' => 'tối',
      'dem' => 'đêm',
      _ => '',
    };

/// Các giờ dự báo thuộc một buổi của ngày [day] (0 hôm nay, 1 mai…) — giờ địa phương của nơi đó.
List<LiveHour> hoursOf(LiveWeather w, int day, String period) {
  if (w.days.isEmpty) return const [];
  final d0 = w.days.first.date;
  final base = DateTime(d0.year, d0.month, d0.day + day);
  final (a, b) = periodHours(period);
  final from = base.add(Duration(hours: a)), to = base.add(Duration(hours: b));
  return [for (final h in w.hours) if (!h.time.isBefore(from) && h.time.isBefore(to)) h];
}

String _dayWord(int day, String period) {
  final p = periodVi(period);
  if (day == 0) return p.isEmpty ? 'Hôm nay' : '${p[0].toUpperCase()}${p.substring(1)} nay';
  if (day == 1) return p.isEmpty ? 'Ngày mai' : '${p[0].toUpperCase()}${p.substring(1)} mai';
  if (day == 2) return p.isEmpty ? 'Ngày kia' : '${p[0].toUpperCase()}${p.substring(1)} ngày kia';
  final dow = _dowVi[DateTime.now().add(Duration(days: day)).weekday - 1];
  return p.isEmpty ? _cap(dow) : '${p[0].toUpperCase()}${p.substring(1)} $dow';
}

/// "Chiều nay có mưa không?" — chỉ xét các giờ của buổi đó.
Say periodRainAnswer(String placeVi, String placeEn, LiveWeather w, int day, String period) {
  final hs = hoursOf(w, day, period);
  if (hs.isEmpty) return rainAnswer(placeVi, placeEn, w, day);
  final when = _dayWord(day, period);
  var prob = 0;
  LiveHour? first;
  for (final h in hs) {
    final p = h.rainProb ?? 0;
    if (p > prob) prob = p;
    if (first == null && (p >= 50 || isRainy(h.code))) first = h;
  }
  final thunder = hs.any((h) => isThunder(h.code));
  if (prob >= 60) {
    return (
      'Có. $when ở $placeVi nhiều khả năng ${thunder ? 'mưa dông' : 'mưa'}, khoảng $prob phần trăm'
          '${first != null ? ', từ khoảng ${first.time.hour} giờ' : ''}. Nên mang ô hoặc áo mưa.',
      'Yes. Rain is likely $when in $placeEn, about $prob percent. Take an umbrella.'
    );
  }
  if (prob >= 30) {
    return (
      'Có thể. $when ở $placeVi có khả năng mưa $prob phần trăm. Mang theo áo mưa mỏng cho chắc.',
      'Maybe. $prob percent chance of rain $when in $placeEn.'
    );
  }
  return ('Không. $when ở $placeVi ít khả năng mưa, chỉ khoảng $prob phần trăm.',
      'No. Rain is unlikely $when in $placeEn, about $prob percent.');
}

/// Giờ nắng gắt (UV ≥ 6) trong ngày [day]: "tránh nắng từ 10 giờ đến 15 giờ". null nếu không có số liệu UV theo giờ.
Say? sunHours(LiveWeather w, int day) {
  final hs = hoursOf(w, day, '');
  final withUv = hs.where((h) => h.uv != null).toList();
  if (withUv.isEmpty) return null;
  final hot = withUv.where((h) => h.uv! >= 6).toList();
  if (hot.isEmpty) return null;
  final peak = hot.map((h) => h.uv!).reduce((a, b) => a > b ? a : b);
  final a = hot.first.time.hour, b = hot.last.time.hour + 1;
  return (
    'Nắng gắt, chỉ số UV ${_uvVi(peak)}, từ khoảng $a giờ đến $b giờ: nên tránh ra ngoài trong khung giờ đó; nếu phải đi thì đội mũ rộng vành, '
        'mặc áo dài tay, bôi kem chống nắng.',
    'Strong sun (UV up to ${_r(peak)}) from about $a to $b: avoid going out then, or wear a hat and sunscreen.'
  );
}

/// Bản tin sáng: bây giờ, cả ngày, mưa theo buổi, giờ tránh nắng, không khí, lời khuyên.
Say morningBulletin(String placeVi, String placeEn, LiveWeather w) {
  final n = w.now;
  final vi = StringBuffer('Bản tin thời tiết hôm nay ở $placeVi. Bây giờ ${_r(n.temp)} độ${n.desc.isEmpty ? '' : ', ${n.desc}'}. ');
  final en = StringBuffer('Today\'s weather in $placeEn. Now ${_r(n.temp)} degrees. ');
  if (w.days.isNotEmpty) {
    final d = w.days.first;
    vi.write('Cả ngày từ ${_r(d.tmin)} đến ${_r(d.tmax)} độ. ');
    en.write('${_r(d.tmin)} to ${_r(d.tmax)} degrees today. ');
  }
  final parts = <String>[];
  for (final p in const ['sang', 'chieu', 'toi']) {
    final hs = hoursOf(w, 0, p);
    if (hs.isEmpty) continue;
    final prob = hs.map((h) => h.rainProb ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    final word = prob >= 60 ? 'dễ mưa' : (prob >= 30 ? 'có thể mưa' : 'ít mưa');
    parts.add('${periodVi(p)} $word');
  }
  if (parts.isNotEmpty) vi.write('Mưa: ${parts.join(', ')}. ');
  final a = w.aqi;
  if (a != null) {
    vi.write('Không khí ${a > 150 ? 'xấu' : (a > 100 ? 'kém' : (a > 50 ? 'trung bình' : 'tốt'))}. ');
    en.write('Air quality index $a. ');
  }
  final tips = adviceFor(w);
  vi.write('Lời khuyên: ${tips.map((t) => t.$1).join(' ')}');
  en.write('Tips: ${tips.map((t) => t.$2).join(' ')}');
  return (vi.toString().trim(), en.toString().trim());
}

// ======================= trời nắng / mây, mặt trời mọc lặn, phơi đồ, so sánh, cuối tuần =======================

String _hm(DateTime t) => t.minute == 0 ? '${t.hour} giờ' : '${t.hour} giờ ${t.minute}';
String _hmEn(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

/// Trời nắng, mây hay mưa — theo mã thời tiết.
String _skyVi(int code, {bool night = false}) {
  if (isThunder(code)) return 'có dông';
  if (isRainy(code)) return 'đang có mưa';
  if (code == 45 || code == 48) return 'có sương mù, nhìn xa kém';
  if (code >= 71 && code <= 86) return 'có tuyết';
  if (code <= 1) return night ? 'trời quang, không mây' : 'trời quang, có nắng';
  if (code == 2) return night ? 'có ít mây' : 'có mây, lúc nắng lúc râm';
  if (code == 3) return 'nhiều mây, âm u, không có nắng';
  return 'không rõ';
}

String _skyEn(int code) {
  if (isThunder(code)) return 'thunderstorms';
  if (isRainy(code)) return 'rain';
  if (code == 45 || code == 48) return 'fog';
  if (code <= 1) return 'clear and sunny';
  if (code == 2) return 'partly cloudy';
  if (code == 3) return 'overcast';
  return 'unclear';
}

/// "Trời có nắng không?" → trời quang / mây / mưa, có tính ban đêm.
Say skyAnswer(String placeVi, String placeEn, LiveWeather w, int day, {String? period}) {
  if (period != null) {
    final hs = hoursOf(w, day, period);
    if (hs.isNotEmpty) {
      // mã gặp nhiều nhất trong buổi (mưa / dông được ưu tiên vì quan trọng hơn)
      final rainy = hs.where((h) => isRainy(h.code)).length;
      final counts = <int, int>{};
      for (final h in hs) {
        counts[h.code] = (counts[h.code] ?? 0) + 1;
      }
      final code = rainy * 3 >= hs.length ? hs.firstWhere((h) => isRainy(h.code)).code : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final night = period == 'toi' || period == 'dem';
      return ('${_dayWord(day, period)} ở $placeVi ${_skyVi(code, night: night)}.', '${_skyEn(code)} in $placeEn.');
    }
  }
  final d = w.days.length > day ? w.days[day] : null;
  if (day == 0) {
    final now = DateTime.now();
    final night = d?.sunrise != null && d?.sunset != null && (now.isBefore(d!.sunrise!) || now.isAfter(d.sunset!));
    var vi = 'Bây giờ ở $placeVi ${night ? 'là ban đêm, ' : ''}${_skyVi(w.now.code, night: night)}.';
    if (!night && w.now.code <= 2 && (w.now.uv ?? 0) >= 6) vi += ' Nắng khá gắt, chỉ số UV ${_r(w.now.uv!)}, nên che nắng.';
    return (vi, 'Now in $placeEn: ${night ? 'night, ' : ''}${_skyEn(w.now.code)}.');
  }
  if (d == null) return ('Chưa có dự báo cho ngày đó ở $placeVi.', 'No forecast for that day in $placeEn yet.');
  return ('${_lbl(day)} ở $placeVi ${_skyVi(d.code)}${(d.uv ?? 0) >= 8 ? ', nắng gắt buổi trưa' : ''}.',
      '${_lblEn(day)} in $placeEn: ${_skyEn(d.code)}.');
}

/// "Mấy giờ mặt trời mọc / lặn?"
Say sunAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  final d = w.days.length > day ? w.days[day] : null;
  if (d == null || d.sunrise == null || d.sunset == null) {
    return ('Mình chưa có giờ mặt trời mọc, lặn ở $placeVi.', 'I don\'t have sunrise and sunset times for $placeEn.');
  }
  final len = d.sunset!.difference(d.sunrise!);
  final dark = d.sunset!.add(const Duration(minutes: 25));
  return (
    '${_lbl(day)} ở $placeVi mặt trời mọc lúc ${_hm(d.sunrise!)}, lặn lúc ${_hm(d.sunset!)}. '
        'Trời tối hẳn khoảng ${_hm(dark)}. Ban ngày dài ${len.inHours} giờ ${len.inMinutes % 60} phút.',
    '${_lblEn(day)} in $placeEn sunrise is at ${_hmEn(d.sunrise!)} and sunset at ${_hmEn(d.sunset!)}.'
  );
}

/// "Có nên phơi quần áo không?" → nhìn khả năng mưa các giờ ban ngày, nắng, độ ẩm.
Say dryAnswer(String placeVi, String placeEn, LiveWeather w, int day) {
  var hs = hoursOf(w, day, '').where((h) => h.time.hour >= 7 && h.time.hour <= 17).toList();
  // hỏi lúc tối / đêm (đã qua giờ phơi ban ngày hoặc chỉ còn 1-2 giờ): xét các giờ tiếp theo
  if ((hs.isEmpty || hs.length < 3) && day == 0) {
    final from = DateTime.now().subtract(const Duration(hours: 1));
    final next = w.hours.where((h) => h.time.isAfter(from)).take(12).toList();
    if (next.isNotEmpty) hs = next;
  }
  final d = w.days.length > day ? w.days[day] : null;
  final maxP = hs.isEmpty ? (d?.rainProb ?? 0) : hs.map((h) => h.rainProb ?? 0).reduce(math.max);
  final rainingNow = day == 0 && (isRainy(w.now.code) || w.now.precip >= 0.2);
  final sunny = hs.isEmpty ? (d != null && d.code <= 2) : hs.where((h) => h.code <= 2).length * 2 >= hs.length;
  final humid = day == 0 ? w.now.humidity : null;
  final l = _lbl(day);
  if (rainingNow || maxP >= 60) {
    return (
      '${rainingNow ? 'Đang mưa' : '$l ở $placeVi dễ mưa, khoảng $maxP phần trăm'}. Không nên phơi ngoài trời, phơi trong nhà hoặc chỗ có mái che.',
      'Rain is likely ($maxP percent). Better dry your clothes indoors.'
    );
  }
  if (maxP >= 30) {
    return ('$l ở $placeVi có thể mưa, khoảng $maxP phần trăm. Phơi được nhưng nên phơi chỗ có mái che, hoặc để ý thu đồ khi trời tối sầm.',
        'There is a $maxP percent chance of rain. You can, but keep the washing under cover.');
  }
  if (humid != null && humid >= 85) {
    return ('$l ở $placeVi ít mưa nhưng độ ẩm cao, $humid phần trăm, đồ sẽ lâu khô${sunny ? ', nên phơi chỗ có nắng và gió' : ''}.',
        'Little rain, but humidity is $humid percent, so clothes will dry slowly.');
  }
  return ('$l ở $placeVi phơi đồ tốt: ít khả năng mưa, chỉ khoảng $maxP phần trăm${sunny ? ', trời có nắng' : ''}.',
      'Good day for drying clothes: only $maxP percent chance of rain${sunny ? ', and sunny' : ''}.');
}

/// So sánh hai nơi: nhiệt độ và khả năng mưa.
Say compareAnswer(String aVi, String aEn, LiveWeather a, String bVi, String bEn, LiveWeather b, int day) {
  double t(LiveWeather w) => day == 0 ? w.now.temp : (w.days.length > day ? w.days[day].tmax : double.nan);
  int p(LiveWeather w) {
    if (day == 0) return w.hours.take(12).map((h) => h.rainProb ?? 0).fold(w.days.isEmpty ? 0 : (w.days.first.rainProb ?? 0), math.max);
    return w.days.length > day ? (w.days[day].rainProb ?? 0) : 0;
  }

  final ta = t(a), tb = t(b);
  if (ta.isNaN || tb.isNaN) return ('Chưa có dự báo ngày đó để so sánh.', 'No forecast for that day to compare.');
  final diff = (_r(ta) - _r(tb)).abs();
  final when = day == 0 ? 'Bây giờ' : _lbl(day);
  final which = day == 0 ? '' : ' cao nhất';
  var vi = '$when, $aVi$which ${_r(ta)} độ, $bVi ${_r(tb)} độ. ';
  vi += diff == 0 ? 'Hai nơi nóng như nhau. ' : '${ta > tb ? aVi : bVi} nóng hơn $diff độ. ';
  final pa = p(a), pb = p(b);
  vi += 'Khả năng mưa: $aVi $pa, $bVi $pb phần trăm';
  vi += (pa - pb).abs() < 15 ? '.' : ', ${pa > pb ? aVi : bVi} dễ mưa hơn.';
  final en = '$aEn ${_r(ta)} degrees, $bEn ${_r(tb)} degrees. Chance of rain: $aEn $pa, $bEn $pb percent.';
  return (vi, en);
}

/// Cuối tuần này: thứ bảy và chủ nhật (hôm nay là chủ nhật thì chỉ hôm nay).
Say weekendText(String placeVi, String placeEn, LiveWeather w, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final we = w.days.where((d) {
    final diff = DateTime(d.date.year, d.date.month, d.date.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    return diff >= 0 && diff <= 6 && (d.date.weekday == 6 || d.date.weekday == 7);
  }).take(2).toList();
  if (we.isEmpty) return ('Chưa có dự báo cuối tuần ở $placeVi.', 'No weekend forecast for $placeEn yet.');
  final vi = StringBuffer('Cuối tuần ở $placeVi. ');
  final en = StringBuffer('This weekend in $placeEn. ');
  for (final d in we) {
    final n = dayName(d, t);
    vi.write('${n.$1}: ${d.desc.isEmpty ? '' : '${d.desc}, '}${_r(d.tmin)} đến ${_r(d.tmax)} độ'
        '${d.rainProb != null ? ', khả năng mưa ${d.rainProb} phần trăm' : ''}. ');
    en.write('${n.$2}: ${_r(d.tmin)} to ${_r(d.tmax)}${d.rainProb != null ? ', rain ${d.rainProb} percent' : ''}. ');
  }
  final wet = we.any((d) => (d.rainProb ?? 0) >= 60);
  vi.write(wet ? 'Có ngày dễ mưa, nhớ mang áo mưa nếu ra ngoài.' : 'Cuối tuần ít mưa, thuận tiện ra ngoài.');
  return (vi.toString().trim(), en.toString().trim());
}

