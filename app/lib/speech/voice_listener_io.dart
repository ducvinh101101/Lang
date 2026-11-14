// NHẬN GIỌNG NÓI tiếng Việt ngay trong app — không cần mạng, không cần cài gì thêm trên Windows.
// (Bản web dùng nhận giọng trực tuyến của trình duyệt; Windows không có sẵn bộ nhận giọng tiếng Việt cho app.)
//
//  • Mô hình Zipformer tiếng Việt (sherpa-onnx-zipformer-vi-int8-2025-04-20, Apache-2.0), xem assets/asr/vi/NGUON.txt.
//    Chạy bằng sherpa-onnx — cùng thư viện với giọng đọc của app.
//  • Thu âm micro qua gói `record` (PCM 16 kHz). Biết lúc bắt đầu / ngừng nói bằng Silero VAD (phân biệt giọng người
//    với tiếng quạt, TV, xe cộ); thiếu mô hình VAD thì quay về cách đo độ to.
//  • Nhận dạng trong isolate riêng: ~0,05 giây cho một câu lệnh, giao diện không giật.
//  • "Từ khoá ưu tiên": tên các lệnh và địa danh của app được ưu tiên → nghe lệnh chuẩn hơn.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../core/app_server.dart';
import '../core/crash_guard.dart';
import '../core/model_store.dart';
import '../features/voice/commands.dart';
import 'listen_types.dart';
import 'nvidia_asr.dart';

// Mỗi ngôn ngữ một mô hình, cả hai ĐÓNG GÓI SẴN trong app: tiếng Việt (assets/asr/vi) và tiếng Anh (NVIDIA Parakeet
// ~132 MB, assets/asr/en_parakeet). Bản build nào thiếu thư mục tiếng Anh thì vẫn tải về như trước
// (5 phần, máy chủ web của app; đổi bằng --dart-define=EN_MODEL_URL=...).
String _assetDir(String lang) => lang == 'en' ? 'assets/asr/en_parakeet' : 'assets/asr/vi';
const _enUrlDef = String.fromEnvironment('EN_MODEL_URL');
const _enUrl = _enUrlDef == '' ? '$appServer/models/en_parakeet/' : _enUrlDef;
const _version = 'v1';
const _rate = 16000;

class VoiceListener {
  VoiceListener({this.log, this.nvidiaAsr});
  final void Function(String)? log;

  /// Bộ nhận giọng đám mây NVIDIA NIM (Parakeet CTC 0.6B) làm kênh dự phòng / tăng độ chính xác.
  NvidiaAsr? nvidiaAsr;

  /// Ngôn ngữ đang nghe: 'vi' | 'en'. Đổi là lần nghe sau dùng mô hình của ngôn ngữ đó.
  String lang = 'vi';

  /// Mã lỗi gần nhất (giữ cùng giao diện với bản web).
  String lastError = '';
  final _workers = <String, SendPort>{};
  final _startingBy = <String, Future<bool>>{};
  SendPort? get _worker => _workers[lang];
  final _replies = <int, Completer<String?>>{};
  int _id = 0;

  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  Completer<ListenResult>? _session;
  static bool _micPermitted = false;
  bool get listening => _session != null;
  bool get ready => _worker != null;

