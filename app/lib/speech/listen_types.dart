// Kiểu dùng chung cho bộ nhận giọng (bản máy tính: voice_listener_io.dart, bản web: voice_listener_web.dart).

enum ListenEnd { heard, silence, noMic, error, cancelled }

class ListenResult {
  final ListenEnd end;
  final String text;
  const ListenResult(this.end, [this.text = '']);
}
