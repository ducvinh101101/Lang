// ĐỊA HÌNH — phần THUẦN DỮ LIỆU (không cần Flutter, kiểm thử được): tên các dạng địa hình lớn, các đỉnh núi,
// dải độ cao, câu tả độ cao / lát cắt địa hình bằng lời cho người khiếm thị.
import 'dart:math' as math;

import '../voice/commands.dart' show normVi;

/// Một dạng địa hình lớn (dãy núi, cao nguyên, đồng bằng, hoang mạc…) — khung vĩ độ / kinh độ thô.
class Landform {
  final String vi, en;
  final double lat0, lat1, lon0, lon1;
  final String noteVi, noteEn; // một câu ngắn
  final int kind; // 0 bất kỳ · 1 vùng cao (núi, cao nguyên) · 2 vùng thấp (đồng bằng) · 3 dưới biển
  const Landform(this.vi, this.en, this.lat0, this.lat1, this.lon0, this.lon1, this.noteVi, this.noteEn, {this.kind = 0});
  bool fits(double e) => switch (kind) { 1 => e >= 250, 2 => e <= 300 && e > -50, 3 => e < 0, _ => true };
  bool has(double lat, double lon) => lat >= lat0 && lat <= lat1 && lon >= lon0 && lon <= lon1;
  double get area => (lat1 - lat0) * (lon1 - lon0);
}

/// Đỉnh núi nổi tiếng (độ cao chính thức, không lấy từ lưới — lưới bị làm tròn theo ô).
class Peak {
  final String vi, en;
  final double lat, lon;
  final int h;
  final List<String> alias; // bỏ dấu
  final String noteVi, noteEn;
  const Peak(this.vi, this.en, this.lat, this.lon, this.h, this.alias, this.noteVi, this.noteEn);
}

const peaks = <Peak>[
  Peak('đỉnh Phan Xi Păng', 'Fansipan', 22.3033, 103.7750, 3143, ['phan xi pang', 'fansipan', 'phan si pan', 'phang xi pang'],
      'nóc nhà Đông Dương, trên dãy Hoàng Liên Sơn, Lào Cai', 'the roof of Indochina, in the Hoang Lien Son range'),
  Peak('đỉnh Pu Si Lung', 'Pu Si Lung', 22.6167, 102.9667, 3076, ['pu si lung'],
      'cao thứ hai Việt Nam, ở Lai Châu sát biên giới', 'second highest in Viet Nam, Lai Chau'),
  Peak('đỉnh Tây Côn Lĩnh', 'Tay Con Linh', 22.7958, 104.8394, 2419, ['tay con linh'], 'nóc nhà vùng Đông Bắc, Hà Giang cũ', 'the roof of the north-east'),
  Peak('đỉnh Ngọc Linh', 'Ngoc Linh', 15.0753, 107.9658, 2598, ['ngoc linh'], 'đỉnh cao nhất dãy Trường Sơn và Tây Nguyên', 'highest of the Truong Son range'),
  Peak('đỉnh Lang Biang', 'Lang Biang', 12.0472, 108.4403, 2167, ['lang biang', 'langbiang'], 'trên cao nguyên Lâm Viên, cạnh Đà Lạt', 'on the Lam Vien plateau near Da Lat'),
  Peak('núi Bà Đen', 'Ba Den Mountain', 11.3800, 106.1700, 986, ['ba den', 'nui ba den'], 'nóc nhà Nam Bộ, Tây Ninh', 'the roof of southern Viet Nam'),
  Peak('đỉnh Bạch Mã', 'Bach Ma', 16.1950, 107.8550, 1450, ['bach ma'], 'dãy Bạch Mã, ranh giới khí hậu Bắc Nam', 'the climate divide of Viet Nam'),
  Peak('núi Everest', 'Mount Everest', 27.9881, 86.9250, 8849, ['everest', 'e vo ret', 'chomolungma', 'chomolangma', 'dinh everest'],
      'đỉnh cao nhất thế giới, dãy Himalaya, giữa Nepal và Trung Quốc', 'the highest on Earth, in the Himalaya'),
  Peak('núi K2', 'K2', 35.8825, 76.5133, 8611, ['k2'], 'cao thứ hai thế giới, dãy Karakoram', 'second highest on Earth'),
  Peak('núi Aconcagua', 'Aconcagua', -32.6532, -70.0109, 6961, ['aconcagua'], 'cao nhất châu Mỹ, dãy Andes', 'highest in the Americas'),
  Peak('núi Denali', 'Denali', 63.0692, -151.0070, 6190, ['denali', 'mckinley'], 'cao nhất Bắc Mỹ', 'highest in North America'),
  Peak('núi Kilimanjaro', 'Kilimanjaro', -3.0674, 37.3556, 5895, ['kilimanjaro', 'ki li man gia ro'], 'cao nhất châu Phi, một núi lửa đã ngủ', 'highest in Africa'),
  Peak('núi Elbrus', 'Mount Elbrus', 43.3550, 42.4392, 5642, ['elbrus'], 'cao nhất châu Âu', 'highest in Europe'),
  Peak('núi Mont Blanc', 'Mont Blanc', 45.8326, 6.8652, 4806, ['mont blanc', 'mong blang'], 'cao nhất dãy Alps', 'highest of the Alps'),
  Peak('núi Phú Sĩ', 'Mount Fuji', 35.3606, 138.7274, 3776, ['phu si', 'fuji'], 'núi lửa, biểu tượng Nhật Bản', 'a volcano, symbol of Japan'),
  Peak('núi Kinabalu', 'Mount Kinabalu', 6.0753, 116.5586, 4095, ['kinabalu'], 'cao nhất Malaysia, đảo Borneo', 'highest in Malaysia'),
  Peak('núi Hkakabo Razi', 'Hkakabo Razi', 28.3333, 97.5333, 5881, ['hkakabo', 'kha ka bo'], 'cao nhất Đông Nam Á, ở Myanmar', 'highest in Southeast Asia'),
];

