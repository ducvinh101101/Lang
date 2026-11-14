// TRÒ CHƠI TÌM HIỂU HỆ MẶT TRỜI — chơi hoàn toàn bằng giọng nói, cho người khiếm thị.
//
// Thiết kế theo kinh nghiệm làm trò chơi âm thanh cho người mù (audio games):
//   • Mọi thông tin đều nói ra hoặc bằng âm thanh; mỗi sự kiện một âm riêng, nhất quán (đúng = "ting ting", sai = trầm).
//   • Lượt ngắn (3–5 câu), câu hỏi ngắn, đáp án đọc rõ "Một… Hai… Ba…" để dễ nhớ.
//   • Không bắt nhớ nhiều: nói "nhắc lại" bất cứ lúc nào; im lặng thì app tự nhắc và gợi ý cách trả lời.
//   • Gợi ý tăng dần khi trả lời sai, không chê; sai thì giải thích ngắn — chơi để HỌC.
//   • Âm thanh là trung tâm: trò "nghe tiếng đoán hành tinh" dùng tiếng nhạc riêng của từng thiên thể (iconosonics).
//
// Ba trò:
//   quiz   — Đố vui: 5 câu hỏi 3 lựa chọn (trả lời bằng số hoặc nói đáp án).
//   riddle — Tôi là ai: 3 câu đố, mỗi câu tối đa 3 gợi ý; đoán sớm được nhiều điểm hơn (3 / 2 / 1).
//   sound  — Nghe tiếng đoán hành tinh: làm quen tiếng của 3 thiên thể, rồi nghe và gọi tên.
//
// Phần này thuần Dart (không giao diện) để kiểm thử được; vòng chơi nằm ở globe_page.dart.
import 'dart:math' as math;

import '../../data/planet_bodies.dart';
import '../voice/commands.dart' show normVi;
import 'planets.dart' show planetIn, planets;

class QuizQ {
  final String q, qEn;
  final List<String> opts, optsEn;
  final int answer;
  final String why, whyEn;
  const QuizQ(this.q, this.qEn, this.opts, this.optsEn, this.answer, this.why, this.whyEn);
}

