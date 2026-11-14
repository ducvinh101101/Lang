// Lời nói của app: hoặc tự đọc bằng TTS, hoặc nhường cho trình đọc màn hình (TalkBack/VoiceOver/Narrator).
// Luôn cập nhật phụ đề để người nhìn kém / máy không có giọng tiếng Việt vẫn đọc được.
//
// Chống văng (đặc biệt trên Windows):
//  • mọi lệnh gọi xuống TTS gốc được XẾP HÀNG, không bao giờ chồng nhau; chỉ gọi stop() khi đang nói;
//  • mỗi lệnh gốc được CrashGuard đánh dấu → nếu plugin làm app văng, lần mở sau tự chuyển sang
//    giọng dự phòng chạy ngoài tiến trình (Windows) hoặc trình đọc màn hình, không văng lại nữa.
// Chạy thử không có TTS: flutter run -d windows --dart-define=NO_TTS=true
import 'dart:async';
import 'dart:io' show Process;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../audio/audio_engine.dart';
import '../core/crash_guard.dart';
import '../core/net_cache.dart';
import 'sapi_fallback.dart';
import 'vi_translit.dart';
import 'web_speech.dart';
import 'piper_voice.dart';
import 'remote_voice.dart';
import 'win_voice.dart';

const bool kNoTts = bool.fromEnvironment('NO_TTS');

enum SpeechMode {
  /// App tự đọc bằng TTS (người dùng không bật trình đọc màn hình).
  tts,

  /// Gửi chữ cho trình đọc màn hình đọc, tránh hai giọng nói chồng nhau.
  screenReader,
}

class Speaker {
  final AudioEngine audio;
  FlutterTts? _tts;
  SapiFallback? _sapi;

  /// Giọng tiếng Việt ĐÓNG GÓI trong app (giống nhau trên mọi máy) — ưu tiên số 1 cho tiếng Việt.
  PiperVoice? _piper;

  /// Tên đặc biệt trong Cài đặt: dùng giọng đóng gói của app.
  static const appVoiceName = '__app__';

  bool get usingBuiltinVoice => _piper != null && lang != 'en' && (preferredVoice == null || preferredVoice == appVoiceName);
  bool get hasBuiltinVoice => _piper != null;

  /// Windows: bộ đọc riêng ngoài tiến trình (xem win_voice.dart) — chọn giọng theo tên, không rơi về giọng Anh âm thầm.
  WinVoice? _win;

  /// Tên giọng người dùng đã chọn (lưu trong Cài đặt).
  String? preferredVoice;
  double _winRate = -1;
  final caption = ValueNotifier<String>('');

  SpeechMode mode = SpeechMode.tts;
  String lang = 'vi';
  double rate = 0.5; // flutter_tts: 0..1, 0,5 là bình thường

  /// Chế độ bạn nhỏ: đọc chậm hơn ~15% so với tốc độ đã chọn.
  bool kid = false;
  double get effectiveRate => math.max(0.15, kid ? rate * 0.85 : rate);
  bool hasVietnamese = false;
  bool hasEnglish = false;
  bool ready = false;
  String? error;

  /// false = không dùng plugin flutter_tts (chế độ an toàn sau khi nó làm app văng, hoặc người dùng tắt).
  bool usePlugin = true;

  (String, String) _last = ('', '');
  bool _turnFresh = true;

  /// Người dùng vừa hỏi câu mới: câu app nói tiếp theo là đầu một câu trả lời mới (cho lệnh "đọc lại").
  void newTurn() => _turnFresh = true;
  Timer? _quickTimer;
  String? _lastQuick;
  Completer<void>? _done;
  bool _speaking = false;
  /// GlobePage gán: true = lệnh đang gọi say() đã bị lệnh mới thay (bấm nhanh nhiều nút).
  bool Function()? hold;
  int _gen = 0;
  Future<void> _chain = Future.value();

  Speaker(this.audio);

  /// Đang dùng giọng dự phòng ngoài tiến trình (Windows).
  bool get usingFallback => _sapi != null || _win != null;

  /// Đang dùng bộ đọc Windows (có danh sách giọng để chọn).
  bool get usingWinVoice => _win != null;
  List<WinVoiceInfo> get winVoices => _win?.voices ?? const [];
  String? get currentVoice => _win?.current;

  /// Windows không có giọng tiếng Việt → câu tiếng Việt sẽ bị đọc bằng giọng Anh. App báo và chỉ cách cài.
  bool get missingVietnamese => _win != null && !hasVietnamese && _piper == null;

  /// Đang đọc dở (để chờ thay vì cắt ngang, giống bản web).
  bool get busy =>
      _speaking || (_win?.playing ?? false) || (_piper?.playing ?? false) || _sapiBusy || (_remote?.playing ?? false);

