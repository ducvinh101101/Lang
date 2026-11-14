import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/crash_guard.dart';

/// Client kết nối tới Cloud / Local ASR:
/// 1. Groq Cloud Whisper Large V3 (miễn phí, siêu nhanh ~200ms, không cần GPU).
/// 2. NVIDIA NIM Local / Self-hosted (Docker `parakeet-ctc-0.6b-vi`).
class CloudAsr {
  CloudAsr({
    this.apiKey = '',
    this.endpoint = defaultCloudEndpoint,
    this.model = defaultModel,
    this.client,
    this.log,
  });

  static const groqEndpoint = 'https://api.groq.com/openai/v1/audio/transcriptions';
  static const groqModel = 'whisper-large-v3';
  static const nvidiaCloudEndpoint = 'https://integrate.api.nvidia.com/v1/audio/transcriptions';
  static const nvidiaLocalEndpoint = 'http://localhost:9000/v1/audio/transcriptions';
  static const nvidiaModel = 'nvidia/parakeet-ctc-0.6b-vi';

  static const defaultCloudEndpoint = groqEndpoint;
  static const defaultLocalEndpoint = nvidiaLocalEndpoint;
  static const defaultModel = groqModel;

  String apiKey;
  String endpoint;
  String model;
  final http.Client? client;
  final void Function(String)? log;

  String get effectiveEndpoint {
    final ep = endpoint.trim();
    if (ep.isNotEmpty && ep != defaultCloudEndpoint) return ep;
    if (apiKey.trim().startsWith('gsk_')) return groqEndpoint;
    if (apiKey.trim().startsWith('nvapi-')) return nvidiaCloudEndpoint;
    return ep.isEmpty ? defaultCloudEndpoint : ep;
  }

  String get effectiveModel {
    if (effectiveEndpoint.contains('groq')) return groqModel;
    if (effectiveEndpoint.contains('nvidia.com')) return nvidiaModel;
    if (effectiveEndpoint.contains('localhost') || effectiveEndpoint.contains('9000')) return nvidiaModel;
    return model;
  }

  bool get enabled =>
      apiKey.trim().isNotEmpty || effectiveEndpoint.contains('localhost') || effectiveEndpoint.contains('127.0.0.1');

  /// Chuyển đổi mẫu PCM float 16 kHz thành mảng byte WAV 16-bit Mono chuẩn RIFF.
  static Uint8List pcmToWav(Float32List s, {int sampleRate = 16000}) {
    final n = s.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono 1 channel
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little); // block align
    b.setUint16(34, 16, Endian.little); // 16 bits
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (s[i] * 32767).round();
      b.setInt16(44 + i * 2, v < -32768 ? -32768 : (v > 32767 ? 32767 : v), Endian.little);
    }
    return b.buffer.asUint8List();
  }

  /// Gửi đoạn âm thanh PCM lên Cloud/NIM để nhận dạng văn bản tiếng Việt/Anh.
  Future<String?> transcribePcm(Float32List samples, {int sampleRate = 16000, String language = 'vi'}) async {
    if (!enabled || samples.isEmpty) return null;
    final wavBytes = pcmToWav(samples, sampleRate: sampleRate);
    return transcribeWav(wavBytes, language: language);
  }

  /// Gửi file WAV trực tiếp qua multipart REST API.
  Future<String?> transcribeWav(Uint8List wavBytes, {String language = 'vi'}) async {
    if (!enabled || wavBytes.isEmpty) return null;
    final targetUrl = effectiveEndpoint;
    final targetModel = effectiveModel;
    final uri = Uri.parse(targetUrl);
    final req = http.MultipartRequest('POST', uri);

    if (apiKey.trim().isNotEmpty) {
      req.headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    req.headers['Accept'] = 'application/json';

    req.fields['model'] = targetModel;
    req.fields['language'] = language;
    if (targetUrl.contains('groq')) {
      req.fields['response_format'] = 'json';
      req.fields['temperature'] = '0.0';
      // Gợi ý từ vựng của app cho Whisper: tên lệnh, địa danh viết đúng chính tả → ít nghe nhầm hơn
      req.fields['prompt'] = language == 'en' ? _promptEn : _promptVi;
    }

    req.files.add(http.MultipartFile.fromBytes(
      'file',
      wavBytes,
      filename: 'speech.wav',
    ));

    final sw = Stopwatch()..start();
    void doLog(String msg) => (log ?? CrashGuard.log)('[ASR: $targetModel] $msg');
    try {
      final c = client;
      final streamed = c != null
          ? await c.send(req).timeout(const Duration(seconds: 12))
          : await req.send().timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final text = (data['text'] as String?)?.trim() ?? '';
        doLog('${sw.elapsedMilliseconds} ms → "$text"');
        return text;
      } else {
        doLog('HTTP ${res.statusCode}: ${res.body}');
        return null;
      }
    } catch (e) {
      doLog('lỗi kết nối: $e');
      return null;
    }
  }
}