  /// Bản build có mô hình nhận giọng không.
  static Future<bool> bundled([String lang = 'vi']) async {
    try {
      await rootBundle.load('${_assetDir(lang)}/tokens.txt');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mô hình của [lang] đã sẵn trên máy chưa (tiếng Anh: đã tải về chưa) — để app báo trước "đang tải".
  static Future<bool> modelReady(String lang) async {
    if (lang != 'en') return true;
    if (await bundled('en')) return true;
    final d = await ModelStore.dir('nghe_en_$_version');
    return File('$d${Platform.pathSeparator}xong.txt').existsSync();
  }

  /// Tiến độ tải mô hình tiếng Anh (0..100) — app đọc to cho người dùng biết.
  void Function(int pct)? onDownload;

  /// Nạp sẵn (tiếng Anh: tải về) bộ nghe của [l] mà KHÔNG đổi ngôn ngữ đang nghe.
  Future<bool> prepareLang(String l) {
    _vadReady ??= _startVad();
    return _startingBy[l] ??= _start(l);
  }

  /// Nạp mô hình (lần đầu chép ra thư mục của app ~80 MB). Gọi nhiều lần cũng chỉ nạp một lần.
  Future<bool> prepare() {
    final l = lang;
    _vadReady ??= _startVad();
    return _startingBy[l] ??= _start(l);
  }

  // ---------- Silero VAD: phát hiện tiếng nói (chạy ngay trên luồng thu âm, mỗi khung 512 mẫu = 32 ms) ----------
  sherpa.VoiceActivityDetector? _vad;
  Future<bool>? _vadReady;
  final _vadPending = <double>[];

  Future<bool> _startVad() async {
    try {
      final data = await rootBundle.load('assets/asr/vad/silero_vad.onnx');
      final sep = Platform.pathSeparator;
      final dir = Directory(await ModelStore.dir('vad_v1'))..createSync(recursive: true);
      final f = File('${dir.path}${sep}silero_vad.onnx');
      if (!f.existsSync() || f.lengthSync() != data.lengthInBytes) {
        f.writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      sherpa.initBindings();
      _vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: f.path,
            threshold: 0.5,
            minSilenceDuration: 0.6, // im ~0,6 giây (+ ~0,15 giây chờ thêm) là coi như nói xong (0,45 hay cắt ngang khi người nói ngập ngừng)
            minSpeechDuration: 0.15,
            maxSpeechDuration: 12,
            windowSize: 512,
          ),
          sampleRate: _rate,
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 30,
      );
      log?.call('[nhận giọng] dùng Silero VAD để biết lúc bắt đầu / ngừng nói');
      return true;
    } catch (e) {
      log?.call('[nhận giọng] không dùng được VAD ($e) → đoán lúc nói theo độ to');
      _vad = null;
      return false;
    }
  }

  /// Đưa mẫu mới vào VAD; trả về true nếu VAD đang nghe thấy giọng người (null = không có VAD).
  bool? _vadFeed(List<double> chunk) {
    final v = _vad;
    if (v == null) return null;
    try {
      _vadPending.addAll(chunk);
      var speaking = false;
      while (_vadPending.length >= 512) {
        v.acceptWaveform(Float32List.fromList(_vadPending.sublist(0, 512)));
        _vadPending.removeRange(0, 512);
        if (v.isDetected()) speaking = true;
        while (!v.isEmpty()) {
          v.pop(); // không cần đoạn đã cắt sẵn: app tự giữ toàn bộ âm thanh của câu
        }
      }
      return speaking || v.isDetected();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _start(String l) async {
    try {
      final dir = await _extract(l);
      if (dir == null) {
        _startingBy.remove(l); // vd mất mạng khi tải mô hình tiếng Anh → lần sau thử lại
        return false;
      }
      final rp = ReceivePort();
      await Isolate.spawn(_workerMain, (rp.sendPort, dir, l == 'vi'));
      final ready = Completer<bool>();
      rp.listen((msg) {
        if (msg is SendPort) {
          _workers[l] = msg;
        } else if (msg is (String, String)) {
          if (msg.$1 == 'ready') {
            if (msg.$2.isNotEmpty) log?.call('[nhận giọng] ${msg.$2}');
            if (!ready.isCompleted) ready.complete(true);
          } else {
            log?.call('[nhận giọng] ${msg.$2}');
            if (!ready.isCompleted) ready.complete(false);
          }
        } else if (msg is (int, String?)) {
          _replies.remove(msg.$1)?.complete(msg.$2);
        }
      });
      final ok = await ready.future.timeout(const Duration(seconds: 40), onTimeout: () => false);
      if (!ok) {
        _workers.remove(l);
        _startingBy.remove(l); // cho thử lại lần sau
      }
      return ok;
    } catch (e) {
      log?.call('[nhận giọng] không khởi động được: $e');
      _startingBy.remove(l);
      return false;
    }
  }

  Future<String?> _extract(String l) async {
    final asset = _assetDir(l);
    final sep = Platform.pathSeparator;
    if (l == 'en' && !await bundled('en')) {
      // tải về một lần, cất trong thư mục của app
      final enBase = await ModelStore.dir('nghe_en_$_version');
      final enOk = File('$enBase${sep}xong.txt');
      if (enOk.existsSync()) return enBase;
      log?.call('[nhận giọng] tải mô hình tiếng Anh từ $_enUrl');
      final got = await ModelStore.download(
        baseUrl: Uri.parse(_enUrl),
        parts: [for (var k = 0; k < 5; k++) 'model.int8.onnx.part$k'],
        outFile: File('$enBase${sep}model.int8.onnx'),
        extra: const ['tokens.txt'],
        progress: onDownload,
        log: log,
      );
      if (!got) return null;
      enOk.writeAsStringSync('ok', flush: true);
      return enBase;
    }
    if (!await bundled(l)) {
      log?.call('[nhận giọng] chưa có $asset trong bản build');
      return null;
    }
    final base = await ModelStore.dir('nghe_${l}_$_version');
    final ok = File('$base${sep}xong.txt');
    if (l == 'en') {
      // tiếng Anh: NVIDIA Parakeet 110M (CTC, ~132 MB, chia 5 phần trong assets → ghép lại); xem NGUON.txt
      final enBase = '$base${sep}parakeet';
      final enOk = File('$enBase${sep}xong.txt');
      Directory(enBase).createSync(recursive: true);
      if (enOk.existsSync()) return enBase;
      final tk = await rootBundle.load('$asset/tokens.txt');
      File('$enBase${sep}tokens.txt').writeAsBytesSync(tk.buffer.asUint8List(tk.offsetInBytes, tk.lengthInBytes), flush: true);
      final out = File('$enBase${sep}model.int8.onnx').openWrite();
      for (var k = 0; k < 5; k++) {
        final data = await rootBundle.load('$asset/model.int8.onnx.part$k');
        out.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      }
      await out.flush();
      await out.close();
      enOk.writeAsStringSync('ok', flush: true);
      return enBase;
    }
    // từ khoá ưu tiên: viết lại mỗi lần (danh sách lệnh/địa danh có thể đổi theo bản app)
    Directory(base).createSync(recursive: true);
    File('$base${sep}hotwords.txt').writeAsStringSync('${hotwordPhrases().join('\n')}\n', flush: true);
    if (ok.existsSync()) return base;
    for (final rel in ['tokens.txt', 'bpe.vocab', 'decoder.onnx', 'joiner.int8.onnx']) {
      final data = await rootBundle.load('$asset/$rel');
      File('$base$sep$rel').writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    }
    // encoder ~71 MB được chia 3 phần trong assets → ghép lại
    final sink = File('$base${sep}encoder.int8.onnx').openWrite();
    for (var k = 0; k < 3; k++) {
      final data = await rootBundle.load('$asset/encoder.int8.onnx.part$k');
      sink.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    await sink.flush();
    await sink.close();
    ok.writeAsStringSync('ok', flush: true);
    return base;
  }

  /// Nghe MỘT câu lệnh: chờ người nói, dừng khi im ~0,8 giây (tối đa [maxSeconds]).
  /// [onLevel] nhận độ to 0..1 (vẽ thanh âm lượng), [onSpeech] gọi khi bắt đầu nghe thấy tiếng nói.
  Future<ListenResult> listen({
    void Function(double level)? onLevel,
    void Function()? onSpeech,
    double maxSeconds = 7,
    double waitSeconds = 5,
  }) async {
    await cancel();
    if (!await prepare()) return const ListenResult(ListenEnd.error);
    final session = Completer<ListenResult>();
    _session = session;
    final rec = AudioRecorder();
    _rec = rec;
    final samples = <double>[];
    _samples = samples;
    final ep = _Endpointer(onSpeech: onSpeech, maxMs: (maxSeconds * 1000).round(), waitMs: (waitSeconds * 1000).round());
    _ep = ep;
    try {
      _vad?.reset();
    } catch (_) {}
    _vadPending.clear();

    void step(double rms, int ms, {bool? voice}) {
      onLevel?.call(math.min(1.0, rms * 8));
      switch (ep.feed(rms, ms, voice: voice)) {
        case _Ep.done:
          unawaited(_decodeAndFinish(session, samples, ep.speechAt));
        case _Ep.silence:
          _finishSession(const ListenResult(ListenEnd.silence));
        case _Ep.go:
          break;
      }
    }

    try {
      CrashGuard.enter('mic', 'start', limit: 10);
      if (!_micPermitted) {
        final allowed = await rec.hasPermission();
        if (!allowed) {
          CrashGuard.leave();
          _finishSession(const ListenResult(ListenEnd.noMic));
          return session.future;
        }
        _micPermitted = true;
      }
      const cfg = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _rate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      );
      Stream<Uint8List>? stream;
      try {
        stream = await rec.startStream(cfg);
      } catch (e) {
        log?.call('[micro] không thu trực tiếp được ($e) → thu ra tệp');
      }
      CrashGuard.leave();
      if (stream != null) {
        var total = 0;
        _sub = stream.listen((chunk) {
          if (!identical(_session, session)) return;
          final bd = ByteData.sublistView(chunk);
          final n = chunk.length ~/ 2;
          if (n == 0) return;
          var sum = 0.0;
          final chunkSamples = List<double>.filled(n, 0);
          for (var i = 0; i < n; i++) {
            final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
            chunkSamples[i] = v;
            sum += v * v;
          }
          samples.addAll(chunkSamples);
          total += n;
          step(math.sqrt(sum / n), total * 1000 ~/ _rate, voice: _vadFeed(chunkSamples));
        }, onError: (Object e) {
          log?.call('[micro] $e');
          _finishSession(const ListenResult(ListenEnd.noMic));
        });
      } else {
        await _listenToFile(rec, session, samples, step);
      }
    } catch (e) {
      CrashGuard.leave();
      log?.call('[micro] không mở được: $e');
      _finishSession(const ListenResult(ListenEnd.noMic));
    }
    return session.future;
  }

  /// Dự phòng khi máy không thu âm dạng luồng: ghi ra tệp WAV, đo độ to mỗi 60 ms để biết lúc ngừng nói,
  /// xong thì đọc tệp vào [samples].
  String? _wavPath;
  Future<void> _listenToFile(AudioRecorder rec, Completer<ListenResult> session, List<double> samples,
      void Function(double rms, int ms) step) async {
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}danbau_lenh.wav';
    _wavPath = path;
    CrashGuard.enter('mic', 'file', limit: 10);
    await rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: _rate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
      path: path,
    );
    CrashGuard.leave();
    final sw = Stopwatch()..start();
    _poll = Timer.periodic(const Duration(milliseconds: 60), (_) async {
      if (!identical(_session, session)) return;
      try {
        final a = await rec.getAmplitude();
        final db = a.current.isFinite ? a.current : -90.0;
        step(math.pow(10, db / 20).toDouble(), sw.elapsedMilliseconds);
      } catch (_) {}
    });
  }

  Timer? _poll;

  /// Đọc mẫu âm thanh từ tệp WAV 16-bit (phần dữ liệu sau khối "data").
  static void _readWav(String path, List<double> out) {
    final b = File(path).readAsBytesSync();
    final bd = ByteData.sublistView(b);
    var p = 12;
    while (p + 8 <= b.length) {
      final id = String.fromCharCodes(b.sublist(p, p + 4));
      final len = bd.getUint32(p + 4, Endian.little);
      if (id == 'data') {
        final end = math.min(b.length, p + 8 + len);
        for (var i = p + 8; i + 1 < end; i += 2) {
          out.add(bd.getInt16(i, Endian.little) / 32768.0);
        }
        return;
      }
      p += 8 + len + (len & 1);
    }
  }

  Future<void> _decodeAndFinish(Completer<ListenResult> session, List<double> samples, int speechAtMs) async {
    if (!identical(_session, session)) return;
    _session = null; // không nhận thêm khối âm thanh nào
    await _stopMic();
    final wav = _wavPath;
    if (wav != null) {
      _wavPath = null;
      try {
        _readWav(wav, samples);
      } catch (e) {
        log?.call('[micro] không đọc được tệp thu âm: $e');
      }
    }
    // cắt bớt đoạn im lặng đầu (giữ 0,6 giây trước lúc bắt đầu nói để không mất âm đầu)
    final from = math.max(0, (speechAtMs - 600) * _rate ~/ 1000);
    final audio = Float32List.fromList(samples.sublist(math.min(from, samples.length)));
    final sw = Stopwatch()..start();
    final asr = nvidiaAsr;
    final cloudFuture = (asr != null && asr.enabled)
        ? asr.transcribePcm(audio, sampleRate: _rate, language: lang)
        : Future<String?>.value(null);
    final localText = (await _recognize(audio))?.trim() ?? '';
    final cloudText = await cloudFuture;
    final seconds = audio.length / _rate;
    final cloudBad = cloudText == null || cloudText.trim().isEmpty ? null : cloudSuspicious(cloudText, localText, seconds);
    final useCloud = cloudText != null && cloudText.trim().isNotEmpty && cloudBad == null;
    final text = useCloud ? cloudText.trim() : localText;
    if (cloudBad != null) {
      log?.call('[nhận giọng] bỏ kết quả cloud ($cloudBad): "$cloudText" → dùng offline: "$localText"');
    } else if (useCloud) {
      log?.call('[nhận giọng] Cloud (${asr?.effectiveModel}): "$cloudText" [offline: "$localText"]');
    } else {
      log?.call('[nhận giọng] ${(audio.length / _rate).toStringAsFixed(1)} giây tiếng → offline ${sw.elapsedMilliseconds} ms: "$text"');
    }
    if (session.isCompleted) return;
    session.complete(text.isEmpty ? const ListenResult(ListenEnd.silence) : ListenResult(ListenEnd.heard, text));
  }

  Future<String?> _recognize(Float32List audio) {
    final w = _worker;
    if (w == null || audio.isEmpty) return Future.value(null);
    final id = ++_id;
    final c = Completer<String?>();
    _replies[id] = c;
    w.send((id, TransferableTypedData.fromList([audio])));
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  void _finishSession(ListenResult r) {
    final s = _session;
    _session = null;
    _wavPath = null;
    unawaited(_stopMic());
    if (s != null && !s.isCompleted) s.complete(r);
  }

  Future<void> _stopMic() async {
    final sub = _sub, rec = _rec;
    _sub = null;
    _rec = null;
    _poll?.cancel();
    _poll = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    if (rec != null) {
      try {
        CrashGuard.enter('mic', 'stop', limit: 10);
        await rec.stop();
        await rec.dispose();
      } catch (_) {
      } finally {
        CrashGuard.leave();
      }
    }
  }

  /// Dừng nghe (đóng bảng lệnh, bấm Esc…).
  Future<void> cancel() async {
    if (_session != null) _finishSession(const ListenResult(ListenEnd.cancelled));
    await _stopMic();
  }

  List<double>? _samples;
  _Endpointer? _ep;

  /// Người dùng bấm "nói xong": nhận dạng ngay phần đã nghe, không chờ im lặng.
  void finishNow() {
    final s = _session, smp = _samples, ep = _ep;
    if (s == null || smp == null) return;
    if (ep != null && !ep.started && _wavPath == null) {
      _finishSession(const ListenResult(ListenEnd.silence));
      return;
    }
    unawaited(_decodeAndFinish(s, smp, ep?.started == true ? ep!.speechAt : 0));
  }
}

/// Isolate nhận dạng: nạp mô hình một lần, nhận âm thanh 16 kHz → trả chữ (viết thường).
void _workerMain((SendPort, String, bool) args) {
  final (out, dir, canHot) = args;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  sherpa.OfflineRecognizer? rec;
  final sep = Platform.pathSeparator;
  // tiếng Anh: một tệp model.int8.onnx (NeMo CTC) → giải mã tham lam, không có từ khoá ưu tiên
  final ctc = File('$dir${sep}model.int8.onnx').existsSync();
  sherpa.OfflineRecognizer make({required bool hot}) => ctc
      ? sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: '$dir${sep}model.int8.onnx'),
            tokens: '$dir${sep}tokens.txt',
            numThreads: 2,
            debug: false,
          ),
          decodingMethod: 'greedy_search',
        ))
      : sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          transducer: sherpa.OfflineTransducerModelConfig(
            encoder: '$dir${sep}encoder.int8.onnx',
            decoder: '$dir${sep}decoder.onnx',
            joiner: '$dir${sep}joiner.int8.onnx',
          ),
          tokens: '$dir${sep}tokens.txt',
          numThreads: 2,
          debug: false,
          modelingUnit: hot ? 'bpe' : '',
          bpeVocab: hot ? '$dir${sep}bpe.vocab' : '',
        ),
        decodingMethod: hot ? 'modified_beam_search' : 'greedy_search',
        // đo trên 210 câu lệnh (3 giọng, yên tĩnh / quạt / TV): điểm 3.0 + 8 nhánh giảm lỗi từ ~21,5% xuống ~19,6%
        // (yên tĩnh) và ~23,9% → ~21,8% (có quạt), chỉ chậm thêm ~10 ms mỗi câu
        maxActivePaths: hot ? 8 : 4,
        hotwordsFile: hot ? '$dir${sep}hotwords.txt' : '',
        hotwordsScore: 3.0,
      ));
  var note = '';
  final canHotHere = canHot && !ctc;
  try {
    sherpa.initBindings();
    try {
      rec = make(hot: canHotHere);
    } catch (e) {
      note = 'không dùng được từ khoá ưu tiên ($e), nghe bình thường';
      rec = make(hot: false);
    }
    // chạy thử một lần với 0,5 giây im lặng: lần nhận dạng đầu tiên (câu lệnh thật đầu tiên) không bị chậm vì khởi động
    try {
      final st = rec.createStream();
      st.acceptWaveform(samples: Float32List(_rate ~/ 2), sampleRate: _rate);
      rec.decode(st);
      st.free();
    } catch (_) {}
    out.send(('ready', note));
  } catch (e) {
    out.send(('error', '$e'));
    return;
  }
  inbox.listen((msg) {
    if (msg is! (int, TransferableTypedData)) return;
    final (id, data) = msg;
    try {
      final samples = data.materialize().asFloat32List();
      final st = rec!.createStream();
      st.acceptWaveform(samples: samples, sampleRate: _rate);
      rec.decode(st);
      final text = rec.getResult(st).text;
      st.free();
      out.send((id, text.toLowerCase()));
    } catch (_) {
      out.send((id, null));
    }
  });
}

