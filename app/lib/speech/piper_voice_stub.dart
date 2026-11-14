// Bản web của PiperVoice: không có giọng đóng gói (sherpa-onnx cần dart:ffi). Speaker dùng giọng trình duyệt.
import '../audio/audio_engine.dart';

class PiperVoice {
  PiperVoice(AudioEngine audio, {void Function(String)? log});
  bool get ready => false;
  bool get playing => false;
  Future<bool> start() async => false;
  static Future<bool> bundled() async => false;
  static List<String> chunks(String t) => [t];
  Future<bool> speak(String text, {double speed = 1.0}) async => false;
  void stopAudio() {}
  void stop() {}
}
