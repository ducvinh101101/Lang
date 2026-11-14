// MÁY HÁT TRÁI ĐẤT — phát một hình EIC/SVS thành âm thanh theo thời gian thực.
//
// Mỗi khung hình (một năm / một ngày / một mùa…) được "hát" trong khoảng 0,9 giây:
//   • GIỌNG CHÍNH (đàn bầu hoặc sáo, liền hơi): cao độ = giá trị chính toàn cầu v (ngũ cung, 3 quãng tám),
//     tai trái–phải = vị trí đông–tây của vùng mạnh nhất (cx).
//   • NHỊP (trống / t'rưng / lách tách): số tiếng trong một khung = diện tích "đáng kể" (area) — càng phủ rộng càng dày.
//   • NỀN (sấm / gió / mưa / sóng): bật khi khung thay đổi nhiều so với khung trước (d) — nghe được "bước ngoặt".
//   • Khung có vùng Việt Nam – Biển Đông thay đổi rõ: thêm một tiếng chiêng nhỏ để người nghe biết "chuyện xảy ra gần nhà".
// Rê tay trên hình: giọng chính đi theo giá trị của điểm đang chạm, đọc số sau khi dừng tay một chút.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../audio/audio_engine.dart';
import '../../core/format.dart' show fmtNum;
import '../../core/haptics.dart';
import 'eic_data.dart';

/// Thời gian mỗi khung (ms) theo mức tốc độ 0…4.
const kEicStepMs = [1600, 1200, 900, 650, 450];

class EicPlayer extends ChangeNotifier {
  final AudioEngine audio;
  final Future<void> Function(String vi, String en) say;
  final EicSet ds;

  EicPlayer({required this.audio, required this.say, required this.ds});

  int index = 0;
  bool running = false, paused = false, done = false;
  int speed = 2;

  /// điểm đang chạm (0…1), null nếu không chạm
  Offset2? touch;
  double? touchValue;

  int _gen = 0;
  Timer? _touchTimer;
  String _lastSpoken = '';

  EicFrame get frame => ds.frames[index.clamp(0, ds.frames.length - 1)];
  int get count => ds.frames.length;

  /// Bắt đầu: giới thiệu ngắn (mô tả + chú giải) rồi phát từ khung [from].
  Future<void> run({int from = 0, bool intro = true}) async {
    final my = ++_gen;
    running = true;
    paused = false;
    done = false;
    index = from.clamp(0, count - 1);
    notifyListeners();
    if (intro) {
      await say('${ds.titleVi}. ${ds.describeVi} ${ds.legendVi}', '${ds.titleEn}. ${ds.describeEn} ${ds.legendEn}');
      if (my != _gen) return;
    }
    await _play(my);
  }

  Future<void> _play(int my) async {
    await audio.voiceStart(instrument: ds.voice == 'sao' ? 'sao' : 'danbau');
    for (; index < count && my == _gen; index++) {
      notifyListeners();
      final f = frame;
      await _singFrame(f, my);
      if (my != _gen) return;
      // đọc nhãn khung đầu, khung giữa và khung cuối để định vị thời gian mà không lấn át âm nhạc
      if (index == 0 || index == count - 1 || index == count ~/ 2) {
        audio.voiceMute();
        await say(f.labelVi, f.labelEn);
        if (my != _gen) return;
      }
    }
    if (my != _gen) return;
    audio.voiceMute();
    running = false;
    done = true;
    index = count - 1;
    notifyListeners();
    await say(summaryVi(), summaryEn());
  }

  /// giá trị giọng chính của khung (toàn cầu hay Biển Đông, theo meta.json)
  double main(EicFrame f) => ds.pitch == 'vn' ? f.vn : f.v;

