// Tổng hợp âm thanh nhạc cụ thành PCM (chạy một lần khi khởi động), theo đúng công thức Web Audio của bản web.
// Mỗi mẫu được render ở một cao độ gốc; khi phát, đổi cao độ bằng tốc độ phát tương đối.
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;

/// Tần số gốc của các mẫu có cao độ.
const double danbauBaseHz = 220.0;
const double trungBaseHz = 523.25;

class _Biquad {
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  /// Công thức RBJ cookbook. type: 'lowpass' | 'highpass' | 'bandpass'
  void set(String type, double freq, double q) {
    final w0 = 2 * math.pi * math.min(freq, sampleRate * 0.45) / sampleRate;
    final cw = math.cos(w0), sw = math.sin(w0), alpha = sw / (2 * q);
    double nb0, nb1, nb2;
    switch (type) {
      case 'highpass':
        nb0 = (1 + cw) / 2;
        nb1 = -(1 + cw);
        nb2 = (1 + cw) / 2;
      case 'bandpass':
        nb0 = alpha;
        nb1 = 0;
        nb2 = -alpha;
      default:
        nb0 = (1 - cw) / 2;
        nb1 = 1 - cw;
        nb2 = (1 - cw) / 2;
    }
    final a0 = 1 + alpha;
    b0 = nb0 / a0;
    b1 = nb1 / a0;
    b2 = nb2 / a0;
    a1 = -2 * cw / a0;
    a2 = (1 - alpha) / a0;
  }

  double process(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

/// Đường bao giống Web Audio: tăng tuyến tính tới peak trong att giây, rồi tắt dần mũ với hằng số tau.
double _env(double t, double peak, double att, double tau) {
  if (t < 0) return 0;
  if (t < att) return peak * t / att;
  return peak * math.exp(-(t - att) / tau);
}

/// Hài của đàn bầu (PeriodicWave imag = [0, 1, 0.5, 0.3, 0.15, 0.08]).
const _dbHarm = [1.0, 0.5, 0.3, 0.15, 0.08];
double _dbWave(double phase) {
  var s = 0.0;
  for (var k = 0; k < _dbHarm.length; k++) {
    s += _dbHarm[k] * math.sin((k + 1) * phase);
  }
  return s / 2.03;
}

Float32List _buf(double seconds) => Float32List((seconds * sampleRate).round());

final _rng = math.Random(7);
double _noise() => _rng.nextDouble() * 2 - 1;

/// Âm sắc đàn bầu thật: người chơi chạm nút bồi âm nên tiếng gần như chỉ còn âm cơ bản + bồi âm 2, mềm như sáo,
/// [bright] (0..1) thêm bồi âm cao lúc vừa gảy (tiếng "tách" của que gảy) rồi tắt dần.
double _dbVoice(double phase, double bright) {
  final b2 = bright * bright;
  final s = math.sin(phase) +
      0.42 * math.sin(2 * phase) +
      (0.10 + 0.25 * bright) * math.sin(3 * phase) +
      (0.03 + 0.16 * b2) * math.sin(4 * phase) +
      0.10 * b2 * math.sin(5 * phase) +
      0.05 * b2 * math.sin(6 * phase);
  return s / (1.55 + 0.56 * bright);
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Vòng lặp liền mạch 1 giây cho giọng chạm–nghe và cho chuỗi nốt luyến: 220 Hz, rung 5 Hz lệch ±1,6 Hz.
/// (220 và 5 đều là số chu kỳ nguyên trong 1 giây → nối vòng không có tiếng "cụp")
Float32List renderDanbauLoop() {
  final out = _buf(1.0);
  const vibHz = 5.0, dev = 1.6;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final phase = 2 * math.pi * (danbauBaseHz * t + dev / (2 * math.pi * vibHz) * (1 - math.cos(2 * math.pi * vibHz * t)));
    out[n] = _dbVoice(phase, 0.08) * 0.8;
  }
  return out;
}

/// Một nốt đàn bầu gảy, gần với tiếng thật:
///  • que gảy: tiếng "tách" ngắn (nhiễu dải 2,5 kHz, 6 ms) + bồi âm cao tắt dần trong ~80 ms
///  • "nhấn": nốt bắt đầu thấp hơn ~20 cent rồi trườn lên đúng cao độ trong ~35 ms
///  • ngân: tắt nhanh lúc đầu rồi ngân dài (~1,4 giây)
///  • rung (vibrato) chỉ bắt đầu sau ~0,2 giây và sâu dần, 5,6 Hz, như tay rung cần đàn
Float32List renderDanbauNote({double dur = 2.4}) {
  final out = _buf(dur);
  final click = _Biquad()..set('bandpass', 2500, 1.2);
  var phase = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final scoop = 1 - 0.012 * math.exp(-t / 0.035);
    final vib = 0.0075 * _smooth(0.18, 0.55, t) * math.sin(2 * math.pi * 5.6 * t + 0.4 * math.sin(2 * math.pi * 0.7 * t));
    final f = danbauBaseHz * scoop * (1 + vib);
    phase += 2 * math.pi * f / sampleRate;
    final bright = math.exp(-t / 0.08);
    final amp = (t < 0.003 ? t / 0.003 : 1.0) * (0.5 * math.exp(-t / 0.18) + 0.5 * math.exp(-t / 1.4));
    final tail = t > dur - 0.12 ? (dur - t) / 0.12 : 1.0; // tắt êm ở cuối mẫu
    var y = _dbVoice(phase, bright) * amp * tail;
    if (t < 0.03) y += click.process(_noise()) * 0.22 * math.exp(-t / 0.006);
    out[n] = y;
  }
  return out;
}

/// Chỉ tiếng que gảy (~60 ms) — gảy lại dây khi chuỗi nốt luyến cần nhấn một nốt mới.
Float32List renderDanbauPluck() {
  final out = _buf(0.06);
  final click = _Biquad()..set('bandpass', 2600, 1.2);
  var phase = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    phase += 2 * math.pi * danbauBaseHz * 3 / sampleRate;
    out[n] = click.process(_noise()) * 0.5 * math.exp(-t / 0.006) + math.sin(phase) * 0.18 * math.exp(-t / 0.018);
  }
  return out;
}

