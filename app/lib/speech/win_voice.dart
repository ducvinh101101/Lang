// Giọng đọc trên Windows, chạy NGOÀI app trong một tiến trình PowerShell sống suốt phiên.
//
// Vì sao không dùng plugin flutter_tts trên Windows (đã đọc mã nguồn flutter_tts 4.2.5):
//  • setLanguage("vi-VN") khi máy không có giọng Việt vẫn báo thành công và giữ GIỌNG TIẾNG ANH mặc định
//    → đọc tiếng Việt bằng giọng Anh (lỗi "giọng không đúng");
//  • speak() bị BỎ QUA nếu plugin còn tưởng đang nói (isSpeaking kẹt khi tổng hợp lỗi) → im lặng dần;
//  • báo "đọc xong" từ luồng nền của MediaPlayer (không phải luồng chính) → có thể làm app văng.
// Tiến trình riêng dùng đúng bộ giọng Windows (OneCore: Microsoft An tiếng Việt, …), chọn giọng theo TÊN,
// dừng được ngay, và nếu có lỗi thì chỉ tiến trình PowerShell chết, app vẫn chạy.
//
// Giao thức (mỗi dòng một lệnh, chữ base64 UTF-8):
//   app → ps : SAY <id> <b64>   STOP   RATE <0.5..3>   VOICE <b64 tên>
//   ps → app : VOICE <b64 tên> <ngôn ngữ> <giới tính>   READY <b64 giọng mặc định>
//              DUR <id> <mili giây>   ERR <id> <b64 lỗi>   VOICEOK / VOICEERR
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

class WinVoiceInfo {
  final String name, locale, gender;
  const WinVoiceInfo(this.name, this.locale, this.gender);
  bool get isVietnamese => locale.toLowerCase().startsWith('vi');
  bool get isEnglish => locale.toLowerCase().startsWith('en');
}

class WinVoice {
  Process? _p;
  final voices = <WinVoiceInfo>[];
  String? defaultVoice;
  String? current;
  int _id = 0;
  final _pending = <int, Completer<int>>{};
  Completer<void>? _playing;
  Timer? _playTimer;
  bool get alive => _p != null;
  bool get playing => _playing != null;

  static bool get supported => !kIsWeb && Platform.isWindows;

  static const _script = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer,Windows.Media.SpeechSynthesis,ContentType=WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $null = $task.Wait(-1); $task.Result }