/// Nơi thấp nhất: rãnh Mariana, Biển Chết.
const deepest = (vi: 'vực Challenger, rãnh Mariana', en: 'the Challenger Deep, Mariana Trench', lat: 11.35, lon: 142.2, h: -10935);

const landforms = <Landform>[
  // ---- Việt Nam ----
  Landform('dãy Hoàng Liên Sơn', 'the Hoang Lien Son range', 21.4, 22.85, 103.3, 104.4,
      'dãy núi cao nhất Việt Nam, có đỉnh Phan Xi Păng 3.143 mét', 'the highest range in Viet Nam, with Fansipan', kind: 1),
  Landform('cao nguyên đá Đồng Văn', 'the Dong Van karst plateau', 22.95, 23.4, 104.95, 105.6,
      'cao nguyên đá vôi tai mèo, cao trên 1.000 mét', 'a limestone plateau over 1,000 metres high', kind: 1),
  Landform('vùng núi Đông Bắc', 'the north-eastern hills', 21.5, 23.1, 105.4, 107.6,
      'các dãy núi hình cánh cung, núi thấp và đồi đá vôi', 'arc-shaped ranges of low mountains and limestone hills', kind: 1),
  Landform('vùng núi Tây Bắc', 'the north-western mountains', 20.4, 22.6, 102.1, 105.0,
      'núi cao, thung lũng sâu, các cao nguyên Sơn La, Mộc Châu', 'high mountains, deep valleys and the Son La plateau', kind: 1),
  Landform('cao nguyên Mộc Châu', 'the Moc Chau plateau', 20.65, 21.0, 104.45, 104.9, 'cao nguyên khoảng 1.000 mét, mát quanh năm', 'a plateau about 1,000 metres high', kind: 1),
  Landform('đồng bằng sông Hồng', 'the Red River Delta', 20.0, 21.4, 105.35, 106.85,
      'đồng bằng phù sa thấp, chỉ vài mét trên mực nước biển, có đê bao quanh', 'a low alluvial delta, only a few metres above sea level', kind: 2),
  Landform('vịnh Hạ Long', 'Ha Long Bay', 20.6, 21.1, 106.9, 107.6, 'hàng nghìn đảo đá vôi nhô lên từ biển nông', 'thousands of limestone islands in shallow sea'),
  Landform('dãy Trường Sơn Bắc', 'the northern Truong Son range', 16.2, 19.9, 104.3, 107.6,
      'dãy núi chạy dọc biên giới Việt Lào, sườn đông dốc xuống biển', 'mountains along the Lao border, steep toward the sea', kind: 1),
  Landform('dãy Bạch Mã và đèo Hải Vân', 'the Bach Ma range and Hai Van Pass', 15.95, 16.35, 107.6, 108.25,
      'dãy núi đâm ngang ra biển, chia khí hậu hai miền Bắc Nam', 'a spur reaching the sea, dividing north and south climates', kind: 1),
  Landform('cao nguyên Lâm Viên, Đà Lạt', 'the Lam Vien plateau, Da Lat', 11.75, 12.25, 108.2, 108.75,
      'cao nguyên cao khoảng 1.500 mét, khí hậu mát quanh năm', 'a plateau about 1,500 metres high, cool all year', kind: 1),
  Landform('khối núi Ngọc Linh', 'the Ngoc Linh massif', 14.8, 15.35, 107.7, 108.2, 'núi cao nhất Tây Nguyên, rừng nguyên sinh', 'the highest massif of the Central Highlands', kind: 1),
  Landform('Tây Nguyên', 'the Central Highlands', 11.3, 15.5, 107.2, 109.0,
      'các cao nguyên xếp tầng đất đỏ ba dan, cao từ 500 đến 1.500 mét', 'stepped basalt plateaus 500 to 1,500 metres high', kind: 1),
  Landform('dải đồng bằng ven biển miền Trung', 'the central coastal plains', 10.9, 19.9, 105.5, 109.5,
      'dải đồng bằng nhỏ hẹp, bị núi cắt ngang, nhiều cồn cát', 'narrow plains cut by mountain spurs, with sand dunes', kind: 2),
  Landform('vùng Đông Nam Bộ', 'the south-east region', 10.4, 12.0, 105.9, 107.6, 'đồi thấp lượn sóng, đất xám và đất đỏ', 'low rolling hills'),
  Landform('đồng bằng sông Cửu Long', 'the Mekong Delta', 8.5, 11.0, 104.4, 106.85,
      'đồng bằng rất thấp, phần lớn dưới 2 mét, sông rạch chằng chịt', 'a very low delta, mostly under 2 metres, full of canals', kind: 2),
  // ---- thế giới ----
  Landform('dãy Himalaya', 'the Himalaya', 26.5, 29.0, 80.0, 95.5, 'dãy núi cao nhất thế giới, có đỉnh Everest 8.849 mét', 'the highest range on Earth, with Everest', kind: 1),
  Landform('cao nguyên Tây Tạng', 'the Tibetan Plateau', 29.0, 37.5, 78.0, 102.0, 'nóc nhà thế giới, cao trung bình hơn 4.500 mét', 'the roof of the world, over 4,500 metres on average', kind: 1),
  Landform('dãy Karakoram', 'the Karakoram', 34.5, 37.0, 74.0, 78.5, 'núi rất cao, nhiều sông băng, có đỉnh K2', 'very high peaks and glaciers, with K2', kind: 1),
  Landform('dãy Thiên Sơn', 'the Tian Shan', 40.0, 44.5, 70.0, 95.0, 'dãy núi dài ở Trung Á', 'a long range in Central Asia', kind: 1),
  Landform('hoang mạc Gô-bi', 'the Gobi Desert', 38.5, 46.5, 94.0, 115.0, 'hoang mạc đá, cao nguyên khô lạnh', 'a cold stony desert plateau'),
  Landform('đồng bằng Tây Xi-bia', 'the West Siberian Plain', 55.0, 72.0, 62.0, 88.0, 'một trong những đồng bằng lớn và phẳng nhất thế giới', 'one of the largest flat plains', kind: 2),
  Landform('dãy U-ran', 'the Ural Mountains', 50.0, 68.0, 56.0, 62.0, 'dãy núi thấp chia châu Âu và châu Á', 'low mountains dividing Europe and Asia', kind: 1),
  Landform('dãy Alps', 'the Alps', 44.0, 48.2, 5.0, 16.5, 'núi cao phủ tuyết ở châu Âu, đỉnh Mont Blanc 4.806 mét', 'snowy peaks of Europe', kind: 1),
  Landform('hoang mạc Sa-ha-ra', 'the Sahara', 15.0, 32.0, -16.0, 33.0, 'hoang mạc nóng lớn nhất thế giới, cồn cát và cao nguyên đá', 'the largest hot desert'),
  Landform('cao nguyên Đông Phi', 'the East African Highlands', -11.0, 15.0, 29.0, 43.0, 'cao nguyên và thung lũng tách giãn, có núi Kilimanjaro', 'highlands and the Rift Valley', kind: 1),
  Landform('dãy An-đét', 'the Andes', -55.0, 10.0, -80.0, -63.0, 'dãy núi dài nhất thế giới, chạy dọc bờ tây Nam Mỹ', 'the longest mountain range on Earth', kind: 1),
  Landform('lưu vực sông A-ma-dôn', 'the Amazon Basin', -15.0, 3.0, -76.0, -48.0, 'đồng bằng rừng mưa nhiệt đới rộng lớn, rất thấp', 'a vast low rainforest basin', kind: 2),
  Landform('dãy Rốc-ki', 'the Rocky Mountains', 35.0, 60.0, -125.0, -104.0, 'dãy núi lớn ở miền tây Bắc Mỹ', 'great mountains of western North America', kind: 1),
  Landform('Đại Bình nguyên Bắc Mỹ', 'the Great Plains', 30.0, 55.0, -104.0, -95.0, 'đồng cỏ phẳng rộng mênh mông', 'vast flat grasslands', kind: 2),
  Landform('khối băng Grơn-len', 'the Greenland ice sheet', 60.0, 84.0, -73.0, -12.0, 'lớp băng dày hơn 2 nghìn mét phủ cả hòn đảo', 'ice over 2,000 metres thick', kind: 1),
  Landform('châu Nam Cực', 'Antarctica', -90.0, -63.0, -180.0, 180.0, 'lục địa phủ băng, cao trung bình hơn 2 nghìn mét', 'an ice-covered continent', kind: 1),
  Landform('rãnh Ma-ri-a-na', 'the Mariana Trench', 10.5, 21.0, 141.0, 148.5, 'nơi sâu nhất đại dương, gần 11 nghìn mét', 'the deepest place in the ocean', kind: 3),
  Landform('lục địa Úc', 'the Australian outback', -32.0, -18.0, 115.0, 145.0, 'lục địa thấp và khô, nhiều hoang mạc', 'a low dry continent'),
];

