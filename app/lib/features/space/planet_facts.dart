// TRẢ LỜI CÂU HỎI VỀ HÀNH TINH KHÔNG CẦN AI (khi chưa có khoá Gemini, hoặc mất mạng).
// Số liệu tròn, dễ nhớ (NASA Planetary Fact Sheet), luôn kèm so sánh với Trái Đất / đồ vật quen thuộc.
//   "Sao Hỏa to bằng mấy Trái Đất", "cách Mặt Trời bao xa", "một ngày dài bao lâu", "có mấy mặt trăng",
//   "lên đó mình nặng bao nhiêu", "nóng hay lạnh", "có sự sống không", "bay tới mất bao lâu"
//   "how big is it compared to Earth", "how far", "how long is a day", "how many moons", "how much would I weigh"
import '../../data/planet_bodies.dart';
import '../voice/commands.dart' show normVi;

class _Facts {
  final double size; // đường kính so với Trái Đất
  final String dist, distEn; // khoảng cách
  final String day, dayEn;
  final String year, yearEn;
  final String moons, moonsEn;
  final double gravity; // so với Trái Đất
  final String temp, tempEn;
  final String life, lifeEn;
  final String trip, tripEn; // tàu vũ trụ bay tới mất bao lâu
  const _Facts(this.size, this.dist, this.distEn, this.day, this.dayEn, this.year, this.yearEn, this.moons, this.moonsEn,
      this.gravity, this.temp, this.tempEn, this.life, this.lifeEn, this.trip, this.tripEn);
}

