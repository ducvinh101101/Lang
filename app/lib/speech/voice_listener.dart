// Bộ nhận giọng nói cho nút "Nói lệnh":
//  • máy tính/điện thoại: mô hình tiếng Việt đóng gói trong app (sherpa-onnx, không cần mạng) — voice_listener_io.dart
//  • web: nhận giọng của trình duyệt (Web Speech API, Chrome/Edge, cần mạng) — voice_listener_web.dart
export 'listen_types.dart';
export 'voice_listener_web.dart' if (dart.library.ffi) 'voice_listener_io.dart';
