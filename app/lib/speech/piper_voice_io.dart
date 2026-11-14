// Giọng đọc tiếng Việt ĐÓNG GÓI TRONG APP — "giọng của mình", giống nhau trên mọi máy, không cần mạng,
// không cần cài giọng Windows. Bản web nghe hay vì mượn giọng trực tuyến của Edge/Chrome; app thì mang theo giọng riêng.
//
//  • Mô hình Piper vi_VN-vais1000-medium (VITS), chạy bằng sherpa-onnx (assets/voices/vi, xem NGUON-GIONG.txt).
//  • Tổng hợp trong một isolate riêng (không làm giật giao diện): ~0,1 giây cho 1 giây tiếng.
//  • Câu dài được CẮT THEO CÂU như bản web: câu đầu phát gần như ngay, câu sau tổng hợp trong lúc câu trước đang đọc.
//  • Phát qua flutter_soloud (cùng bộ âm thanh với nhạc cụ) → dừng được ngay.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../audio/audio_engine.dart';
import '../core/model_store.dart';

const _assetDir = 'assets/voices/vi';
const _version = 'v1'; // đổi khi thay mô hình để app chép lại

class PiperVoice {
  final AudioEngine audio;
  final void Function(String)? log;
  PiperVoice(this.audio, {this.log});

  SendPort? _worker;
  final _replies = <int, Completer<Uint8List?>>{};
  int _id = 0;
  int _gen = 0;
  Completer<void>? _playing;
  Timer? _playTimer;
  bool get ready => _worker != null;
  bool _active = false; // đang trong một lần speak() (kể cả lúc chờ tổng hợp đoạn sau)
  bool get playing => _playing != null || _active;

  /// Chép mô hình từ assets ra thư mục tạm (ghép 3 phần model.onnx), khởi động isolate tổng hợp.
  Future<bool> start() async {
    try {
      if (!audio.ready) {
        log?.call('[giọng app] bộ âm thanh chưa sẵn sàng → không dùng được giọng đóng gói');
        return false;
      }
      final dir = await _extract();
      if (dir == null) return false;
      final rp = ReceivePort();
      await Isolate.spawn(_workerMain, (rp.sendPort, dir));
      final ready = Completer<bool>();
      rp.listen((msg) {
        if (msg is SendPort) {
          _worker = msg;
        } else if (msg is (String, String)) {
          if (msg.$1 == 'ready') {
            if (!ready.isCompleted) ready.complete(true);
          } else if (msg.$1 == 'error') {
            log?.call('[giọng app] ${msg.$2}');
            if (!ready.isCompleted) ready.complete(false);
          }
        } else if (msg is (int, TransferableTypedData?)) {
          _replies.remove(msg.$1)?.complete(msg.$2?.materialize().asUint8List());
        }
      });
      final ok = await ready.future.timeout(const Duration(seconds: 30), onTimeout: () => false);
      if (!ok) _worker = null;
      return ok;
    } catch (e) {
      log?.call('[giọng app] không khởi động được: $e');
      return false;
    }
  }