const quizBank = <QuizQ>[
  QuizQ('Hành tinh nào gần Mặt Trời nhất?', 'Which planet is closest to the Sun?', ['Sao Thủy', 'Sao Kim', 'Sao Hỏa'],
      ['Mercury', 'Venus', 'Mars'], 0, 'Sao Thủy chỉ cách Mặt Trời khoảng 58 triệu ki-lô-mét.', 'Mercury is only about 58 million kilometres from the Sun.'),
  QuizQ('Hành tinh nào nóng nhất Hệ Mặt Trời?', 'Which planet is the hottest?', ['Sao Thủy', 'Sao Kim', 'Sao Mộc'], ['Mercury', 'Venus', 'Jupiter'], 1,
      'Sao Kim có lớp khí rất dày giữ nhiệt như cái chăn, nóng khoảng 465 độ, dù Sao Thủy ở gần Mặt Trời hơn.',
      'Venus has a thick blanket of gas that traps heat, about 465 degrees, even though Mercury is closer to the Sun.'),
  QuizQ('Hành tinh nào lớn nhất?', 'Which planet is the biggest?', ['Sao Thổ', 'Trái Đất', 'Sao Mộc'], ['Saturn', 'Earth', 'Jupiter'], 2,
      'Sao Mộc lớn nhất, đường kính gấp khoảng 11 lần Trái Đất.', 'Jupiter is the biggest, about 11 times as wide as Earth.'),
  QuizQ('Hành tinh nào được gọi là hành tinh đỏ?', 'Which planet is called the red planet?', ['Sao Hỏa', 'Sao Kim', 'Sao Hải Vương'],
      ['Mars', 'Venus', 'Neptune'], 0, 'Đất đá Sao Hỏa có nhiều gỉ sắt nên có màu đỏ cam.', 'Mars soil is full of rusty iron, so it looks red.'),
  QuizQ('Hành tinh nào có vành đai rõ và đẹp nhất?', 'Which planet has the brightest, most beautiful rings?', ['Sao Mộc', 'Sao Thổ', 'Sao Thủy'],
      ['Jupiter', 'Saturn', 'Mercury'], 1, 'Vành đai Sao Thổ làm từ hàng tỉ mảnh băng và đá.', 'Saturn\'s rings are made of billions of pieces of ice and rock.'),
  QuizQ('Hành tinh nào nằm nghiêng, như lăn quanh Mặt Trời?', 'Which planet rolls around the Sun on its side?',
      ['Sao Thiên Vương', 'Sao Hỏa', 'Trái Đất'], ['Uranus', 'Mars', 'Earth'], 0,
      'Sao Thiên Vương nghiêng gần như nằm hẳn xuống, có lẽ vì từng bị một vật thể lớn va vào.', 'Uranus is tipped on its side, probably after a giant collision.'),
  QuizQ('Hành tinh nào xa Mặt Trời nhất?', 'Which planet is farthest from the Sun?', ['Sao Thiên Vương', 'Sao Hải Vương', 'Sao Thổ'],
      ['Uranus', 'Neptune', 'Saturn'], 1, 'Sao Hải Vương cách Mặt Trời khoảng 4,5 tỉ ki-lô-mét.', 'Neptune is about 4.5 billion kilometres from the Sun.'),
  QuizQ('Hành tinh nào có gió mạnh nhất?', 'Which planet has the strongest winds?', ['Sao Hải Vương', 'Trái Đất', 'Sao Kim'], ['Neptune', 'Earth', 'Venus'], 0,
      'Gió trên Sao Hải Vương tới khoảng 2000 ki-lô-mét một giờ.', 'Winds on Neptune reach about 2,000 kilometres per hour.'),
  QuizQ('Sao Hỏa có mấy mặt trăng?', 'How many moons does Mars have?', ['Một', 'Hai', 'Không có'], ['One', 'Two', 'None'], 1,
      'Sao Hỏa có hai mặt trăng nhỏ là Phobos và Deimos.', 'Mars has two small moons, Phobos and Deimos.'),
  QuizQ('Mặt Trời là gì?', 'What is the Sun?', ['Một hành tinh', 'Một ngôi sao', 'Một mặt trăng'], ['A planet', 'A star', 'A moon'], 1,
      'Mặt Trời là một ngôi sao, ngôi sao gần chúng ta nhất.', 'The Sun is a star, the closest star to us.'),
  QuizQ('Ánh sáng Mặt Trời đi tới Trái Đất mất khoảng bao lâu?', 'How long does sunlight take to reach Earth?', ['8 giây', '8 phút', '8 giờ'],
      ['8 seconds', '8 minutes', '8 hours'], 1, 'Khoảng 8 phút, dù ánh sáng đi nhanh nhất vũ trụ.', 'About 8 minutes, even though light is the fastest thing there is.'),
  QuizQ('Trái Đất là hành tinh thứ mấy tính từ Mặt Trời?', 'Counting from the Sun, which planet is Earth?', ['Thứ hai', 'Thứ ba', 'Thứ tư'],
      ['Second', 'Third', 'Fourth'], 1, 'Thứ ba: Sao Thủy, Sao Kim, rồi đến Trái Đất.', 'Third: Mercury, Venus, then Earth.'),
  QuizQ('Hệ Mặt Trời có bao nhiêu hành tinh?', 'How many planets are in the Solar System?', ['Bảy', 'Tám', 'Chín'], ['Seven', 'Eight', 'Nine'], 1,
      'Tám hành tinh. Sao Diêm Vương từ năm 2006 được xếp là hành tinh lùn.', 'Eight. Since 2006 Pluto has been called a dwarf planet.'),
  QuizQ('Hành tinh nào quay nhanh nhất, một ngày chỉ khoảng 10 giờ?', 'Which planet spins fastest, with a day of only about 10 hours?',
      ['Sao Mộc', 'Sao Kim', 'Trái Đất'], ['Jupiter', 'Venus', 'Earth'], 0, 'Sao Mộc to nhất mà lại quay nhanh nhất.', 'Jupiter is the biggest and also spins the fastest.'),
  QuizQ('Trên Sao Kim, mặt trời mọc ở hướng nào?', 'On Venus, where does the Sun rise?', ['Hướng đông', 'Hướng tây', 'Hướng bắc'],
      ['In the east', 'In the west', 'In the north'], 1, 'Sao Kim tự quay ngược chiều nên mặt trời mọc ở hướng tây.', 'Venus spins backwards, so the Sun rises in the west.'),
  QuizQ('Con người lần đầu đặt chân lên Mặt Trăng vào năm nào?', 'When did people first walk on the Moon?', ['1969', '1975', '1957'],
      ['1969', '1975', '1957'], 0, 'Năm 1969, Neil Armstrong bước xuống Mặt Trăng trong chuyến Apollo 11.', 'In 1969, Neil Armstrong stepped onto the Moon on Apollo 11.'),
  QuizQ('Nếu bạn nặng 30 ki-lô-gam, lên Mặt Trăng cân sẽ chỉ khoảng bao nhiêu?', 'If you weigh 30 kilograms, about how much would a scale show on the Moon?',
      ['5 ki-lô-gam', '30 ki-lô-gam', '60 ki-lô-gam'], ['5 kilograms', '30 kilograms', '60 kilograms'], 0,
      'Sức hút Mặt Trăng chỉ bằng khoảng một phần sáu Trái Đất.', 'Moon gravity is only about one sixth of Earth\'s.'),
  QuizQ('Hành tinh nào nhẹ tới mức có thể nổi trên nước, nếu có bồn đủ lớn?', 'Which planet is light enough to float in a big enough bathtub?',
      ['Sao Thổ', 'Sao Hỏa', 'Sao Thủy'], ['Saturn', 'Mars', 'Mercury'], 0, 'Sao Thổ chủ yếu là khí nhẹ, nhẹ hơn nước.', 'Saturn is mostly light gas, less dense than water.'),
  QuizQ('Vết Đỏ Lớn, một cơn bão to hơn cả Trái Đất, ở trên hành tinh nào?', 'The Great Red Spot, a storm bigger than Earth, is on which planet?',
      ['Sao Mộc', 'Sao Hỏa', 'Sao Hải Vương'], ['Jupiter', 'Mars', 'Neptune'], 0, 'Cơn bão này trên Sao Mộc đã thổi hàng trăm năm.', 'This storm on Jupiter has blown for hundreds of years.'),
  QuizQ('Một năm trên Sao Thủy dài khoảng bao lâu?', 'How long is a year on Mercury?', ['88 ngày', '365 ngày', '12 năm'],
      ['88 days', '365 days', '12 years'], 0, 'Sao Thủy chạy vòng quanh Mặt Trời chỉ mất 88 ngày.', 'Mercury goes around the Sun in only 88 days.'),
  QuizQ('Núi lửa Olympus, ngọn núi cao nhất Hệ Mặt Trời, nằm ở đâu?', 'Olympus Mons, the tallest volcano in the Solar System, is on…',
      ['Trái Đất', 'Sao Hỏa', 'Mặt Trăng'], ['Earth', 'Mars', 'the Moon'], 1, 'Nó trên Sao Hỏa, cao gần gấp ba đỉnh Everest.', 'It is on Mars, almost three times as tall as Everest.'),
  QuizQ('Hành tinh nào là nơi duy nhất ta biết có sự sống?', 'Which is the only planet we know has life?', ['Sao Hỏa', 'Trái Đất', 'Sao Kim'],
      ['Mars', 'Earth', 'Venus'], 1, 'Trái Đất có nước lỏng, không khí và nhiệt độ vừa phải.', 'Earth has liquid water, air and a gentle temperature.'),
  QuizQ('Mặt Trăng quay quanh Trái Đất một vòng mất khoảng bao lâu?', 'How long does the Moon take to go around Earth?', ['Một ngày', 'Một tuần', 'Một tháng'],
      ['One day', 'One week', 'One month'], 2, 'Khoảng 27 ngày, gần một tháng; vì thế mới có lịch âm theo Mặt Trăng.', 'About 27 days, close to a month.'),
  QuizQ('Hành tinh nào nằm giữa Trái Đất và Sao Mộc?', 'Which planet lies between Earth and Jupiter?', ['Sao Hỏa', 'Sao Kim', 'Sao Thổ'],
      ['Mars', 'Venus', 'Saturn'], 0, 'Thứ tự là Trái Đất, Sao Hỏa, rồi đến Sao Mộc.', 'The order is Earth, Mars, then Jupiter.'),
];