const _f = <int, _Facts>{
  0: _Facts(109, 'cách Trái Đất khoảng 150 triệu ki-lô-mét; ánh sáng đi mất hơn 8 phút', 'about 150 million kilometres from Earth; light takes just over 8 minutes',
      'tự quay một vòng mất khoảng 27 ngày', 'spins once in about 27 days', 'là ngôi sao ở trung tâm, các hành tinh quay quanh nó', 'is the star at the centre; the planets go around it',
      'không có mặt trăng nào, nhưng có 8 hành tinh quay quanh', 'has no moons, but eight planets orbit it', 28,
      'bề mặt nóng khoảng 5.500 độ C, lõi tới 15 triệu độ', 'the surface is about 5,500 °C and the core about 15 million °C',
      'không thể có sự sống, quá nóng', 'far too hot for life', 'không tàu nào đáp xuống được; tàu Parker bay sát nhất', 'no spacecraft can land; the Parker probe flies closest'),
  1: _Facts(0.38, 'cách Mặt Trời khoảng 58 triệu ki-lô-mét, gần nhất trong các hành tinh', 'about 58 million kilometres from the Sun, the closest planet',
      'một ngày, từ lúc mặt trời mọc tới lần mọc sau, dài tới 176 ngày Trái Đất', 'one day, sunrise to sunrise, lasts 176 Earth days', 'một năm chỉ 88 ngày', 'a year is only 88 days',
      'không có mặt trăng nào', 'has no moons', 0.38, 'ban ngày nóng 430 độ C, ban đêm lạnh âm 180 độ', 'about 430 °C by day and minus 180 °C at night',
      'không có không khí để thở, chưa thấy sự sống', 'no air to breathe and no sign of life', 'tàu MESSENGER mất gần 7 năm mới vào được quỹ đạo', 'the MESSENGER probe took almost 7 years to reach orbit'),
  2: _Facts(0.95, 'cách Mặt Trời khoảng 108 triệu ki-lô-mét', 'about 108 million kilometres from the Sun',
      'một ngày dài khoảng 117 ngày Trái Đất, và mặt trời mọc ở hướng tây', 'a day lasts about 117 Earth days, and the Sun rises in the west', 'một năm 225 ngày', 'a year is 225 days',
      'không có mặt trăng nào', 'has no moons', 0.9, 'nóng khoảng 465 độ C, nóng nhất Hệ Mặt Trời, đủ làm chảy chì', 'about 465 °C, the hottest planet, hot enough to melt lead',
      'không khí dày đặc khí CO2 và mây a-xít, không thể sống', 'thick carbon dioxide air and acid clouds, no life', 'tàu vũ trụ bay tới mất khoảng 4 tới 6 tháng', 'a spacecraft takes about 4 to 6 months'),
  3: _Facts(1, 'cách Mặt Trời khoảng 150 triệu ki-lô-mét', 'about 150 million kilometres from the Sun',
      'một ngày dài 24 giờ', 'a day lasts 24 hours', 'một năm 365 ngày', 'a year is 365 days', 'có 1 mặt trăng', 'has one Moon', 1,
      'trung bình khoảng 15 độ C', 'about 15 °C on average', 'là nơi duy nhất ta biết có sự sống', 'is the only place we know has life',
      'là nhà của chúng ta', 'is our home'),
  4: _Facts(0.27, 'cách Trái Đất khoảng 384 nghìn ki-lô-mét, bằng 30 lần xếp Trái Đất thành hàng', 'about 384 thousand kilometres from Earth, about 30 Earths in a row',
      'một ngày, từ lúc mặt trời mọc tới lần mọc sau, dài khoảng 29 ngày rưỡi', 'one day, sunrise to sunrise, lasts about 29 and a half Earth days', 'quay quanh Trái Đất một vòng mất khoảng 27 ngày', 'goes around Earth in about 27 days',
      'chính nó là mặt trăng của Trái Đất', 'is Earth’s own moon', 0.17, 'ban ngày khoảng 120 độ C, ban đêm âm 170 độ', 'about 120 °C by day and minus 170 °C at night',
      'không có không khí, không có sự sống', 'no air and no life', 'tàu Apollo chở người bay tới mất khoảng 3 ngày', 'the Apollo astronauts took about 3 days'),
  5: _Facts(0.53, 'cách Mặt Trời khoảng 228 triệu ki-lô-mét', 'about 228 million kilometres from the Sun',
      'một ngày dài 24 giờ 37 phút, gần giống Trái Đất', 'a day lasts 24 hours 37 minutes, almost like Earth', 'một năm 687 ngày, gần gấp đôi năm của ta', 'a year is 687 days, almost two of ours',
      'có 2 mặt trăng nhỏ là Phobos và Deimos', 'has two small moons, Phobos and Deimos', 0.38, 'rất lạnh, trung bình âm 60 độ C', 'very cold, about minus 60 °C on average',
      'chưa tìm thấy sự sống; các xe tự hành của NASA đang tìm dấu vết nước và sự sống xưa', 'no life found yet; NASA rovers are searching for traces of ancient water and life', 'tàu vũ trụ bay tới mất khoảng 7 tháng', 'a spacecraft takes about 7 months'),
  6: _Facts(11.2, 'cách Mặt Trời khoảng 778 triệu ki-lô-mét', 'about 778 million kilometres from the Sun',
      'một ngày chỉ khoảng 10 giờ, quay nhanh nhất', 'a day is only about 10 hours, the fastest spin', 'một năm dài gần 12 năm Trái Đất', 'a year lasts almost 12 Earth years',
      'có khoảng 115 mặt trăng đã xác nhận, theo NASA tính đến năm 2026', 'has about 115 moons, according to NASA as of 2026', 2.5, 'đỉnh mây lạnh khoảng âm 110 độ C', 'cloud tops are about minus 110 °C',
      'là hành tinh khí, không có mặt đất để đứng', 'is a gas giant with no ground to stand on', 'tàu Juno bay tới mất khoảng 5 năm', 'the Juno probe took about 5 years'),
  7: _Facts(9.4, 'cách Mặt Trời khoảng 1,4 tỉ ki-lô-mét', 'about 1.4 billion kilometres from the Sun',
      'một ngày khoảng 10 giờ rưỡi', 'a day is about 10 and a half hours', 'một năm dài khoảng 29 năm Trái Đất', 'a year lasts about 29 Earth years',
      'có 293 mặt trăng đã xác nhận, nhiều nhất Hệ Mặt Trời, theo NASA tính đến năm 2026', 'has 293 confirmed moons, the most of any planet according to NASA as of 2026', 1.1, 'lạnh khoảng âm 140 độ C', 'about minus 140 °C',
      'là hành tinh khí, nhẹ tới mức có thể nổi trên nước', 'is a gas giant, light enough to float on water', 'tàu Cassini bay tới mất gần 7 năm', 'the Cassini probe took almost 7 years'),
  8: _Facts(4.0, 'cách Mặt Trời khoảng 2,9 tỉ ki-lô-mét', 'about 2.9 billion kilometres from the Sun',
      'một ngày khoảng 17 giờ, và nó nằm nghiêng mà lăn quanh Mặt Trời', 'a day is about 17 hours, and it rolls around the Sun on its side', 'một năm dài 84 năm Trái Đất', 'a year lasts 84 Earth years',
      'có khoảng 29 mặt trăng đã xác nhận, theo NASA tính đến năm 2026', 'has about 29 moons, according to NASA as of 2026', 0.9, 'rất lạnh, khoảng âm 195 độ C', 'very cold, about minus 195 °C',
      'là hành tinh băng khổng lồ, không thể sống', 'is an ice giant, no life', 'tàu Voyager 2 bay tới mất 8 năm rưỡi', 'Voyager 2 took eight and a half years'),
  9: _Facts(3.9, 'cách Mặt Trời khoảng 4,5 tỉ ki-lô-mét, xa nhất', 'about 4.5 billion kilometres from the Sun, the farthest planet',
      'một ngày khoảng 16 giờ', 'a day is about 16 hours', 'một năm dài 165 năm Trái Đất', 'a year lasts 165 Earth years',
      'có khoảng 16 mặt trăng đã xác nhận, theo NASA tính đến năm 2026', 'has about 16 moons, according to NASA as of 2026', 1.1, 'lạnh khoảng âm 200 độ C, gió mạnh nhất Hệ Mặt Trời', 'about minus 200 °C, with the strongest winds of any planet',
      'là hành tinh băng khổng lồ, không thể sống', 'is an ice giant, no life', 'tàu Voyager 2 bay tới mất 12 năm', 'Voyager 2 took 12 years'),
};