/// T'rưng: ba mode không hài (1 : 2,76 : 5,4), tắt rất nhanh.
Float32List renderTrung() {
  final out = _buf(0.9);
  const modes = [[1.0, 1.0, 0.12], [2.76, 0.45, 0.05], [5.4, 0.2, 0.025]];
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    var s = 0.0;
    for (final m in modes) {
      s += math.sin(2 * math.pi * trungBaseHz * m[0] * t) * _env(t, m[1], 0.002, m[2]);
    }
    out[n] = s * 0.6;
  }
  return out;
}

/// Mõ: hai sin 1250/1900 Hz + tiếng gõ nhiễu băng hẹp.
Float32List renderMo() {
  final out = _buf(0.3);
  final bp = _Biquad()..set('bandpass', 2500, 4);
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    var s = math.sin(2 * math.pi * 1250 * t) * _env(t, 0.35, 0.002, 0.03) +
        math.sin(2 * math.pi * 1900 * t) * _env(t, 0.12, 0.002, 0.03);
    if (t < 0.05) s += bp.process(_noise()) * _env(t, 0.2, 0.002, 0.01) * 3;
    out[n] = s;
  }
  return out;
}

/// Trống: sin quét 130 → 52 Hz trong 120 ms + nhiễu trầm.
Float32List renderTrong() {
  final out = _buf(1.2);
  final lp = _Biquad()..set('lowpass', 300, 0.7);
  var phase = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final double f = t < 0.12 ? (130 * math.pow(52 / 130, t / 0.12)).toDouble() : 52.0;
    phase += 2 * math.pi * f / sampleRate;
    var s = math.sin(phase) * _env(t, 1.0, 0.003, 0.18);
    if (t < 0.2) s += lp.process(_noise()) * _env(t, 0.5, 0.002, 0.05);
    out[n] = s;
  }
  return out;
}