/// Dạng địa hình chứa điểm (khung nhỏ nhất), null nếu không có. Biết độ cao [e] thì bỏ khung không hợp
/// (Vinh thấp ven biển không phải "dãy Trường Sơn" dù nằm trong khung của dãy núi).
Landform? landformAt(double lat, double lon, {double? e}) {
  Landform? best;
  for (final f in landforms) {
    if (e != null && !e.isNaN && !f.fits(e)) continue;
    if (f.has(lat, lon) && (best == null || f.area < best.area)) best = f;
  }
  return best;
}

/// Đỉnh núi được nhắc trong câu (bỏ dấu), null nếu không có.
Peak? peakIn(String text) {
  final t = ' ${normVi(text)} ';
  Peak? best;
  var bestLen = 0;
  for (final p in peaks) {
    for (final a in p.alias) {
      if (t.contains(' $a ') && a.length > bestLen) {
        best = p;
        bestLen = a.length;
      }
    }
  }
  return best;
}

/// Dải độ cao: chỉ số 0…10 (đổi dải → rung, đọc tên) và tên.
int bandOf(double e) {
  const cuts = [-6000.0, -200.0, 0.0, 50.0, 200.0, 500.0, 1000.0, 2000.0, 3500.0, 5000.0];
  var i = 0;
  while (i < cuts.length && e >= cuts[i]) {
    i++;
  }
  return i;
}

