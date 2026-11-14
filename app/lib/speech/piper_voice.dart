// Giọng tiếng Việt đóng gói (Piper qua sherpa-onnx, cần dart:ffi) — chỉ có trên máy tính/điện thoại.
// Trên web dùng bản rỗng: Speaker tự chuyển sang giọng của trình duyệt (flutter_tts → speechSynthesis), như bản web gốc.
export 'piper_voice_stub.dart' if (dart.library.ffi) 'piper_voice_io.dart';