/// Chiêng: bốn partial, hai partial thấp lệch nhau tạo phách.
Float32List renderChieng() {
  final out = _buf(4.5);
  const parts = [[196.0, 1.0, 1.2], [198.5, 0.7, 1.2], [466.0, 0.35, 0.6], [608.0, 0.2, 0.4]];
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    var s = 0.0;
    for (final p in parts) {
      s += math.sin(2 * math.pi * p[0] * t) * _env(t, p[1], 0.015, p[2]);
    }
    out[n] = s * 0.45;
  }
  return out;
}

/// Tiếng lửa lách tách: nhiễu thông cao 20 ms, tắt rất nhanh. Render vài biến thể để nghe tự nhiên.
Float32List renderCrackle(int seed) {
  final r = math.Random(seed);
  final out = _buf(0.03);
  final hp = _Biquad()..set('highpass', 1800, 0.7);
  final tau = 0.004 + r.nextDouble() * 0.006;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    out[n] = hp.process(r.nextDouble() * 2 - 1) * _env(t, 1.0, 0.002, tau);
  }
  return out;
}

/// Sóng biển: nhiễu thông thấp, tần cắt 400 → 900 → 350 Hz, biên độ lên rồi xuống trong 1,35 s.
Float32List renderSong() {
  final out = _buf(1.4);
  final lp = _Biquad();
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    if (n % 64 == 0) {
      final fc = t < 0.6 ? 400 + 500 * t / 0.6 : (t < 1.3 ? 900 - 550 * (t - 0.6) / 0.7 : 350.0);
      lp.set('lowpass', fc.toDouble(), 0.707);
    }
    final g = t < 0.55 ? t / 0.55 : math.max(0.0, 1 - (t - 0.55) / 0.8);
    out[n] = lp.process(_noise()) * g * 1.6;
  }
  return out;
}

/// Âm báo giao diện. kind: ok | err | tick
Float32List renderEarcon(String kind) {
  final out = _buf(0.35);
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    double s;
    switch (kind) {
      case 'ok':
        s = math.sin(2 * math.pi * 660 * t) * _env(t, 0.5, 0.005, 0.06) +
            math.sin(2 * math.pi * 880 * t) * _env(t - 0.09, 0.5, 0.005, 0.08);
      case 'err':
        s = math.sin(2 * math.pi * 330 * t) * _env(t, 0.5, 0.005, 0.08) +
            math.sin(2 * math.pi * 247 * t) * _env(t - 0.11, 0.5, 0.005, 0.1);
      case 'think':
        // "đang tìm dữ liệu": hai tiếng chuông nhỏ trong trẻo, nhẹ (ding ding), ngũ cung G6 – C7
        s = (math.sin(2 * math.pi * 1568 * t) + 0.3 * math.sin(2 * math.pi * 3136 * t)) * _env(t, 0.22, 0.003, 0.07) +
            (math.sin(2 * math.pi * 2093 * t) + 0.3 * math.sin(2 * math.pi * 4186 * t)) * _env(t - 0.13, 0.18, 0.003, 0.08);
      default:
        s = math.sin(2 * math.pi * 2600 * t) * _env(t, 0.3, 0.001, 0.008);
    }
    out[n] = s;
  }
  return out;
}

// ======================= Âm nền thời tiết (phát 2–3 giây trước khi đọc chi tiết) =======================

/// Đường bao vào/ra mềm cho âm nền: lên trong [a] giây, xuống trong [r] giây cuối.
double _fade(double t, double dur, {double a = 0.4, double r = 0.8}) {
  if (t < a) return t / a;
  if (t > dur - r) return math.max(0.0, (dur - t) / r);
  return 1.0;
}

/// Tiếng mưa: nhiễu thông cao mịn (mưa rơi đều) + những giọt nước lách tách.
Float32List renderAmbRain() {
  const dur = 3.0;
  final out = _buf(dur);
  final hp = _Biquad()..set('highpass', 1200, 0.6);
  final bp = _Biquad()..set('bandpass', 3500, 1.2);
  final r = math.Random(11);
  var drop = 0.0, dropF = 3000.0, dropT = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    if (r.nextDouble() < 0.0016) {
      drop = 0.5 + r.nextDouble() * 0.5;
      dropF = 1800 + r.nextDouble() * 2600;
      dropT = t;
    }
    final d = drop * math.sin(2 * math.pi * dropF * (t - dropT)) * math.exp(-(t - dropT) / 0.006);
    out[n] = (hp.process(_noise()) * 0.35 + bp.process(_noise()) * 0.25 + d * 0.5) * _fade(t, dur);
  }
  return out;
}

