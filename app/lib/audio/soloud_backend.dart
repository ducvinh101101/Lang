// File DUY NHẤT dùng flutter_soloud. Nếu API của phiên bản bạn cài khác, chỉ cần sửa ở đây.
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'sound_backend.dart';

class SoloudBackend implements SoundBackend {
  final _sl = SoLoud.instance;
  final _sources = <String, AudioSource>{};

  @override
  Future<void> init() async {
    if (!_sl.isInitialized) await _sl.init();
    try {
      _sl.setMaxActiveVoiceCount(48); // tiếng mưa/lửa chồng nhiều nốt ngắn
    } catch (_) {}
  }

  @override
  Future<void> load(String name, Uint8List wav) async {
    // tên có đuôi (vd 'nasa_x.mp3') → giữ nguyên để thư viện giải mã đúng định dạng; còn lại là WAV tổng hợp
    _sources[name] = await _sl.loadMem(name.contains('.') ? name : '$name.wav', wav);
  }

  @override
  Future<void> unload(String name) async {
    final src = _sources.remove(name);
    if (src != null) await _sl.disposeSource(src);
  }

  @override
  Future<Object?> play(String name, {double volume = 1, double pan = 0, double speed = 1, bool loop = false}) async {
    final src = _sources[name];
    if (src == null) return null;
    // flutter_soloud 4.x/5.x: play() trả SoundHandle đồng bộ (bản 2.x/3.x trả Future → thêm await nếu dùng bản cũ)
    if (speed == 1) {
      return _sl.play(src, volume: volume, pan: pan, looping: loop);
    }
    // Đặt tốc độ trước khi nghe thấy: phát ở trạng thái tạm dừng, chỉnh, rồi bỏ tạm dừng
    final h = _sl.play(src, volume: volume, pan: pan, looping: loop, paused: true);
    _sl.setRelativePlaySpeed(h, speed);
    _sl.setPause(h, false);
    return h;
  }

  @override
  void setSpeed(Object handle, double speed, {Duration fade = Duration.zero}) {
    final h = handle as SoundHandle;
    if (!_sl.getIsValidVoiceHandle(h)) return;
    if (fade == Duration.zero) {
      _sl.setRelativePlaySpeed(h, speed);
    } else {
      _sl.fadeRelativePlaySpeed(h, speed, fade);
    }
  }

  @override
  void setVolume(Object handle, double volume, {Duration fade = Duration.zero}) {
    final h = handle as SoundHandle;
    if (!_sl.getIsValidVoiceHandle(h)) return;
    if (fade == Duration.zero) {
      _sl.setVolume(h, volume);
    } else {
      _sl.fadeVolume(h, volume, fade);
    }
  }

  @override
  void setPan(Object handle, double pan) {
    final h = handle as SoundHandle;
    if (_sl.getIsValidVoiceHandle(h)) _sl.setPan(h, pan);
  }

  @override
  void stop(Object handle) {
    final h = handle as SoundHandle;
    if (_sl.getIsValidVoiceHandle(h)) _sl.stop(h);
  }

  @override
  void setMasterVolume(double v) {
    if (_sl.isInitialized) _sl.setGlobalVolume(v);
  }

  @override
  Future<void> dispose() async {
    _sl.deinit();
  }
}