  /// Cao độ: trải khoảng giá trị THẬT của bộ này ra gần hết 3 quãng tám (khung thấp nhất ≈ 0,1, cao nhất ≈ 0,95)
  /// để thay đổi nhỏ (vd biển Đông 27 → 30 °C) vẫn nghe rõ; lời đọc vẫn dùng số thật.
  double pitchOf(EicFrame f) {
    var lo = 1.0, hi = 0.0;
    for (final x in ds.frames) {
      final m = main(x);
      if (m < lo) lo = m;
      if (m > hi) hi = m;
    }
    if (hi - lo < 0.02) return main(f);
    return 0.1 + 0.85 * (main(f) - lo) / (hi - lo);
  }

  Future<void> _singFrame(EicFrame f, int my) async {
    final step = kEicStepMs[speed.clamp(0, kEicStepMs.length - 1)];
    final pan = f.cx.clamp(-1.0, 1.0);
    final m = pitchOf(f);
    audio.voiceSet(freq: toScale(m), pan: pan, gain: 0.05 + 0.08 * m);
    if (f.d > 0.6) _bed(pan, f.d);
    // vùng Việt Nam – Biển Đông đổi rõ so với khung trước: một tiếng chiêng nhỏ
    final i = ds.frames.indexOf(f);
    if (i > 0 && (f.vn - ds.frames[i - 1].vn).abs() > 0.06) audio.chieng(0.08);
    final hits = pulseCount(f.area);
    if (hits == 0 || ds.pulse == 'none') {
      await Future<void>.delayed(Duration(milliseconds: step));
      return;
    }
    final gap = step ~/ hits;
    for (var h = 0; h < hits && my == _gen; h++) {
      final hp = (pan + (h.isEven ? -0.25 : 0.25)).clamp(-1.0, 1.0);
      switch (ds.pulse) {
        case 'trong':
          audio.trong(0.12 + 0.1 * f.v, hp);
        case 'crackle':
          audio.crackle(0.25 + 0.3 * f.v, hp);
        default:
          audio.trung(toScale(1 - f.v * 0.5), 0.12, hp);
      }
      await Future<void>.delayed(Duration(milliseconds: gap));
    }
  }

  void _bed(double pan, double d) {
    switch (ds.bed) {
      case 'thunder':
      case 'wind':
      case 'rain':
        audio.ambient(ds.bed, amp: 0.1 + 0.15 * d.clamp(0.0, 1.0), pan: pan);
      case 'song':
        audio.song(0.1 + 0.15 * d.clamp(0.0, 1.0), pan);
    }
  }

  /// Số tiếng nhịp trong một khung: 0 (gần như không có) … 6 (phủ kín).
  static int pulseCount(double area) => area <= 0.02 ? 0 : math.min(6, 1 + (area * 8).floor());

  // ---------- điều khiển bằng giọng ----------
  void pause() {
    if (!running) return;
    _gen++;
    paused = true;
    running = false;
    audio.voiceMute();
    notifyListeners();
  }

  Future<void> resume() async {
    if (done) return run(intro: false);
    if (running) return;
    final my = ++_gen;
    running = true;
    paused = false;
    notifyListeners();
    await _play(my);
  }

  /// nhanh hơn (+1) / chậm lại (−1); trả về mức mới
  int changeSpeed(int delta) {
    speed = (speed + delta).clamp(0, kEicStepMs.length - 1);
    notifyListeners();
    return speed;
  }

  /// Nhảy tới khung [i] (vd "năm 2020", "khung sau"), đọc nhãn rồi hát riêng khung đó.
  Future<void> jump(int i) async {
    final my = ++_gen;
    running = false;
    paused = true;
    done = false;
    index = i.clamp(0, count - 1);
    notifyListeners();
    await audio.voiceStart(instrument: ds.voice == 'sao' ? 'sao' : 'danbau');
    await say('${frame.labelVi}. ${frameVi(frame)}', '${frame.labelEn}. ${frameEn(frame)}');
    if (my != _gen) return;
    await _singFrame(frame, my);
    audio.voiceMute();
  }

