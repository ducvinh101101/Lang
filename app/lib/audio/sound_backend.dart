import 'dart:typed_data';

/// Lớp mỏng giữa AudioEngine và thư viện âm thanh.
/// Chỉ soloud_backend.dart phụ thuộc flutter_soloud; đổi thư viện thì chỉ viết lại file đó.
abstract class SoundBackend {
  Future<void> init();
  Future<void> load(String name, Uint8List wav);

  /// Giải phóng mẫu đã nạp (dùng cho câu đọc tạo ra liên tục).
  Future<void> unload(String name);

  /// Phát mẫu `name`. speed = tốc độ phát tương đối (đổi cao độ). Trả về handle (kiểu tùy backend) hoặc null.
  Future<Object?> play(String name, {double volume = 1, double pan = 0, double speed = 1, bool loop = false});

  void setSpeed(Object handle, double speed, {Duration fade = Duration.zero});
  void setVolume(Object handle, double volume, {Duration fade = Duration.zero});
  void setPan(Object handle, double pan);
  void stop(Object handle);
  void setMasterVolume(double v);
  Future<void> dispose();
}

/// Backend im lặng — dùng trong test hoặc khi thư viện âm thanh không khởi động được.
class SilentBackend implements SoundBackend {
  @override
  Future<void> init() async {}
  @override
  Future<void> load(String name, Uint8List wav) async {}
  @override
  Future<void> unload(String name) async {}
  @override
  Future<Object?> play(String name, {double volume = 1, double pan = 0, double speed = 1, bool loop = false}) async =>
      null;
  @override
  void setSpeed(Object handle, double speed, {Duration fade = Duration.zero}) {}
  @override
  void setVolume(Object handle, double volume, {Duration fade = Duration.zero}) {}
  @override
  void setPan(Object handle, double pan) {}
  @override
  void stop(Object handle) {}
  @override
  void setMasterVolume(double v) {}
  @override
  Future<void> dispose() async {}
}