class Riddle {
  final int sound; // chỉ số thiên thể (0 Mặt Trời … 9 Sao Hải Vương)
  final List<String> clues, cluesEn; // khó → dễ
  const Riddle(this.sound, this.clues, this.cluesEn);
}

const riddleBank = <Riddle>[
  Riddle(5, ['Mình có ngọn núi lửa cao nhất Hệ Mặt Trời.', 'Mình có hai mặt trăng nhỏ.', 'Người ta gọi mình là hành tinh đỏ.'],
      ['I have the tallest volcano in the Solar System.', 'I have two small moons.', 'People call me the red planet.']),
  Riddle(7, ['Mình nhẹ tới mức có thể nổi trên nước.', 'Mình có 293 mặt trăng đã xác nhận, nhiều nhất Hệ Mặt Trời theo NASA tính đến năm 2026.', 'Mình có vành đai đẹp nhất.'],
      ['I am light enough to float on water.', 'I have 293 confirmed moons, the most of any planet according to NASA as of 2026.', 'I have the most beautiful rings.']),
  Riddle(6, ['Trên mình có một cơn bão đã thổi hàng trăm năm.', 'Một ngày của mình chỉ khoảng 10 giờ.', 'Mình là hành tinh lớn nhất.'],
      ['A storm has been blowing on me for hundreds of years.', 'My day is only about 10 hours long.', 'I am the biggest planet.']),
  Riddle(2, ['Trên mình, mặt trời mọc ở hướng tây.', 'Mình nóng nhất dù không gần Mặt Trời nhất.', 'Người Việt gọi mình là sao Mai và sao Hôm.'],
      ['On me, the Sun rises in the west.', 'I am the hottest planet, though not the closest to the Sun.', 'I shine as the morning star and the evening star.']),
  Riddle(1, ['Một năm của mình chỉ 88 ngày.', 'Mình nhỏ nhất trong tám hành tinh.', 'Mình gần Mặt Trời nhất.'],
      ['My year is only 88 days.', 'I am the smallest of the eight planets.', 'I am the closest planet to the Sun.']),
  Riddle(8, ['Mình là một hành tinh băng khổng lồ.', 'Một năm của mình dài 84 năm Trái Đất.', 'Mình nằm nghiêng mà lăn quanh Mặt Trời.'],
      ['I am an ice giant.', 'My year lasts 84 Earth years.', 'I roll around the Sun on my side.']),
  Riddle(9, ['Người ta tìm ra mình nhờ tính toán, trước cả khi nhìn thấy.', 'Mình có gió mạnh nhất Hệ Mặt Trời.', 'Mình là hành tinh xa Mặt Trời nhất.'],
      ['I was found by maths before anyone saw me.', 'I have the strongest winds in the Solar System.', 'I am the farthest planet from the Sun.']),
  Riddle(3, ['Khoảng bảy phần mười bề mặt của mình là nước.', 'Mình có đúng một mặt trăng.', 'Mình là nhà của bạn.'],
      ['About seven tenths of my surface is water.', 'I have exactly one moon.', 'I am your home.']),
  Riddle(4, ['Mình không tự phát sáng, chỉ phản chiếu ánh sáng Mặt Trời.', 'Năm 1969, con người lần đầu đặt chân lên mình.', 'Mình quay quanh Trái Đất.'],
      ['I do not make my own light; I reflect sunlight.', 'In 1969 people first walked on me.', 'I go around the Earth.']),
  Riddle(0, ['Mình là một ngôi sao chứ không phải hành tinh.', 'Ánh sáng của mình tới Trái Đất mất hơn 8 phút.', 'Tám hành tinh đều quay quanh mình.'],
      ['I am a star, not a planet.', 'My light takes over 8 minutes to reach Earth.', 'All eight planets go around me.']),
];