String _num(double x, bool en) {
  final s = x >= 10
      ? x.round().toString()
      : x < 1
          ? x.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '') // 0,165 → 0,17 (không làm tròn thành 0,2)
          : (x * 10).round() % 10 == 0
              ? x.round().toString()
              : x.toStringAsFixed(1);
  return en ? s : s.replaceAll('.', ',');
}

String _deg(double c, bool en) {
  final a = c.abs().round();
  final g = a >= 1000 ? '${a ~/ 1000}${en ? ',' : '.'}${(a % 1000).toString().padLeft(3, '0')}' : '$a';
  return c < 0 ? (en ? 'minus $g' : 'âm $g') : g;
}

/// Số liệu của thiên thể lấy từ NASA (planets_nasa.json) nếu đã nạp; thiếu phần nào thì giữ câu dự phòng [base].
_Facts _fromNasa(int sound, _Facts base) {
  final b = PlanetBody.bySound(sound);
  if (b == null) return base;
  String lower(String x) => x.isEmpty ? x : x[0].toLowerCase() + x.substring(1);
  String noteVi(String x) => RegExp(r'^\d').hasMatch(x) ? 'có $x' : lower(x);
  String noteEn(String x) => RegExp(r'^\d').hasMatch(x) ? 'has $x' : lower(x);
  final light = b.lightMinutes >= 1 ? b.lightMinutes.round() : 0;
  final dist = sound == 0 || sound == 4 || b.distSunMkm <= 0
      ? base.dist
      : 'cách Mặt Trời khoảng ${b.distVi()}${light > 0 ? '; ánh sáng Mặt Trời đi tới mất khoảng $light phút' : ''}';
  final distEn = sound == 0 || sound == 4 || b.distSunMkm <= 0
      ? base.distEn
      : 'about ${b.distEn()} from the Sun${light > 0 ? '; sunlight takes about $light minutes to get there' : ''}';
  final day = b.dayVi().isEmpty ? base.day : 'một ngày, từ lúc mặt trời mọc tới lần mọc sau, dài ${b.dayVi()}';
  final dayEn = b.dayEn().isEmpty ? base.dayEn : 'one day, sunrise to sunrise, lasts ${b.dayEn()}';
  final year = sound == 0 || sound == 4 || b.yearVi().isEmpty ? base.year : 'một năm dài ${b.yearVi()}';
  final yearEn = sound == 0 || sound == 4 || b.yearEn().isEmpty ? base.yearEn : 'a year lasts ${b.yearEn()}';
  final moons = b.moonsNoteVi.isEmpty ? base.moons : noteVi(b.moonsNoteVi);
  final moonsEn = b.moonsNoteEn.isEmpty ? base.moonsEn : noteEn(b.moonsNoteEn);
  final gasGiant = sound >= 6;
  final temp = sound == 0
      ? base.temp
      : b.tempRangeVi != null
          ? 'nhiệt độ trung bình khoảng ${_deg(b.meanTempC, false)} độ C; ${lower(b.tempRangeVi!.replaceAll('°C', ' độ C').replaceAll('+', ''))}'
          : 'nhiệt độ trung bình khoảng ${_deg(b.meanTempC, false)} độ C${gasGiant ? ' ở tầng mây' : ''}';
  final tempEn = sound == 0 ? base.tempEn : 'about ${_deg(b.meanTempC, true)} °C on average${gasGiant ? ' at the cloud tops' : ''}';
  return _Facts(b.sizeVsEarth, dist, distEn, day, dayEn, year, yearEn, moons, moonsEn, b.gravityVsEarth, temp, tempEn, base.life,
      base.lifeEn, base.trip, base.tripEn);
}