(String, String) bandName(int band) => switch (band) {
      0 => ('rãnh đại dương rất sâu', 'a very deep ocean trench'),
      1 => ('đáy đại dương sâu', 'the deep ocean floor'),
      2 => ('biển nông, thềm lục địa', 'shallow sea over the continental shelf'),
      3 => ('đồng bằng thấp', 'low plains'),
      4 => ('đồng bằng, gò đồi thấp', 'plains and low hills'),
      5 => ('đồi, trung du', 'hills'),
      6 => ('núi thấp, cao nguyên', 'low mountains and plateaus'),
      7 => ('núi trung bình, cao nguyên cao', 'mid mountains and high plateaus'),
      8 => ('núi cao', 'high mountains'),
      9 => ('núi rất cao, có tuyết', 'very high snowy mountains'),
      _ => ('đỉnh núi cao nhất thế giới, tuyết phủ quanh năm', 'the highest peaks on Earth, snow all year'),
    };

/// Số có dấu chấm nghìn (tiếng Việt: 3.143) / dấu phẩy (English: 3,143).
String groupNum(int n, {bool en = false}) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(en ? ',' : '.');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

/// Làm tròn độ cao cho dễ nghe: dưới 100 m giữ nguyên, dưới 1.000 m tròn 5 m, còn lại tròn 10 m.
int roundElev(double e) {
  final a = e.abs();
  final step = a < 100 ? 1 : (a < 1000 ? 5 : 10);
  return (e / step).round() * step;
}