/// Vì sao tiếng của mỗi thiên thể lại như vậy (nói sau khi đoán, để nhớ lâu).
const soundWhy = <int, (String, String)>{
  0: ('Tiếng ầm cuộn trầm như một lò lửa khổng lồ.', 'A deep rolling roar, like a giant furnace.'),
  1: ('Tiếng ping cao dồn dập, vì Sao Thủy chạy quanh Mặt Trời nhanh nhất.', 'Quick high pings, because Mercury races around the Sun.'),
  2: ('Tiếng xì xì dày đặc, như lớp khí nóng và dày của Sao Kim.', 'A thick hiss, like Venus\'s hot heavy air.'),
  3: ('Gió nhẹ, tiếng nước và một giai điệu ấm, như Trái Đất có sự sống.', 'Soft wind, water and a warm tune, like our living Earth.'),
  4: ('Gần như im lặng, chỉ một nốt cao xa xăm, vì Mặt Trăng không có không khí.', 'Almost silent, one faraway note, because the Moon has no air.'),
  5: ('Tiếng gió mỏng, khô và rít, như không khí loãng trên Sao Hỏa.', 'A thin dry whistling wind, like the thin air on Mars.'),
  6: ('Tiếng trầm rất sâu và xoáy, vì Sao Mộc khổng lồ và đầy bão.', 'A very deep swirling rumble, for giant stormy Jupiter.'),
  7: ('Tiếng chuông ngân lấp lánh, như vành đai băng của Sao Thổ.', 'Shimmering bells, like Saturn\'s icy rings.'),
  8: ('Tiếng thủy tinh lạnh, lắc lư, vì Sao Thiên Vương băng giá và nằm nghiêng.', 'Cold swaying glass, for icy tilted Uranus.'),
  9: ('Tiếng gió vù vù và trầm lạnh, vì Sao Hải Vương có gió mạnh nhất.', 'Rushing wind and cold depths, for windy Neptune.'),
};

