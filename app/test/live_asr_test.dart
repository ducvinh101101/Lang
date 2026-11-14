import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:earthsense/speech/nvidia_asr.dart';

void main() {
  test('Live test Cloud ASR (Groq Whisper / NVIDIA NIM)', () async {
    const groqKey = String.fromEnvironment('GROQ_API_KEY');
    const nvidiaKey = String.fromEnvironment('NVIDIA_API_KEY');

    final key = groqKey.isNotEmpty ? groqKey : nvidiaKey;
    print('[Live Test] Key length: ${key.length} (${groqKey.isNotEmpty ? "Groq" : "NVIDIA"})');
    if (key.isEmpty) {
      print('[Live Test] Bỏ qua vì chưa truyền API Key');
      return;
    }

    final asr = CloudAsr(
      apiKey: key,
      log: (msg) => print('[Live Test Log] $msg'),
    );

    print('[Live Test] Provider: ${asr.effectiveModel} at ${asr.effectiveEndpoint}');

    // Tạo mẫu âm thanh giả lập (1 giây sine wave 440Hz)
    const rate = 16000;
    final samples = Float32List(rate);
    for (var i = 0; i < rate ~/ 2; i++) {
      samples[i] = (sin(2 * pi * 440 * i / rate) * 0.3);
    }

    final stopwatch = Stopwatch()..start();
    final result = await asr.transcribePcm(samples, sampleRate: rate, language: 'vi');
    stopwatch.stop();

    print('[Live Test] Thời gian phản hồi: ${stopwatch.elapsedMilliseconds} ms');
    print('[Live Test] Kết quả văn bản nhận được: "$result"');

    expect(result, isNotNull);
  });
}
