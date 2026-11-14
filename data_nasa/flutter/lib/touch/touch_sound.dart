// touch_sound.dart — âm thanh F3 (theo mục 5 file 6 và mục 8 file 5) + đọc tiếng Việt + rung.
// Âm do app tự tạo từ số liệu NASA -> audio_kind = app_sonification.
//   - Độ cao   : nốt sáo, đất càng cao nốt càng cao (elevNote)
//   - Độ dốc   : rung ngắn, dốc càng nhiều rung càng mạnh và dài (slope)
//   - Mặt nước : tiếng sóng biển ngoài khơi, tiếng nước sông hồ trên đất liền (water)
//   - Dân cư   : tiếng xe cộ chạy qua, càng đông dân càng nhiều xe (traffic)
// Luật đổi số liệu nằm ở touch_rules.dart.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'touch_rules.dart';

export 'touch_rules.dart' show elevToMidi, snapPenta, WaterKind;

const _sr = 22050;

Uint8List _wav(Float64List s, {int sr = _sr}) {
  final n = s.length, b = ByteData(44 + n * 2);
  void str(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, sr, Endian.little);
  b.setUint32(28, sr * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (s[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Nốt sáo: âm cơ bản + hoạ âm 2, 3 nhỏ, rung nhẹ (vibrato 5 Hz) và chút hơi thổi.
Uint8List _flute(int midi, {double sec = 0.14}) {
  final n = (sec * _sr).round(), f = midiToHz(midi), s = Float64List(n), rnd = math.Random(midi);
  var breath = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _sr;
    final env = math.min(1.0, i / (0.015 * _sr)) * math.min(1.0, (n - i) / (0.04 * _sr));
    final ph = 2 * math.pi * f * t + 0.004 * f * math.sin(2 * math.pi * 5 * t) / 5;
    breath += 0.2 * ((rnd.nextDouble() * 2 - 1) - breath);
    s[i] = env * (0.42 * math.sin(ph) + 0.1 * math.sin(2 * ph) + 0.04 * math.sin(3 * ph) + 0.05 * breath);
  }
  return _wav(s);
}

Uint8List _click({int ms = 20, int seed = 1}) {
  final n = _sr * ms ~/ 1000, rnd = math.Random(seed), s = Float64List(n);
  for (var i = 0; i < n; i++) {
    s[i] = (rnd.nextDouble() * 2 - 1) * math.exp(-i / (n / 5));
  }
  return _wav(s);
}

/// Sóng biển: tiếng ào lọc thấp, to nhỏ theo nhịp 2 giây.
Uint8List _waves({double sec = 4}) {
  final n = (sec * _sr).round(), rnd = math.Random(2), s = Float64List(n);
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    lp += 0.03 * ((rnd.nextDouble() * 2 - 1) - lp);
    final swell = 0.55 + 0.45 * math.sin(2 * math.pi * i / (2 * _sr));
    s[i] = 2.5 * lp * swell;
  }
  return _wav(s);
}

/// Nước sông hồ: tiếng róc rách — nền nước nhẹ + các giọt "bóp" cao độ trượt ngẫu nhiên.
Uint8List _stream({double sec = 3}) {
  final n = (sec * _sr).round(), rnd = math.Random(5), s = Float64List(n);
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    lp += 0.12 * ((rnd.nextDouble() * 2 - 1) - lp);
    s[i] = 0.6 * lp;
  }
  for (var k = 0; k < (sec * 14).round(); k++) {
    final start = rnd.nextInt(n - _sr ~/ 10), len = _sr ~/ 25 + rnd.nextInt(_sr ~/ 30);
    final f0 = 600 + rnd.nextDouble() * 900;
    var ph = 0.0;
    for (var i = 0; i < len && start + i < n; i++) {
      final f = f0 * (1 + 1.2 * i / len); // giọt nước: cao độ trượt lên
      ph += 2 * math.pi * f / _sr;
      s[start + i] += 0.25 * math.sin(ph) * math.sin(math.pi * i / len);
    }
  }
  return _wav(s);
}

/// Một xe chạy qua (2 giây): tiếng máy (răng cưa thấp) + tiếng lốp (ồn lọc),
/// to dần rồi nhỏ dần, cao độ hạ xuống khi xe đi qua (hiệu ứng Doppler).
Uint8List _car(int seed, {double sec = 2}) {
  final n = (sec * _sr).round(), rnd = math.Random(seed), s = Float64List(n);
  final base = 70 + rnd.nextDouble() * 50, mid = n * (0.4 + 0.2 * rnd.nextDouble());
  var ph = 0.0, lp = 0.0;
  for (var i = 0; i < n; i++) {
    final x = (i - mid) / (_sr * 0.45);
    final env = 1 / (1 + x * x); // gần nhất ở giữa
    final f = base * (1 + 0.06 * (2 / math.pi) * math.atan(-x * 3));
    ph += f / _sr;
    final saw = 2 * (ph - ph.floorToDouble()) - 1;
    lp += 0.25 * ((rnd.nextDouble() * 2 - 1) - lp);
    s[i] = env * (0.35 * saw + 0.5 * lp);
  }
  return _wav(s);
}

class TouchSound {
  final _tts = FlutterTts();
  final _notes = <int, Uint8List>{};
  late final Uint8List _tick, _sea, _river;
  late final List<Uint8List> _cars;
  final _pool = List.generate(4, (_) => AudioPlayer());
  final _carPool = List.generate(3, (_) => AudioPlayer());
  final _waterPlayer = AudioPlayer();
  final _rnd = math.Random();
  int _next = 0, _nextCar = 0;
  DateTime _lastNote = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPulse = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _trafficTimer;
  double _trafficDensity = 0;
  final _carTimers = <Timer>[];
  WaterKind _water = WaterKind.none;
  bool _hasVibrator = false, _hasAmplitude = false;

  Future<void> init() async {
    for (var m = 60; m <= 84; m++) {
      _notes[snapPenta(m)] ??= _flute(snapPenta(m));
    }
    _tick = _click(ms: 20, seed: 7);
    _sea = _waves();
    _river = _stream();
    _cars = [for (var k = 0; k < 4; k++) _car(11 + k)];
    await _waterPlayer.setReleaseMode(ReleaseMode.loop);
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(false);
    if (!kIsWeb) {
      _hasVibrator = await Vibration.hasVibrator();
      _hasAmplitude = _hasVibrator && await Vibration.hasAmplitudeControl();
    }
  }

  Future<void> _play(Uint8List b, {double vol = 1}) async {
    final p = _pool[_next++ % _pool.length];
    await p.setVolume(vol);
    await p.play(BytesSource(b));
  }

  /// Câu mới luôn ngắt câu cũ.
  Future<void> say(String text) async {
    await _tts.stop();
    if (text.isNotEmpty) await _tts.speak(text);
  }

  /// Đọc hết câu rồi mới trả về (dùng khi cần nói trước, phát sau).
  Future<void> sayAndWait(String text) async {
    await _tts.awaitSpeakCompletion(true);
    await say(text);
    await _tts.awaitSpeakCompletion(false);
  }

  /// Sang vùng mới: tiếng "tíc" + rung nhẹ.
  void tick() {
    _play(_tick, vol: 0.8);
    HapticFeedback.selectionClick();
  }

  /// Nốt sáo theo độ cao, tối đa 8 nốt/giây.
  void elevNote(double meters, {double vol = 0.7}) {
    final now = DateTime.now();
    if (now.difference(_lastNote).inMilliseconds < 125) return;
    _lastNote = now;
    _play(_notes[elevToMidi(meters)]!, vol: vol);
  }

  /// Rung theo độ dốc của ô vừa chạm (tối đa 10 nhịp/giây). Bằng phẳng (< 2°) thì không rung.
  void slope(double? deg) {
    final p = slopePulse(deg);
    final now = DateTime.now();
    if (p == null || now.difference(_lastPulse).inMilliseconds < 100) return;
    _lastPulse = now;
    if (_hasAmplitude) {
      Vibration.vibrate(duration: p.ms, amplitude: p.amplitude);
    } else if (_hasVibrator && !kIsWeb && p.level == 3) {
      Vibration.vibrate(duration: p.ms);
    } else {
      // iOS / web / máy không chỉnh được cường độ: 3 mức rung có sẵn
      switch (p.level) {
        case 1:
          HapticFeedback.lightImpact();
        case 2:
          HapticFeedback.mediumImpact();
        default:
          HapticFeedback.heavyImpact();
      }
    }
  }

  /// Tiếng xe cộ theo mật độ dân số: mỗi 2 giây có carsPerWindow(density) xe chạy qua
  /// ở thời điểm ngẫu nhiên. Gọi lại khi sang ô mới; null hoặc thưa dân thì im.
  void traffic(double? density) {
    _trafficDensity = density ?? 0;
    if (carsPerWindow(density) == 0) {
      _stopTraffic();
      return;
    }
    if (_trafficTimer != null) return; // đang chạy: cửa sổ sau tự lấy mật độ mới
    void window() {
      final k = carsPerWindow(_trafficDensity), vol = trafficVolume(_trafficDensity);
      for (var i = 0; i < k; i++) {
        _carTimers.add(Timer(Duration(milliseconds: _rnd.nextInt(2000)), () async {
          final p = _carPool[_nextCar++ % _carPool.length];
          await p.setVolume(vol);
          await p.play(BytesSource(_cars[_rnd.nextInt(_cars.length)]));
        }));
      }
      _carTimers.removeWhere((t) => !t.isActive);
    }

    window();
    _trafficTimer = Timer.periodic(const Duration(seconds: 2), (_) => window());
  }

  void _stopTraffic() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    for (final t in _carTimers) {
      t.cancel();
    }
    _carTimers.clear();
    for (final p in _carPool) {
      p.stop();
    }
  }

  /// Âm nền nước: sóng biển, nước sông hồ, hoặc tắt.
  void water(WaterKind kind) {
    if (kind == _water) return;
    _water = kind;
    _waterPlayer.stop();
    if (kind == WaterKind.none) return;
    _stopTraffic();
    _waterPlayer.play(BytesSource(kind == WaterKind.sea ? _sea : _river),
        volume: kind == WaterKind.sea ? 0.5 : 0.45);
  }

  /// Giữ tương thích với code cũ.
  void sea(bool on) => water(on ? WaterKind.sea : WaterKind.none);

  /// Vượt biên giới đất liền: tắt âm nền, rung dài 150 ms.
  Future<void> border() async {
    _stopTraffic();
    water(WaterKind.none);
    if (_hasVibrator) {
      Vibration.vibrate(duration: 150);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Nhấc tay: tắt mọi âm thanh.
  void silence() {
    _stopTraffic();
    water(WaterKind.none);
    _tts.stop();
    for (final p in _pool) {
      p.stop();
    }
  }

  /// "Nói luật trước, phát nốt mốc trước" khi mở bản đồ.
  Future<void> introduceElevation() async {
    await sayAndWait('Lớp độ cao. Nốt càng cao là đất càng cao. Đây là mực nước biển.');
    await _play(_notes[elevToMidi(0)]!);
    await Future.delayed(const Duration(milliseconds: 400));
    await sayAndWait('Còn đây là từ hai nghìn mét trở lên. Máy rung khi đất dốc, có tiếng nước khi qua sông hồ.');
    await _play(_notes[elevToMidi(2000)]!);
  }

  Future<void> dispose() async {
    silence();
    for (final p in [..._pool, ..._carPool, _waterPlayer]) {
      await p.dispose();
    }
  }
}