String bodyName(int sound, {bool en = false}) {
  final p = planets.firstWhere((x) => x.sound == sound);
  return en ? p.en.replaceFirst('the ', 'the ') : p.vi;
}

// ---------------- dựng một lượt chơi ----------------

/// Một lượt đố vui: khi đã có số liệu NASA (F2), hơn nửa số câu được SINH TỪ DỮ LIỆU (sự thật thú vị, số mặt trăng,
/// độ dài năm, kích thước, khoảng cách, lực hút), phần còn lại lấy từ ngân hàng câu hỏi có sẵn.
List<QuizQ> buildQuiz(math.Random r, {int n = 5, List<PlanetBody>? bodies}) {
  final gen = nasaQuiz(r, bodies ?? PlanetBody.loaded, n: (n * 0.6).ceil());
  final rest = (List<QuizQ>.of(quizBank)..shuffle(r)).take(n - gen.length);
  return [...gen, ...rest]..shuffle(r);
}

/// Câu đố "Tôi là ai": khi có số liệu NASA, phần lớn câu đố dựng từ sự thật thú vị + số liệu của thiên thể.
List<Riddle> buildRiddles(math.Random r, {int n = 3, List<PlanetBody>? bodies}) {
  final gen = nasaRiddles(r, bodies ?? PlanetBody.loaded, n: math.max(0, n - 1));
  final used = {for (final g in gen) g.sound};
  final rest = (List<Riddle>.of(riddleBank)..shuffle(r)).where((x) => !used.contains(x.sound)).take(n - gen.length);
  return [...gen, ...rest]..shuffle(r);
}

// ---------------- sinh nội dung trò chơi từ dữ liệu NASA (F2) ----------------

String _maskVi(String text, PlanetBody b, String repl) =>
    text.replaceAll(RegExp(RegExp.escape(b.nameVi), caseSensitive: false), repl);

String _maskEn(String text, PlanetBody b, String repl) {
  final n = b.nameEn.replaceFirst(RegExp(r'^the ', caseSensitive: false), '');
  return text.replaceAll(RegExp('(the )?${RegExp.escape(n)}', caseSensitive: false), repl);
}

bool _mentions(String text, PlanetBody other) =>
    normVi(text).contains(normVi(other.nameVi)) ||
    text.toLowerCase().contains(other.nameEn.replaceFirst(RegExp(r'^the ', caseSensitive: false), '').toLowerCase());

String _cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);

