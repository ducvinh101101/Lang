// Không phải web: không dùng (giọng đọc đi qua Piper / Windows / flutter_tts).
class WebSpeech {
  static bool get supported => false;
  static bool get speaking => false;
  static bool hasVoice(String lang) => false;
  static int get voiceCount => 0;
  static void cancel() {}
  static void unlock() {}
  static bool get preferServerVoice => false;
  static Future<bool> speak(String text,
          {required String lang, double rate = 1.0, required bool Function() alive, void Function(String)? log}) async =>
      false;
}
