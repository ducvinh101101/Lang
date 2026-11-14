// Bộ âm thanh dùng chung cho mọi màn: giọng chạm–nghe liên tục + các nhạc cụ phát một lần.
// Ánh xạ dữ liệu → âm thanh giữ đúng như bản web (thang ngũ cung, đàn bầu/T'rưng/lửa, mõ khi qua vùng, sóng ở biển).
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/crash_guard.dart';
import 'sound_backend.dart';
import 'synth.dart';

/// Ngũ cung (cung, thương, giốc, chủy, vũ) — bậc nửa cung tính từ nốt gốc.
const ho = [0, 2, 5, 7, 9];

/// x ∈ [0,1] → tần số trên 3 quãng tám ngũ cung, từ C3 (130,81 Hz).
double toScale(double x) {
  x = math.max(0.0, math.min(1.0, x));
  final s = (x * (ho.length * 3 - 1)).round();
  return 130.81 * math.pow(2, (12 * (s ~/ ho.length) + ho[s % ho.length]) / 12).toDouble();
}

final _rng = math.Random();

/// Một nốt cao ngẫu nhiên trong ngũ cung quãng C5, cho tiếng mưa.
double randHigh() => 523.25 * math.pow(2, ho[_rng.nextInt(5)] / 12).toDouble();

const _crackleVariants = 4;
const _gain = 3.0; // biên độ trong code web → âm lượng mẫu đã chuẩn hóa

Map<String, Uint8List> _renderCore() => {
      'danbau_note': toWav(renderDanbauNote()),
      'danbau_pluck': toWav(renderDanbauPluck()),
      'trung': toWav(renderTrung()),
      'mo': toWav(renderMo()),
      'trong': toWav(renderTrong()),
      'chieng': toWav(renderChieng()),
      'song': toWav(renderSong()),
      'earcon_ok': toWav(renderEarcon('ok')),
      'earcon_err': toWav(renderEarcon('err')),
      'earcon_tick': toWav(renderEarcon('tick')),
      'earcon_think': toWav(renderEarcon('think')),
    };

Map<String, Uint8List> _renderHeavyArg(Object? _) => _renderHeavy();

Map<String, Uint8List> _renderHeavy() => {
      'danbau_loop': toWav(renderDanbauLoop(), normalize: false),
      for (var k = 0; k < _crackleVariants; k++) 'crackle$k': toWav(renderCrackle(k + 1)),
      'amb_rain': toWav(renderAmbRain()),
      'amb_wind': toWav(renderAmbWind()),
      'amb_sun': toWav(renderAmbSun()),
      'amb_thunder': toWav(renderAmbThunder()),
      'amb_quake': toWav(renderAmbQuake()),
      'amb_traffic': toWav(renderAmbTraffic()),
      'sao_loop': toWav(renderSaoLoop(), normalize: false),
      'alarm': toWav(renderAlarm()),
      for (var k = 0; k < planetSoundCount; k++) 'planet_$k': toWav(renderPlanet(k)),
    };

class AudioEngine extends ChangeNotifier {
  final SoundBackend _b;
  AudioEngine(this._b);

  bool ready = false;
  String? error;

  /// false = không khởi động thư viện âm thanh (chế độ an toàn sau khi nó làm app văng, hoặc người dùng tắt).
  bool enabled = true;
  double _volume = 0.8;
  bool _ducked = false;
  Object? _voice; // vòng lặp đàn bầu cho chạm–nghe
  String _voiceInstr = 'danbau';
  bool _voiceOn = false;
  final _recent = <(Object, DateTime)>[];

  double get volume => _volume;

  Future<void> init() async {
    if (ready || !enabled) return;
    try {
      CrashGuard.enter('audio', 'init');
      // Thư viện âm thanh đôi khi treo lúc mở thiết bị loa (máy vừa đổi loa/tai nghe, app khác đang giữ loa…).
      // Không được để app kẹt mãi ở "Đang lên dây đàn": quá 8 giây thì đi tiếp không có nhạc cụ (giọng đọc
      // chuyển sang giọng của máy), thư viện mở xong muộn thì tự nạp âm thanh ở nền.
      final initF = _b.init();
      final inTime = await initF.then((_) => true).timeout(const Duration(seconds: 8), onTimeout: () => false);
      CrashGuard.leave();
      if (!inTime) {
        error = 'audio init timeout';
        CrashGuard.log('[audio] mở loa quá 8 giây → tạm chạy không có nhạc cụ');
        unawaited(initF.then((_) => _loadSamples()).catchError((Object e) {
          CrashGuard.log('[audio] mở loa muộn vẫn lỗi: $e');
        }));
        notifyListeners();
        return;
      }
      await _loadSamples();
    } catch (e) {
      CrashGuard.leave();
      error = '$e';
      CrashGuard.log('[audio] init lỗi: $e');
    }
    notifyListeners();
  }