  /// Tìm khung theo năm / nhãn có trong câu nói.
  int? findFrame(String text) {
    final t = text.toLowerCase();
    final y = RegExp(r'(19|20)\d\d').firstMatch(t)?.group(0);
    for (var i = 0; i < count; i++) {
      final f = ds.frames[i];
      if (y != null && (f.labelVi.contains(y) || f.labelEn.contains(y))) return i;
    }
    // "tháng 7" (đã bỏ dấu: "thang 7") → khung có nhãn bắt đầu bằng "tháng 7" / "đầu tháng 7"
    final m = RegExp(r'\b(?:thang|tháng|month)\s*(\d{1,2})\b').firstMatch(t)?.group(1);
    if (m != null) {
      for (var i = 0; i < count; i++) {
        if (RegExp('(^|\\s)tháng $m(\\D|\$)').hasMatch(ds.frames[i].labelVi)) return i;
      }
    }
    return null;
  }

  void stop() {
    _gen++;
    running = false;
    _touchTimer?.cancel();
    audio.voiceMute();
    notifyListeners();
  }

  // ---------- rê tay ----------
  /// [x],[y] ∈ [0,1] trên hình; trả về giá trị 0…1 hoặc null (biển / không có dữ liệu)
  double? touchAt(double x, double y) {
    if (running) pause();
    touch = Offset2(x, y);
    final v = ds.at(index, x, y);
    final changed = (v == null) != (touchValue == null) || (v != null && touchValue != null && (bandOf5(v) != bandOf5(touchValue!)));
    touchValue = v;
    if (changed) Haptics.light();
    if (v == null) {
      audio.voiceSet(freq: toScale(0), pan: x * 2 - 1, gain: 0);
    } else {
      audio.voiceSet(freq: toScale(v), pan: x * 2 - 1, gain: 0.06 + 0.08 * v);
    }
    notifyListeners();
    _touchTimer?.cancel();
    _touchTimer = Timer(const Duration(milliseconds: 650), () => _speakTouch(x, y, v));
    return v;
  }

  Future<void> touchStart() => audio.voiceStart(instrument: ds.voice == 'sao' ? 'sao' : 'danbau');

  void touchEnd() {
    touch = null;
    audio.voiceMute();
    notifyListeners();
  }

  void _speakTouch(double x, double y, double? v) {
    final lon = -180 + 360 * x, lat = 90 - 180 * y;
    final where = placeName(lat, lon);
    final vi = v == null ? '$where: không có số liệu.' : '$where: ${valueVi(v)}.';
    if (vi == _lastSpoken) return;
    _lastSpoken = vi;
    final en = v == null ? '${where.en}: no data.' : '${where.en}: ${valueEn(v)}.';
    say(vi, en);
  }

  // ---------- lời đọc ----------
  static int bandOf5(double v) => (v * 5).floor().clamp(0, 4);

  static const _bandVi = ['rất thấp', 'thấp', 'vừa', 'cao', 'rất cao'];
  static const _bandEn = ['very low', 'low', 'medium', 'high', 'very high'];

  String valueVi(double v) {
    final b = _bandVi[bandOf5(v)];
    if (ds.unitVi.isEmpty || ds.high == ds.low) return b;
    return '$b, khoảng ${fmtNum(ds.real(v), _dec)} ${ds.unitVi}';
  }

  String valueEn(double v) {
    final b = _bandEn[bandOf5(v)];
    if (ds.unitEn.isEmpty || ds.high == ds.low) return b;
    return '$b, about ${fmtNum(ds.real(v), _dec, lang: 'en')} ${ds.unitEn}';
  }

  int get _dec => (ds.high - ds.low).abs() < 10 ? 1 : 0;

  String frameVi(EicFrame f) => 'Toàn cầu ${_bandVi[bandOf5(f.v)]}, phủ ${fmtNum(f.area * 100, 0)} phần trăm diện tích'
      '${f.vn > 0 ? ', vùng Việt Nam – Biển Đông ${_bandVi[bandOf5(f.vn)]}' : ''}.';
  String frameEn(EicFrame f) => 'Global level ${_bandEn[bandOf5(f.v)]}, covering ${fmtNum(f.area * 100, 0, lang: 'en')} percent of the map'
      '${f.vn > 0 ? ', Vietnam and the East Sea ${_bandEn[bandOf5(f.vn)]}' : ''}.';