/// Trả lời một câu hỏi về thiên thể [sound] (0 Mặt Trời … 9 Sao Hải Vương). null nếu không nhận ra câu hỏi.
/// Số liệu lấy từ NASA (planets_nasa.json) khi đã nạp — nền tảng sự thật của phần Khám phá vũ trụ.
String? planetAnswer(int sound, String nameVi, String nameEn, String question, {required bool en}) {
  final f0 = _f[sound];
  if (f0 == null) return null;
  final f = _fromNasa(sound, f0);
  // bỏ tên thiên thể khỏi câu ("Sao Thổ" có chữ "tho", "Mặt Trăng" có chữ "mat trang") kẻo hiểu nhầm ý hỏi
  var q = ' ${normVi(question)} ';
  for (final name in <String>{normVi(nameVi), normVi(nameEn), 'sao tho', 'tho tinh', if (sound == 4) 'the moon'}) {
    if (name.isNotEmpty) q = q.replaceFirst(' $name ', ' ');
  }
  final t = q;
  bool has(String re) => RegExp(re).hasMatch(t);
  final n = en ? nameEn : nameVi;
  String cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);
  if (has(r' (nang|can nang|trong luc|hut|nhay|weigh|weight|gravity|jump|heavy) ')) {
    final kg = (50 * f.gravity).round();
    return en
        ? 'Gravity on $n is ${_num(f.gravity, true)} times Earth\'s. A person who weighs 50 kilograms here would weigh about $kg kilograms there.'
        : 'Lực hút ở $n bằng ${_num(f.gravity, false)} lần Trái Đất. Một người nặng 50 ki-lô-gam ở đây, lên đó cân chỉ còn khoảng $kg ki-lô-gam${f.gravity < 0.5 ? ', nhảy cao gấp mấy lần' : ''}.';
  }
  if (has(r' (mat trang|ve tinh|moons?|satellites?) ')) return cap('$n ${en ? f.moonsEn : f.moons}.');
  if (has(r' (bao lau moi toi|bay toi|bay den|mat bao lau|di toi|get there|travel there|fly there|reach|how long to) ')) {
    if (sound == 3) return en ? 'We are already here!' : 'Chúng ta đang ở đây rồi!';
    return cap('${en ? 'To $n: ' : 'Tới $n: '}${en ? f.tripEn : f.trip}.');
  }
  if (has(r' (ngay|day|rotate|spin|quay) ')) return en ? 'On $n, ${f.dayEn}.' : 'Ở $n, ${f.day}.';
  if (has(r' (nam|year|orbit|quanh mat troi) ')) {
    if (sound == 0) return en ? 'The Sun ${f.yearEn}.' : 'Mặt Trời ${f.year}.';
    return en ? 'On $n, ${f.yearEn}.' : 'Ở $n, ${f.year}.';
  }
  if (has(r' (xa|cach|khoang cach|far|distance|away) ')) return cap('$n ${en ? 'is ${f.distEn}' : 'ở ${f.dist}'}.');
  if (has(r' (nong|lanh|nhiet do|hot|cold|temperature|warm) ')) return cap(en ? '$n: ${f.tempEn}.' : '$n ${f.temp}.');
  if (has(r' (song|su song|o duoc|tho duoc|hit tho|life|live|alive|breathe|aliens?) ')) return cap(en ? '$n ${f.lifeEn}.' : '$n ${f.life}.');
  if (has(r' (to bang|to hon|to khong|to co|to the nao|to nhu|lon|nho|kich thuoc|bang may|so voi|big|size|large|small|compared?|bigger|smaller|wide) ')) {
    if (sound == 3) return en ? 'That is Earth itself, about 12,700 kilometres across.' : 'Đây chính là Trái Đất, đường kính khoảng 12.700 ki-lô-mét.';
    if (f.size >= 1) {
      final many = (f.size * f.size * f.size).round();
      return en
          ? '$n is about ${_num(f.size, true)} times wider than Earth; about $many Earths could fit inside it.'
          : '$n rộng gấp khoảng ${_num(f.size, false)} lần Trái Đất; nhét vừa khoảng $many Trái Đất vào trong.';
    }
    return en
        ? '$n is ${_num(f.size, true)} times as wide as Earth${f.size <= 0.55 ? ', about ${f.size < 0.3 ? 'a quarter' : f.size < 0.45 ? 'a third' : 'half'} its width' : ', almost the same size'}.'
        : '$n rộng bằng ${_num(f.size, false)} lần Trái Đất${f.size <= 0.55 ? ', cỡ ${f.size < 0.3 ? 'một phần tư' : f.size < 0.45 ? 'một phần ba' : 'một nửa'}' : ', gần bằng Trái Đất'}.';
  }
  return null;
}

/// Gợi ý câu hỏi khi không nhận ra câu hỏi và chưa có AI.
String planetHint(bool en) => en
    ? 'You can ask: how big is it, how far is it, how long is a day, how many moons, how much would I weigh, is it hot, could we live there.'
    : 'Bạn có thể hỏi: to bằng mấy Trái Đất, cách bao xa, một ngày dài bao lâu, có mấy mặt trăng, lên đó nặng bao nhiêu, nóng hay lạnh, có sống được không.';