// Ngắn (Whisper chỉ đọc ~224 token đầu) và viết như câu lệnh thật để Whisper bắt chước chính tả, dấu tiếng Việt.
const _promptVi = 'Lệnh cho ứng dụng Lắng: thời tiết Hà Nội, chiều nay có mưa không, bão Yagi, lũ miền Trung, '
    'khí hậu Huế, Hà Nội xưa và nay, rê tay khám phá Đà Lạt, quét mặt cắt địa hình, máy hát Trái Đất, nghe sét, '
    'đèn ban đêm, nhiệt độ biển, chiều cao rừng, khí CO2, tháng 5, năm 2020, giải thích, mô tả, chú giải, '
    'Sao Hỏa, Sao Thổ, Sao Mộc, âm thanh NASA, chơi trò chơi, tạm nghỉ, nghe lệnh, quay lại, thoát, dừng, '
    'Đà Nẵng, Thành phố Hồ Chí Minh, Sa Pa, Quảng Ngãi, Phan Xi Păng.';
const _promptEn = 'Commands for the Lang app: weather in Hanoi, will it rain this afternoon, Typhoon Yagi, '
    'explore by touch in Da Lat, scan the terrain, Earth Jukebox, listen to lightning, night lights, ocean temperature, '
    'forest height, month 5, year 2020, explain, describe, legend, Mars, Saturn, Jupiter, NASA sounds, play a game, '
    'go back, exit, stop, Da Nang, Hue, Sa Pa.';

// Câu Whisper hay "bịa" khi gặp đoạn ngắn / im lặng / tiếng ồn (học từ phụ đề YouTube) — không bao giờ là lệnh của app.
final _whisperJunk = RegExp(
    r'(subscribe|đăng ký kênh|dang ky kenh|theo dõi kênh|ghiền mì gõ|ghien mi go|cảm ơn các bạn đã (theo dõi|xem|lắng nghe)|'
    r'hẹn gặp lại các bạn|like và share|bấm like|thank(s| you) for watching|please subscribe|see you (in the )?next|'
    r'amara\.org|subtitles by|♪|\[music\]|\(music\))',
    caseSensitive: false);

/// Kết quả cloud có đáng ngờ không. Trả lý do (để ghi log) hoặc null nếu dùng được.
/// Cloud (Whisper) mạnh với câu dài, nhưng với lệnh ngắn hay "bịa" câu không có trong âm thanh;
/// khi đó bộ nghe offline (có từ khoá ưu tiên là tên lệnh, địa danh) đáng tin hơn.
String? cloudSuspicious(String cloud, String local, double seconds) {
  final c = cloud.trim();
  if (_whisperJunk.hasMatch(c)) return 'câu bịa quen thuộc của Whisper';
  final cw = c.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final lw = local.trim().isEmpty ? 0 : local.trim().split(RegExp(r'\s+')).length;
  // người nói ~2–4 tiếng mỗi giây; nhiều hơn ~6 tiếng/giây (+3) là nghe ra chữ không có trong âm thanh
  if (cw > seconds * 6 + 3) return 'quá nhiều chữ so với ${seconds.toStringAsFixed(1)} giây tiếng';
  // offline nghe ra một câu ngắn mà cloud dài gấp nhiều lần → cloud đã thêm chữ
  if (lw > 0 && cw > lw * 3 + 4) return 'dài hơn hẳn kết quả offline';
  return null;
}

/// Tương thích ngược với tên gọi NvidiaAsr cũ
typedef NvidiaAsr = CloudAsr;