  Future<void> _loadSamples() async {
    // 1) Nạp ngay các âm ngắn cốt lõi (~100 ms) để bộ phát giọng nói Piper và âm báo sẵn sàng tức thì khi mở app
    final core = _renderCore();
    for (final e in core.entries) {
      CrashGuard.enter('audio', 'load');
      await _b.load(e.key, e.value);
      CrashGuard.leave();
    }
    _b.setMasterVolume(_volume);
    ready = true;
    error = null;
    notifyListeners();
    // 2) Các âm nền dài (mưa, gió, 10 hành tinh…) tổng hợp ở nền để không giữ màn hình khởi động
    unawaited(_loadHeavySamples());
  }

  Future<void> _loadHeavySamples() async {
    try {
      final wavs = await compute(_renderHeavyArg, null);
      for (final e in wavs.entries) {
        CrashGuard.enter('audio', 'load');
        await _b.load(e.key, e.value);
        CrashGuard.leave();
      }
    } catch (e) {
      CrashGuard.leave();
      CrashGuard.log('[audio] nạp âm nền lỗi: $e');
    }
  }

  void setVolume(double v) {
    _volume = math.max(0.0, math.min(1.0, v));
    try {
      _b.setMasterVolume(_volume);
    } catch (_) {}
    notifyListeners();
  }

  /// Hạ nhỏ âm dữ liệu khi giọng đọc đang nói.
  /// (Hạ riêng âm nhạc cụ, KHÔNG hạ giọng đọc — giọng đọc đóng gói cũng phát qua bộ âm thanh này.)
  void duck(bool on) {
    if (_ducked == on) return;
    _ducked = on;
    final v = _voice;
    if (v != null && _voiceOn) {
      try {
        _b.setVolume(v, (on ? 0.3 : 1.0) * _lastVoiceGain * _gain, fade: const Duration(milliseconds: 60));
      } catch (_) {}
    }
  }

  double get _duckK => _ducked ? 0.3 : 1.0;
  double _lastVoiceGain = 0;

  // ---------- Giọng đọc đóng gói (PiperVoice) ----------
  int _speechN = 0;
  String? _speechName;
  Object? _speechHandle;

  /// Phát một câu đọc (WAV). Câu mới thay câu cũ.
  Future<void> playSpeech(Uint8List wav, {double volume = 1.0}) async {
    if (!ready) return;
    stopSpeech();
    final name = 'speech_${++_speechN}';
    try {
      CrashGuard.enter('audio', 'speech');
      await _b.load(name, wav);
      _speechHandle = await _b.play(name, volume: volume);
      CrashGuard.leave();
      final old = _speechName;
      _speechName = name;
      if (old != null) await _b.unload(old); // giải phóng câu trước (đã dừng)
    } catch (e) {
      CrashGuard.leave();
      debugPrint('[audio] speech: $e');
    }
  }

  void stopSpeech() {
    final h = _speechHandle;
    _speechHandle = null;
    if (h != null) {
      try {
        _b.stop(h);
      } catch (_) {}
    }
  }

  Future<void> _shot(String name, {double amp = 0.3, double pan = 0, double speed = 1}) async {
    if (!ready) return;
    try {
      CrashGuard.enter('audio', 'play');
      final h = await _b.play(name,
          volume: math.min(1.0, amp * _gain * _duckK),
          pan: math.max(-1.0, math.min(1.0, pan)),
          speed: math.max(0.05, math.min(8.0, speed)));
      CrashGuard.leave();
      if (h != null) _track(h);
    } catch (e) {
      CrashGuard.leave();
      debugPrint('[audio] $name: $e');
    }
  }

  void _track(Object h) {
    final now = DateTime.now();
    _recent.add((h, now));
    _recent.removeWhere((r) => now.difference(r.$2).inSeconds > 6);
  }

  // ---------- Giọng chạm–nghe ----------
  /// [instrument]: 'danbau' (mặc định) | 'sao' (sáo trúc — chạm địa hình: đất càng cao tiếng sáo càng cao).
  Future<void> voiceStart({String instrument = 'danbau'}) async {
    if (!ready) return;
    if (_voice != null && _voiceInstr == instrument) return;
    final old = _voice;
    if (old != null) {
      try {
        _b.stop(old);
      } catch (_) {}
      _voice = null;
      _voiceOn = false;
    }
    try {
      CrashGuard.enter('audio', 'voiceStart');
      _voiceInstr = instrument;
      _voice = await _b.play(instrument == 'sao' ? 'sao_loop' : 'danbau_loop', volume: 0, loop: true);
    } catch (e) {
      debugPrint('[audio] voiceStart: $e');
    } finally {
      CrashGuard.leave();
    }
  }

