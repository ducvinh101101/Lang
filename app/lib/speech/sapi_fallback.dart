// Giọng đọc dự phòng cho Windows, chạy NGOÀI tiến trình app (PowerShell + System.Speech).
// Dùng khi plugin flutter_tts từng làm app văng (chế độ an toàn): nếu giọng dự phòng có lỗi thì chỉ tiến trình
// PowerShell chết, app vẫn chạy. Chậm hơn ~0,5 giây mỗi câu nhưng người khiếm thị không bị mất tiếng.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

class SapiFallback {
  Process? _p;

  static bool get supported => !kIsWeb && Platform.isWindows;

  static const _script = r"Add-Type -AssemblyName System.Speech;"
      r"$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
      r"$v=$s.GetInstalledVoices()|Where-Object{$_.Enabled -and $_.VoiceInfo.Culture.Name -like $env:DANBAU_LANG}|Select-Object -First 1;"
      r"if($v){$s.SelectVoice($v.VoiceInfo.Name)};"
      r"$s.Rate=[int]$env:DANBAU_RATE;"
      r"$s.Speak($env:DANBAU_TEXT)";

  /// Đọc text; trả về khi đọc xong hoặc bị dừng.
  Future<void> speak(String text, {required String lang, required double rate}) async {
    stop();
    try {
      final r = math.max(-10, math.min(10, ((rate - 0.5) * 16).round()));
      final p = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', _script],
        environment: {'DANBAU_TEXT': text, 'DANBAU_RATE': '$r', 'DANBAU_LANG': lang == 'en' ? 'en*' : 'vi*'},
      );
      _p = p;
      unawaited(p.stdout.drain<void>());
      unawaited(p.stderr.drain<void>());
      await p.exitCode;
      if (identical(_p, p)) _p = null;
    } catch (_) {
      _p = null;
    }
  }

  void stop() {
    final p = _p;
    _p = null;
    if (p != null) {
      try {
        p.kill();
      } catch (_) {}
    }
  }
}