/// "cao khoảng 1.520 mét so với mực nước biển" / "sâu khoảng 3.200 mét dưới mặt biển".
(String, String) elevPhrase(double e) {
  final r = roundElev(e);
  if (r < 0) {
    return ('sâu khoảng ${groupNum(-r)} mét dưới mặt biển', 'about ${groupNum(-r, en: true)} metres below sea level');
  }
  if (r <= 2) return ('gần ngang mực nước biển', 'about sea level');
  return ('cao khoảng ${groupNum(r)} mét so với mực nước biển', 'about ${groupNum(r, en: true)} metres above sea level');
}

/// Câu trả lời "nơi X cao bao nhiêu".
(String, String) heightAnswer(String nameVi, String nameEn, double lat, double lon, double e, {Peak? peak}) {
  if (peak != null) {
    return (
      '${_cap(peak.vi)} cao ${groupNum(peak.h)} mét, ${peak.noteVi}.',
      '${peak.en} is ${groupNum(peak.h, en: true)} metres high, ${peak.noteEn}.',
    );
  }
  final (pv, pe) = elevPhrase(e);
  final (bv, be) = bandName(bandOf(e));
  final f = landformAt(lat, lon, e: e);
  return (
    '$nameVi $pv, thuộc vùng $bv${f == null ? '' : ', nằm trong ${f.vi}: ${f.noteVi}'}.',
    '$nameEn is $pe: $be${f == null ? '' : ', in ${f.en}: ${f.noteEn}'}.',
  );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Hướng (8 hướng) theo chỉ số 0 = bắc, theo chiều kim đồng hồ.
(String, String) dir8(int i) => const [
      ('bắc', 'north'),
      ('đông bắc', 'north-east'),
      ('đông', 'east'),
      ('đông nam', 'south-east'),
      ('nam', 'south'),
      ('tây nam', 'south-west'),
      ('tây', 'west'),
      ('tây bắc', 'north-west'),
    ][i % 8];

/// Tả địa hình quanh một điểm: [ring] = độ cao 8 hướng (bắc, đông bắc…) ở khoảng [km] km; [center] = độ cao giữa.
(String, String) reliefAnswer(String nameVi, String nameEn, double lat, double lon, double center, List<double> ring, double km) {
  final ok = [for (var i = 0; i < ring.length; i++) if (!ring[i].isNaN) i];
  final (pv, pe) = elevPhrase(center);
  final f = landformAt(lat, lon, e: center);
  final head = '$nameVi $pv${f == null ? '' : ', thuộc ${f.vi}'}.';
  final headEn = '$nameEn is $pe${f == null ? '' : ', in ${f.en}'}.';
  if (ok.isEmpty) return (head, headEn);
  var hi = ok.first, lo = ok.first;
  for (final i in ok) {
    if (ring[i] > ring[hi]) hi = i;
    if (ring[i] < ring[lo]) lo = i;
  }
  final all = [center, for (final i in ok) ring[i]];
  final range = all.reduce(math.max) - all.reduce(math.min);
  final (kv, ke) = range < 30
      ? ('Quanh đây khá bằng phẳng', 'The land around is quite flat')
      : range < 150
          ? ('Quanh đây là đồi thoải, lượn sóng', 'The land around is gently rolling')
          : range < 600
              ? ('Quanh đây đồi núi, dốc vừa', 'The land around is hilly')
              : ('Quanh đây núi non hiểm trở, rất dốc', 'The land around is steep and mountainous');
  final kmS = km.round();
  final seaN = [for (final i in ok) if (ring[i] < -1) i];
  String seaV = '', seaE = '';
  if (seaN.isNotEmpty && center > 0) {
    final names = seaN.map((i) => dir8(i).$1).join(', ');
    seaV = ' Biển ở phía $names.';
    seaE = ' The sea lies to the ${seaN.map((i) => dir8(i).$2).join(', ')}.';
  }
  final (hv, he) = dir8(hi);
  final (lv, le) = dir8(lo);
  final rhi = roundElev(ring[hi]), rlo = roundElev(ring[lo]);
  return (
    '$head $kv. Cách $kmS ki lô mét, cao nhất là phía $hv, khoảng ${groupNum(rhi)} mét; thấp nhất phía $lv, '
        '${rlo < 0 ? 'là biển' : 'khoảng ${groupNum(rlo)} mét'}.$seaV',
    '$headEn $ke. At $kmS kilometres, the highest ground is to the $he, about ${groupNum(rhi, en: true)} metres; '
        'the lowest to the $le${rlo < 0 ? ', which is sea' : ', about ${groupNum(rlo, en: true)} metres'}.$seaE',
  );
}

/// Tóm tắt một lát cắt địa hình: [elev] lấy mẫu đều dọc đường, [lenKm] dài cả đường, [names] tên chặng (có thể rỗng).
(String, String) profileSummary(List<double> elev, double lenKm, {String fromVi = 'đầu', String toVi = 'cuối', String fromEn = 'start', String toEn = 'end'}) {
  final ok = elev.where((e) => !e.isNaN).toList();
  if (ok.isEmpty) return ('Chưa có số liệu độ cao.', 'No elevation data.');
  var hi = 0, lo = 0;
  for (var i = 0; i < elev.length; i++) {
    if (elev[i].isNaN) continue;
    if (elev[hi].isNaN || elev[i] > elev[hi]) hi = i;
    if (elev[lo].isNaN || elev[i] < elev[lo]) lo = i;
  }
  final n = math.max(1, elev.length - 1);
  final kmHi = (lenKm * hi / n).round(), kmLo = (lenKm * lo / n).round();
  final sea = elev.where((e) => e < -1).length;
  // đếm số lần lên dốc lớn (đoạn tăng liên tiếp > 300 m)
  var climbs = 0;
  var run = 0.0;
  for (var i = 1; i < elev.length; i++) {
    final d = elev[i] - elev[i - 1];
    if (d.isNaN) continue;
    if (d > 0) {
      run += d;
    } else {
      if (run > 300) climbs++;
      run = 0;
    }
  }
  if (run > 300) climbs++;
  final rh = roundElev(elev[hi]), rl = roundElev(elev[lo]);
  final seaV = sea == 0 ? '' : (sea * 2 >= elev.length ? ' Phần lớn đường đi qua biển.' : ' Có đoạn đi qua biển.');
  final seaE = sea == 0 ? '' : (sea * 2 >= elev.length ? ' Most of the way is over the sea.' : ' Part of the way is over the sea.');
  final climbV = climbs == 0 ? 'Đường khá bằng.' : (climbs == 1 ? 'Có một lần lên núi lớn.' : 'Có $climbs lần lên núi lớn.');
  final climbE = climbs == 0 ? 'The way is fairly flat.' : (climbs == 1 ? 'There is one big climb.' : 'There are $climbs big climbs.');
  return (
    'Dài khoảng ${groupNum(lenKm.round())} ki lô mét. Cao nhất ${groupNum(rh)} mét, cách $fromVi $kmHi ki lô mét. '
        'Thấp nhất ${rl < 0 ? 'sâu ${groupNum(-rl)} mét dưới biển' : '${groupNum(rl)} mét'}, cách $fromVi $kmLo ki lô mét. $climbV$seaV',
    'About ${groupNum(lenKm.round(), en: true)} kilometres long. Highest ${groupNum(rh, en: true)} metres, $kmHi kilometres from the $fromEn. '
        'Lowest ${rl < 0 ? '${groupNum(-rl, en: true)} metres below the sea' : '${groupNum(rl, en: true)} metres'}, $kmLo kilometres from the $fromEn. $climbE$seaE',
  );
}

/// Đường đi dọc Việt Nam từ bắc vào nam (qua các vùng địa hình chính) — để nghe "hình dáng" đất nước.
const vnSpine = <(String, String, double, double)>[
  ('Lũng Cú, Hà Giang', 'Lung Cu', 23.36, 105.32),
  ('cao nguyên đá Đồng Văn', 'Dong Van plateau', 23.2, 105.25),
  ('Sa Pa, dãy Hoàng Liên Sơn', 'Sa Pa, Hoang Lien Son', 22.33, 103.84),
  ('Mộc Châu', 'Moc Chau', 20.85, 104.65),
  ('đồng bằng sông Hồng, Hà Nội', 'Red River Delta, Hanoi', 21.03, 105.85),
  ('Ninh Bình', 'Ninh Binh', 20.25, 105.97),
  ('Vinh, Nghệ An', 'Vinh', 18.67, 105.68),
  ('Phong Nha, Quảng Bình', 'Phong Nha', 17.59, 106.28),
  ('Huế', 'Hue', 16.46, 107.59),
  ('dãy Bạch Mã', 'Bach Ma', 16.19, 107.86),
  ('Đà Nẵng', 'Da Nang', 16.05, 108.2),
  ('núi Ngọc Linh', 'Ngoc Linh', 15.07, 107.97),
  ('Pleiku', 'Pleiku', 13.98, 108.0),
  ('Buôn Ma Thuột', 'Buon Ma Thuot', 12.67, 108.04),
  ('Đà Lạt', 'Da Lat', 11.94, 108.44),
  ('Thành phố Hồ Chí Minh', 'Ho Chi Minh City', 10.78, 106.7),
  ('Cần Thơ', 'Can Tho', 10.03, 105.78),
  ('mũi Cà Mau', 'Ca Mau Cape', 8.6, 104.72),
];

/// Khoảng cách (km) theo đường tròn lớn.
double distKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1, dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Điểm cách (lat, lon) [km] km theo hướng [bearingDeg] (0 = bắc).
(double, double) offsetKm(double lat, double lon, double km, double bearingDeg) {
  const r = 6371.0;
  final d = km / r, b = bearingDeg * math.pi / 180;
  final p1 = lat * math.pi / 180, l1 = lon * math.pi / 180;
  final p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b));
  final l2 = l1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2));
  return (p2 * 180 / math.pi, ((l2 * 180 / math.pi + 540) % 360) - 180);
}