  // ---------- Web: giọng tiếng Việt qua máy chủ khi trình duyệt không có ----------
  RemoteVoice? _remote;
  // chạy thử bản web trên máy (flutter run -d chrome) không có /api: trỏ tới trang đã deploy bằng
  //   --dart-define=TTS_URL=https://<tên-dự-án>.vercel.app/api/tts
  static const _ttsUrl = String.fromEnvironment('TTS_URL');
  RemoteVoice _remoteVoice() => _remote ??=
      RemoteVoice(audio, _ttsUrl.isNotEmpty ? Uri.parse(_ttsUrl) : Uri.base.resolve('/api/tts'), log: CrashGuard.log);
  bool? _webViVoice;

  /// true khi trình duyệt không có giọng Việt mà máy chủ đọc được (Edge/Safari/Chrome Android có giọng Việt → false).
  /// Giọng của trình duyệt đã im lặng (đọc 3 lần không ra tiếng) trong phiên này → các câu sau đọc bằng giọng máy chủ.
  bool _webSpeechSilent = false;

  Future<bool> _webNeedsServerVoice() async {
    if (!kIsWeb || !WebSpeech.supported) return false;
    if (_webSpeechSilent || WebSpeech.preferServerVoice) return audio.ready && await _remoteVoice().available();
    var has = _webViVoice;
    if (has == null) {
      // Chrome nạp danh sách giọng chậm: chờ tối đa ~1,5 giây cho lần đầu
      for (var k = 0; k < 6 && WebSpeech.voiceCount == 0; k++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      has = WebSpeech.hasVoice('vi');
      if (WebSpeech.voiceCount > 0) _webViVoice = has;
      CrashGuard.log('[giọng web] trình duyệt ${has ? 'CÓ' : 'KHÔNG có'} giọng tiếng Việt');
    }
    if (has) return false;
    return audio.ready && await _remoteVoice().available();
  }
  bool _sapiBusy = false;
  SapiFallback? _sapiBackup;

  /// Chạy f sau mọi lệnh TTS trước đó; lỗi không làm hỏng hàng đợi.
  Future<void> _serial(Future<void> Function() f) {
    final next = _chain.then((_) => f()).catchError((Object e) {
      CrashGuard.log('[tts] $e');
    });
    _chain = next;
    return next;
  }

  /// Bọc một lệnh gốc: đánh dấu trước, xoá dấu sau.
  Future<T> _native<T>(String what, Future<T> Function() f) async {
    CrashGuard.enter('tts', what);
    try {
      // Một số điện thoại Android: bộ đọc của máy chưa kết nối xong thì isLanguageAvailable / setLanguage… KHÔNG BAO GIỜ
      // trả lời → app kẹt mãi ở "Đang lên dây đàn". Quá 6 giây thì bỏ qua (riêng speak có thể lâu hơn).
      if (what == 'speak') return await f();
      return await f().timeout(const Duration(seconds: 6));
    } finally {
      CrashGuard.leave();
    }
  }

  Future<void> init() async {
    if (kNoTts) {
      error = 'NO_TTS';
      return;
    }
    // 1) Giọng tiếng Việt đóng gói trong app: giống nhau trên mọi máy, không cần mạng, không cần cài giọng
    if (_piper == null && await PiperVoice.bundled()) {
      final pv = PiperVoice(audio, log: CrashGuard.log);
      if (await pv.start()) {
        _piper = pv;
        hasVietnamese = true;
        ready = true;
      } else {
        CrashGuard.log('[giọng] không dùng được giọng đóng gói, chuyển sang giọng của máy');
      }
    }
    // 2) Windows: bộ đọc riêng ngoài tiến trình (giọng cài trong Windows; dùng cho tiếng Anh hoặc khi người dùng chọn)
    if (WinVoice.supported) {
      final w = WinVoice();
      if (await w.start(log: CrashGuard.log)) {
        _win = w;
        hasVietnamese = _piper != null || w.voices.any((v) => v.isVietnamese);
        hasEnglish = w.voices.any((v) => v.isEnglish);
        ready = true;
        _applyWinVoice();
        if (!hasVietnamese && _piper == null) {
          CrashGuard.log('[giọng] Windows chưa có giọng tiếng Việt. Giọng đang có: '
              '${w.voices.map((v) => '${v.name} (${v.locale})').join(', ')}');
        }
        return;
      }
      CrashGuard.log('[giọng] bộ đọc Windows không chạy được, chuyển sang plugin');
    }
    if (!usePlugin) {
      _useFallback('Đã tắt plugin giọng đọc (chế độ an toàn)');
      return;
    }
    // Nếu đã có giọng đóng gói Piper sẵn sàng, khởi tạo FlutterTts của hệ điều hành ở nền
    // để vào app đọc lời chào ngay lập tức, không chờ dịch vụ TTS của Android khởi động chậm (6–10 giây).
    if (_piper != null) {
      unawaited(_initPluginTts());
      return;
    }
    await _initPluginTts();
  }

  Future<void> _initPluginTts() async {
    try {
      final tts = FlutterTts();
      _tts = tts;
      tts.setStartHandler(() {
        _speaking = true;
        audio.duck(true);
      });
      tts.setCompletionHandler(_finish);
      tts.setCancelHandler(_finish);
      tts.setErrorHandler((m) {
        CrashGuard.log('[tts] lỗi khi đọc: $m');
        _finish();
      });
      hasVietnamese = _piper != null || await _isAvailable('vi-VN');
      hasEnglish = await _isAvailable('en-US');
      await _applyVoice();
      ready = true;
      if (kIsWeb) unawaited(_webVoiceRetry());
    } catch (e) {
      error = '$e';
      CrashGuard.log('[tts] init lỗi: $e');
      _tts = null;
      _useFallback('$e');
    }
  }

  void _useFallback(String why) {
    if (SapiFallback.supported) {
      _sapi = SapiFallback();
      ready = true;
      debugPrint('[tts] dùng giọng dự phòng ngoài tiến trình: $why');
    }
  }

  Future<bool> _isAvailable(String code) async {
    final tts = _tts;
    if (tts == null) return false;
    try {
      final dynamic r = await _native<dynamic>('isLanguageAvailable', () async => await tts.isLanguageAvailable(code));
      if (r == true || r == 1) return true;
    } catch (_) {
      // Windows có thể không hỗ trợ isLanguageAvailable → thử danh sách ngôn ngữ
    }
    try {
      final dynamic langs = await _native<dynamic>('getLanguages', () async => await tts.getLanguages);
      final prefix = code.split('-').first.toLowerCase();
      if (langs is List) {
        return langs.any((l) => '$l'.toLowerCase().replaceAll('_', '-').startsWith(prefix));
      }
    } catch (_) {}
    return false;
  }

  void _finish() {
    _speaking = false;
    CrashGuard.clearSoft();
    audio.duck(false);
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  /// Chọn giọng cho bộ đọc Windows: giọng đã lưu (đúng ngôn ngữ) → giọng Việt/Anh đầu tiên → giữ nguyên.
  void _applyWinVoice() {
    final w = _win;
    if (w == null) return;
    final v = w.bestFor(lang, preferred: preferredVoice) ?? w.bestFor(lang == 'en' ? 'vi' : 'en');
    if (v != null && v.name != w.current) w.setVoice(v.name);
    _setWinRate(effectiveRate + 0.5); // giống plugin: 0,5 → tốc độ 1,0 (bình thường)
  }

  void _setWinRate(double r) {
    if ((r - _winRate).abs() < 0.001) return;
    _winRate = r;
    _win?.setRate(r);
  }

  /// Chọn giọng theo tên (Cài đặt / Menu). [appVoiceName] = giọng đóng gói của app.
  void setVoiceName(String name) {
    preferredVoice = name;
    if (name != appVoiceName) _win?.setVoice(name);
  }

  /// Khởi động lại bộ đọc (sau khi người dùng cài thêm giọng tiếng Việt trong Windows).
  Future<void> restart() async {
    _win?.dispose();
    _win = null;
    _piper?.stop();
    ready = false;
    _winRate = -1;
    await init();
  }

  /// Mở trang cài giọng nói của Windows (Settings → Time & language → Speech).
  Future<void> openSystemVoiceSettings() async {
    if (!WinVoice.supported) return;
    try {
      if (!kIsWeb) await Process.start('explorer.exe', ['ms-settings:speech']);
    } catch (e) {
      CrashGuard.log('[giọng] không mở được cài đặt: $e');
    }
  }

  void dispose() {
    _win?.dispose();
    _sapi?.stop();
  }

  Future<void> _applyVoice() async {
    if (_win != null) {
      _applyWinVoice();
      return;
    }
    return _applyPluginVoice();
  }

  Future<void> _applyPluginVoice() => _serial(() async {
        final tts = _tts;
        if (tts == null) return;
        try {
          await _native<dynamic>('setLanguage', () async => await tts.setLanguage(lang == 'en' && hasEnglish ? 'en-US' : 'vi-VN'));
        } catch (_) {}
        try {
          // Web: tốc độ của trình duyệt có 1,0 = bình thường (Android/Windows: 0,5 = bình thường)
          await _native<dynamic>('setSpeechRate', () async => await tts.setSpeechRate(kIsWeb ? effectiveRate * 2 : effectiveRate));
        } catch (_) {}
        if (kIsWeb) {
          _webVoiceOk = false;
          await _pickWebVoice(tts);
        }
      });

  // ---------- Web: chọn giọng của trình duyệt ----------
  bool _webVoiceOk = false;

  /// Chọn giọng tiếng Việt TỐT NHẤT của trình duyệt (như bản web gốc): ưu tiên giọng "Natural"/"Online"
  /// của Edge (Microsoft HoaiMy/NamMinh), rồi giọng Google, rồi giọng tiếng Việt bất kỳ.
  Future<void> _pickWebVoice(FlutterTts tts) async {
    if (_webVoiceOk) return;
    try {
      final want = lang == 'en' && hasEnglish ? 'en' : 'vi';
      final list = await tts.getVoices;
      final vs = <Map<dynamic, dynamic>>[
        if (list is List)
          for (final v in list)
            if (v is Map && '${v['locale']}'.toLowerCase().startsWith(want)) v,
      ];
      if (vs.isEmpty) return;
      int score(Map<dynamic, dynamic> v) {
        final n = '${v['name']}'.toLowerCase();
        return (n.contains('natural') ? 4 : 0) + (n.contains('online') ? 2 : 0) + (n.contains('google') ? 1 : 0);
      }

      vs.sort((a, b) => score(b).compareTo(score(a)));
      await tts.setVoice({'name': '${vs.first['name']}', 'locale': '${vs.first['locale']}'});
      if (want == 'vi') hasVietnamese = true;
      _webVoiceOk = true;
    } catch (e) {
      CrashGuard.log('[tts web] chọn giọng lỗi: $e');
    }
  }

  /// Trình duyệt nạp danh sách giọng chậm (Chrome trả về rỗng lúc đầu) → thử lại vài lần.
  /// Không có giọng tiếng Việt → báo bằng tiếng Anh (giọng Anh đọc đúng) để người khiếm thị biết vì sao.
  Future<void> _webVoiceRetry() async {
    for (final ms in const [600, 1500, 3000]) {
      if (_webVoiceOk) return;
      await Future<void>.delayed(Duration(milliseconds: ms));
      final tts = _tts;
      if (tts == null) return;
      await _pickWebVoice(tts);
    }
    if (_webVoiceOk || lang != 'vi') return;
    if (await _remoteVoice().available()) return; // máy chủ đọc giọng Việt thay → không cần cảnh báo
    webMissingVietnamese = true;
    for (var k = 0; k < 40 && busy; k++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    const msg = 'This browser has no Vietnamese voice, so Vietnamese will sound wrong. '
        'Please open Lang in Microsoft Edge, or install Vietnamese speech on this device.';
    await say(msg, msg, false);
  }

  /// Web: trình duyệt không có giọng tiếng Việt (hiện cảnh báo trong Cài đặt).
  bool webMissingVietnamese = false;

  Future<void> setLang(String l) async {
    lang = l;
    await _applyVoice();
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _applyVoice();
  }

  Future<void> setKid(bool on) async {
    kid = on;
    await _applyVoice();
  }

  String pick(String vi, String en) => lang == 'en' ? en : vi;

  /// Có giọng đọc phù hợp với ngôn ngữ đang chọn không (chỉ để hiện cảnh báo trong Cài đặt).
  bool get hasVoiceForLang => lang == 'en' ? (hasEnglish || hasVietnamese) : hasVietnamese;

  /// Vẫn thử đọc khi KHÔNG dò được giọng tiếng Việt: trên Windows việc dò hay báo sai.
  bool get canSpeak => ready;

  /// Đọc lại câu gần nhất (lệnh "đọc lại").
  Future<void> repeatLast() {
    final (vi, en) = _last;
    if (vi.isEmpty) return say('Chưa có gì để đọc lại.', 'Nothing to repeat yet.', false);
    return say(vi, en, false);
  }

  /// Đọc một câu (huỷ câu đang đọc). Trả về khi đọc xong (tối đa 20 giây).
  Future<void> say(String vi, [String? en, bool remember = true]) {
    if (hold?.call() ?? false) return Future<void>.value(); // lệnh cũ đã bị lệnh mới thay: không đọc chen vào
    _quickTimer?.cancel(); // câu quan trọng: huỷ tên vùng đang chờ đọc, kẻo nó cắt ngang câu này
    // vừa phải dùng số liệu đã lưu vì mạng lỗi → nói rõ một lần, trước câu trả lời
    if (remember && NetCache.staleAt != null && !NetCache.announced) {
      NetCache.announced = true;
      final n = staleNote();
      vi = '${n.$1}$vi';
      en = en == null ? null : '${n.$2}$en';
    }
    return _say(vi, en, remember);
  }

  /// Chuẩn hoá chữ cho máy đọc tiếng Việt (giữ nguyên phụ đề):
  ///  • "1.346" (dấu chấm ngăn nghìn) → "1346", kẻo bị đọc thành "một chấm ba bốn sáu"
  ///  • "tháng 11/2020" → "tháng 11 năm 2020", kẻo bị đọc thành phân số
  ///  • "EarthSense" → "quả địa cầu biết nói" (đọc tên tiếng Anh bằng giọng Việt nghe thành "ớt sen")
  String _forSpeech(String t) {
    if (lang == 'en') return _foldVi(t); // giọng tiếng Anh đọc "Đà Nẵng" sai → bỏ dấu: "Da Nang"
    // tên app: giọng tiếng Việt đọc chữ Anh không chuẩn → phiên âm (phụ đề vẫn hiện "EarthSense")
    var s = t.replaceAll('EarthSense', 'Lắng');
    // chữ / tên tiếng Anh chen giữa câu Việt: phiên âm theo cách đọc quen của người Việt (phụ đề vẫn giữ chữ gốc)
    for (final (from, to) in _viSpell) {
      s = s.replaceAll(from, to);
    }
    // tên nước ngoài còn lại: viết lại thành tiếng kiểu Việt cho giọng Việt đọc tròn
    s = phienAmCau(s);
    // Đơn vị đo lường và ký hiệu khoa học đọc tự nhiên cho giọng Việt
    s = s.replaceAllMapped(RegExp(r'-(\d+(?:[.,]\d+)?)\s*°C'), (m) => 'âm ${m[1]} độ C');
    s = s.replaceAllMapped(RegExp(r'-(\d+(?:[.,]\d+)?)\s*°(?!\w)'), (m) => 'âm ${m[1]} độ');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*°C'), (m) => '${m[1]} độ C');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*°(?!\w)'), (m) => '${m[1]} độ');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*%'), (m) => '${m[1]} phần trăm');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*km/h'), (m) => '${m[1]} ki lô mét một giờ');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*m/s'), (m) => '${m[1]} mét trên giây');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*mm\b'), (m) => '${m[1]} mi li mét');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*km\b'), (m) => '${m[1]} ki lô mét');
    s = s.replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*hPa\b'), (m) => '${m[1]} héc tô pát xcan');
    s = s.replaceAll('~', 'khoảng ').replaceAll('≈', 'khoảng ');

    s = s.replaceAllMapped(RegExp(r'tháng (\d{1,2})/(\d{4})'), (m) => 'tháng ${m[1]} năm ${m[2]}');
    final thousands = RegExp(r'(\d)\.(\d{3})(?!\d)');
    for (var k = 0; k < 4 && thousands.hasMatch(s); k++) {
      s = s.replaceAllMapped(thousands, (m) => '${m[1]}${m[2]}');
    }
    return s;
  }

  /// (mẫu, cách đọc) — mẫu dài/cụ thể đặt trước. Viết tách tiếng bằng dấu cách để giọng Việt đọc tròn từng âm.
  static final List<(Pattern, String)> _viSpell = [
    ('NASA EONET', 'Na xa'), ('NASA POWER', 'Na xa'), (RegExp(r'\bNASA\b'), 'Na xa'), ('EONET', ''),
    ('chỉ số AQI', 'chỉ số'), (RegExp(r'\bAQI\b'), 'chỉ số không khí'), (RegExp(r'\bUV\b'), 'u vê'),
    ('PM2.5', 'pê em hai phẩy năm'), (RegExp(r'\bPM10\b'), 'pê em mười'), ('CO2', 'các bô níc'),
    ('dữ liệu tái phân tích khí hậu ERA5', 'dữ liệu tái phân tích khí hậu'), (RegExp(r'\bERA5\b'), ''),
    ('OpenStreetMap', 'bản đồ mở'), ('Open-Meteo', 'Ô pần Mê tê ô'), (RegExp(r'\bAPOD\b'), ''),
    ('Parker Solar Probe', 'Pác cơ Sô la Prốp'), ('MESSENGER', 'Mét xen giơ'), ('BepiColombo', 'Bê pi Cô lôm bô'),
    ('Venera', 'Vê nê ra'), ('DAVINCI', 'Đa vin xi'), ('VERITAS', 'Vê ri tát'), ('Europa Clipper', 'Ơ rô pa Cờ líp pơ'),
    ('Europa', 'Ơ rô pa'), ('Juno', 'Giu nô'), ('Galileo', 'Ga li lê'), ('Ganymede', 'Ga ni mét'), ('Callisto', 'Ca lít xtô'),
    (RegExp(r'\bIo\b'), 'I ô'), ('Cassini', 'Ca xi ni'), ('Huygens', 'Huy ghen'), ('Enceladus', 'En xê la đút'),
    ('Dragonfly', 'Đờ ra gôn phờ lai'), ('Titania', 'Ti ta ni a'), ('Titan', 'Ti tan'), ('Voyager', 'Voi a giơ'),
    ('Olympus Mons', 'Ô lim pớt Mon'), ('Valles Marineris', 'Va lét Ma ri nê rít'), ('Everest', 'Ê vơ rét'),
    ('Curiosity', 'Ki u ri ô xi ti'), ('Perseverance', 'Pơ xê vê ren'), ('Ingenuity', 'In giơ niu i ti'),
    ('Phobos', 'Phô bốt'), ('Deimos', 'Đây mốt'), ('William Herschel', 'Uy li am Hơ sen'), ('Shakespeare', 'Sếch xpia'),
    ('Miranda', 'Mi ran đa'), ('Ariel', 'A ri en'), ('Oberon', 'Ô bê rôn'), ('Urbain Le Verrier', 'Uya banh Lơ Ve ri ê'),
    ('Johann Galle', 'Giô han Ga lê'), ('Triton', 'Tri tôn'), ('Neil Armstrong', 'Nin Ác xtơ rông'),
    ('Buzz Aldrin', 'Bơ dơ An đrin'), ('Apollo', 'A pô lô'), ('Artemis', 'Ác tê mít'), ('Gemini', 'Giê mi nai'),
    // thành phố hay gặp (dịch vụ tìm địa danh có lúc trả tên tiếng Anh)
    ('New York', 'Niu Oóc'), ('London', 'Luân Đôn'), ('Paris', 'Pa ri'), ('Tokyo', 'Tô ki ô'), ('Moscow', 'Mát xcơ va'),
    ('Beijing', 'Bắc Kinh'), ('Shanghai', 'Thượng Hải'), ('Seoul', 'Xơ un'), ('Bangkok', 'Băng Cốc'), ('Singapore', 'Xinh ga po'),
    ('Sydney', 'Xít ni'), ('Washington', 'Oa sinh tơn'), ('Los Angeles', 'Lốt An giơ lét'), ('Berlin', 'Béc lin'),
    ('Rome', 'Rô ma'), ('Madrid', 'Ma đrít'), ('Phnom Penh', 'Nôm Pênh'), ('Vientiane', 'Viêng Chăn'), ('Jakarta', 'Gia các ta'),
    ('Manila', 'Ma ni la'), ('Kuala Lumpur', 'Cu a la Lăm pơ'), ('Dubai', 'Đu bai'), ('Cairo', 'Cai rô'),
    ('Ho Chi Minh City', 'Thành phố Hồ Chí Minh'), ('Hanoi', 'Hà Nội'), ('Da Nang', 'Đà Nẵng'), (RegExp(r'\bHue\b'), 'Huế'),
    ('Saigon', 'Sài Gòn'), ('Viet Nam', 'Việt Nam'), ('Vietnam', 'Việt Nam'), ('Hong Kong', 'Hồng Kông'), ('Taipei', 'Đài Bắc'),
    ('Kyoto', 'Ki ô tô'), ('Osaka', 'Ô xa ca'), ('New Delhi', 'Niu Đê li'), ('Delhi', 'Đê li'), ('Mumbai', 'Mum bai'),
    ('Istanbul', 'I xtan bun'), ('Athens', 'A ten'), ('Vienna', 'Viên'), ('Prague', 'Pra ha'), ('Warsaw', 'Vác sa va'),
    ('Geneva', 'Giơ ne vơ'), ('Brussels', 'Brúc xen'), ('Lisbon', 'Li xbon'), ('Stockholm', 'Xtốc khôm'), ('Munich', 'Mu ních'),
    ('Amsterdam', 'Am xtéc đam'), ('Melbourne', 'Men bơn'), ('Auckland', 'Ốc lơn'), ('Vancouver', 'Van cu vơ'),
    ('Rio de Janeiro', 'Ri ô đê Gia nây rô'), ('Mexico City', 'Thành phố Mê hi cô'), ('Buenos Aires', 'Bu ê nốt Ai rết'),
    ('São Paulo', 'Xao Pao lô'), ('Sao Paulo', 'Xao Pao lô'), ('Dhaka', 'Đắc ca'), ('Yangon', 'Y an gun'), ('Chicago', 'Chi ca gô'),
    ('San Francisco', 'Xan Phran xít xcô'), ('Toronto', 'Tô rôn tô'), ('Hawaii', 'Ha oai'), ('Alaska', 'A lát xca'),
    // tên bão / sự kiện của NASA (tiếng Anh)
    ('Super Typhoon', 'Siêu bão'), ('Typhoon', 'bão'), ('Hurricane', 'bão'), ('Tropical Storm', 'bão nhiệt đới'),
    ('Tropical Cyclone', 'bão nhiệt đới'), ('Cyclone', 'bão'), ('Tropical Depression', 'áp thấp nhiệt đới'),
    ('Wildfire', 'cháy rừng'), ('Volcano', 'núi lửa'), ('Floods', 'lũ'), ('Flood', 'lũ'),
  ];

  void _announce(String text) {
    try {
      SemanticsService.announce(text, TextDirection.ltr);
    } catch (_) {}
  }

  Future<void> _say(String vi, String? en, bool remember, {bool fast = false}) {
    final text = pick(vi, en ?? vi);
    if (remember) {
      // "đọc lại" phải đọc lại CẢ câu trả lời, không chỉ câu nhắc cuối ("Muốn tự rê tay… nói khám phá bằng tay"):
      // các câu nói liền trong cùng một lượt hỏi được ghép lại; lượt hỏi mới (newTurn) thì bắt đầu lại
      final e = en ?? vi;
      final join = !_turnFresh && _last.$1.isNotEmpty && _last.$1.length + vi.length < 1200;
      _last = join ? ('${_last.$1} $vi', '${_last.$2} $e') : (vi, e);
      _turnFresh = false;
    }
    caption.value = text;
    final my = ++_gen;
    if (mode == SpeechMode.screenReader) {
      _announce(text);
      return Future.value();
    }
    final piper = _piper;
    if (piper != null && usingBuiltinVoice) {
      // giọng đóng gói phát qua bộ âm thanh của app: nhạc cụ tự hạ nhỏ, giọng giữ nguyên
      audio.duck(true);
      final sp = (effectiveRate / 0.5) * (fast ? 1.12 : 1.0);
      return piper.speak(_forSpeech(text), speed: sp.clamp(0.5, 2.0)).then((ok) async {
        // giọng đóng gói không phát được câu này → đọc bằng giọng của máy, không để phụ đề hiện mà im lặng
        if (!ok && my == _gen) {
          CrashGuard.log('[giọng] giọng app không đọc được câu này → đọc bằng giọng của máy');
          if (SapiFallback.supported) {
            _sapiBusy = true;
            try {
              await (_sapiBackup ??= SapiFallback()).speak(_forSpeech(text), lang: lang, rate: effectiveRate);
            } finally {
              _sapiBusy = false;
            }
          } else if (_tts != null) {
            try {
              await _native<dynamic>('speak', () async => await _tts!.speak(_forSpeech(text)));
            } catch (_) {}
          }
        }
      }).whenComplete(() {
        if (my == _gen) audio.duck(false);
      });
    }
    final win = _win;
    if (win != null) {
      _setWinRate((effectiveRate + 0.5) * (fast ? 1.12 : 1.0));
      audio.duck(true);
      return win.speak(_forSpeech(text), rate: _winRate).whenComplete(() {
        if (my == _gen) audio.duck(false);
      });
    }
    final sapi = _sapi;
    if (sapi != null) {
      _sapiBusy = true;
      audio.duck(true);
      return sapi.speak(_forSpeech(text), lang: lang, rate: effectiveRate).whenComplete(() {
        _sapiBusy = false;
        if (my == _gen) audio.duck(false);
      });
    }
    // Web: tự điều khiển speechSynthesis (chia đoạn, đọc lại khi bị nuốt, đổi sang giọng trong máy khi giọng online lỗi)
    // → hết cảnh phụ đề hiện mà không có tiếng
    if (kIsWeb && WebSpeech.supported) {
      if (WebSpeech.speaking) WebSpeech.cancel(); // câu mới thay câu cũ ngay, không chờ câu cũ đọc hết
      if (_remote?.playing ?? false) _remote!.stop();
      final done = Completer<void>();
      _serial(() async {
        if (my != _gen) {
          if (!done.isCompleted) done.complete();
          return;
        }
        _speaking = true;
        audio.duck(true);
        try {
          final speed = (effectiveRate / 0.5) * (fast ? 1.12 : 1.0);
          // Trình duyệt KHÔNG có giọng tiếng Việt (Chrome trên Windows, Firefox…): đọc bằng giọng Việt của app
          // qua máy chủ, thay vì để giọng tiếng Anh đọc tiếng Việt rất khó nghe
          if (lang != 'en' && await _webNeedsServerVoice()) {
            final ok = await _remoteVoice().speak(_forSpeech(text), speed: speed.clamp(0.6, 1.8).toDouble());
            if (ok || my != _gen) return;
          }
          final spoke =
              await WebSpeech.speak(_forSpeech(text), lang: lang, rate: speed, alive: () => my == _gen, log: CrashGuard.log);
          // Trình duyệt nhận câu nhưng không đọc (Safari / iPad chưa mở khoá, mất giọng online…): đọc lại bằng giọng
          // Việt của app qua máy chủ, và dùng luôn giọng đó cho các câu sau
          if (!spoke && my == _gen && lang != 'en' && audio.ready && await _remoteVoice().available()) {
            _webSpeechSilent = true;
            CrashGuard.log('[giọng web] giọng trình duyệt im lặng → chuyển sang giọng máy chủ');
            await _remoteVoice().speak(_forSpeech(text), speed: speed.clamp(0.6, 1.8).toDouble());
          }
        } catch (e) {
          CrashGuard.log('[giọng web] $e');
        } finally {
          if (my == _gen) {
            _speaking = false;
            audio.duck(false);
          }
          if (!done.isCompleted) done.complete();
        }
      });
      // phòng khi âm thanh trình duyệt không bao giờ báo xong (tab bị ẩn, giọng máy chủ dừng giữa đoạn…):
      // không để cả vòng nghe chờ mãi
      final cap = math.max(4000, math.min(90000, (3000 + text.length * 110 / (effectiveRate / 0.5)).round()));
      return done.future.timeout(Duration(milliseconds: cap), onTimeout: () {
        CrashGuard.log('[giọng web] đọc quá lâu không báo xong → coi như xong');
      });
    }
    final tts = _tts;
    if (!canSpeak || tts == null) {
      _announce(text); // không có giọng: nhờ trình đọc màn hình (nếu có) + phụ đề
      return Future.value();
    }
    final done = Completer<void>();
    _serial(() async {
      if (my != _gen) {
        // đã có câu mới hơn: bỏ câu này
        if (!done.isCompleted) done.complete();
        return;
      }
      if (_speaking) {
        try {
          await _native<dynamic>('stop', () async => await tts.stop());
        } catch (_) {}
        _finish();
      }
      if (kIsWeb && !_webVoiceOk) await _pickWebVoice(tts); // giọng có thể vừa nạp xong
      _done = done;
      _speaking = true; // đặt ngay, phòng khi nền tảng không gọi start handler
      try {
        await _native<dynamic>('speak', () async => await tts.speak(_forSpeech(text)));
        if (_speaking) CrashGuard.soft('tts', 'speaking');
      } catch (e) {
        CrashGuard.log('[tts] speak lỗi: $e');
        _finish();
      }
    });
    // Ước lượng thời lượng đọc: phòng khi nền tảng không báo "đọc xong" thì cũng không treo bài học
    final ms = math.max(1500, math.min(20000, (1500 + text.length * 90 / (effectiveRate / 0.5)).round()));
    return done.future.timeout(Duration(milliseconds: ms), onTimeout: () {
      if (identical(_done, done)) _finish();
    });
  }

  /// Câu ngắn (tên vùng khi rê ngón tay): chờ ngón tay dừng 350 ms mới đọc, bỏ qua nếu trùng câu vừa đọc.
  void quick(String vi, [String? en]) {
    _quickTimer?.cancel();
    _quickTimer = Timer(const Duration(milliseconds: 350), () {
      final t = pick(vi, en ?? vi);
      if (t == _lastQuick) return;
      _lastQuick = t;
      _say(vi, en, false, fast: true); // tên vùng đọc nhanh hơn 12%, như bản web
    });
  }

  void resetQuick() => _lastQuick = null;

  /// Huỷ tên vùng đang chờ đọc (khi sắp đọc câu đầy đủ hơn).
  void cancelQuick() => _quickTimer?.cancel();

  Future<void> stop() {
    if (hold?.call() ?? false) return Future<void>.value(); // lệnh cũ không được cắt lời của lệnh mới
    _quickTimer?.cancel();
    caption.value = '';
    _gen++;
    _sapi?.stop();
    _sapiBackup?.stop();
    _win?.stop();
    _piper?.stop();
    if (kIsWeb) {
      WebSpeech.cancel();
      _remote?.stop();
      _speaking = false;
      audio.duck(false);
      return Future.value();
    }
    if (!_speaking) return Future.value();
    return _serial(() async {
      try {
        final tts = _tts;
        if (tts != null) await _native<dynamic>('stop', () async => await tts.stop());
      } catch (_) {}
      _finish();
    });
  }
}

const _viSrc = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
const _viDst = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
String _foldVi(String t) {
  final b = StringBuffer();
  for (final r in t.runes) {
    final c = String.fromCharCode(r);
    final i = _viSrc.indexOf(c);
    b.write(i < 0 ? c : _viDst[i]);
  }
  return b.toString();
}