enum _Ep { go, done, silence }

/// Nhận biết lúc bắt đầu / ngừng nói theo độ to (tự học mức ồn nền trong 0,3 giây đầu).
class _Endpointer {
  _Endpointer({this.onSpeech, required this.maxMs, required this.waitMs});
  final void Function()? onSpeech;
  final int maxMs, waitMs;
  double noise = 0.006;
  double peak = 0; // giọng to nhất đã nghe
  bool started = false;
  int speechAt = 0, lastLoud = 0;

  /// Câu lệnh dài nhất tính từ lúc bắt đầu nói (lệnh thường 1–5 giây, câu dài đến 12 giây).
  static const maxSpeechMs = 12000;

  /// Im bao lâu thì coi là nói xong (chờ đủ 650 ms để không cắt ngang khi lấy hơi / ngập ngừng giữa câu).
  static const endSilenceMs = 650;

  int _lastEnergy = 0;

  /// Có VAD: BẮT ĐẦU khi VAD thấy giọng người (voice == true); KẾT THÚC khi đã ngừng nói đủ ~0,65 giây.
  _Ep _feedVad(double rms, int ms, bool voice) {
    final thr = math.max(0.015, noise * 2.5);

    if (!started) {
      // Chỉ học ồn nền khi VAD xác nhận KHÔNG có tiếng người
      if (!voice) {
        noise = math.max(0.005, math.min(0.06, noise * 0.96 + rms * 0.04));
      }
      // BẮT ĐẦU NÓI:
      // Bắt buộc VAD phải thấy tiếng người (voice == true)
      // HOẶC âm lượng to đột biến rõ ràng (rms > 0.038 và vượt xa ồn nền 3.5 lần)
      final hasVoice = voice || (rms > math.max(0.038, noise * 3.5));
      if (hasVoice) {
        started = true;
        speechAt = ms;
        lastLoud = ms;
        _lastEnergy = ms;
        onSpeech?.call();
      }
    } else {
      // Đang trong phiên nói: duy trì trạng thái khi có tiếng người hoặc năng lượng vượt ngưỡng
      final loud = voice || (rms > thr && rms > peak * 0.22);
      if (rms > peak) peak = rms;
      if (loud) {
        lastLoud = ms;
        _lastEnergy = ms;
      }
      // KẾT THÚC CÂU NÓI:
      // 1. Phải nói được ít nhất 400ms (tránh tiếng thở, nhấp chuột, tặc lưỡi 50-100ms thành câu nói)
      // 2. Im lặng thực sự (VAD không thấy tiếng nói VÀ đã qua endSilenceMs = 650ms)
      // 3. Hoặc năng lượng đã tắt hẳn quá 900ms
      if (ms - speechAt > 400) {
        if (!voice && ms - lastLoud > endSilenceMs) return _Ep.done;
        if (ms - _lastEnergy > 900) return _Ep.done;
      }
      if (ms - speechAt > maxSpeechMs) return _Ep.done;
    }

    if (!started && ms > waitMs) return _Ep.silence;
    if (ms > maxMs) return started ? _Ep.done : _Ep.silence;
    return _Ep.go;
  }

  /// [voice]: kết luận của Silero VAD (true = đang có giọng người); null = không có VAD → đoán theo độ to [rms].
  _Ep feed(double rms, int ms, {bool? voice}) {
    if (voice != null) return _feedVad(rms, ms, voice);
    if (ms < 300 && !started) {
      noise = math.max(0.006, math.min(0.06, noise * 0.7 + rms * 0.3));
      return _Ep.go;
    }
    final thr = math.max(0.02, noise * 3.0);
    if (!started && rms <= thr) {
      noise = math.max(0.005, math.min(0.06, noise * 0.96 + rms * 0.04));
    }
    final loud = rms > thr && (!started || rms > peak * 0.25);
    if (loud) {
      if (!started) {
        started = true;
        speechAt = ms;
        onSpeech?.call();
      }
      lastLoud = ms;
    }
    if (started && rms > peak) peak = rms;
    if (started && ms - lastLoud > endSilenceMs && ms - speechAt > 400) return _Ep.done;
    if (started && ms - speechAt > maxSpeechMs) return _Ep.done;
    if (!started && ms > waitMs) return _Ep.silence;
    if (ms > maxMs) return started ? _Ep.done : _Ep.silence;
    return _Ep.go;
  }
}
