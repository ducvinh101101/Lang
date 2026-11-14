// Trạng thái chung của app + các dịch vụ (dữ liệu, âm thanh, giọng nói, cài đặt).
// Không dùng package quản lý state: ChangeNotifier + InheritedNotifier là đủ cho bản base.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/audio_engine.dart';
import 'audio/soloud_backend.dart';
import 'audio/sound_backend.dart';
import 'core/app_server.dart';
import 'core/crash_guard.dart';
import 'core/net_cache.dart';
import 'data/asset_data.dart';
import 'data/climate_data.dart';
import 'data/loader.dart';
import 'core/geo.dart';
import 'data/synthetic_data.dart';
import 'live/gemini_assistant.dart';
import 'live/live_grid.dart';
import 'live/live_weather.dart';
import 'speech/nvidia_asr.dart';
import 'speech/speaker.dart';
import 'speech/voice_listener.dart';
import 'core/stats.dart';

class AppState extends ChangeNotifier {
  late final AudioEngine audio;
  late final Speaker speaker;

  /// Nhận giọng nói tiếng Việt đóng gói trong app (nút "Nói lệnh").
  final listener = VoiceListener(log: CrashGuard.log);

  /// NVIDIA NIM ASR (Parakeet CTC 0.6B Vi-En) dự phòng trực tuyến/local.
  final nvidiaAsr = NvidiaAsr(log: CrashGuard.log);

  /// Thời tiết THẬT (bây giờ + dự báo) và trợ lý AI Gemini.
  final weather = WeatherService()..log = CrashGuard.log;
  final ai = GeminiAssistant()..log = CrashGuard.log;

  // ---------- Bản đồ HÔM NAY (số liệu thật của hôm nay) ----------
  late final liveGrid = LiveGridService(weather.client, log: CrashGuard.log);
  LiveGridData? live;
  bool liveMap = false; // người dùng chọn xem bản đồ hôm nay
  bool liveBusy = false;
  String? liveError;
  Timer? _liveTimer;

  /// Bản đồ đang thật sự hiện số liệu hôm nay (đã tải xong).
  bool get liveMapOn => liveMap && live != null;

  /// Nguồn số liệu của bản đồ chạm–nghe: hôm nay hoặc dữ liệu NASA các năm. Dòng thời gian, bài học vẫn dùng [data].
  ClimateData get mapData => liveMapOn ? live! : data;

  /// Đang xem bản đồ theo ngày và số liệu đã khớp đúng ngày chọn.
  bool get liveMapOnDay => liveMapOn && live!.day == liveDay;

  /// Ngày đang xem trên bản đồ theo ngày (null = hôm nay). Không lưu: mở lại app thì về hôm nay.
  DateTime? liveDay;

  /// "hôm nay, cập nhật lúc 22 giờ 10" / "ngày 15 tháng 10 năm 2024" — thay cho "tháng 10 năm 2020".
  String liveWhen(String lang) {
    final d = live?.day;
    if (d != null) {
      final f = live!.isForecast ? (lang == 'vi' ? ', dự báo' : ', forecast') : '';
      final l = dayLabel(d, lang);
      return '${lang == 'vi' ? l[0].toUpperCase() + l.substring(1) : l}$f';
    }
    final u = live?.updated;
    if (u == null) return lang == 'vi' ? 'Hôm nay' : 'Today';
    final mm = u.minute.toString().padLeft(2, '0');
    return lang == 'vi' ? 'Hôm nay, cập nhật lúc ${u.hour} giờ $mm' : 'Today, updated ${u.hour}:$mm';
  }