/// Tiếng gió: nhiễu thông thấp, tần cắt lên xuống chậm như từng cơn gió.
Float32List renderAmbWind() {
  const dur = 3.0;
  final out = _buf(dur);
  final lp = _Biquad();
  final bp = _Biquad();
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    if (n % 64 == 0) {
      final gust = 0.5 + 0.5 * math.sin(2 * math.pi * 0.45 * t - 1.2);
      lp.set('lowpass', 250 + 650 * gust, 0.9);
      bp.set('bandpass', 500 + 900 * gust, 3);
    }
    final g = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.45 * t - 1.2));
    out[n] = (lp.process(_noise()) * 1.2 + bp.process(_noise()) * 0.8) * g * _fade(t, dur);
  }
  return out;
}

/// Nắng: hợp âm sáng, ấm (ngũ cung) ngân nhẹ, lấp lánh ở quãng cao.
Float32List renderAmbSun() {
  const dur = 3.0;
  final out = _buf(dur);
  const fs = [392.0, 493.88, 587.33, 783.99];
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    var s = 0.0;
    for (var k = 0; k < fs.length; k++) {
      s += math.sin(2 * math.pi * fs[k] * t + k) * (0.6 - k * 0.1) * (0.8 + 0.2 * math.sin(2 * math.pi * (0.7 + k * 0.3) * t));
    }
    // lấp lánh
    s += math.sin(2 * math.pi * 1567.98 * t) * 0.12 * math.max(0.0, math.sin(2 * math.pi * 2.3 * t));
    out[n] = s * 0.3 * _fade(t, dur, a: 0.6, r: 1.0);
  }
  return out;
}

/// Sấm: tiếng ầm trầm cuộn dài.
Float32List renderAmbThunder() {
  const dur = 3.0;
  final out = _buf(dur);
  final lp = _Biquad()..set('lowpass', 140, 0.8);
  final lp2 = _Biquad()..set('lowpass', 600, 0.7);
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final crack = t > 0.15 && t < 0.5 ? lp2.process(_noise()) * math.exp(-(t - 0.15) / 0.12) * 1.5 : 0.0;
    final roll = lp.process(_noise()) * 3.2 * math.exp(-math.max(0.0, t - 0.2) / 1.1) * (t < 0.2 ? t / 0.2 : 1.0);
    out[n] = (roll + crack) * (0.8 + 0.2 * math.sin(2 * math.pi * 3.1 * t));
  }
  return out;
}

/// Động đất: tiếng ầm rất trầm (40–90 Hz) từ lòng đất, có những cú giật mạnh dồn dập.
Float32List renderAmbQuake() {
  const dur = 3.0;
  final out = _buf(dur);
  final lp = _Biquad()..set('lowpass', 90, 0.9);
  final lp2 = _Biquad()..set('lowpass', 260, 0.7);
  final r = math.Random(23);
  var jolt = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    if (n % 2205 == 0 && r.nextDouble() < 0.55) jolt = 0.6 + r.nextDouble() * 0.8; // mỗi 50 ms có thể giật
    jolt *= 0.9996;
    final rumble = lp.process(_noise()) * 4.0 * (0.6 + 0.4 * math.sin(2 * math.pi * 1.7 * t));
    final crack = lp2.process(_noise()) * jolt * 0.9;
    out[n] = (rumble + crack + 0.35 * math.sin(2 * math.pi * 38 * t) * jolt) * _fade(t, dur, a: 0.25, r: 0.9);
  }
  return out;
}