/// Sinh tối đa [n] câu đố vui 3 lựa chọn từ số liệu NASA (mỗi kiểu câu nhiều nhất một lần).
List<QuizQ> nasaQuiz(math.Random r, List<PlanetBody> bodies, {int n = 3}) {
  if (bodies.length < 4) return const [];
  final planetsOnly = bodies.where((b) => b.isPlanet).toList();
  final out = <QuizQ>[];
  QuizQ? pick3(List<PlanetBody> pool, double Function(PlanetBody) key, String qVi, String qEn, String Function(PlanetBody) whyVi,
      String Function(PlanetBody) whyEn, {bool highest = true}) {
    final p = List<PlanetBody>.of(pool)..shuffle(r);
    final three = <PlanetBody>[];
    for (final b in p) {
      if (three.every((x) => (key(x) - key(b)).abs() > 1e-6)) three.add(b);
      if (three.length == 3) break;
    }
    if (three.length < 3) return null;
    var best = 0;
    for (var k = 1; k < 3; k++) {
      if (highest ? key(three[k]) > key(three[best]) : key(three[k]) < key(three[best])) best = k;
    }
    return QuizQ(qVi, qEn, [for (final b in three) b.nameVi], [for (final b in three) _cap(b.nameEn)], best,
        '${three.map(whyVi).join('; ')}. Theo số liệu NASA.', '${three.map(whyEn).join('; ')}. Source: NASA.');
  }

  final makers = <QuizQ? Function()>[
    // 1) sự thật thú vị thuộc về thiên thể nào
    () {
      final withFacts = bodies.where((b) => b.bilingualFacts.isNotEmpty).toList()..shuffle(r);
      for (final a in withFacts) {
        final f = a.bilingualFacts[r.nextInt(a.bilingualFacts.length)];
        final others =
            (bodies.where((b) => b.sound != a.sound && !_mentions(f.vi, b) && !_mentions(f.en, b)).toList()..shuffle(r)).take(2).toList();
        if (others.length < 2) continue;
        final opts = [a, ...others]..shuffle(r);
        return QuizQ(
          'Sự thật này nói về thiên thể nào? ${_maskVi(f.vi, a, 'thiên thể này')}',
          'Which body is this fact about? ${_maskEn(f.en, a, 'this body')}',
          [for (final b in opts) b.nameVi],
          [for (final b in opts) _cap(b.nameEn)],
          opts.indexOf(a),
          '${f.vi} Theo NASA.',
          '${f.en} Source: NASA.',
        );
      }
      return null;
    },
    // 2) nhiều mặt trăng nhất
    () => pick3(planetsOnly, (b) => b.moons.toDouble(), 'Trong ba hành tinh này, hành tinh nào có nhiều mặt trăng nhất?',
        'Of these three planets, which has the most moons?', (b) => '${b.nameVi} có ${b.moons} mặt trăng',
        (b) => '${_cap(b.nameEn)} has ${b.moons} moons'),
    // 3) lớn nhất
    () => pick3(planetsOnly, (b) => b.sizeVsEarth, 'Trong ba hành tinh này, hành tinh nào to nhất?', 'Of these three planets, which is the biggest?',
        (b) => '${b.nameVi} rộng ${_n(b.sizeVsEarth)} lần Trái Đất', (b) => '${_cap(b.nameEn)} is ${b.sizeVsEarth} times as wide as Earth'),
    // 4) xa Mặt Trời nhất
    () => pick3(planetsOnly, (b) => b.distSunMkm, 'Trong ba hành tinh này, hành tinh nào xa Mặt Trời nhất?',
        'Of these three planets, which is farthest from the Sun?', (b) => '${b.nameVi} cách Mặt Trời ${b.distVi()}',
        (b) => '${_cap(b.nameEn)} is ${b.distEn()} from the Sun'),
    // 5) lực hút yếu nhất
    () => pick3(bodies.where((b) => b.sound != 0).toList(), (b) => b.gravityVsEarth, 'Đứng trên thiên thể nào thì bạn thấy mình nhẹ nhất?',
        'On which of these would you feel lightest?', (b) => 'lực hút ở ${b.nameVi} bằng ${_n(b.gravityVsEarth)} lần Trái Đất',
        (b) => 'gravity on ${b.nameEn} is ${b.gravityVsEarth} times that of Earth', highest: false),
    // 6) một năm dài bao lâu
    () {
      final p = List<PlanetBody>.of(planetsOnly)..shuffle(r);
      final a = p.first;
      final others = p.skip(1).where((b) => b.yearVi() != a.yearVi()).take(2).toList();
      if (others.length < 2 || a.yearVi().isEmpty) return null;
      final opts = [a, ...others]..shuffle(r);
      return QuizQ('Một năm trên ${a.nameVi} dài khoảng bao lâu?', 'How long is a year on ${a.nameEn}?',
          [for (final b in opts) b.yearVi()], [for (final b in opts) b.yearEn()], opts.indexOf(a),
          '${a.nameVi} đi hết một vòng quanh Mặt Trời mất ${a.yearVi()}, theo NASA.',
          '${_cap(a.nameEn)} takes ${a.yearEn()} to go around the Sun, according to NASA.');
    },
  ]..shuffle(r);
  for (final m in makers) {
    if (out.length >= n) break;
    final q = m();
    if (q != null) out.add(q);
  }
  return out;
}