  /// Tóm tắt sau khi nghe hết: xu hướng đầu–cuối, khung mạnh nhất, khung đổi nhiều nhất.
  ({int hi, int jump, double change}) stats() {
    var hi = 0, jump = 0;
    for (var i = 0; i < count; i++) {
      if (main(ds.frames[i]) > main(ds.frames[hi])) hi = i;
      if (ds.frames[i].d > ds.frames[jump].d) jump = i;
    }
    final a = main(ds.frames.first), b = main(ds.frames.last);
    final change = a <= 0.001 ? 0.0 : (b - a) / a;
    return (hi: hi, jump: jump, change: change);
  }

  /// Thay đổi riêng vùng Việt Nam – Biển Đông (khung đầu → cuối), null nếu không đáng kể / không có số liệu
  double? vnChange() {
    if (ds.pitch == 'vn') return null; // giọng chính đã là Biển Đông
    final a = ds.frames.first.vn, b = ds.frames.last.vn;
    if (a <= 0.02 || b <= 0.02) return null;
    return (b - a) / a;
  }

  int? _vnPeak() {
    var hi = 0;
    for (var i = 0; i < count; i++) {
      if (ds.frames[i].vn > ds.frames[hi].vn) hi = i;
    }
    return ds.frames[hi].vn > 0.02 ? hi : null;
  }

  int _lowest() {
    var lo = 0;
    for (var i = 0; i < count; i++) {
      if (main(ds.frames[i]) < main(ds.frames[lo])) lo = i;
    }
    return lo;
  }

  String summaryVi() {
    final s = stats();
    final f = ds.frames;
    if (ds.sweep == 'season') {
      final vnHi = _vnPeak();
      return 'Hết một vòng năm. ${ds.pitch == 'vn' ? 'Biển Đông' : 'Toàn cầu'} mạnh nhất lúc ${f[s.hi].labelVi}, yếu nhất lúc ${f[_lowest()].labelVi}. '
          '${vnHi == null || ds.pitch == 'vn' ? '' : 'Riêng vùng Việt Nam và Biển Đông mạnh nhất lúc ${f[vnHi].labelVi}. '}'
          'Nói "nghe lại", tên tháng, "giải thích", hoặc rê tay lên hình để nghe từng nơi.';
    }
    if (ds.sweep == 'space') {
      return 'Hết vòng quét từ Tây sang Đông. Cao nhất ở dải ${f[s.hi].labelVi}; thấp nhất ở dải ${f[_lowest()].labelVi}. '
          'Rê tay lên hình để nghe từng nơi, hoặc nói "nghe lại", "giải thích".';
    }
    final trend = s.change.abs() < 0.05
        ? 'gần như không đổi'
        : (s.change > 0 ? 'tăng khoảng ${fmtNum(s.change * 100, 0)} phần trăm' : 'giảm khoảng ${fmtNum(-s.change * 100, 0)} phần trăm');
    final vc = vnChange();
    final vn = vc == null || vc.abs() < 0.05
        ? ''
        : 'Riêng vùng Việt Nam và Biển Đông ${vc > 0 ? 'tăng' : 'giảm'} khoảng ${fmtNum(vc.abs() * 100, 0)} phần trăm. ';
    return 'Hết. Từ ${f.first.labelVi} đến ${f.last.labelVi}, ${ds.pitch == 'vn' ? 'Biển Đông' : 'mức toàn cầu'} $trend. $vn'
        'Mạnh nhất lúc ${f[s.hi].labelVi}; thay đổi đột ngột nhất lúc ${f[s.jump].labelVi}. '
        'Nói "nghe lại", "năm" kèm số năm, "giải thích", hoặc rê tay lên hình để nghe từng nơi.';
  }