  /// Tải (lại) số liệu hôm nay cho cả bản đồ. Trả về true nếu thành công.
  Future<bool> refreshLive({bool force = false}) async {
    if (liveBusy) return live != null;
    final want = liveDay;
    final same = live != null && live!.day == want;
    final age = live == null ? null : DateTime.now().difference(live!.updated);
    // ngày đã qua không đổi → không cần tải lại; hôm nay: làm mới sau 20 phút
    if (!force && same && age != null && (want != null || age < const Duration(minutes: 20))) return true;
    liveBusy = true;
    notifyListeners();
    try {
      live = want == null ? await liveGrid.fetch(data) : await liveGrid.fetchDay(data, want);
      liveError = null;
      if (liveMap && !live!.vars.containsKey(v)) v = 'rain';
      return true;
    } on LiveError catch (e) {
      liveError = lang == 'vi' ? e.vi : e.en;
      CrashGuard.log('[bản đồ hôm nay] ${e.vi}');
      return false;
    } catch (e) {
      liveError = '$e';
      CrashGuard.log('[bản đồ hôm nay] $e');
      return false;
    } finally {
      liveBusy = false;
      notifyListeners();
    }
  }

  /// Xem bản đồ của MỘT NGÀY (đã qua hoặc dự báo). Ngày hôm nay = về bản đồ hôm nay.
  Future<bool> setLiveDay(DateTime d) async {
    final t = DateTime.now();
    final isToday = d.year == t.year && d.month == t.month && d.day == t.day;
    liveDay = isToday ? null : DateTime(d.year, d.month, d.day);
    liveMap = true;
    _liveTimer?.cancel();
    final ok = await refreshLive();
    Stats.instance.track('today');
    if (live != null && !live!.vars.containsKey(v)) v = 'rain';
    if (isToday) _liveTimer = Timer.periodic(const Duration(minutes: 20), (_) => refreshLive(force: true));
    notifyListeners();
    return ok && live?.day == liveDay;
  }

  /// Bật/tắt bản đồ hôm nay (lưu lại). Bật thì tải số liệu và tự làm mới mỗi 20 phút.
  /// [save] = false: chỉ trong lần dùng này (chế độ khiếm thị tự bật hôm nay — không đổi lựa chọn của chế độ thường).
  Future<bool> setLiveMap(bool on, {bool save = true}) async {
    liveDay = null; // nút / lệnh "hôm nay" luôn về hôm nay
    liveMap = on;
    if (save && !blindMode) await _prefs.setBool('mapToday', on);
    _liveTimer?.cancel();
    var ok = true;
    if (on) {
      ok = await refreshLive();
      Stats.instance.track('today');
      if (live != null && !live!.vars.containsKey(v)) v = 'rain';
      _liveTimer = Timer.periodic(const Duration(minutes: 20), (_) => refreshLive(force: true));
    }
    notifyListeners();
    return ok;
  }

  /// Đọc / ghi một giá trị nhỏ đã lưu (vd ngày đã đọc bản tin sáng).
  String? pref(String key) => _prefs.getString(key);
  Future<void> setPref(String key, String value) => _prefs.setString(key, value);

  /// Chế độ bắt buộc gọi tên (Wake word): mặc định TẮT (false) để người dùng hỏi tự nhiên là trả lời ngay.
  bool get wakeMode => _prefs.getString('wakeMode') == '1';
  Future<void> setWakeMode(bool on) async {
    await _prefs.setString('wakeMode', on ? '1' : '0');
    notifyListeners();
  }

  Future<void> setStatsEnabled(bool on) async {
    await Stats.instance.setEnabled(on);
    notifyListeners();
  }

  Future<void> setFirmsKey(String k) async {
    liveGrid.firmsKey = k.trim();
    await _prefs.setString('firmsKey', k.trim());
    notifyListeners();
  }

  /// Nơi mặc định khi hỏi thời tiết không nói tên nơi (tên trong danh sách `places`), null = chưa đặt.
  String? homePlace;
  Place? get home => homePlace == null ? null : places.where((p) => p.name == homePlace).firstOrNull;