/// Phố xá: tiếng máy xe ì ì (răng cưa trầm lên xuống), tiếng lốp lướt qua trái → phải, thỉnh thoảng một tiếng còi ngắn.
Float32List renderAmbTraffic() {
  const dur = 3.0;
  final out = _buf(dur);
  final lp = _Biquad()..set('lowpass', 420, 0.8);
  final bp = _Biquad()..set('bandpass', 900, 0.9);
  var ph = 0.0, ph2 = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final f = 82 + 18 * math.sin(2 * math.pi * 0.6 * t) + 10 * math.sin(2 * math.pi * 2.3 * t);
    ph += f / sampleRate;
    ph2 += f * 1.51 / sampleRate;
    final saw = 2 * (ph - ph.floorToDouble()) - 1, saw2 = 2 * (ph2 - ph2.floorToDouble()) - 1;
    final engine = lp.process(saw * 0.6 + saw2 * 0.35);
    // hai xe lướt qua (tiếng lốp dâng lên rồi tắt)
    final pass = math.exp(-math.pow((t - 0.9) / 0.35, 2)) + 0.8 * math.exp(-math.pow((t - 2.1) / 0.4, 2));
    final tyre = bp.process(_noise()) * pass * 0.9;
    // còi xe máy ngắn ở giây 1,5
    final horn = t > 1.45 && t < 1.7 ? (math.sin(2 * math.pi * 420 * t) + 0.6 * math.sin(2 * math.pi * 530 * t)) * 0.18 : 0.0;
    out[n] = (engine * 0.8 + tyre + horn) * _fade(t, dur, a: 0.3, r: 0.6);
  }
  return out;
}

/// Tần số gốc của vòng lặp sáo.
const double saoBaseHz = 440.0;

/// Sáo trúc liền hơi: âm cơ bản tròn + bồi âm 2, 3 rất nhẹ + tiếng hơi thổi; rung 5 Hz. Vòng lặp liền mạch 1 giây
/// (440 và 5 là số chu kỳ nguyên trong 1 giây).
Float32List renderSaoLoop() {
  final out = _buf(1.0);
  const vibHz = 5.0, dev = 3.0;
  final bp = _Biquad()..set('bandpass', 1300, 1.4);
  // chạy bộ lọc hơi thổi một vòng trước để vào trạng thái ổn định (không có tiếng "bụp" ở chỗ nối)
  for (var n = 0; n < sampleRate; n++) {
    bp.process(_noise());
  }
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final phase = 2 * math.pi * (saoBaseHz * t + dev / (2 * math.pi * vibHz) * (1 - math.cos(2 * math.pi * vibHz * t)));
    final tone = math.sin(phase) + 0.18 * math.sin(2 * phase) + 0.07 * math.sin(3 * phase);
    final breath = bp.process(_noise()) * 0.22 * (0.8 + 0.2 * math.sin(2 * math.pi * vibHz * t));
    out[n] = (tone * 0.75 + breath) * 0.8;
  }
  return out;
}

/// Còi cảnh báo thiên tai: hai nốt luân phiên (khác hẳn mọi âm khác trong app).
Float32List renderAlarm() {
  const dur = 1.6;
  final out = _buf(dur);
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final hi = (t * 2.5).floor() % 2 == 0;
    final f = hi ? 988.0 : 740.0;
    final s = math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t);
    out[n] = s * 0.5 * _fade(t, dur, a: 0.02, r: 0.15);
  }
  return out;
}

// ======================= Âm thanh đặc trưng của các thiên thể (do app tổng hợp, gợi tả tính chất) =======================
// 0 Mặt Trời · 1 Sao Thủy · 2 Sao Kim · 3 Trái Đất · 4 Mặt Trăng · 5 Sao Hỏa · 6 Sao Mộc · 7 Sao Thổ · 8 Sao Thiên Vương · 9 Sao Hải Vương
const planetSoundCount = 10;