  /// freq: tần số mong muốn; gain: 0 tắt tiếng (vẫn chạy ngầm để chạm lại không trễ).
  void voiceSet({required double freq, required double pan, required double gain}) {
    final v = _voice;
    if (v == null) return;
    try {
      CrashGuard.enter('audio', 'voiceSet');
      // rê tay sang độ cao khác: trượt cao độ 70 ms như vuốt cần đàn (không nhảy bậc)
      _b.setSpeed(v, math.max(0.05, math.min(8.0, freq / (_voiceInstr == 'sao' ? saoBaseHz : danbauBaseHz))),
          fade: const Duration(milliseconds: 70));
      _b.setPan(v, math.max(-1.0, math.min(1.0, pan)));
      _lastVoiceGain = gain;
      _b.setVolume(v, math.min(1.0, gain * _gain * _duckK), fade: const Duration(milliseconds: 20));
      _voiceOn = gain > 0;
    } catch (_) {
    } finally {
      CrashGuard.leave();
    }
  }

  void voiceMute() {
    final v = _voice;
    if (v == null || !_voiceOn) return;
    try {
      _b.setVolume(v, 0, fade: const Duration(milliseconds: 50));
    } catch (_) {}
    _voiceOn = false;
  }

  // ---------- Nhạc cụ ----------
  /// Nốt đàn bầu gảy rồi LUYẾN từ f0 sang f1 (giữ cao độ đầu ~90 ms cho nghe rõ, rồi uốn cần đàn sang f1),
  /// ngân tự nhiên và tắt êm sau khoảng [dur] × 1,6 giây.
  Future<void> danbauNote(double f0, double f1, double dur, double amp, double pan) async {
    if (!ready) return;
    try {
      CrashGuard.enter('audio', 'note');
      final vol = math.min(1.0, amp * _gain * _duckK);
      final h = await _b.play('danbau_note',
          volume: vol, pan: math.max(-1.0, math.min(1.0, pan)), speed: _spd(f0));
      CrashGuard.leave();
      if (h == null) return;
      _track(h);
      if ((f1 - f0).abs() > 0.5) {
        final glide = (math.max(0.08, 0.55 * dur) * 1000).round();
        Future<void>.delayed(const Duration(milliseconds: 90), () {
          try {
            _b.setSpeed(h, _spd(f1), fade: Duration(milliseconds: glide));
          } catch (_) {}
        });
      }
      // nốt ngắn: không để ngân chồng lên nốt sau
      if (dur < 1.0) {
        Future<void>.delayed(Duration(milliseconds: (dur * 1600).round()), () {
          try {
            _b.setVolume(h, 0, fade: const Duration(milliseconds: 220));
          } catch (_) {}
        });
      }
    } catch (_) {
      CrashGuard.leave();
    }
  }

  double _spd(double f) => math.max(0.05, math.min(8.0, f / danbauBaseHz));

  /// Bắt đầu một CÂU NHẠC ĐÀN BẦU LIỀN TIẾNG: một dây ngân liên tục, các nốt sau chuyển bằng cách uốn cần đàn
  /// (luyến) thay vì gảy rời từng nốt. Trả về null nếu chưa có âm thanh.
  Future<DanbauPhrase?> phraseStart(double freq, {double pan = 0, double amp = 0.24}) async {
    if (!ready) return null;
    try {
      CrashGuard.enter('audio', 'phrase');
      final vol = math.min(1.0, amp * _gain * _duckK);
      final h = await _b.play('danbau_loop', volume: 0, loop: true, speed: _spd(freq), pan: pan.clamp(-1.0, 1.0).toDouble());
      CrashGuard.leave();
      if (h == null) return null;
      _track(h);
      _b.setVolume(h, vol, fade: const Duration(milliseconds: 12));
      unawaited(_shot('danbau_pluck', amp: amp * 0.8, pan: pan, speed: _spd(freq)));
      return DanbauPhrase._(this, h, freq, vol);
    } catch (_) {
      CrashGuard.leave();
      return null;
    }
  }
  void trung(double f, double amp, double pan) => _shot('trung', amp: amp, pan: pan, speed: f / trungBaseHz);
  void mo() => _shot('mo', amp: 0.35);
  void trong(double amp, [double pan = 0]) => _shot('trong', amp: amp, pan: pan);
  void chieng(double amp) => _shot('chieng', amp: amp);
  void song(double amp, double pan) => _shot('song', amp: amp, pan: pan);
  void crackle(double amp, double pan) =>
      _shot('crackle${_rng.nextInt(_crackleVariants)}', amp: amp * (0.3 + _rng.nextDouble()) * 0.5, pan: pan);
  void earcon(String kind) => _shot('earcon_$kind', amp: 0.2);