  // Khoá có thể đặt sẵn khi build: --dart-define=GEMINI_API_KEY=... --dart-define=GOOGLE_WEATHER_KEY=... --dart-define=NVIDIA_API_KEY=...
  static const _envGemini = String.fromEnvironment('GEMINI_API_KEY');
  static const _envGoogleWeather = String.fromEnvironment('GOOGLE_WEATHER_KEY');
  static const _envNvidia = String.fromEnvironment('NVIDIA_API_KEY');
  static const _envGroq = String.fromEnvironment('GROQ_API_KEY');

  /// Khoá đã nhập trong Cài đặt; nếu chưa nhập (hoặc để trống) thì dùng khoá truyền lúc build/chạy
  /// (--dart-define-from-file=keys.json). Khoá KHÔNG viết thẳng trong mã nguồn.
  String _keyOr(String pref, String env) {
    final v = _prefs.getString(pref)?.trim() ?? '';
    return v.isNotEmpty ? v : env;
  }
  late SharedPreferences _prefs;

  ClimateData data = SyntheticData();
  AssetData? assetData; // null nếu chưa có output pipeline trong assets/data
  String? assetError;

  // Cài đặt (lưu lại)
  String lang = 'vi';
  String speechModePref = 'auto'; // auto | tts | sr
  bool haptics = true;
  bool earcons = true;

  /// Nguồn dữ liệu: auto (dữ liệu NASA đóng gói nếu có, không thì mô phỏng) | assets | remote | synthetic
  String dataSource = 'auto';

  /// URL thư mục gói dữ liệu (chứa touchgrid.json), vd https://<tên>.github.io/danbau-trai-dat/web/data/
  String remoteUrl = '';
  String? dataError;
  bool dataBusy = false;

  /// Lắng chỉ còn MỘT chế độ: cho người khiếm thị (quả địa cầu + nghe lệnh liên tục).
  /// Giữ hai cờ này (hằng) để các phần chung (lời đọc, trợ lý AI) không phải sửa.
  final bool kidMode = false;
  final bool blindMode = true;

  /// Dùng plugin giọng đọc của hệ điều hành (tắt = giọng dự phòng/ trình đọc màn hình). Đổi có hiệu lực khi mở lại app.
  bool pluginTts = true;

  /// Bật nhạc cụ (thư viện âm thanh). Đổi có hiệu lực khi mở lại app.
  bool instruments = true;

  /// Lần trước app văng trong phần nào → đã tự tắt phần đó: 'tts' | 'audio' | null. Hiện thông báo một lần.
  String? safeMode;


  // Trạng thái khám phá
  String v = 'rain';
  int year = 2020;
  int month = 9; // 0..11 → tháng 10/2020, như bản web

  bool loading = true;

  AppState({SoundBackend? backend}) {
    // Chạy thử không âm thanh: flutter run -d windows --dart-define=NO_AUDIO=true
    const noAudio = bool.fromEnvironment('NO_AUDIO');
    audio = AudioEngine(backend ?? (noAudio ? SilentBackend() : SoloudBackend()));
    speaker = Speaker(audio);
  }