Float32List renderPlanet(int i) {
  const dur = 3.2;
  final out = _buf(dur);
  final f1 = _Biquad(), f2 = _Biquad();
  final r = math.Random(100 + i);
  var ping = 0.0, pingT = -1.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    double s;
    switch (i) {
      case 0: // Mặt Trời: lò lửa khổng lồ — tiếng ầm cuộn + nhịp trầm
        if (n == 0) f1.set('lowpass', 220, 0.7);
        s = f1.process(_noise()) * 2.4 * (0.7 + 0.3 * math.sin(2 * math.pi * 0.8 * t)) +
            math.sin(2 * math.pi * 55 * t) * 0.35 * (0.6 + 0.4 * math.sin(2 * math.pi * 0.5 * t));
      case 1: // Sao Thủy: chạy nhanh nhất — tiếng "ping" cao dồn dập
        if (t - pingT > 0.16) {
          pingT = t;
          ping = 0.6 + r.nextDouble() * 0.4;
        }
        s = ping * math.sin(2 * math.pi * 1760 * (t - pingT)) * math.exp(-(t - pingT) / 0.04);
      case 2: // Sao Kim: khí quyển đặc, nóng — tiếng xì xì dày đặc + ầm trầm
        if (n == 0) {
          f1.set('bandpass', 700, 0.6);
          f2.set('lowpass', 90, 0.7);
        }
        s = f1.process(_noise()) * 0.9 + f2.process(_noise()) * 2.0;
      case 3: // Trái Đất: gió nhẹ + nước + một giai điệu ấm
        if (n == 0) f1.set('lowpass', 500, 0.7);
        final mel = [392.0, 440.0, 523.25, 440.0][(t / 0.8).floor() % 4];
        s = f1.process(_noise()) * 0.6 * (0.6 + 0.4 * math.sin(2 * math.pi * 0.3 * t)) +
            _dbWave(2 * math.pi * mel * t) * 0.35 * math.exp(-((t % 0.8)) / 0.5);
      case 4: // Mặt Trăng: gần như im lặng — một nốt cao rất xa, ngân chậm
        s = math.sin(2 * math.pi * 880 * t) * 0.25 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.25 * t));
      case 5: // Sao Hỏa: gió mỏng, khô, rít
        if (n % 64 == 0) f1.set('bandpass', 1600 + 1200 * math.sin(2 * math.pi * 0.35 * t), 4);
        s = f1.process(_noise()) * 1.4 * (0.4 + 0.6 * math.max(0.0, math.sin(2 * math.pi * 0.35 * t)));
      case 6: // Sao Mộc: khổng lồ — trầm rất sâu, bão xoáy
        if (n == 0) f1.set('lowpass', 160, 0.8);
        s = (math.sin(2 * math.pi * 41.2 * t) * 0.6 + math.sin(2 * math.pi * 61.8 * t) * 0.35) *
                (0.6 + 0.4 * math.sin(2 * math.pi * 1.7 * t)) +
            f1.process(_noise()) * 1.2 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.6 * t));
      case 7: // Sao Thổ: vành đai băng — tiếng chuông ngân lấp lánh
        s = 0;
        for (final (f, a) in const [(311.1, 0.5), (622.3, 0.3), (933.4, 0.2), (1244.5, 0.15), (1555.6, 0.1)]) {
          s += math.sin(2 * math.pi * (f + 1.5) * t) * a;
        }
        s *= 0.6 * (0.7 + 0.3 * math.sin(2 * math.pi * 1.5 * t));
      case 8: // Sao Thiên Vương: băng giá, nằm nghiêng — tiếng thủy tinh lạnh, lắc lư
        s = math.sin(2 * math.pi * (1046.5 + 12 * math.sin(2 * math.pi * 0.4 * t)) * t) * 0.35 +
            math.sin(2 * math.pi * 1568 * t) * 0.18;
      default: // Sao Hải Vương: gió nhanh nhất Hệ Mặt Trời — cơn gió vù vù + trầm lạnh
        if (n % 64 == 0) f1.set('bandpass', 750 + 450 * math.sin(2 * math.pi * 1.6 * t), 2);
        s = f1.process(_noise()) * 1.6 + math.sin(2 * math.pi * 65.4 * t) * 0.3;
    }
    out[n] = s * _fade(t, dur, a: 0.3, r: 0.7);
  }
  return out;
}

/// Float [-1, 1] → WAV PCM 16-bit mono. Chuẩn hóa đỉnh về 0,9 để không vỡ tiếng.
Uint8List toWav(Float32List pcm, {bool normalize = true}) {
  var peak = 0.0;
  for (final x in pcm) {
    peak = math.max(peak, x.abs());
  }
  final gain = (normalize && peak > 0) ? 0.9 / peak : 1.0;
  final dataBytes = pcm.length * 2;
  final b = ByteData(44 + dataBytes);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < pcm.length; i++) {
    final v = (pcm[i] * gain).clamp(-1.0, 1.0);
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