function B64($s) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$s)) }
function UnB64($s) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
function Say($s) { [Console]::Out.WriteLine($s); [Console]::Out.Flush() }
$all = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
foreach ($v in $all) { Say ('VOICE ' + (B64 $v.DisplayName) + ' ' + $v.Language + ' ' + $v.Gender) }
Say ('READY ' + (B64 ([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::DefaultVoice.DisplayName)))
$sp = New-Object System.Media.SoundPlayer
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  $parts = $line.Split(' ')
  try {
    switch ($parts[0]) {
      'STOP' { $sp.Stop() }
      'RATE' { $synth.Options.SpeakingRate = [double]::Parse($parts[1], [Globalization.CultureInfo]::InvariantCulture) }
      'VOICE' {
        $n = UnB64 $parts[1]
        $v = $all | Where-Object { $_.DisplayName -eq $n } | Select-Object -First 1
        if ($v) { $synth.Voice = $v; Say 'VOICEOK' } else { Say 'VOICEERR' }
      }
      'SAY' {
        $id = $parts[1]
        $text = UnB64 $parts[2]
        $sp.Stop()
        $st = Await ($synth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $ms = New-Object IO.MemoryStream
        [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($st.GetInputStreamAt(0)).CopyTo($ms)
        $b = $ms.ToArray()
        $byteRate = [BitConverter]::ToInt32($b, 28)
        $dur = 0
        if ($byteRate -gt 0) { $dur = [int](($b.Length - 44) * 1000 / $byteRate) }
        $ms.Position = 0
        $sp.Stream = $ms
        $sp.Play()
        Say ('DUR ' + $id + ' ' + $dur)
      }
    }
  } catch {
    Say ('ERR ' + $parts[1] + ' ' + (B64 $_.Exception.Message))
  }
}
''';

  /// Khởi động tiến trình giọng đọc. Trả về false nếu không chạy được (sẽ dùng phương án khác).
  Future<bool> start({void Function(String)? log}) async {
    if (!supported) return false;
    try {
      // -EncodedCommand: kịch bản gửi dạng UTF-16LE base64, không lo lỗi dấu nháy trên dòng lệnh
      final u16 = Uint8List(_script.length * 2);
      for (var i = 0; i < _script.length; i++) {
        final c = _script.codeUnitAt(i);
        u16[2 * i] = c & 0xff;
        u16[2 * i + 1] = c >> 8;
      }
      final p = await Process.start('powershell.exe',
          // -Mta: lệnh async của WinRT bị treo (deadlock) nếu chờ trên luồng STA mặc định của PowerShell
          ['-Mta', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', base64.encode(u16)]);
      _p = p;
      final ready = Completer<bool>();
      p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        final parts = line.trim().split(' ');
        switch (parts.first) {
          case 'VOICE' when parts.length >= 3:
            voices.add(WinVoiceInfo(_unb64(parts[1]), parts[2], parts.length > 3 ? parts[3] : ''));
          case 'READY':
            defaultVoice = parts.length > 1 ? _unb64(parts[1]) : null;
            current = defaultVoice;
            if (!ready.isCompleted) ready.complete(true);
          case 'DUR' when parts.length >= 3:
            _pending.remove(int.tryParse(parts[1]))?.complete(int.tryParse(parts[2]) ?? 0);
          case 'ERR':
            final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
            log?.call('[giọng Windows] ${parts.length > 2 ? _unb64(parts[2]) : line}');
            if (id != null) _pending.remove(id)?.complete(-1);
        }
      });
      p.stderr.transform(utf8.decoder).listen((e) {
        // "#< CLIXML" / "<Objs…>" là dữ liệu tiến trình của PowerShell, không phải lỗi
        final t = e.trim();
        if (t.isEmpty || t.startsWith('#< CLIXML') || t.startsWith('<Objs')) return;
        log?.call('[giọng Windows] $t');
      });
      unawaited(p.exitCode.then((code) {
        log?.call('[giọng Windows] tiến trình kết thúc (mã $code)');
        _p = null;
        for (final c in _pending.values) {
          if (!c.isCompleted) c.complete(-1);
        }
        _pending.clear();
        _endPlaying();
        if (!ready.isCompleted) ready.complete(false);
      }));
      return await ready.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
    } catch (e) {
      log?.call('[giọng Windows] không khởi động được: $e');
      _p = null;
      return false;
    }
  }

  static String _unb64(String s) {
    try {
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return s;
    }
  }

  void _send(String cmd) {
    try {
      _p?.stdin.writeln(cmd);
    } catch (_) {}
  }

  /// Chọn giọng theo tên (đúng như danh sách voices).
  void setVoice(String name) {
    if (voices.any((v) => v.name == name)) {
      current = name;
      _send('VOICE ${base64.encode(utf8.encode(name))}');
    }
  }

  /// Giọng tốt nhất cho ngôn ngữ: giọng đã lưu (nếu đúng ngôn ngữ) → giọng Việt/Anh đầu tiên → null.
  WinVoiceInfo? bestFor(String lang, {String? preferred}) {
    bool ok(WinVoiceInfo v) => lang == 'en' ? v.isEnglish : v.isVietnamese;
    for (final v in voices) {
      if (v.name == preferred && ok(v)) return v;
    }
    for (final v in voices) {
      if (ok(v)) return v;
    }
    return null;
  }

  /// rate: SpeakingRate của Windows, 1.0 = bình thường.
  void setRate(double rate) => _send('RATE ${rate.clamp(0.5, 3.0).toStringAsFixed(2)}');

  void _endPlaying() {
    _playTimer?.cancel();
    _playTimer = null;
    final c = _playing;
    _playing = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Đọc text; Future hoàn tất khi đọc xong (theo độ dài âm thanh), bị dừng, hoặc có câu mới.
  /// Không bao giờ treo: nếu tiến trình không báo độ dài, dùng thời lượng ước tính theo số chữ.
  Future<void> speak(String text, {double rate = 1.0}) async {
    if (_p == null) return;
    _endPlaying();
    final id = ++_id;
    final c = Completer<int>();
    _pending[id] = c;
    _send('SAY $id ${base64.encode(utf8.encode(text))}');
    final playing = Completer<void>();
    _playing = playing;
    // ước tính: ~14 ký tự/giây ở tốc độ 1,0, cộng thời gian tổng hợp giọng
    final estimate = (900 + text.length * 72 / rate).round();
    _playTimer = Timer(Duration(milliseconds: estimate), () {
      if (identical(_playing, playing)) {
        missedDur++;
        _endPlaying();
      }
    });
    unawaited(c.future.then((ms) {
      if (!identical(_playing, playing)) return; // đã có câu mới / đã dừng
      _playTimer?.cancel();
      if (ms <= 0) {
        _endPlaying();
      } else {
        _playTimer = Timer(Duration(milliseconds: ms + 150), _endPlaying);
      }
    }));
    await playing.future;
  }

  /// Số lần tiến trình không kịp báo độ dài câu (để ghi nhật ký chẩn đoán).
  int missedDur = 0;

  void stop() {
    _send('STOP');
    _endPlaying();
  }

  void dispose() {
    try {
      _p?.kill();
    } catch (_) {}
    _p = null;
  }
}
