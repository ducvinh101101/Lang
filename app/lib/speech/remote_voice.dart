// GIỌNG TIẾNG VIỆT QUA MÁY CHỦ (bản web, khi trình duyệt không có giọng Việt — Chrome trên Windows, Firefox…).
// Máy chủ (api/tts.mjs) đọc bằng đúng giọng Piper của app máy tính và trả về WAV; app phát qua bộ âm thanh của app.
// Câu dài chia thành đoạn ngắn: đoạn sau được tải trong lúc đoạn trước đang đọc → nghe liền mạch. Mỗi đoạn là một
// địa chỉ cố định nên CDN giữ lại: câu hay gặp gần như phát ngay.
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../audio/audio_engine.dart';

class RemoteVoice {
  RemoteVoice(this.audio, this.base, {this.log});
  final AudioEngine audio;
  final Uri base; // .../api/tts
  final void Function(String)? log;
  final _client = http.Client();
  final _mem = <String, Uint8List>{}; // đoạn vừa đọc (đọc lại / lặp câu không phải tải lại)

  bool? _ok;
  int _gen = 0;
  bool _active = false;
  Timer? _timer;
  Completer<void>? _playing;

  bool get playing => _active;

  /// Máy chủ có giọng không (hỏi một lần).
  Future<bool> available() async {
    final o = _ok;
    if (o != null) return o;
    try {
      final r = await _client.get(base.replace(queryParameters: {'ping': '1'})).timeout(const Duration(seconds: 6));
      _ok = r.statusCode == 200 && r.body.contains('true');
    } catch (_) {
      _ok = false;
    }
    log?.call('[giọng máy chủ] ${_ok! ? 'sẵn sàng' : 'không dùng được'}');
    return _ok!;
  }

  /// Chia câu thành đoạn. [firstShort]: đoạn ĐẦU cắt ngắn ở dấu phẩy đầu tiên (nếu câu dài) để máy chủ
  /// trả tiếng về nhanh — người nghe được phản hồi sớm, các đoạn sau tải trong lúc đang đọc.
  static List<String> chunks(String text, {bool firstShort = false}) => _chunks(text, firstShort: firstShort);

  static List<String> _chunks(String text, {bool firstShort = false}) {
    final parts = text.split(RegExp(r'(?<=[.!?;:])\s+'));
    final out = <String>[];
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].trim();
      if (firstShort && out.isEmpty && p.length > 70) {
        final c = p.indexOf(', ', 18);
        if (c > 0 && c < 70 && p.length - c > 20) {
          out.add(p.substring(0, c + 1).trim());
          p = p.substring(c + 1).trim();
        }
      }
      while (p.length > 220) {
        var cut = p.lastIndexOf(', ', 220);
        if (cut < 60) cut = p.lastIndexOf(' ', 220);
        if (cut < 40) cut = 220;
        out.add(p.substring(0, cut + 1).trim());
        p = p.substring(cut + 1).trim();
      }
      if (p.isNotEmpty) out.add(p);
    }
    return out;
  }

  Future<Uint8List?> _fetch(String chunk, double speed) async {
    final key = '${speed.toStringAsFixed(2)}|$chunk';
    final hit = _mem[key];
    if (hit != null) return hit;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await _client
            .get(base.replace(queryParameters: {'t': chunk, 's': speed.toStringAsFixed(2)}))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200 && r.bodyBytes.length > 44) {
          if (_mem.length > 40) _mem.remove(_mem.keys.first);
          return _mem[key] = r.bodyBytes;
        }
        log?.call('[giọng máy chủ] HTTP ${r.statusCode}');
      } catch (e) {
        log?.call('[giọng máy chủ] $e');
      }
    }
    return null;
  }

  /// Đọc text; true nếu đã phát được ít nhất một đoạn.
  Future<bool> speak(String text, {double speed = 1.0}) async {
    final my = ++_gen;
    stop(keepGen: true);
    _active = true;
    var played = false;
    try {
      final parts = _chunks(text, firstShort: true);
      if (parts.isEmpty) return true;
      // tải trước tối đa 3 đoạn cùng lúc: đoạn đang đọc + 2 đoạn sau → không có khoảng lặng giữa các đoạn
      final pending = <int, Future<Uint8List?>>{};
      void ahead(int upTo) {
        for (var j = 0; j <= upTo && j < parts.length; j++) {
          pending.putIfAbsent(j, () => _fetch(parts[j], speed));
        }
      }

      ahead(2);
      for (var k = 0; k < parts.length; k++) {
        final wav = await pending.remove(k)!;
        if (my != _gen) return true;
        ahead(k + 3);
        if (wav == null) continue;
        final byteRate = ByteData.sublistView(wav, 28, 32).getUint32(0, Endian.little);
        final ms = (wav.length - 44) * 1000 ~/ (byteRate == 0 ? 44100 : byteRate);
        final done = Completer<void>();
        _playing = done;
        // bộ âm thanh của trình duyệt có lúc không trả lời (tab ẩn, vừa bị dừng) → không chờ quá 6 giây
        await audio.playSpeech(wav).timeout(const Duration(seconds: 6), onTimeout: () => log?.call('[giọng máy chủ] phát quá lâu'));
        if (my != _gen) return true;
        played = true;
        _timer = Timer(Duration(milliseconds: ms + 60), _end);
        await done.future.timeout(Duration(milliseconds: ms + 3000), onTimeout: _end);
        if (my != _gen) return true;
      }
      return played;
    } finally {
      if (my == _gen) _active = false;
    }
  }

  void _end() {
    _timer?.cancel();
    _timer = null;
    final c = _playing;
    _playing = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void stop({bool keepGen = false}) {
    if (!keepGen) _gen++;
    _active = false;
    audio.stopSpeech();
    _end();
  }
}