/// Sinh tối đa [n] câu đố "Tôi là ai" (khó → dễ): hai sự thật thú vị (đã giấu tên), rồi một gợi ý số liệu dễ đoán.
List<Riddle> nasaRiddles(math.Random r, List<PlanetBody> bodies, {int n = 2}) {
  final pool = bodies.where((b) => b.bilingualFacts.length >= 2).toList()..shuffle(r);
  final out = <Riddle>[];
  for (final b in pool.take(n)) {
    final fs = List<PlanetFact>.of(b.bilingualFacts)..shuffle(r);
    final easyVi = b.sound == 0
        ? 'Tám hành tinh đều quay quanh mình.'
        : b.sound == 4
            ? 'Mình quay quanh Trái Đất.'
            : 'Mình là hành tinh thứ ${_order(b, bodies)} tính từ Mặt Trời, và có ${b.moons} mặt trăng.';
    final easyEn = b.sound == 0
        ? 'All eight planets go around me.'
        : b.sound == 4
            ? 'I go around the Earth.'
            : 'I am planet number ${_order(b, bodies)} from the Sun, and I have ${b.moons} moons.';
    out.add(Riddle(b.sound, [
      for (final f in fs.take(2)) _maskVi(f.vi, b, 'mình'),
      easyVi,
    ], [
      for (final f in fs.take(2)) _maskEn(f.en, b, 'me'),
      easyEn,
    ]));
  }
  return out;
}

int _order(PlanetBody b, List<PlanetBody> bodies) {
  final ps = bodies.where((x) => x.isPlanet).toList()..sort((a, c) => a.distSunMkm.compareTo(c.distSunMkm));
  return ps.indexWhere((x) => x.sound == b.sound) + 1;
}

String _n(double x) => (x >= 10 ? x.round().toString() : x.toStringAsFixed(x == x.roundToDouble() ? 0 : 2)).replaceAll('.', ',');

/// Trò nghe tiếng: 3 thiên thể để làm quen, rồi [rounds] lượt hỏi (không lặp liền một thiên thể).
({List<int> learn, List<int> asks}) buildSoundGame(math.Random r, {int rounds = 4}) {
  final all = List<int>.generate(10, (i) => i)..shuffle(r);
  final learn = all.take(3).toList();
  final asks = <int>[];
  while (asks.length < rounds) {
    final x = learn[r.nextInt(learn.length)];
    if (asks.isNotEmpty && asks.last == x) continue;
    asks.add(x);
  }
  return (learn: learn, asks: asks);
}

// ---------------- hiểu câu trả lời ----------------

/// Lệnh điều khiển trong lúc chơi: 'stop' | 'repeat' | 'hint' | 'skip' | null.
String? gameControl(String heard) {
  final t = normVi(heard);
  if (RegExp(r'\b(dung|dung lai|thoi|ngung|thoat|ket thuc|khong choi|nghi choi|stop|quit|exit|end)\b').hasMatch(t)) return 'stop';
  if (RegExp(r'\b(nhac lai|lap lai|doc lai|noi lai|nghe lai|chua nghe ro|repeat|again|say it again)\b').hasMatch(t)) return 'repeat';
  if (RegExp(r'\b(goi y|giup|tro giup|cho goi y|hint|clue|help)\b').hasMatch(t)) return 'hint';
  if (RegExp(r'\b(bo qua|khong biet|chiu|cau khac|dap an la gi|skip|pass|i don t know|dont know|next)\b').hasMatch(t)) return 'skip';
  return null;
}

const _numWords = {
  'khong': '0', 'mot': '1', 'hai': '2', 'ba': '3', 'bon': '4', 'tu': '4', 'nam': '5', 'sau': '6', 'bay': '7', 'tam': '8', 'chin': '9',
  'muoi': '10', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8',
  'nine': '9', 'ten': '10', 'zero': '0',
};