  /// Âm nền thời tiết: 'rain' | 'wind' | 'sun' | 'thunder' (khoảng 3 giây).
  /// Thêm: 'quake' (động đất), 'traffic' (xe cộ). [speed] < 1 trầm và dài hơn, > 1 cao và ngắn hơn.
  void ambient(String kind, {double amp = 0.22, double pan = 0, double speed = 1}) =>
      _shot('amb_$kind', amp: amp, pan: pan, speed: speed);

  final _recordings = <String>{};

  /// Phát một BẢN GHI ÂM (mp3 của NASA…): nạp bằng [bytes] ở lần đầu, các lần sau phát ngay. Trả về false nếu
  /// chưa có âm thanh hoặc thư viện không giải mã được.
  Future<bool> playRecording(String name, Future<Uint8List> Function() bytes, {double amp = 0.33}) async {
    if (!ready) return false;
    final key = name.endsWith('.mp3') ? name : '$name.mp3';
    try {
      if (!_recordings.contains(key)) {
        CrashGuard.enter('audio', 'loadRecording');
        await _b.load(key, await bytes());
        CrashGuard.leave();
        _recordings.add(key);
      }
      await _shot(key, amp: amp);
      return true;
    } catch (e) {
      CrashGuard.leave();
      CrashGuard.log('[audio] bản ghi $key: $e');
      return false;
    }
  }

  /// Còi cảnh báo thiên tai.
  void alarm() => _shot('alarm', amp: 0.25);

  /// Âm thanh đặc trưng của thiên thể (0 Mặt Trời … 9 Sao Hải Vương).
  void planet(int i, {double amp = 0.3}) => _shot('planet_$i', amp: amp);

  /// Dừng mọi âm thanh (nút "Dừng" luôn phải có hiệu lực ngay).
  void stopAll() {
    for (final r in _recent) {
      try {
        _b.stop(r.$1);
      } catch (_) {}
    }
    _recent.clear();
    voiceMute();
  }

  @override
  void dispose() {
    _b.dispose();
    super.dispose();
  }
}

/// Một câu nhạc đàn bầu đang ngân (xem [AudioEngine.phraseStart]).
class DanbauPhrase {
  DanbauPhrase._(this._e, this._h, this._f, this._vol);
  final AudioEngine _e;
  final Object _h;
  double _f;
  final double _vol;
  bool _ended = false;

  /// Chuyển sang nốt [freq] trong [stepMs] ms tới:
  ///  • quãng nhỏ (dưới 5 nửa cung): luyến — uốn cần đàn trượt cao độ, nhanh hay chậm theo độ xa
  ///  • quãng lớn hoặc nhắc lại đúng nốt cũ: gảy lại dây (tiếng que gảy + nhấn âm lượng) rồi mới chuyển
  void to(double freq, {double pan = 0, int stepMs = 300}) {
    if (_ended) return;
    final semi = 12 * math.log(freq / _f) / math.ln2;
    final b = _e._b;
    try {
      final glide = (45 + 14 * semi.abs()).clamp(50, math.min(160, stepMs * 0.5)).round();
      b.setSpeed(_h, _e._spd(freq), fade: Duration(milliseconds: glide));
      b.setPan(_h, pan.clamp(-1.0, 1.0).toDouble());
      if (semi.abs() >= 5 || semi.abs() < 0.3) {
        unawaited(_e._shot('danbau_pluck', amp: 0.2, pan: pan, speed: _e._spd(freq)));
        b.setVolume(_h, _vol, fade: const Duration(milliseconds: 8));
      } else {
        b.setVolume(_h, _vol * 0.9, fade: Duration(milliseconds: glide));
      }
      // ngân rồi nhỏ dần trong thời gian của nốt, như dây đàn tắt dần
      Future<void>.delayed(Duration(milliseconds: glide + 10), () {
        if (_ended) return;
        try {
          b.setVolume(_h, _vol * 0.62, fade: Duration(milliseconds: math.max(60, stepMs - glide - 10)));
        } catch (_) {}
      });
    } catch (_) {}
    _f = freq;
  }

  /// Kết câu: ngân thêm rồi tắt dần (không cắt cụt).
  void end({int ms = 450}) {
    if (_ended) return;
    _ended = true;
    final b = _e._b;
    try {
      b.setVolume(_h, 0, fade: Duration(milliseconds: ms));
    } catch (_) {}
    Future<void>.delayed(Duration(milliseconds: ms + 60), () {
      try {
        b.stop(_h);
      } catch (_) {}
    });
  }
}

