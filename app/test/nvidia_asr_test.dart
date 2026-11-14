import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:earthsense/speech/nvidia_asr.dart';

void main() {
  group('NvidiaAsr WAV Conversion', () {
    test('pcmToWav creates valid RIFF/WAVE 16-bit mono header and PCM payload', () {
      final pcm = Float32List.fromList([-1.0, 0.0, 1.0, 0.5, -0.5]);
      final wav = NvidiaAsr.pcmToWav(pcm, sampleRate: 16000);

      expect(wav.length, equals(44 + pcm.length * 2));

      // RIFF header
      expect(utf8.decode(wav.sublist(0, 4)), equals('RIFF'));
      expect(utf8.decode(wav.sublist(8, 12)), equals('WAVE'));

      // fmt chunk
      expect(utf8.decode(wav.sublist(12, 16)), equals('fmt '));
      final bd = ByteData.sublistView(wav);
      expect(bd.getUint16(20, Endian.little), equals(1)); // PCM format
      expect(bd.getUint16(22, Endian.little), equals(1)); // Mono
      expect(bd.getUint32(24, Endian.little), equals(16000)); // Sample rate
      expect(bd.getUint32(28, Endian.little), equals(32000)); // Byte rate (16000 * 2)
      expect(bd.getUint16(32, Endian.little), equals(2)); // Block align
      expect(bd.getUint16(34, Endian.little), equals(16)); // Bits per sample

      // data chunk
      expect(utf8.decode(wav.sublist(36, 40)), equals('data'));
      expect(bd.getUint32(40, Endian.little), equals(pcm.length * 2));

      // Samples conversion
      final s0 = bd.getInt16(44, Endian.little);
      final s1 = bd.getInt16(46, Endian.little);
      final s2 = bd.getInt16(48, Endian.little);
      expect(s0, equals(-32767)); // -1.0 clamped * 32767
      expect(s1, equals(0)); // 0.0
      expect(s2, equals(32767)); // 1.0 clamped * 32767
    });
  });

  group('NvidiaAsr Transcription', () {
    test('returns null when apiKey is empty', () async {
      final asr = NvidiaAsr(apiKey: '');
      expect(asr.enabled, isFalse);

      final res = await asr.transcribePcm(Float32List(1600));
      expect(res, isNull);
    });

    test('sends multipart request to Groq endpoint when key starts with gsk_', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals(CloudAsr.groqEndpoint));
        expect(request.method, equals('POST'));
        expect(request.headers['authorization'], equals('Bearer gsk_test_key'));

        return http.Response.bytes(
          utf8.encode(jsonEncode({'text': 'thời tiết ở Hà Nội hôm nay thế nào'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final asr = CloudAsr(
        apiKey: 'gsk_test_key',
        client: mockClient,
      );

      expect(asr.enabled, isTrue);
      expect(asr.effectiveModel, equals(CloudAsr.groqModel));

      final text = await asr.transcribePcm(
        Float32List.fromList([0.1, -0.2, 0.3]),
        sampleRate: 16000,
        language: 'vi',
      );

      expect(text, equals('thời tiết ở Hà Nội hôm nay thế nào'));
    });

    test('supports custom local Docker endpoint', () async {
      const customUrl = 'http://localhost:9000/v1/audio/transcriptions';

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals(customUrl));
        return http.Response.bytes(
          utf8.encode(jsonEncode({'text': 'bão số 3 đổ bộ'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final asr = NvidiaAsr(
        apiKey: 'nvapi-dummy',
        endpoint: customUrl,
        client: mockClient,
      );

      final text = await asr.transcribeWav(Uint8List.fromList([1, 2, 3]));
      expect(text, equals('bão số 3 đổ bộ'));
    });

    test('sends request to nvidiaCloudEndpoint when key starts with nvapi-', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals(CloudAsr.nvidiaCloudEndpoint));
        expect(request.headers['authorization'], equals('Bearer nvapi-test-key'));
        return http.Response.bytes(
          utf8.encode(jsonEncode({'text': 'thời tiết Đà Nẵng'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final asr = CloudAsr(
        apiKey: 'nvapi-test-key',
        client: mockClient,
      );

      expect(asr.effectiveEndpoint, equals(CloudAsr.nvidiaCloudEndpoint));
      expect(asr.effectiveModel, equals(CloudAsr.nvidiaModel));

      final res = await asr.transcribePcm(Float32List(100));
      expect(res, equals('thời tiết Đà Nẵng'));
    });

    test('returns null gracefully on server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final asr = NvidiaAsr(
        apiKey: 'nvapi-key',
        client: mockClient,
      );

      final text = await asr.transcribePcm(Float32List(100));
      expect(text, isNull);
    });
  });
}