/// Thay số đọc bằng chữ thành chữ số ("tám phút" → "8 phut") để so với đáp án viết bằng số.
String _digits(String t) => t.split(' ').map((w) => _numWords[w] ?? w).join(' ');

/// Đáp án người chơi chọn (0, 1, 2) hoặc null nếu không hiểu.
/// Nhận: số thứ tự ("một", "số hai", "đáp án ba", "câu B", "the second"), hoặc nói luôn nội dung đáp án.
int? matchOption(String heard, List<String> opts) {
  final t = normVi(heard);
  if (t.isEmpty) return null;
  // 1) nói nội dung đáp án: tên hành tinh, hoặc đủ các từ chính của đáp án
  final pl = planetIn(heard);
  if (pl != null) {
    final hits = [for (var k = 0; k < opts.length; k++) if (planetIn(opts[k])?.sound == pl.sound) k];
    if (hits.length == 1) return hits.first;
  }
  final td = ' ${_digits(t)} ';
  // chỉ xét những từ PHÂN BIỆT các đáp án ("hướng tây" → "tây"; "5 ki-lô-gam" → "5")
  final ow = [for (final o in opts) _digits(normVi(o)).split(' ').where((w) => w.isNotEmpty).toList()];
  final common = ow.isEmpty ? <String>{} : ow.skip(1).fold(ow.first.toSet(), (a, b) => a.intersection(b.toSet()));
  int? byText;
  for (var k = 0; k < opts.length; k++) {
    final words = ow[k].where((w) => !common.contains(w) && w != 'a' && w != 'the').toList();
    if (words.isEmpty) continue;
    // năm "1969": chấp nhận nói "69"
    final ok = words.every((w) => td.contains(' $w ') || (w.length == 4 && int.tryParse(w) != null && td.contains(' ${w.substring(2)} ')));
    if (ok) {
      if (byText != null) return null; // khớp hai đáp án → chưa rõ
      byText = k;
    }
  }
  if (byText != null) return byText;
  // 2) số thứ tự / chữ cái
  final m = RegExp(r'^(?:(?:dap an|cau|so|chon|phuong an|lua chon|toi chon|minh chon|answer|number|option|the)\s+)?'
          r'(1|2|3|mot|hai|ba|thu nhat|thu hai|thu ba|nhat|a|b|c|be|xe|one|two|three|first|second|third)'
          r'(?:\s+(?:lua chon|phuong an|co ma|di|a|nhe|nha|chu|ạ|please))?$')
      .firstMatch(t);
  if (m == null) return null;
  switch (m.group(1)) {
    case '1':
    case 'mot':
    case 'thu nhat':
    case 'nhat':
    case 'a':
    case 'one':
    case 'first':
      return 0;
    case '2':
    case 'hai':
    case 'thu hai':
    case 'b':
    case 'be':
    case 'two':
    case 'second':
      return opts.length > 1 ? 1 : null;
    default:
      return opts.length > 2 ? 2 : null;
  }
}

/// Thiên thể người chơi gọi tên (chỉ số âm thanh) hoặc null.
int? matchBody(String heard) => planetIn(heard)?.sound;

/// Lời khen / động viên ngắn, xoay vòng cho đỡ nhàm.
const praiseVi = ['Chính xác!', 'Đúng rồi, giỏi quá!', 'Tuyệt vời!', 'Chuẩn luôn!', 'Đúng rồi!'];
const praiseEn = ['Correct!', 'Well done!', 'Great!', 'Spot on!', 'That\'s right!'];

/// Nhận xét cuối lượt theo tỉ lệ điểm.
(String, String) finalWords(int score, int max) {
  final p = max == 0 ? 0 : score / max;
  if (p >= 0.99) return ('Điểm tuyệt đối! Bạn đúng là nhà thiên văn nhí.', 'A perfect score! You are a real astronomer.');
  if (p >= 0.6) return ('Rất tốt! Bạn biết nhiều về vũ trụ đấy.', 'Very good! You know a lot about space.');
  if (p >= 0.3) return ('Khá lắm! Chơi thêm vài lần là nhớ hết.', 'Nice! Play a few more times and you will remember it all.');
  return ('Không sao cả, mỗi lần chơi là học thêm một điều mới.', 'No worries, every game teaches something new.');
}