  /// Có mô hình trong assets không (bản build thiếu thư mục assets/voices/vi thì bỏ qua êm).
  static Future<bool> bundled() async {
    try {
      await rootBundle.load('$_assetDir/tokens.txt');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _extract() async {
    if (!await bundled()) {
      log?.call('[giọng app] chưa có assets/voices/vi trong bản build');
      return null;
    }
    final sep = Platform.pathSeparator;
    final base = await ModelStore.dir('giong_vi_$_version'); // thư mục bền của app (thư mục tạm hay bị dọn → ghép lại lâu)
    final ok = File('$base${sep}xong.txt');
    if (ok.existsSync()) return base;
    Future<void> copy(String rel) async {
      final data = await rootBundle.load('$_assetDir/$rel');
      final f = File('$base$sep${rel.replaceAll('/', sep)}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    }

    for (final rel in [
      'tokens.txt',
      'espeak-ng-data/intonations',
      'espeak-ng-data/phondata',
      'espeak-ng-data/phondata-manifest',
      'espeak-ng-data/phonindex',
      'espeak-ng-data/phontab',
      'espeak-ng-data/vi_dict',
      'espeak-ng-data/lang/aav/vi',
    ]) {
      await copy(rel);
    }
    // model.onnx được chia 3 phần trong assets → ghép lại
    final model = File('$base${sep}model.onnx');
    final sink = model.openWrite();
    for (var k = 0; k < 3; k++) {
      final data = await rootBundle.load('$_assetDir/model.onnx.part$k');
      sink.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    await sink.flush();
    await sink.close();
    ok.writeAsStringSync('ok', flush: true);
    return base;
  }

  /// Cắt câu thông minh:
  /// - Nếu câu/văn bản ngắn hoặc vừa (<220 ký tự, ~35-45 từ), KHÔNG cắt chunk mà để Piper đọc nguyên khối liền mạch,
  ///   tránh hoàn toàn các khoảng khựng im lặng giữa các câu.
  /// - Nếu văn bản dài (≥220 ký tự), chia thành các đoạn lớn (≥140 ký tự) để đoạn đầu đủ dài (~8-12 giây),
  ///   giúp nền ONNX kịp tổng hợp đoạn tiếp theo trong lúc đoạn trước đang phát.
  static List<String> chunks(String t) {
    final trimmed = t.trim();
    if (trimmed.length < 220) return [trimmed];
    final out = <String>[];
    for (final m in RegExp(r'[^.!?;]+[.!?;]*').allMatches(trimmed)) {
      final s = m.group(0)!.trim();
      if (s.isEmpty) continue;
      if (out.isNotEmpty && (s.length < 40 || out.last.length < 140)) {
        out[out.length - 1] = '${out.last} $s';
      } else {
        out.add(s);
      }
    }
    if (out.length > 1 && out[0].length < 140) {
      out[0] = '${out[0]} ${out[1]}';
      out.removeAt(1);
    }
    return out.isEmpty ? [trimmed] : out;
  }

  Future<Uint8List?> _synth(String text, double speed) {
    final w = _worker;
    if (w == null) return Future.value(null);
    final id = ++_id;
    final c = Completer<Uint8List?>();
    _replies[id] = c;
    w.send((id, text, speed));
    return c.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
  }

  void _endPlaying() {
    _playTimer?.cancel();
    _playTimer = null;
    final c = _playing;
    _playing = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Đọc text (câu mới luôn thay câu đang đọc). Trả về khi đọc xong hoặc bị dừng.
  /// true nếu đã phát được ít nhất một đoạn (false: tổng hợp lỗi / bộ âm thanh chưa sẵn sàng → nên đọc bằng giọng khác).
  Future<bool> speak(String text, {double speed = 1.0}) async {
    final my = ++_gen;
    stopAudio();
    _active = true;
    try {
      return await _speakParts(text, speed, my);
    } finally {
      if (my == _gen) _active = false;
    }
  }

  Future<bool> _speakParts(String text, double speed, int my) async {
    final parts = chunks(text);
    var played = false;
    Future<Uint8List?>? next = _synth(parts.first, speed);
    for (var k = 0; k < parts.length; k++) {
      var wav = await next;
      if (my != _gen) return true;
      // tổng hợp câu sau trong lúc câu này đang đọc
      next = k + 1 < parts.length ? _synth(parts[k + 1], speed) : null;
      if (wav == null || wav.length <= 44) {
        // tổng hợp lỗi / quá lâu: thử lại đoạn này một lần rồi mới bỏ (trước đây bỏ luôn → phụ đề có mà không có tiếng)
        log?.call('[giọng app] chưa tổng hợp được đoạn ${k + 1}/${parts.length}, thử lại');
        wav = await _synth(parts[k], speed);
        if (my != _gen) return true;
        if (wav == null || wav.length <= 44) {
          log?.call('[giọng app] bỏ đoạn: "${parts[k]}"');
          continue;
        }
      }
      if (!audio.ready) {
        log?.call('[giọng app] bộ âm thanh chưa sẵn sàng, không phát được');
        return played;
      }
      played = true;
      final byteRate = ByteData.sublistView(wav, 28, 32).getUint32(0, Endian.little);
      final ms = (wav.length - 44) * 1000 ~/ (byteRate == 0 ? 44100 : byteRate);
      final done = Completer<void>();
      _playing = done;
      await audio.playSpeech(wav);
      if (my != _gen) return true;
      final extraMs = (k + 1 < parts.length) ? 0 : 40;
      _playTimer = Timer(Duration(milliseconds: ms + extraMs), _endPlaying);
      await done.future;
      if (my != _gen) return true;
    }
    return played;
  }

  void stopAudio() {
    audio.stopSpeech();
    _endPlaying();
  }

  void stop() {
    _gen++;
    _active = false;
    stopAudio();
  }
}

/// Isolate tổng hợp: nạp mô hình một lần, nhận (id, câu, tốc độ) → trả WAV 16-bit.
void _workerMain((SendPort, String) args) {
  final (out, dir) = args;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  sherpa.OfflineTts? tts;
  try {
    sherpa.initBindings();
    final sep = Platform.pathSeparator;
    tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: '$dir${sep}model.onnx',
          tokens: '$dir${sep}tokens.txt',
          dataDir: '$dir${sep}espeak-ng-data',
        ),
        numThreads: 2,
        debug: false,
      ),
      maxNumSenetences: 1,
    ));
    out.send(('ready', ''));
  } catch (e) {
    out.send(('error', '$e'));
    return;
  }
  inbox.listen((msg) {
    if (msg is! (int, String, double)) return;
    final (id, text, speed) = msg;
    try {
      final a = tts!.generate(text: text, sid: 0, speed: speed);
      if (a.samples.isEmpty) {
        out.send((id, null));
        return;
      }
      out.send((id, TransferableTypedData.fromList([_wav(a.samples, a.sampleRate)])));
    } catch (_) {
      out.send((id, null));
    }
  });
}

Uint8List _wav(Float32List s, int rate) {
  // Cắt bỏ khoảng lặng dư thừa ở đầu và đuôi do mô hình Piper VITS sinh ra
  // Giữ lại ~15ms đệm để âm thanh vào/ra tự nhiên không bị pop/click
  final pad = (rate * 0.015).round();
  var start = 0;
  while (start < s.length && s[start].abs() < 0.005) {
    start++;
  }
  start = (start - pad).clamp(0, s.length);

  var end = s.length;
  while (end > start && s[end - 1].abs() < 0.005) {
    end--;
  }
  end = (end + pad).clamp(start, s.length);

  final len = end - start;
  final b = ByteData(44 + len * 2);
  void str(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + len * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, len * 2, Endian.little);
  var peak = 0.0;
  for (var i = start; i < end; i++) {
    final a = s[i].abs();
    if (a > peak) peak = a;
  }
  final gain = peak > 0.01 ? (0.90 / peak).clamp(1.0, 2.2) : 1.0;
  for (var i = 0; i < len; i++) {
    final v = (s[start + i] * gain * 32767).round();
    b.setInt16(44 + i * 2, v < -32768 ? -32768 : (v > 32767 ? 32767 : v), Endian.little);
  }
  return b.buffer.asUint8List();
}