/// Tiếng đàn theo độ cao: 0 (biển nông) … 1 (8.000 m). Căn bậc hai để đồng bằng / đồi cũng nghe khác nhau rõ.
double elevTone(double e) => e <= 0 ? 0.0 : math.sqrt(math.min(1.0, e / 8000));

const terrainOverviewVn = (
  'Việt Nam có ba phần tư diện tích là đồi núi, phần lớn là đồi núi thấp. Phía bắc và tây bắc là núi cao: dãy Hoàng Liên Sơn có đỉnh '
      'Phan Xi Păng cao 3.143 mét, nóc nhà Đông Dương. Phía đông bắc là các dãy núi hình cánh cung và cao nguyên đá Đồng Văn. '
      'Dãy Trường Sơn chạy dọc phía tây miền Trung; dãy Bạch Mã đâm ngang ra biển ở Huế, Đà Nẵng. Tây Nguyên là các cao nguyên đất đỏ '
      'xếp tầng, cao từ 500 đến 1.500 mét, có Đà Lạt mát quanh năm. Hai đồng bằng lớn rất thấp: đồng bằng sông Hồng ở phía bắc và '
      'đồng bằng sông Cửu Long ở phía nam, chỉ cao vài mét trên mặt biển. Ven biển miền Trung là dải đồng bằng nhỏ hẹp. '
      'Nói: đi dọc Việt Nam, để nghe địa hình từ bắc vào nam bằng tiếng đàn; hoặc hỏi độ cao các đỉnh núi.',
  'Three quarters of Viet Nam is hills and mountains, mostly low. The north-west has the Hoang Lien Son range with Fansipan, '
      '3,143 metres, the roof of Indochina. The Truong Son range runs along the west of central Viet Nam. The Central Highlands '
      'are stepped red-soil plateaus 500 to 1,500 metres high. Two very low deltas, the Red River in the north and the Mekong in '
      'the south, lie only a few metres above the sea. Say "along Viet Nam" to hear the land from north to south.',
);

const terrainOverviewWorld = (
  'Trên Trái Đất, đất liền chỉ chiếm khoảng 29 phần trăm, còn lại là biển và đại dương. Nơi cao nhất là đỉnh Everest 8.849 mét '
      'trên dãy Himalaya; sau lưng nó là cao nguyên Tây Tạng, nóc nhà thế giới, cao hơn 4.500 mét. Nơi sâu nhất là vực Challenger '
      'trong rãnh Mariana, sâu gần 11 nghìn mét dưới mặt biển. Các dãy núi lớn: An-đét dọc Nam Mỹ, Rốc-ki ở Bắc Mỹ, Alps ở châu Âu. '
      'Những vùng thấp, phẳng: lưu vực sông A-ma-dôn, đồng bằng Tây Xi-bia. Bạn có thể hỏi độ cao của bất kỳ dãy núi hay đỉnh núi nào.',
  'Land covers about 29 percent of the Earth; the rest is sea and ocean. The highest point is Mount Everest, 8,849 metres, in the '
      'Himalaya, beside the Tibetan Plateau. The deepest is the Challenger Deep in the Mariana Trench, nearly 11,000 metres down. '
      'You can ask for the height of any mountain peak or range.',
);