  String t(String vi, String en) => lang == 'en' ? en : vi;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Bản release Android từng lỗi "NoSuchMethodError … SharedPreferencesApiRegistrar.getAll" (R8 cắt mất hàm) → app
      // kẹt ở "Đang lên dây đàn". Không đọc được cài đặt thì dùng bộ nhớ tạm: app vẫn chạy, chỉ không lưu cài đặt.
      CrashGuard.log('Không mở được cài đặt đã lưu ($e) → dùng cài đặt mặc định trong lần chạy này');
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      _prefs = await SharedPreferences.getInstance();
    }
    await Stats.instance.init(_prefs);
    Stats.instance.mode = () => 'blind';
    lang = _prefs.getString('lang') ?? 'vi';
    // bộ nghe tiếng Anh không còn đóng gói sẵn (tải khi cần): máy chưa tải mà lần trước để tiếng Anh → mở bằng tiếng Việt,
    // kẻo app không nghe được câu nào (người dùng nói "chuyển sang tiếng Anh" là app tải về)
    if (lang == 'en' && !await VoiceListener.modelReady('en')) lang = 'vi';
    speechModePref = _prefs.getString('speechMode') ?? 'auto';
    haptics = _prefs.getBool('haptics') ?? true;
    earcons = _prefs.getBool('earcons') ?? true;
    dataSource = _prefs.getString('dataSource') ?? ((_prefs.getBool('useAssets') ?? false) ? 'assets' : 'auto');
    remoteUrl = _prefs.getString('remoteUrl') ?? '';
    speaker.lang = lang;
    listener.lang = lang;
    unawaited(listener.prepare());
    NetCache.log = CrashGuard.log;
    speaker.rate = _prefs.getDouble('rate') ?? 0.5;
    pluginTts = _prefs.getBool('pluginTts') ?? true;
    instruments = _prefs.getBool('instruments') ?? true;
    // Chế độ an toàn: lần trước app văng ngay trong plugin nào thì lần này tự tắt plugin đó
    final crashed = CrashGuard.crashedPart;
    if (crashed == 'tts' && pluginTts) {
      pluginTts = false;
      safeMode = 'tts'; // chỉ tắt trong lần chạy này, không lưu lại
    } else if (crashed == 'audio' && instruments) {
      instruments = false;
      safeMode = 'audio'; // chỉ tắt trong lần chạy này: lần sau tự bật lại nhạc cụ
    }
    if (safeMode != null) CrashGuard.log('Bật chế độ an toàn: tắt $safeMode');
    speaker.usePlugin = pluginTts;
    speaker.preferredVoice = _prefs.getString('voiceName');
    homePlace = _prefs.getString('homePlace');
    liveGrid.firmsKey = _keyOr('firmsKey', const String.fromEnvironment('FIRMS_MAP_KEY'));
    // Người khiếm thị: mặc định bản đồ là số liệu HÔM NAY (cần cho đi lại hằng ngày); người khác: dữ liệu NASA
    // Người khiếm thị: LUÔN bắt đầu bằng bản đồ hôm nay (xem ngày/tháng khác chỉ trong lần dùng đó).
    // Người khác: theo lựa chọn đã lưu, mặc định dữ liệu NASA.
    // quả địa cầu lấy thời tiết từng nơi khi được hỏi → không tải sẵn bản đồ lưới Việt Nam lúc mở app
    liveMap = false;
    weather.provider = _prefs.getString('weatherProvider') ?? 'open-meteo';
    weather.googleKey = _keyOr('googleWeatherKey', _envGoogleWeather);
    ai.apiKey = _keyOr('geminiKey', _envGemini);
    final groq = _keyOr('groqKey', _envGroq);
    final nvidia = _keyOr('nvidiaKey', _envNvidia);
    if (groq.isNotEmpty) {
      nvidiaAsr.apiKey = groq;
      nvidiaAsr.endpoint = _prefs.getString('nvidiaEndpoint') ?? NvidiaAsr.groqEndpoint;
    } else {
      nvidiaAsr.apiKey = nvidia;
      nvidiaAsr.endpoint = _prefs.getString('nvidiaEndpoint') ?? NvidiaAsr.nvidiaLocalEndpoint;
    }
    listener.nvidiaAsr = nvidiaAsr;
    // Đổi mặc định cũ (gemini-flash-latest, hạn mức ít) sang Gemma 4 — người dùng vẫn chọn lại được trong Cài đặt
    final savedModel = _prefs.getString('geminiModel');
    ai.model = savedModel == null || savedModel == 'gemini-flash-latest' ? GeminiAssistant.defaultModel : savedModel;
    // Bản web (Vercel): dùng trợ lý AI qua máy chủ nếu chủ trang đã cài khoá GEMINI_API_KEY (khoá không lộ ra trình duyệt)
    // App cài trên máy (bản build từ CI không mang khoá): chưa có khoá riêng → cũng dùng trợ lý AI qua máy chủ của app
    if (kIsWeb) {
      unawaited(ai.detectProxy(Uri.base.resolve('/api/gemini')).then((_) => notifyListeners()));
    } else if (ai.apiKey.trim().isEmpty) {
      unawaited(ai.detectProxy(Uri.parse('$appServer/api/gemini')).then((_) => notifyListeners()));
    }
    audio.enabled = instruments;

    // Lỗi ở đây KHÔNG được làm app kẹt mãi ở màn "Đang lên dây đàn" (người khiếm thị không thấy gì để thoát)
    // Gói dữ liệu lưới Việt Nam cũ (chỉ Cài đặt còn dùng) nạp ở NỀN → không làm chậm lúc mở app
    unawaited(() async {
      try {
        assetData = await AssetData.tryLoad();
      } catch (e) {
        assetError = '$e';
      }
      try {
        await _applySource();
      } catch (e) {
        dataError ??= '$e';
      }
      notifyListeners();
    }());
    // Bộ âm thanh phải sẵn sàng trước: giọng tiếng Việt đóng gói phát qua nó
    try {
      await audio.init();
    } catch (e, st) {
      CrashGuard.log('Khởi động âm thanh lỗi: $e\n$st');
    }
    // Người khiếm thị không thấy màn "Đang lên dây đàn": phát tiếng tích nhẹ đều đặn cho tới khi app nói được
    audio.earcon('tick');
    final alive = Timer.periodic(const Duration(milliseconds: 1800), (_) => audio.earcon('tick'));
    try {
      // Lần đầu trên điện thoại phải chép ~60 MB giọng đọc ra máy: cho tối đa 45 giây rồi vẫn vào app (giọng xong sau
      // thì tự dùng) — không bao giờ kẹt mãi ở màn "Đang lên dây đàn".
      await speaker.init().timeout(const Duration(seconds: 45), onTimeout: () {
        CrashGuard.log('Khởi động giọng đọc quá 45 giây → vào app trước, giọng đọc sẵn sàng sau');
      });
    } catch (e, st) {
      CrashGuard.log('Khởi động giọng đọc lỗi: $e\n$st');
    }
    alive.cancel();
    try {
      audio.setVolume(_prefs.getDouble('volume') ?? 0.9);
    } catch (_) {}
    loading = false;
    if (liveMap) unawaited(setLiveMap(true, save: false)); // tải bản đồ hôm nay ở nền
    // thống kê ẩn danh: một lượt mở app (+ chế độ đang dùng)
    Stats.instance.track('open');
    notifyListeners();
  }

  /// Gọi từ widget gốc khi biết trình đọc màn hình có bật hay không.
  void syncScreenReader(bool accessibleNavigation) {
    final m = switch (speechModePref) {
      'tts' => SpeechMode.tts,
      'sr' => SpeechMode.screenReader,
      // Web: trang tự bật cây ngữ nghĩa cho trình đọc màn hình nên "accessibleNavigation" luôn bật dù không có
      // trình đọc màn hình → nếu tin nó, app sẽ im lặng. Trên web mặc định app TỰ ĐỌC; người dùng NVDA/JAWS/VoiceOver
      // chọn "Tôi dùng trình đọc màn hình" ở trang Bắt đầu (hoặc trong Cài đặt).
      _ => accessibleNavigation && !kIsWeb ? SpeechMode.screenReader : SpeechMode.tts,
    };
    speaker.mode = m;
  }

  void _clampTime() {
    if (!data.years.contains(year)) year = data.years.last;
    if (!data.vars.containsKey(v)) v = data.vars.keys.first;
  }

  /// Nạp mọi lớp (mưa, nhiệt, cháy, …) của năm đang chọn: đọc "thời tiết ở đây" cần tất cả, không chỉ lớp đang nghe.
  Future<void> ensureAllVars([int? y]) async {
    final yy = y ?? year;
    await Future.wait([
      for (final k in data.vars.keys)
        data.ensureYear(k, yy).catchError((Object e) {
          debugPrint('[dữ liệu] thiếu $k $yy: $e');
        }),
    ]);
  }

  Future<void> setVar(String nv) async {
    // lớp không có trong bản đồ hôm nay (vd cháy rừng khi chưa có khoá FIRMS) → chuyển sang dữ liệu NASA
    if (liveMapOn && !live!.vars.containsKey(nv)) {
      liveMap = false;
      _liveTimer?.cancel();
    }
    v = nv;
    await ensureAllVars();
    notifyListeners();
  }

  /// Chọn một tháng cụ thể của dữ liệu NASA → bản đồ chuyển về dữ liệu các năm (bản đồ hôm nay không có tháng).
  Future<void> setTime(int y, int m) async {
    if (liveMap) {
      liveMap = false; // chỉ trong lần dùng này — không lưu, lần sau người khiếm thị vẫn mở ra là hôm nay
      _liveTimer?.cancel();
    }
    year = y;
    month = m;
    await ensureAllVars();
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    lang = l;
    listener.lang = l;
    unawaited(listener.prepare()); // nạp sẵn bộ nhận giọng của ngôn ngữ mới
    await _prefs.setString('lang', l);
    await speaker.setLang(l);
    notifyListeners();
  }

  Future<void> setSpeechMode(String m) async {
    speechModePref = m;
    await _prefs.setString('speechMode', m);
    notifyListeners();
  }

  Future<void> setRate(double r) async {
    await speaker.setRate(r);
    await _prefs.setDouble('rate', r);
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    audio.setVolume(vol);
    await _prefs.setDouble('volume', vol);
    notifyListeners();
  }

  Future<void> setHaptics(bool on) async {
    haptics = on;
    await _prefs.setBool('haptics', on);
    notifyListeners();
  }

  Future<void> setEarcons(bool on) async {
    earcons = on;
    await _prefs.setBool('earcons', on);
    notifyListeners();
  }

  /// Chọn nguồn dữ liệu (và URL nếu là remote). Lỗi tải được ghi vào dataError, app quay về nguồn dự phòng.
  Future<void> setDataSource(String src, {String? url}) async {
    dataSource = src;
    if (url != null) remoteUrl = url.trim();
    await _prefs.setString('dataSource', dataSource);
    await _prefs.setString('remoteUrl', remoteUrl);
    dataBusy = true;
    notifyListeners();
    await _applySource();
    dataBusy = false;
    notifyListeners();
  }

  Future<void> _applySource() async {
    dataError = null;
    ClimateData next;
    switch (dataSource) {
      case 'synthetic':
        next = SyntheticData();
      case 'remote':
        try {
          if (remoteUrl.isEmpty) throw StateError(t('Chưa nhập URL gói dữ liệu', 'No data URL entered'));
          next = (await AssetData.tryLoad(HttpLoader(remoteUrl)))!;
        } catch (e) {
          dataError = t('Không tải được dữ liệu từ URL: $e', 'Could not load data from URL: $e');
          next = assetData ?? SyntheticData();
        }
      case 'assets':
        if (assetData == null) {
          dataError = assetError ??
              t('Chưa có dữ liệu trong app. Chạy: python -m pipeline.update',
                  'No bundled data yet. Run: python -m pipeline.update');
        }
        next = assetData ?? SyntheticData();
      default: // auto
        next = assetData ?? SyntheticData();
    }
    data = next;
    _clampTime();
    try {
      await ensureAllVars();
    } catch (e) {
      dataError ??= '$e';
    }
  }

  /// Chọn giọng đọc theo tên (Windows) và đọc thử.
  Future<void> setVoiceName(String name) async {
    speaker.setVoiceName(name);
    await _prefs.setString('voiceName', name);
    notifyListeners();
    final label = name == Speaker.appVoiceName ? 'tiếng Việt của app' : name;
    await speaker.say('Xin chào, đây là giọng $label. Lượng mưa tháng 10 ở Huế khoảng 800 mi-li-mét.',
        'Hello, this is the $label voice. October rainfall in Hue is about 800 millimetres.');
  }

  /// Khởi động lại bộ đọc sau khi cài thêm giọng tiếng Việt.
  Future<void> recheckVoices() async {
    await speaker.restart();
    notifyListeners();
    if (speaker.hasVietnamese) {
      await speaker.say('Đã có giọng đọc tiếng Việt.', 'Vietnamese voice found.');
    }
  }

  // ---------- Thời tiết trực tiếp & AI ----------
  Future<void> setHomePlace(String? name) async {
    homePlace = name;
    if (name == null) {
      await _prefs.remove('homePlace');
    } else {
      await _prefs.setString('homePlace', name);
    }
    notifyListeners();
  }

  /// 'open-meteo' (miễn phí, không cần khoá) | 'google' (cần khoá Weather API)
  Future<void> setWeatherProvider(String p) async {
    weather.provider = p;
    await _prefs.setString('weatherProvider', p);
    notifyListeners();
  }

  Future<void> setGoogleWeatherKey(String k) async {
    weather.googleKey = k.trim();
    await _prefs.setString('googleWeatherKey', k.trim());
    notifyListeners();
  }

  Future<void> setGemini({String? key, String? model}) async {
    if (key != null) {
      ai.apiKey = key.trim();
      await _prefs.setString('geminiKey', key.trim());
    }
    if (model != null && model.trim().isNotEmpty) {
      ai.model = model.trim();
      await _prefs.setString('geminiModel', model.trim());
    }
    ai.reset();
    notifyListeners();
  }

  Future<void> setGroqKey(String k) async {
    final trimmed = k.trim();
    await _prefs.setString('groqKey', trimmed);
    if (trimmed.isNotEmpty) {
      nvidiaAsr.apiKey = trimmed;
      nvidiaAsr.endpoint = NvidiaAsr.groqEndpoint;
    }
    notifyListeners();
  }

  Future<void> setNvidiaKey(String k) async {
    nvidiaAsr.apiKey = k.trim();
    await _prefs.setString('nvidiaKey', k.trim());
    notifyListeners();
  }

  Future<void> setNvidiaEndpoint(String u) async {
    final trimmed = u.trim();
    nvidiaAsr.endpoint = trimmed.isEmpty ? NvidiaAsr.defaultCloudEndpoint : trimmed;
    await _prefs.setString('nvidiaEndpoint', nvidiaAsr.endpoint);
    notifyListeners();
  }

  Future<void> setPluginTts(bool on) async {
    pluginTts = on;
    if (on) CrashGuard.forgive();
    await _prefs.setBool('pluginTts', on);
    notifyListeners();
  }

  Future<void> setInstruments(bool on) async {
    instruments = on;
    if (on) CrashGuard.forgive();
    await _prefs.setBool('instruments', on);
    notifyListeners();
  }

  void dismissSafeMode() {
    safeMode = null;
    notifyListeners();
  }

  void earcon(String kind) {
    if (earcons) audio.earcon(kind);
  }

  void stopAll() {
    audio.stopAll();
    speaker.stop();
    notifyListeners(); // các màn đang phát (Dòng thời gian) tự dừng khi nghe thông báo này
    stopSignal.value++;
  }

  /// Tăng mỗi lần bấm "Dừng mọi âm thanh"; các bộ phát lắng nghe để dừng.
  final stopSignal = ValueNotifier<int>(0);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Lấy state mà không đăng ký rebuild (dùng trong callback).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