  String summaryEn() {
    final s = stats();
    final f = ds.frames;
    if (ds.sweep == 'season') {
      final vnHi = _vnPeak();
      return 'One full year. ${ds.pitch == 'vn' ? 'The East Sea' : 'Globally'} strongest in ${f[s.hi].labelEn}, weakest in ${f[_lowest()].labelEn}. '
          '${vnHi == null || ds.pitch == 'vn' ? '' : 'Vietnam and the East Sea peak in ${f[vnHi].labelEn}. '}'
          'Say "play again", a month, "explain", or slide over the picture.';
    }
    if (ds.sweep == 'space') {
      return 'Sweep from west to east finished. Highest in the band ${f[s.hi].labelEn}; lowest in ${f[_lowest()].labelEn}. '
          'Slide over the map to hear each place, or say "play again" or "explain".';
    }
    final trend = s.change.abs() < 0.05
        ? 'stayed about the same'
        : (s.change > 0 ? 'rose about ${fmtNum(s.change * 100, 0, lang: 'en')} percent' : 'fell about ${fmtNum(-s.change * 100, 0, lang: 'en')} percent');
    final vc = vnChange();
    final vn = vc == null || vc.abs() < 0.05
        ? ''
        : 'Vietnam and the East Sea alone ${vc > 0 ? 'rose' : 'fell'} about ${fmtNum(vc.abs() * 100, 0, lang: 'en')} percent. ';
    return 'Done. From ${f.first.labelEn} to ${f.last.labelEn}, ${ds.pitch == 'vn' ? 'the East Sea' : 'the global level'} $trend. $vn'
        'Strongest at ${f[s.hi].labelEn}; the sharpest change at ${f[s.jump].labelEn}. '
        'Say "play again", a year, "explain", or slide your finger over the picture.';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class Offset2 {
  final double x, y;
  const Offset2(this.x, this.y);
}

/// Tên vùng thô theo toạ độ (đủ để người nghe định hướng khi rê tay trên bản đồ thế giới).
class PlaceName {
  final String vi, en;
  const PlaceName(this.vi, this.en);
  @override
  String toString() => vi;
}

PlaceName placeName(double lat, double lon) {
  bool box(double la0, double la1, double lo0, double lo1) => lat >= la0 && lat <= la1 && lon >= lo0 && lon <= lo1;
  if (box(8, 24, 102, 110)) return const PlaceName('Việt Nam', 'Vietnam');
  if (box(3, 23, 105, 121)) return const PlaceName('Biển Đông', 'East Sea');
  if (lat > 66) return const PlaceName('vùng Bắc Cực', 'the Arctic');
  if (lat < -60) return const PlaceName('châu Nam Cực', 'Antarctica');
  if (box(-35, 37, -18, 52)) return const PlaceName('châu Phi', 'Africa');
  if (box(36, 71, -10, 40)) return const PlaceName('châu Âu', 'Europe');
  if (box(12, 42, 35, 63)) return const PlaceName('Trung Đông', 'the Middle East');
  if (box(5, 36, 63, 92)) return const PlaceName('Nam Á', 'South Asia');
  if (box(-10, 28, 92, 150)) return const PlaceName('Đông Nam Á', 'Southeast Asia');
  if (box(20, 55, 92, 146)) return const PlaceName('Đông Á', 'East Asia');
  if (box(36, 78, 40, 180)) return const PlaceName('Bắc Á', 'Northern Asia');
  if (box(-45, -10, 112, 155)) return const PlaceName('nước Úc', 'Australia');
  if (box(15, 72, -168, -52)) return const PlaceName('Bắc Mỹ', 'North America');
  if (box(7, 23, -118, -60)) return const PlaceName('Trung Mỹ', 'Central America');
  if (box(-56, 13, -82, -34)) return const PlaceName('Nam Mỹ', 'South America');
  if (box(-60, 30, -70, 20) || box(30, 66, -60, -10)) return const PlaceName('Đại Tây Dương', 'the Atlantic Ocean');
  if (box(-60, 25, 20, 112)) return const PlaceName('Ấn Độ Dương', 'the Indian Ocean');
  return const PlaceName('Thái Bình Dương', 'the Pacific Ocean');
}
