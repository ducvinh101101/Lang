// MÀN HÌNH DUY NHẤT của Lắng: quả địa cầu 3D + nghe lệnh bằng giọng nói LIÊN TỤC (không cần bấm nút).
//  • App luôn lắng nghe khi không đọc / không chơi nhạc (tự tạm ngừng nghe lúc đang nói để không tự nghe mình).
//  • Nói tên một nơi bất kỳ → quả cầu xoay và phóng tới đó, đọc các chỉ số thời tiết, rồi chơi bằng nhạc cụ.
//  • Người nhìn được (người đi cùng) vẫn kéo để xoay, chụm hai ngón để phóng, chạm để nghe nơi đó; chạm khi app
//    đang đọc = dừng đọc. Bàn phím: Esc dừng, + / − phóng, mũi tên xoay, Enter đọc chỗ đang xem.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../app_state.dart';
import '../../audio/audio_engine.dart' show toScale;
import '../../core/crash_guard.dart';
import '../../core/dev_commands.dart';
import '../../core/net_cache.dart';
import '../../core/haptics.dart';
import '../../core/stats.dart';
import '../../core/locate.dart';
import '../../data/nasa_normalized_data.dart';
import '../../data/planet_bodies.dart';
import '../../live/apod.dart';
import '../../live/eonet.dart';
import '../../live/hazard_history.dart';
import '../../live/nasa_sounds.dart';
import '../history/history_player.dart';
import '../history/history_records.dart';
import '../terrain_scan/terrain_scan_view.dart';
import '../terrain_scan/terrain_sense.dart';
import '../terrain_scan/touch_grid.dart';
import '../eic/eic_commands.dart';
import '../eic/eic_data.dart';
import '../eic/eic_player.dart';
import '../eic/eic_view.dart';
import '../../live/geo_around.dart';
import '../../live/live_weather.dart';
import '../../live/nasa_power.dart';
import '../../live/weather_talk.dart';
import '../../live/vn_admin.dart';
import '../../live/vn_gazetteer.dart';
import '../../speech/voice_listener.dart';
import '../settings/settings_sheet.dart';
import '../../core/geo.dart' show places;
import '../voice/commands.dart' show normVi, parseCommand;
import '../space/planet_painter.dart';
import '../space/solar_painter.dart';
import '../space/planet_facts.dart';
import '../space/planet_games.dart';
import '../space/planets.dart';
import '../space/planets_en.dart';
import 'globe_painter.dart';
import 'hanoi_guide.dart';
import 'hanoi_places.dart';
import 'intent_domain.dart';
import 'local_map.dart';
import '../../core/z_gesture.dart';
import '../../core/two_finger_swipe.dart';
import '../../speech/web_speech.dart';
import 'terrain.dart';
import 'terrain_data.dart';
import 'vn_landmarks.dart';
import 'world.dart';
import 'world_commands.dart';
import 'asr_fix_en.dart';
import 'asr_fix_vi.dart';
import 'world_commands_en.dart';
import 'world_sound.dart';
import '../../live/earth_rag.dart';
import 'weather_card.dart';
import 'audio_visualizer.dart';

import 'transcript_dialog.dart';

/// Khoá Zone mang số thứ tự lệnh (xem GlobePage._stale).
const _kCmdGen = #lang_cmd_gen;

/// Một nơi đã tìm được (dùng chung định nghĩa với WeatherCard).
typedef _Loc = GlobeLoc;

class GlobePage extends StatefulWidget {
  const GlobePage({super.key});

  @override
  State<GlobePage> createState() => _GlobePageState();
}

class _GlobePageState extends State<GlobePage> with TickerProviderStateMixin {
  World? _world;
  // camera và nhịp nhấp nháy là ValueNotifier: thay đổi chỉ vẽ lại đúng lớp cần vẽ, KHÔNG dựng lại cả màn hình
  final _camN = ValueNotifier<GlobeCamera>(GlobeCamera.start);
  GlobeCamera get _cam => _camN.value;
  set _cam(GlobeCamera v) => _camN.value = v;
  final _pulseN = ValueNotifier<double>(0);
  // quả cầu đang chuyển động (kéo, bay, tự quay) → lớp nền vẽ bản nhẹ; đứng yên 180 ms là vẽ lại bản đầy đủ
  final _movingN = ValueNotifier<bool>(false);
  Timer? _stillTimer;
  void _onCamMove() {
    if (!_movingN.value) _movingN.value = true;
    _stillTimer?.cancel();
    _stillTimer = Timer(const Duration(milliseconds: 180), () => _movingN.value = false);
  }
  final _spaceN = ValueNotifier<double>(0);
  bool _reduceMotion = false;
  GlobePin? _pin;
  _Loc? _focus; // nơi đang nói tới
  LiveWeather? _focusWeather;
  _Loc? _focusWeatherLoc; // nơi mà _focusWeather thuộc về (tránh hiện / gửi AI số liệu của nơi cũ)

  /// Thời tiết đã tải cho đúng nơi [loc] (cách < 1 km), null nếu số liệu đang giữ là của nơi khác.
  LiveWeather? _weatherAt(_Loc? loc) {
    final w = _focusWeather, at = _focusWeatherLoc;
    if (w == null || at == null || loc == null) return null;
    return distKm(at.lat, at.lon, loc.lat, loc.lon) < 1 ? w : null;
  }

  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  GlobeCamera _from = GlobeCamera.start, _to = GlobeCamera.start;
  Completer<void>? _flyDone;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  DateTime _touchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  final _keyFocus = FocusNode();
  late AppState _s;
  late final WorldSound _sound = WorldSound(_s.audio);
  late final NasaPowerService _nasa = NasaPowerService(_s.weather.client, log: CrashGuard.log);
  late final EonetService _eonet = EonetService(_s.weather.client, log: CrashGuard.log);
  late final HazardHistoryService _hazHist = HazardHistoryService(_s.weather.client, log: CrashGuard.log);

  /// F3: quét mặt cắt địa hình đang chạy (null = không quét).
  TerrainScanPlayer? _scan;

  /// #14 MÁY HÁT TRÁI ĐẤT: hình NASA SVS đang hát (null = không mở).
  EicPlayer? _eic;
  EicLibrary? _eicLib;

  /// F3: khu dân cư (phường đô thị + thành phố lớn) để rê tay nghe tiếng xe cộ.
  final _urban = UrbanIndex();
  DateTime _tTraffic = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _tSlope = DateTime.fromMillisecondsSinceEpoch(0);
  bool _inUrban = false;
  bool _inWater = false;

  /// F1: bộ phát lại lịch sử thời tiết & thiên tai đang mở (null = không phát).
  HistoryPlayer? _hist;
  final _noShake = ValueNotifier<Offset>(Offset.zero);
  late final GeoAroundService _geo = GeoAroundService(_s.weather.client, log: CrashGuard.log);
  late final ApodService _apodSvc = ApodService(_s.weather.client);
  late final Terrain _terrain = Terrain(_s.weather.client, log: CrashGuard.log);

  // thiên tai đang diễn ra (vẽ chấm đỏ trên quả cầu) và những cái đã cảnh báo trong lần dùng này
  List<NaturalEvent> _events = const [];
  final _alerted = <String>{};

  // địa lý quanh ta: bản đồ chạm (null = đang xem quả cầu)
  AroundData? _local;
  String _localName = '';

  // vũ trụ: thiên thể đang kể chuyện (null = Trái Đất / quả cầu)
  Planet? _planet;
  // màn Hệ Mặt Trời (vừa vào phần vũ trụ, chưa chọn hành tinh) và thiên thể đang được giới thiệu
  bool _solar = false;
  int? _solarHi;
  // cờ dừng vòng kể chuyện / quét / phát lại. Lệnh CŨ (đã bị lệnh mới thay) luôn thấy cờ này bật → tự dừng.
  bool _storyStopFlag = false;
  bool get _storyStop => _storyStopFlag || _stale;
  set _storyStop(bool v) => _storyStopFlag = v;

  // ẤN NHANH NHIỀU NÚT / NÓI LỆNH MỚI KHI LỆNH CŨ CHƯA XONG: mỗi lệnh chạy trong một "vùng" (Zone) mang số thứ tự.
  // Lệnh mới tăng số thứ tự → mọi việc còn dở của lệnh cũ (đọc, chơi nhạc, hiện thẻ thời tiết, bay camera)
  // tự im lặng thay vì đọc chen vào câu trả lời của lệnh mới.
  int _cmdGen = 0;
  bool get _stale {
    final g = Zone.current[_kCmdGen];
    return g is int && g != _cmdGen;
  }

  // nghe lệnh liên tục
  bool _loopOn = false;
  bool _listening = false;
  bool _paused = false; // "tạm nghỉ": chỉ nghe câu "tiếp tục"
  bool _busy = false; // đang xử lý lệnh
  int _noMicCount = 0;
  DateTime _lastConfused = DateTime.fromMillisecondsSinceEpoch(0);
  final _heard = ValueNotifier<String>('');
  final _stickyCaption = ValueNotifier<String>('');
  Timer? _captionFadeTimer;
  final List<TranscriptItem> _transcript = [];
  bool _showWeatherCard = true;

  /// Những câu app vừa đọc (để nhận ra khi micro thu lại chính giọng của app).
  final _spoken = <(String, DateTime)>[];
  WCmd? _lastCmd; // câu hỏi trước (cho câu nối tiếp "còn Đà Nẵng thì sao")
  void _onCaption() {
    final c = _s.speaker.caption.value;
    if (c.isNotEmpty) {
      CrashGuard.log('[app nói] $c'); // nhật ký đầy đủ cuộc trò chuyện (để kiểm tra, sửa lỗi)
      _spoken.add((normVi(expandDigitsVi(c)), DateTime.now()));
      if (_spoken.length > 6) _spoken.removeAt(0);

      _captionFadeTimer?.cancel();
      _stickyCaption.value = c;
      if (_transcript.isEmpty || _transcript.last.text != c) {
        _transcript.add(TranscriptItem(isUser: false, text: c, time: DateTime.now()));
      }
    } else {
      // Giọng đọc vừa dứt: KHÔNG xoá ngay mà giữ lại 10 giây để người khiếm thính/đọc chữ đọc kịp
      _captionFadeTimer?.cancel();
      _captionFadeTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _s.speaker.caption.value.isEmpty) {
          _stickyCaption.value = '';
        }
      });
    }
  }

  void _onHeardChanged() {
    final h = _heard.value;
    if (h.isNotEmpty) {
      // Khi đang chạm khám phá bản đồ địa hình: bỏ qua tiếng loa phát độ cao ("cao 13", "trao 13"...)
      if (_local != null && (RegExp(r'^(trao|cao)\s*\d+').hasMatch(normVi(h)) || normVi(h) == 'trao' || normVi(h) == 'cao')) {
        return;
      }
      _captionFadeTimer?.cancel();
      _stickyCaption.value = '“$h”';
      if (_transcript.isEmpty || _transcript.last.text != h) {
        _transcript.add(TranscriptItem(isUser: true, text: h, time: DateTime.now()));
      }
    }
  }

  /// Câu nghe được có phải là giọng của chính app (tiếng vọng từ loa) không.
  bool _isEcho(String heard) => isEchoOf(normVi(heard), [
        for (final (txt, at) in _spoken) (txt, DateTime.now().difference(at)),
      ], speaking: _s.speaker.busy);

  @override
  void initState() {
    super.initState();
    _camN.addListener(_onCamMove);
    _heard.addListener(_onHeardChanged);
    _fly.addListener(() {
      final t = Curves.easeInOutCubic.transform(_fly.value);
      // bay: lùi ra xa ở giữa đường rồi mới phóng vào (giống Google Earth)
      final mid = math.min(_from.zoom, _to.zoom);
      final dip = math.max(1.0, math.min(mid, 2.5));
      final base = GlobeCamera.lerp(_from, _to, t);
      final away = math.sin(t * math.pi);
      final far = _angle(_from, _to) > 25 ? (base.zoom * (1 - away) + dip * away) : base.zoom;
      _cam = base.copyWith(zoom: math.max(0.9, far)); // chỉ lớp quả cầu vẽ lại
    });
    _fly.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        _flyDone?.complete();
        _flyDone = null;
      }
    });
    _ticker.start();
    World.load().then((w) {
      if (mounted) setState(() => _world = w);
    }).catchError((Object e) {
      CrashGuard.log('[địa cầu] không nạp được bản đồ thế giới: $e');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  bool _captionHooked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = AppScope.read(context);
    if (!_captionHooked) {
      _captionHooked = true;
      _s.speaker.hold = () => _stale;
      _sound.hold = () => _stale;
      _s.speaker.caption.addListener(_onCaption);
      // danh bạ xã, phường (offline): nạp sớm để bộ tách lệnh nhận đủ tên xã dài / có chữ trùng từ hỏi
      unawaited(VnGazetteer.load().then((g) {
        if (g != null) {
          vnPlaceNameKnown = g.knows;
          vnPlaceNameKnownExact = g.knowsExact;
          // F3: trụ sở các PHƯỜNG (đơn vị hành chính đô thị) = khu dân cư đông đúc
          for (final w in g.wards) {
            if (w.$2 == 'Phường') _urban.add(w.$5, w.$6, 2.2);
          }
        }
      }));
      for (final pl in places) {
        _urban.add(pl.lat, pl.lon, pl.major ? 9 : 4);
      }
      // F3: lưới địa lý thật (SRTM, GPWv4) do data_nasa/build_f3.py xuất ra — chưa có thì dùng ước lượng
      unawaited(TouchGrid.load('assets/touch/vn', rootBundle.loadString,
              (path) async => (await rootBundle.load(path)).buffer.asUint8List())
          .then((g) => TouchGrid.loaded = g));
      // F2: danh mục bản ghi âm thật của NASA (để bộ hiểu lệnh nhận tên "Sputnik", "Apollo 11"…)
      unawaited(_loadNasaSounds());
      // Nạp kho dữ liệu chuẩn hóa NASA (GISTEMP, POWER, FIRMS, NSSDCA Planets, QA Bank, Space Media, Da Lat Scene)
      unawaited(NasaNormalizedRepo.load().then((repo) {
        // F3: các thành phố lớn trong bộ khí hậu NASA (14 Việt Nam + 15 thế giới) cũng là khu dân cư
        for (final pl in repo.rawPlaces) {
          final la = (pl['lat'] as num?)?.toDouble(), lo = (pl['lon'] as num?)?.toDouble();
          if (la != null && lo != null) _urban.add(la, lo, pl['group'] == 'vn' ? 7 : 16);
        }
      }));
    }
  }

  /// Dừng hiệu ứng bay (người dùng kéo quả cầu): báo "bay xong" để lệnh đang chờ không bị treo.
  void _stopFly() {
    _fly.stop();
    _flyDone?.complete();
    _flyDone = null;
  }

  @override
  void dispose() {
    _s.speaker.hold = null;
    _hist?.dispose();
    _hist = null;
    _scan?.dispose();
    _scan = null;
    _eic?.dispose();
    _eic = null;
    _noShake.dispose();
    _captionFadeTimer?.cancel();
    _alertTimer?.cancel();
    _devTimer?.cancel();
    _stillTimer?.cancel();
    _camN.removeListener(_onCamMove);
    _camN.dispose();
    _movingN.dispose();
    _pulseN.dispose();
    _spaceN.dispose();
    _loopOn = false;
    _s.speaker.caption.removeListener(_onCaption);
    _heard.removeListener(_onHeardChanged);
    _stickyCaption.dispose();
    unawaited(_s.listener.cancel());
    _sound.stop();
    _ticker.dispose();
    _fly.dispose();
    _keyFocus.dispose();
    _heard.dispose();
    super.dispose();
  }

  /// Góc (độ) giữa hai tâm nhìn.
  static double _angle(GlobeCamera a, GlobeCamera b) {
    final p1 = a.lat * math.pi / 180, p2 = b.lat * math.pi / 180, dl = (b.lon - a.lon) * math.pi / 180;
    final c = math.sin(p1) * math.sin(p2) + math.cos(p1) * math.cos(p2) * math.cos(dl);
    return math.acos(c.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.5) return;
    // quả cầu tự quay chậm khi đang nhìn cả thế giới và không ai chạm
    final idle = DateTime.now().difference(_touchedAt).inSeconds > 6;
    // "Giảm chuyển động" của hệ điều hành: không tự quay, không nhấp nháy
    if (!_reduceMotion && !_fly.isAnimating && _cam.zoom < 1.25 && _focus == null && idle && _local == null && _planet == null && !_solar) {
      _cam = _cam.copyWith(lon: wrapLon(_cam.lon + dt * 4));
    }
    if (!_reduceMotion && (_pin != null || _listening || _events.isNotEmpty)) {
      _pulseN.value = (_pulseN.value + dt / 1.4) % 1.0;
    }
    if (_planet != null || _solar) _spaceN.value += dt;
  }

  Future<void> _flyTo(GlobeCamera to, {int? ms}) {
    _fly.stop();
    _from = _cam;
    _to = to;
    final ang = _angle(_from, _to);
    final zr = (math.log(to.zoom) - math.log(_cam.zoom)).abs();
    // bay nhanh hơn (tối đa 1,8 giây): người khiếm thị không xem cảnh bay, chỉ chờ câu trả lời
    _fly.duration = Duration(milliseconds: ms ?? (650 + ang * 7 + zr * 160).clamp(550, 1800).round());
    _flyDone?.complete();
    final done = Completer<void>();
    _flyDone = done;
    _fly.forward(from: 0);
    return done.future;
  }

  // ======================= Khởi động =======================
  Future<void> _start() async {
    final s = _s;
    // chờ app nạp xong giọng đọc
    for (var k = 0; k < 40 && s.loading; k++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    _keyFocus.requestFocus();
    Stats.instance.track('blind');
    unawaited(_loadEvents());
    unawaited(s.listener.prepare()); // Nạp sẵn mô hình ASR trong RAM song song với lời chào
    // Chờ nhẹ 250ms để kênh âm thanh điện thoại mở hoàn toàn rồi phát tiếng chuông báo sẵn sàng và đọc lời chào
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    s.earcon('ok');
    // Lời chào toàn diện ngay khi mở app: giới thiệu chuyển hoá dữ liệu khoa học NASA bằng nhạc cụ dân tộc Việt Nam và 3 chức năng chính.
    final now = DateTime.now();
    final morning = now.hour >= 5 && now.hour < 11 ? ' Buổi sáng, bạn có thể nói: bản tin, để nghe thời tiết hôm nay.' : '';
    final first = s.pref('introDone') != '1';
    await s.setPref('introDone', '1');
    await s.speaker.say(
        first
            ? 'Xin chào, mình là Lắng, quả địa cầu âm thanh hóa dữ liệu NASA bằng nhạc cụ dân tộc Việt Nam. Bạn không cần bấm gì, cứ nói tự nhiên là mình nghe. '
                'Mình có ba phần chính. Một: Thời tiết toàn cầu và 45 năm lịch sử khí hậu, thiên tai NASA; ví dụ nói: thời tiết Hà Nội, hoặc lịch sử thời tiết Đà Nẵng. '
                'Hai: Địa lý đa giác quan và khám phá quanh bạn; ví dụ nói: rê tay khám phá, quét mặt cắt địa hình, hoặc quanh đây có gì. '
                'Ba: Khám phá vũ trụ với âm thanh thật từ NASA; ví dụ nói: kể chuyện Sao Hỏa, âm thanh thật của NASA, hoặc trò chơi.$morning '
                'Bạn muốn bắt đầu với phần nào?'
            : 'Xin chào, Lắng đây. Bạn muốn nghe thời tiết và lịch sử khí hậu NASA, chạm khám phá địa lý, hay nghe âm thanh vũ trụ?$morning',
        first
            ? 'Hello, I am Lang, transforming NASA Earth and space science into traditional Vietnamese instruments. Just speak naturally. '
                'There are three main parts. One: Global weather and 45-year NASA climate and disaster history, for example: weather in Hanoi, or weather history of Da Nang. '
                'Two: Multimodal geography and surroundings, for example: touch terrain, scan cross section, or what is around here. '
                'Three: Space exploration with real NASA audio recordings, for example: tell me about Mars, NASA sounds, or play a game.$morning '
                'Which would you like to start with?'
            : 'Hello, Lang here. Weather and NASA climate history, tactile geography, or space exploration?$morning');
    _await('section');
    if (!mounted) return;
    // QUAN TRỌNG: _loopOn đã bật ở trên (để nghe được câu nói chen trong lúc chào). Phải hạ xuống trước khi gọi
    // _startLoop(), vì _startLoop() thấy _loopOn đang bật sẽ thoát luôn → app KHÔNG BAO GIỜ mở micro sau lời chào.
    _loopOn = false;
    _startLoop();
  }

  // ======================= Nghe lệnh liên tục =======================
  void _startLoop() {
    if (_loopOn) return;
    _loopOn = true;
    unawaited(_loop());
    if (kDebugMode && !kIsWeb) _devTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _devCommands());
  }

  // Bản debug: lệnh thử đọc từ tệp (xem core/dev_commands.dart) — chạy lần lượt như câu vừa nghe được
  Timer? _devTimer;
  bool _devRunning = false;
  Future<void> _devCommands() async {
    if (_devRunning || !mounted) return;
    _devRunning = true;
    try {
      for (final line in await takeDevCommands()) {
        while (mounted && (_busy || _s.speaker.busy)) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (!mounted) return;
        CrashGuard.log('[thử lệnh] "$line"');
        await _onHeard(line);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      _devRunning = false;
    }
  }

  bool get _quiet => !_s.speaker.busy && !_sound.playing && !_busy;

  bool _noRecognizerSaid = false;
  // lần đầu bắt đầu nghe / đã từng nghe thấy tiếng nói / đã nhắc "chưa nghe thấy" (bản web)
  DateTime? _listenSince;
  bool _speechSeen = false, _silentHintSaid = false;

  Future<void> _loop() async {
    final s = _s;
    final ok = await s.listener.prepare();
    if (!ok) {
      _loopOn = false;
      // chỉ nói MỘT lần: mỗi lần chạm quả cầu app thử bật lại bộ nghe — không lặp lại lời này đè lên tên nơi vừa chạm
      if (_noRecognizerSaid) return;
      _noRecognizerSaid = true;
      await s.speaker.say(
          kIsWeb
              ? 'Trình duyệt này chưa nhận được giọng nói. Hãy mở bằng Chrome hoặc Edge. Bạn vẫn có thể chạm vào quả địa cầu để nghe.'
              : 'Chưa bật được bộ nghe giọng nói. Bạn vẫn có thể chạm vào quả địa cầu để nghe.',
          kIsWeb
              ? 'This browser cannot recognise speech. Please use Chrome or Edge. You can still touch the globe to listen.'
              : 'Speech recognition is not available. You can still touch the globe to listen.');
      return;
    }
    while (_loopOn && mounted) {
      // Chờ app nói / chơi nhạc xong VÀ yên lặng liên tục ~0,24 giây để tránh âm đuôi loa lọt vào phiên nghe mới
      var calm = 0;
      while (_loopOn && mounted && calm < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        calm = _quiet ? calm + 1 : 0;
      }
      if (!_loopOn || !mounted) break;
      setState(() => _listening = true);
      final r = await s.listener.listen(waitSeconds: 8, maxSeconds: 12, onSpeech: () => _speechSeen = true);
      if (!mounted) break;
      setState(() => _listening = false);
      // Trình duyệt mở micro nhưng ~40 giây chưa từng báo "nghe thấy tiếng nói" (hay gặp ở Edge khi dịch vụ nhận giọng
      // của Windows / mạng có vấn đề): người khiếm thị không thấy gì để biết → nói rõ MỘT lần cách khắc phục
      if (kIsWeb && r.end != ListenEnd.heard && !_speechSeen && !_silentHintSaid &&
          DateTime.now().difference(_listenSince!).inSeconds > 40) {
        _silentHintSaid = true;
        await s.speaker.say(
            'Mình vẫn chưa nghe thấy tiếng bạn. Bạn hãy thử mở bằng Google Chrome hoặc kiểm tra lại micro của máy nhé. '
                'Bạn vẫn có thể chạm vào quả địa cầu để nghe thông tin.',
            'I have not heard you yet. If you are speaking and I do not answer, try Google Chrome.');
        continue;
      }
      switch (r.end) {
        case ListenEnd.heard:
          _speechSeen = true;
          _noMicCount = 0;
          _micErrors = 0;
          s.listener.lastError = '';
          if (r.text.trim().isEmpty) continue;
          final text = await _finishSentence(r.text.trim());
          await _bargeWhile(_onHeard(text));
        case ListenEnd.noMic:
          _noMicCount++;
          if (_noMicCount == 1) {
            await s.speaker.say(
                kIsWeb
                    ? 'Mình chưa dùng được micro. Nhờ người đi cùng bấm biểu tượng ổ khóa cạnh địa chỉ trang, chọn Micro, Cho phép, '
                        'rồi chạm vào màn hình một lần.'
                    : 'Mình chưa dùng được micro. Hãy cho phép ứng dụng dùng micro, rồi chạm vào màn hình một lần.',
                'I cannot use the microphone. Please allow microphone access, then tap the screen once.');
          }
          _loopOn = false; // chạm màn hình để thử lại
        case ListenEnd.error:
          // lỗi lặp lại (thường gặp trên Edge: "network" khi Windows tắt Nhận dạng giọng nói trực tuyến) → nói rõ một lần
          _micErrors++;
          final code = s.listener.lastError;
          if (code.isNotEmpty) _heard.value = '(micro lỗi: $code)';
          if (_micErrors == 3) await _micTrouble(code);
          await Future<void>.delayed(Duration(seconds: _micErrors < 3 ? 2 : 5));
        case ListenEnd.silence:
        case ListenEnd.cancelled:
          break;
      }
    }
    if (mounted) setState(() => _listening = false);
  }

  int _micErrors = 0;

  /// Bộ nghe của trình duyệt lỗi liên tục: nói nguyên nhân hay gặp và cách sửa (người khiếm thị không thấy Console).
  Future<void> _micTrouble(String code) async {
    final s = _s;
    s.earcon('err');
    if (code == 'network' || code == 'service-not-allowed' || code == 'language-not-supported') {
      await s.speaker.say(
          'Trình duyệt chưa nhận được giọng nói, mã lỗi $code. Nếu dùng Edge trên Windows, hãy bật: Cài đặt, Quyền riêng tư, '
              'Giọng nói, Nhận dạng giọng nói trực tuyến; và kiểm tra mạng. Hoặc mở trang bằng Chrome. Bạn vẫn chạm vào quả cầu để nghe được.',
          'The browser cannot recognise speech (error $code). On Edge for Windows, turn on Settings, Privacy, Speech, '
              'Online speech recognition, and check the network, or use Chrome.');
    } else {
      await s.speaker.say('Bộ nghe giọng nói của trình duyệt đang lỗi${code.isEmpty ? '' : ', mã $code'}. Mình sẽ thử lại.',
          'The browser speech recogniser keeps failing${code.isEmpty ? '' : ' ($code)'}. Retrying.');
    }
  }

  /// Câu bị cắt giữa chừng vì người nói ngập ngừng ("thời tiết… ở Hà Nội", "kể về… Sao Hỏa"): nghe thêm một nhịp
  /// rồi ghép lại, thay vì làm ngay nửa câu đầu (trước đây "thời tiết" bị hiểu là mở phần hướng dẫn thời tiết).
  /// Đang chờ trả lời câu hỏi trực tiếp thì không bắt chờ thêm.
  Future<String> _finishSentence(String text) async {
    final isAwaiting = _awaiting != null && DateTime.now().isBefore(_awaitUntil);
    if (isAwaiting) return text;
    for (var k = 0; k < 2 && looksUnfinished(text) && mounted && _loopOn; k++) {
      _heard.value = text;
      final more = await _s.listener.listen(waitSeconds: 2.5, maxSeconds: 6);
      if (more.end != ListenEnd.heard || more.text.trim().isEmpty) break;
      CrashGuard.log('[nghe] ghép câu ngập ngừng: "$text" + "${more.text.trim()}"');
      text = '$text ${more.text.trim()}';
    }
    return text;
  }

  Future<void> _bargeWhile(Future<void> job) async {
    // Không bật micro nghe khẩu lệnh giữa chừng khi ứng dụng đang phát tiếng / trả lời.
    await job.timeout(const Duration(seconds: 90), onTimeout: () {
      CrashGuard.log('[nghe] việc đang làm quá 90 giây → nghe lệnh tiếp');
    });
  }

  DateTime _wokeAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _ignoreHeardUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Lệnh người dùng chủ động BẤM (chip gợi ý) hoặc GÕ (ô tìm kiếm): không phải tiếng micro nên không qua các bộ lọc
  /// dành cho micro (tiếng vọng của loa, chế độ gọi tên, vừa chạm dừng, tạm nghỉ) — trước đây các lệnh này có thể bị
  /// bỏ qua im lặng. Đang đọc / chơi nhạc thì dừng lại để làm lệnh mới.
  Future<void> _onTyped(String text) async {
    _touchedAt = DateTime.now();
    if (_gameOn) {
      final n = normVi(text);
      // ĐANG CHƠI: câu gõ ngắn (một, hai, Sao Hỏa, gợi ý, nhắc lại, dừng…) là câu trả lời cho trò chơi
      final command = isHomePhrase(n) ||
          RegExp(r'\b(ve trai dat|thoi tiet|kham pha|am thanh nasa|am thanh that|do am thanh|he mat troi|ke ve|ke chuyen|lich su)\b').hasMatch(n) ||
          n.split(' ').length > 6;
      if (!command) {
        _feedGame(text);
        return;
      }
      // lệnh khác (nút "Về Trái Đất", hỏi thời tiết…): dừng trò rồi làm lệnh đó
      _gameQuit = true;
      _feedGame('dừng');
      unawaited(_s.listener.cancel());
      _s.speaker.stop();
      for (var i = 0; i < 60 && _gameOn; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
    }
    if (_s.speaker.busy || _sound.playing) {
      _stopSound();
      // chờ câu đang đọc dừng hẳn để vòng kể chuyện / quét cũ thấy cờ dừng trước khi lệnh mới hạ cờ xuống
      for (var i = 0; i < 15 && _s.speaker.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }
    _paused = false;
    if (!_loopOn) _startLoop();
    await _onHeard(text, typed: true);
  }

  /// Chạy một lệnh như lệnh MỚI NHẤT: lệnh đang dở (nếu có) bị thay và im lặng.
  Future<T> _fresh<T>(Future<T> Function() job) {
    final my = ++_cmdGen;
    return runZoned(job, zoneValues: {_kCmdGen: my});
  }

  Future<void> _onHeard(String text, {bool typed = false}) => _fresh(() => _onHeardRun(text, typed: typed));

  Future<void> _onHeardRun(String text, {required bool typed}) async {
    final myGen = _cmdGen;
    if (!typed && DateTime.now().isBefore(_ignoreHeardUntil)) {
      CrashGuard.log('[lệnh] bỏ qua — trong khoảng thời gian vừa ấn dừng: "$text"');
      return;
    }
    if (_s.lang == 'en') {
      // tiếng Anh giọng Việt hay bị nghe sai tên riêng/từ khoá ("venomist" → "vietnamese") → sửa theo từ điển lệnh
      final f = fixEnglishAsr(text);
      if (f != text.toLowerCase().trim()) CrashGuard.log('[sửa chữ en] "$text" → "$f"');
      text = f;
    } else {
      // Sửa lỗi ngữ âm tiếng Việt do ASR nghe nhầm ("phang xi pang" → "Phan Xi Păng", "vịnh hạ nòng" → "Vịnh Hạ Long"...)
      final f = fixVietnameseAsr(text);
      if (f != text.trim()) CrashGuard.log('[sửa chữ vi] "$text" → "$f"');
      text = f;
    }
    if (!typed && _isEcho(text)) {
      CrashGuard.log('[lệnh] bỏ qua — trùng câu app vừa đọc: "$text"');
      return;
    }
    // Khi đang ở chế độ chạm địa hình: bỏ qua các âm thanh nghe nhầm từ loa phát độ cao (vd "trao 13", "cao 13 mét")
    if (!typed && _local != null && (RegExp(r'^(trao|cao)\s*\d+').hasMatch(normVi(text)) || normVi(text) == 'trao' || normVi(text) == 'cao')) {
      CrashGuard.log('[lệnh] bỏ qua tiếng vọng độ cao khi chạm bản đồ: "$text"');
      return;
    }
    _s.speaker.newTurn();
    // CHẾ ĐỘ GỌI TÊN (nơi ồn, nhiều người nói chuyện): chỉ làm theo câu bắt đầu bằng "Lắng ơi" / "Trái Đất ơi" / "Hey Sense"
    final nt = normVi(text);

    // Chuyển đổi bật/tắt chế độ bắt buộc gọi tên bằng giọng nói nếu người dùng yêu cầu
    if (RegExp(r'\b(bat che do goi ten|chi nghe khi goi|wake word on)').hasMatch(nt)) {
      await _s.setWakeMode(true);
      _s.earcon('ok');
      await _s.speaker.say(
          'Đã bật chế độ bắt buộc gọi tên. Từ giờ hãy bắt đầu bằng: Lắng ơi, rồi nói câu hỏi. Muốn tắt, nói: luôn nghe.',
          'Wake word on. Start each request with: Hey Listen. To turn it off, say: always listen.');
      return;
    }
    if (RegExp(r'\b(tat che do goi ten|luon nghe|always listen|wake word off)').hasMatch(nt)) {
      await _s.setWakeMode(false);
      _s.earcon('ok');
      await _s.speaker.say('Đã tắt chế độ gọi tên. Bạn hỏi tự nhiên, mình trả lời ngay.', 'Wake word off. Ask naturally and I will answer.');
      return;
    }

    // Nhận diện lời gọi tên (chỉ ở ĐẦU câu, bao gồm cả các từ máy hay nghe nhầm như "là ngươi", "làng ngươi", "nắng ơi")
    const wakePattern =
        r'^(lang nguoi oi|la nguoi oi|ban lang oi|earth sense|earthsense|trai dat oi|hello earth|hello sense|okay earth|ok earth|hey listen|hey earth|hey sense|hey lang|lang nguoi|la nguoi|lang ne|nang oi|lang oi|e lang|listen|sense)\b\s*';
    final m = RegExp(wakePattern).firstMatch(nt);
    if (m != null) {
      final rest = nt.substring(m.end).trim();
      if (rest.isEmpty) {
        // Người dùng chỉ gọi "Lắng ơi" hoặc "Hey Listen" mà chưa nói lệnh
        _wokeAt = DateTime.now();
        _s.earcon('ok');
        await _s.speaker.say('Mình nghe đây.', 'Yes?');
        return;
      }
      // Bỏ phần gọi tên, giữ lại phần câu hỏi
      final drop = nt.substring(0, m.end).trim().split(' ').length;
      final words = text.trim().split(RegExp(r'\s+'));
      text = words.length > drop ? words.sublist(drop).join(' ') : rest;
    }

    // Nếu người dùng chủ động BẬT chế độ bắt buộc gọi tên trong cài đặt
    if (_s.wakeMode && !typed) {
      final awake = DateTime.now().difference(_wokeAt).inSeconds < 25;
      if (m == null && !awake) {
        CrashGuard.log('[gọi tên] bỏ qua (đang bật chế độ bắt buộc gọi tên): "$text"');
        return;
      }
      _wokeAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    // Bỏ qua tiếng ậm ừ / tiếng ồn vô nghĩa ("a lô", "ừ", "ơi", "alo")
    if (isFillerOnly(text)) {
      CrashGuard.log('[lệnh] bỏ qua tiếng ậm ừ / tiếng ồn: "$text"');
      return;
    }
    _heard.value = text;
    _s.earcon('ok'); // Tiếng chuông báo ngay khi nhận được khẩu lệnh
    final en = _s.lang == 'en';
    _busy = true;
    _storyStop = false;
    // Tiếng "ding" chỉ phát trong khoảng thời gian từ khi vừa nhận khẩu lệnh đến khi bắt đầu trả lời
    final startCap = _s.speaker.caption.value;
    var answered = false;
    var silentMs = 0, sinceDing = 99999;
    late final Timer thinking;
    void checkAnswered() {
      if (answered) return;
      if (_s.speaker.busy || _s.speaker.caption.value != startCap || _sound.playing || _gameOn || _local != null) {
        answered = true;
        thinking.cancel();
      }
    }
    _s.speaker.caption.addListener(checkAnswered);
    thinking = Timer.periodic(const Duration(milliseconds: 150), (_) {
      checkAnswered();
      if (answered) return;
      silentMs += 150;
      sinceDing += 150;
      if (silentMs >= 750 && sinceDing >= 1200) {
        sinceDing = 0;
        _s.audio.earcon('think');
      }
    });
    try {
      Stats.instance.track('voice');
      // LỐI THOÁT LUÔN CÓ: "về màn hình chính" ở bất kỳ đâu; đang ở rê tay / quét lát cắt / lịch sử thì
      // "quay lại", "trở về", "đóng", "ra ngoài", "xong rồi"… là thoát ra (không bị kẹt trong chế độ chạm)
      final nb = normVi(text);
      if (!_paused && isHomePhrase(nb)) {
        await _goHome();
        return;
      }
      if (!_paused && (_local != null || _terrainTouch || _scan != null || _hist != null || _eic != null) && isBackPhrase(nb)) {
        await _run(WCmd(WKind.exitLocal, raw: text));
        return;
      }
      // #14 MÁY HÁT TRÁI ĐẤT: "máy hát trái đất", "nghe ánh đèn ban đêm", "nghe sét"…; đang mở thì dừng / tiếp tục / nhanh hơn…
      if (!_paused && await _eicRoute(nb)) return;
      // câu hỏi kiến thức NASA (hỏi–đáp kiểm chứng, bão Yagi, GISTEMP…): trả lời trước. Khi app vừa hỏi lại người dùng
      // ("muốn nghe hành tinh nào?") chỉ câu dài (câu hỏi thật, ≥ 5 từ) mới vào đây, câu trả lời ngắn để phần đang chờ xử lý
      if (!_paused &&
          (_awaiting == null || !DateTime.now().isBefore(_awaitUntil) || nb.split(' ').length >= 5)) {
        if (await _handleNasaNormalizedQuery(text)) return;
      }
      // hỏi chỗ ĂN / chỗ Ở ở Hà Nội ("quán phở nào ngon ở phố cổ", "khách sạn 4 sao gần Hồ Gươm", "còn nữa", "chi tiết số 2")
      // → trả lời từ dữ liệu assets/data/hanoi_places.json
      // tách phần THỜI TIẾT và phần ĐỊA ĐIỂM (ăn, ở, chơi quanh Hà Nội) để cùng một tên nơi không bị hiểu nhầm
      if (!en && await _routeDomain(text)) return;
      WCmd parse(String x) => en ? parseWorldEn(x) : parseWorld(x);
      var c = parse(text);
      // đang ở màn một hành tinh mà hỏi kiểu "to bằng mấy Trái Đất", "how far is it" → hỏi về hành tinh đó,
      // không bay tới nơi tên "Earth" ở Mỹ
      final pl = _planet;
      if (pl != null &&
          const {WKind.go, WKind.unknown, WKind.weather, WKind.around, WKind.climate}.contains(c.kind) &&
          RegExp(r'\b(bao|may|khong|sao|the nao|nhu nao|co .* khong|how|what|why|is it|does it|can|could|would|compared?|so voi)\b')
              .hasMatch(normVi(text))) {
        CrashGuard.log('[lệnh] "$text" → hỏi về ${pl.vi}');
        await _askPlanet(pl, text);
        return;
      }
      // câu nối tiếp: "còn Đà Nẵng thì sao", "cả thế giới thì sao" → hỏi lại đúng loại câu trước cho nơi mới
      final last = _lastCmd;
      if (last != null && c.followUp && const {WKind.go, WKind.world, WKind.weather, WKind.unknown}.contains(c.kind) &&
          const {WKind.weather, WKind.forecast, WKind.disasters, WKind.climate, WKind.history, WKind.around, WKind.bulletin}
              .contains(last.kind)) {
        final tgt = c.kind == WKind.world
            ? ''
            : c.target.replaceFirst(RegExp(r'^(còn|con|thế còn|and|what about|how about)\s+', caseSensitive: false), '');
        c = WCmd(last.kind,
            target: tgt,
            liveDay: c.liveDay ?? last.liveDay,
            period: c.period ?? last.period,
            aspect: c.kind == WKind.world ? (last.kind == WKind.disasters ? 'world' : last.aspect) : (c.aspect ?? last.aspect),
            month: last.month,
            year: last.year,
            raw: text);
        if (c.kind != WKind.disasters && tgt.isEmpty && const {WKind.world}.contains(parse(text).kind)) {
          c = parse(text); // "cả thế giới thì sao" sau câu thời tiết: chỉ xem cả quả cầu
        }
      }
      // ĐANG CHỜ TRẢ LỜI một câu app vừa hỏi ("bạn muốn bắt đầu với phần nào?", "muốn nghe hành tinh nào?"…)
      final waiting = _awaiting;
      if (waiting != null && DateTime.now().isBefore(_awaitUntil) && !_paused) {
        final routed = _answerAwaiting(waiting, c, text);
        if (routed != null) {
          _awaiting = null;
          c = routed;
        }
      }
      CrashGuard.log('[lệnh] "$text" → $c');
      // nhớ phần đang dùng (để câu chỉ có tên nơi đi đúng phần) và nơi vừa hỏi (để chữa "ý tôi là địa điểm")
      if (const {WKind.weather, WKind.forecast, WKind.hours, WKind.day, WKind.climate, WKind.bulletin, WKind.disasters, WKind.go}
          .contains(c.kind)) {
        _setDomain(Domain.weather);
      } else if (const {WKind.landmarks, WKind.landmark, WKind.around}.contains(c.kind)) {
        _setDomain(Domain.places);
      } else if (c.kind == WKind.help && c.target == 'weather') {
        _setDomain(Domain.weather);
      } else if (c.kind == WKind.help && c.target == 'geo') {
        _setDomain(Domain.places);
      }
      if (c.target.isNotEmpty && !c.target.contains('|') && c.kind != WKind.help && c.kind != WKind.planet) {
        _lastTargetText = c.target;
      }
      if (c.kind == WKind.ignore && c.target.isEmpty) return;
      if (c.kind != WKind.unknown && c.kind != WKind.ignore) _lastCmd = c;
      if (_paused) {
        if (RegExp(r'\b(tiep tuc|nghe lenh|bat dau|bat nghe|nghe di|day di|continue|resume|wake up|start listening)\b')
            .hasMatch(normVi(text))) {
          _paused = false;
          await _s.speaker.say('Mình nghe tiếp đây.', 'Listening again.');
        }
        return;
      }
      await _run(c);
    } catch (e) {
      CrashGuard.log('[lệnh] lỗi: $e');
      _s.earcon('err');
      await _s.speaker.say('Có lỗi, bạn thử nói lại nhé.', 'Something went wrong, please try again.');
    } finally {
      _s.speaker.caption.removeListener(checkAnswered);
      thinking.cancel();
      if (myGen == _cmdGen) _busy = false; // lệnh mới đang chạy thì nó tự hạ cờ khi xong
    }
  }

  // ======================= Dẫn người dùng vào từng phần =======================
  // Sau lời chào / sau khi giới thiệu một phần, app hỏi lại và CHỜ câu trả lời ngắn trong ~30 giây:
  //   'section' — chọn phần (thời tiết / địa lý / vũ trụ, hoặc "phần thứ ba")
  //   'planet'  — chọn hành tinh ("Sao Hỏa", "có", "cái nào cũng được")
  //   'place'   — nơi muốn xem thời tiết ("Đà Nẵng")
  //   'around'  — nơi muốn tả địa lý ("ở đây", "Hồ Hoàn Kiếm")
  String? _awaiting;
  DateTime _awaitUntil = DateTime.fromMillisecondsSinceEpoch(0);

  void _await(String what) {
    _awaiting = what;
    _awaitUntil = DateTime.now().add(const Duration(seconds: 30));
  }

  static final _yesRe = RegExp(r'^(co|co a|duoc|duoc a|u|uh|um|vang|da|da vang|ok|oke|okay|yes|yeah|sure|bat dau|bat dau di|'
      r'tuy ban|ban chon di|gi cung duoc|cai nao cung duoc|sao cung duoc|nao cung duoc|ke di|nghe di|di|any|anything|'
      r'whatever|you choose|start|go ahead|of course|co chu|muon)$');
  static final _hereRe = RegExp(r'\b(o day|cho nay|noi nay|quanh day|quanh toi|cho toi|noi toi dung|cho toi dang dung|'
      r'toi dang dung|here|around me|where i am|my location)\b');

  /// Phần người dùng chọn ('weather' | 'geo' | 'space'), kể cả khi nói lệch / nghe nhầm một chút.
  static String? _sectionIn(String t) {
    if (RegExp(r'\b(thoi tiet|du bao|weather|forecast)\b').hasMatch(t)) return 'weather';
    if (RegExp(r'\b(hanh tinh|hanh trinh|vu tru|mat troi|mat trang|thien van|ngoi sao|vi sao|sao hoa|sao moc|planet|planets|space|'
            r'solar|stars|phan (thu )?(ba|3)|muc (thu )?(ba|3)|thu ba|cai thu ba|so (ba|3)|cuoi cung|third|last)\b|^(3|ba|three)$')
        .hasMatch(t)) {
      return 'space';
    }
    if (RegExp(r'\b(dia ly|dia hinh|dia diem|an uong|vui choi|quanh|xung quanh|vi tri|ban do|noi toi dung|geography|around|surroundings|map|terrain|'
            r'phan (thu )?(hai|2)|muc (thu )?(hai|2)|thu hai|cai thu hai|so (hai|2)|second)\b|^(2|hai|two)$')
        .hasMatch(t)) {
      return 'geo';
    }
    if (RegExp(r'\b(thoi tiet|du bao|mua|nang|nhiet do|the gioi|weather|forecast|rain|phan (thu )?(nhat|mot|1)|muc (thu )?(nhat|mot|1)|'
            r'thu nhat|thu mot|so (mot|1)|dau tien|cai dau|first)\b|^(1|mot|one)$')
        .hasMatch(t)) {
      return 'weather';
    }
    return null;
  }

  /// Câu vừa nghe có phải là câu trả lời cho điều app đang chờ không. null = không, xử lý như lệnh bình thường.
  WCmd? _answerAwaiting(String what, WCmd c, String text) {
    final t = normVi(text);
    final yes = _yesRe.hasMatch(t);
    // lệnh rõ ràng khác (thời tiết Paris, dừng, trợ giúp…) thì làm lệnh đó, không ép thành câu trả lời
    const loose = {WKind.unknown, WKind.ignore, WKind.go, WKind.help, WKind.planets};
    switch (what) {
      case 'section':
        if (!loose.contains(c.kind) && c.kind != WKind.weather) return null;
        final sec = _sectionIn(t);
        // câu thời tiết ĐỦ Ý ("thời tiết chỗ tôi", "hôm nay có mưa không") → làm luôn, không coi là chọn phần;
        // chỉ "thời tiết", "phần thời tiết đi", "phần thứ hai", "thứ hai" mới là chọn phần
        if (c.kind == WKind.weather &&
            (c.target.isNotEmpty ||
                (c.liveDay != null && sec == null) ||
                c.aspect != null ||
                c.period != null ||
                _hereRe.hasMatch(t) ||
                t.split(' ').length > 4)) {
          return null;
        }
        if (sec != null) return WCmd(WKind.help, target: sec, raw: text);
        return null;
      case 'planet':
        final p = planetIn(text);
        // đã hiểu là câu về hành tinh ("Sao Thổ có bao nhiêu mặt trăng", "sự thật về Sao Kim") → giữ nguyên câu hỏi;
        // chỉ nói tên ("Sao Thổ") → kể chuyện
        if (c.kind == WKind.planet) return c;
        if (p != null && c.kind != WKind.weather) return WCmd(WKind.planet, target: p.vi, raw: 'kể chuyện ${p.vi}');
        if (yes && loose.contains(c.kind)) return const WCmd(WKind.planet, target: 'Sao Hỏa', raw: 'kể chuyện Sao Hỏa');
        return null;
      case 'game':
        // vừa mời chọn trò / chơi lại
        if (c.kind == WKind.game && c.target.isNotEmpty) return c;
        if (c.kind == WKind.stop || c.kind == WKind.exitLocal || c.kind == WKind.world) return null;

        // Bắt mọi cách nói chọn trò 1, 2, 3:
        final is1 = RegExp(r'\b(1|mot|so mot|thu nhat|thu mot|do vui|trac nghiem|quiz|one|first)\b').hasMatch(t);
        final is2 = RegExp(r'\b(2|hai|so hai|thu hai|nhi|thu nhi|toi la ai|minh la ai|cau do|do me|doan hanh tinh|riddle|two|second)\b').hasMatch(t) ||
            t.contains('le hoi hai');
        final is3 = RegExp(r'\b(3|ba|so ba|thu ba|nghe tieng|doan tieng|tieng nhac|am thanh|sound|three|third)\b').hasMatch(t) ||
            RegExp(r'^(va|va\.\.\.|va…|va nhe|uc|da|qua)$').hasMatch(t);

        String? g;
        if (is3) {
          g = 'sound';
        } else if (is2) {
          g = 'riddle';
        } else if (is1) {
          g = 'quiz';
        } else if ((yes || RegExp(r'\b(choi lai|choi tiep|lai|van nua|play again|again)\b').hasMatch(t)) && _lastGame != null) {
          g = _lastGame;
        } else if (RegExp(r'\b(nhac lai|noi lai|tro gi|tro nao|la nhung tro nao|repeat)\b').hasMatch(t) || t == 'tro choi' || t == 'game') {
          return const WCmd(WKind.game, raw: '');
        }

        if (g != null) return WCmd(WKind.game, target: g, raw: text);

        // Nếu người dùng nói lệnh thời tiết/địa danh RÕ RÀNG khác (ví dụ "thời tiết Hà Nội", "kể chuyện Sao Hỏa"):
        final hasRealTarget = (c.kind == WKind.weather && c.target.isNotEmpty && !onlyWeatherWords(c.target) && !c.target.contains('chon') && !c.target.contains('tro')) ||
            c.kind == WKind.planet ||
            c.kind == WKind.around ||
            c.kind == WKind.landmark;
        if (hasRealTarget) return null;

        // Còn nếu là câu mơ hồ / nghe sai lúc đang chờ chọn trò:
        // ĐỪNG gọi Gemini nói về thời tiết nơi khác! Hướng dẫn người dùng chọn trò.
        return WCmd(WKind.ignore, target: 'gameHelp', raw: text);
      case 'landmark':
        // vừa kể tên các địa danh → người dùng nói một tên trong đó
        final l = landmarkIn(text);
        if (l != null && (loose.contains(c.kind) || c.kind == WKind.explore)) return WCmd(WKind.landmark, target: l.name, raw: text);
        return null;
      case 'place':
        if (yes && loose.contains(c.kind)) return WCmd(WKind.weather, raw: text); // nơi đang xem
        if (c.kind == WKind.go && c.target.isNotEmpty) return WCmd(WKind.weather, target: c.target, raw: text);
        return null;
      case 'around':
        if ((yes || _hereRe.hasMatch(t)) && (loose.contains(c.kind) || c.kind == WKind.around)) {
          return const WCmd(WKind.around, raw: 'quanh đây có gì');
        }
        if (c.kind == WKind.go && c.target.isNotEmpty) return WCmd(WKind.around, target: c.target, raw: text);
        final hz = findHanoiZone(name: text, matchKeywordOnly: true);
        if (hz != null && loose.contains(c.kind)) return WCmd(WKind.around, target: hz.nameVi, raw: text);
        return null;
    }
    return null;
  }

  /// Giới thiệu NGẮN một phần + ví dụ cụ thể, đưa người dùng vào phần đó, rồi hỏi bước tiếp theo.
  Future<void> _enterSection(String sec) async {
    final s = _s;
    s.ai.reset();
    switch (sec) {
      case 'space':
        _focus = null;
        _pin = null;
        // MÀN HỆ MẶT TRỜI: Mặt Trời và tám hành tinh chạy trên quỹ đạo — nhìn là biết đã sang phần vũ trụ
        setState(() {
          _local = null;
          _planet = null;
          _solar = true;
          _solarHi = null;
          _spaceN.value = 0;
        });
        // điểm danh nhanh: lần lượt sáng từng hành tinh kèm tiếng nhạc riêng của nó (~3 giây)
        for (final i in const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]) {
          if (!mounted || !_solar) return;
          setState(() => _solarHi = i);
          s.audio.planet(i, amp: 0.16);
          await Future<void>.delayed(const Duration(milliseconds: 320));
        }
        if (!mounted || !_solar) return;
        setState(() => _solarHi = 5); // gợi ý: Sao Hỏa
        await s.speaker.say(
            // lời giới thiệu NGẮN (người khiếm thị phải nghe hết mới nói được): 3 việc chính + câu hỏi
            'Phần khám phá vũ trụ. Bạn nói tên một hành tinh để nghe chuyện và hỏi tiếp, ví dụ: Sao Hỏa, hay Sao Thổ có bao nhiêu mặt trăng. '
                'Nói: âm thanh thật của NASA, để nghe bản ghi như bước chân Apollo 11; hoặc nói: trò chơi. '
                'Bạn muốn nghe hành tinh nào?',
            'Space exploration. Say a planet to hear its story and ask questions, for example: Mars, or how many moons does Saturn have. '
                'Say "NASA sounds" for real recordings like the Apollo 11 first step, or say "play a game". '
                'Which planet would you like?');
        _await('planet');
      case 'geo':
        await s.speaker.say(
            // lời giới thiệu NGẮN: 3 việc + cách thoát + câu hỏi
            'Phần địa lý quanh bạn. Nói: rê tay khám phá, để rê ngón tay trên bản đồ địa hình thật, nghe tiếng sáo theo độ cao và rung theo độ dốc. '
                'Nói: quét mặt cắt địa hình, để nghe dáng núi đồi; hoặc hỏi: quanh đây có gì. Muốn thoát thì nói: quay lại. '
                'Bạn muốn làm gì?',
            'Geography around you. Say "touch explore" to run your finger over a real terrain map: a flute follows height, vibration follows slope. '
                'Say "scan the terrain" to hear the shape of the land, or ask "what is around here". Say "go back" to leave. '
                'What would you like?');
        _await('around');
      default: // weather
        if (_local == null && _planet == null) {
          _focus = null;
          _pin = null;
          unawaited(_flyTo(_cam.copyWith(zoom: 1.0)));
        } else {
          _leaveModes();
        }
        await s.speaker.say(
            'Phần thời tiết toàn cầu và 45 năm lịch sử khí hậu NASA. Bạn nói tên bất kỳ nơi nào, mình sẽ bay tới đó và diễn tấu thời tiết qua tiếng đàn bầu và đàn t\'rưng. '
                'Bạn có thể hỏi dự báo: chiều nay có mưa không, mai đi chơi có hợp không, có bão không; '
                'nói: nghe nhạc, để nghe đàn bầu diễn tấu nhiệt độ; '
                'hoặc nói: lịch sử thời tiết Huế 3 năm qua, bão Yagi, hay chuỗi biến đổi khí hậu 146 năm để nghe và xem lại diễn biến thiên tai từ NASA POWER. '
                'Bạn muốn xem thời tiết ở đâu?',
            'Global weather and 45-year NASA climate history. Say any place and I will fly there, sonifying weather through Dan Bau and Dan T\'rung. '
                'Ask: will it rain this afternoon, is tomorrow good for an outing, any storms; '
                'say "play music" to hear temperature played on the dan bau; '
                'or say "weather history of Hue over 3 years", Typhoon Yagi, or 146-year climate warming to replay NASA POWER events. '
                'Where would you like to explore?');
        _await('place');
    }
  }

  // ======================= Thực hiện lệnh =======================
  Future<void> _run(WCmd c) async {
    final s = _s;
    NetCache.reset();
    switch (c.kind) {
      case WKind.stop:
        _stopSound();
      case WKind.pause:
        _paused = true;
        await s.speaker.say('Mình tạm nghỉ. Khi cần, nói: tiếp tục.', 'Pausing. Say "continue" when you need me.');
      case WKind.help:
        // hỏi về một phần → giới thiệu ngắn + ví dụ, đưa vào phần đó; hỏi chung → kể ba phần + ví dụ rồi chờ chọn
        if (c.target.isNotEmpty) {
          await _enterSection(c.target);
        } else {
          final h = helpFor('');
          await s.speaker.say(h.$1, h.$2);
          _await('section');
        }
      case WKind.settings:
        await s.speaker.say('Mở cài đặt trên màn hình.', 'Opening settings on screen.');
        if (mounted) unawaited(showSettings(context));
      case WKind.repeat:
        await s.speaker.repeatLast();
      case WKind.louder:
        await s.setVolume(math.min(1.0, s.audio.volume + 0.15));
      case WKind.quieter:
        await s.setVolume(math.max(0.1, s.audio.volume - 0.15));
      case WKind.faster:
        await s.setRate(math.min(0.9, s.speaker.rate + 0.1));
        await s.speaker.say('Đọc nhanh hơn như thế này.', 'Faster, like this.');
      case WKind.slower:
        await s.setRate(math.max(0.2, s.speaker.rate - 0.1));
        await s.speaker.say('Đọc chậm hơn như thế này.', 'Slower, like this.');
      case WKind.world:
        _leaveModes();
        _focus = null;
        _pin = null;
        s.earcon('tick');
        await _flyTo(_cam.copyWith(zoom: 1.0));
        await s.speaker.say('Cả quả địa cầu.', 'The whole globe.');
      case WKind.zoomOut:
        if (_local != null || _planet != null || _solar || _hist != null || _scan != null || _eic != null) {
          _leaveModes();
          await s.speaker.say('Về quả địa cầu.', 'Back to the globe.');
          return;
        }
        s.earcon('tick');
        final z = math.max(1.0, _cam.zoom / 3);
        if (z <= 1.0) _pin = null;
        await _flyTo(_cam.copyWith(zoom: z), ms: 900);
        await _sayWhere();
      case WKind.zoomIn:
        s.earcon('tick');
        if (_focus == null && _cam.zoom < 1.6) {
          // đang xem cả quả cầu (đang tự quay, chỗ giữa là ngẫu nhiên) → phóng vào nơi của bạn, không phải nơi tình cờ ở giữa
          final h = _here();
          await _flyTo(GlobeCamera(h.lat, h.lon, 3), ms: 900);
        } else {
          await _flyTo(_cam.copyWith(zoom: math.min(40, _cam.zoom * 3)), ms: 900);
        }
        await _readAt(_cam.lat, _cam.lon);
      case WKind.where:
        await _sayWhere();
      case WKind.go:
        final loc = await _resolve(c.target, strict: c.bare) ?? await _guess(c.raw);
        if (loc == null && c.bare) return _unknown(c.raw); // có thể chỉ là tiếng ồn
        if (loc == null) return _notFound(c.target);
        // chỉ nói tên nơi → CHỈ ĐẶT VỊ TRÍ (bay tới, đọc tên); kèm "thời tiết" / "khám phá" mới bật chức năng đó
        await _goTo(loc);
        unawaited(s.weather.get(loc.lat, loc.lon, lang: s.lang).then<void>((_) {}, onError: (Object _) {})); // tải sẵn
        final hint = _goHints++ < 2;
        await s.speaker.say(
            '${loc.vi}.${hint ? ' Bạn hỏi tiếp được: thời tiết, hoặc quanh đây có gì chơi.' : ''}',
            '${loc.en}.${hint ? ' You can ask: weather, or what is around.' : ''}');
      case WKind.weather when c.aspect == 'compare':
        await _compare(c);
      case WKind.weather:
      case WKind.forecast:
      case WKind.hours:
      case WKind.music:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target);
        if (c.kind == WKind.weather && c.liveDay == null && c.aspect == null) {
          return _goAndRead(loc, isLocal: _isLocalPlace(loc, c.raw));
        }
        await _goTo(loc);
        final w = await _weatherOf(loc);
        if (w == null) return;
        await _readWeatherKind(c, loc, w);
      case WKind.climate:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _goTo(loc);
        await _climate(loc, c.month, c.year);
      case WKind.day:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _goTo(loc);
        await _day(loc, c.date!);
      case WKind.setHome:
        final p = parseCommand(c.target).place;
        if (p == null) {
          await s.speaker.say('Hiện mình chỉ đặt được nơi của bạn ở Việt Nam. Ví dụ: tôi ở Huế.',
              'For now your home place must be in Viet Nam. For example: I live in Hue.');
          return;
        }
        await s.setHomePlace(p.name);
        await s.speaker.say('Đã đặt nơi của bạn là ${p.name}.', 'Your place is now ${p.name}.');
      case WKind.bulletin:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _bulletin(loc);
      case WKind.disasters:
        await _disasters(c);
      case WKind.around:
      case WKind.explore:
        final loc = c.aspect == 'gps'
            ? await _gpsLoc()
            : (c.target.isEmpty ? (c.kind == WKind.explore ? await _exploreHere(c.raw) : await _hereFor(c.raw)) : await _resolve(c.target));
        if (loc == null) {
          if (c.aspect != 'gps') await _notFound(c.target, raw: c.raw);
          return;
        }
        final rawNorm = normVi(c.raw);
        final asksSurroundings = RegExp(
                r'\b(quanh|xung quanh|gan do|co gi|mo ta|kham pha|canh quan|dia diem|an uong|an gi|vui choi|choi gi|du lich|tham quan)\b')
            .hasMatch(rawNorm);
        if (c.aspect == 'gps' && !asksSurroundings && c.kind != WKind.explore) {
          // Người dùng chỉ hỏi vị trí ("tôi đang ở đâu", "vị trí hiện tại"): _gpsLoc() đã đọc rõ
          return;
        }
        await _around(loc, explore: c.kind == WKind.explore, raw: c.raw);
      case WKind.terrain:
        await _terrainCmd(c);
      case WKind.exitLocal:
        final wasTouch = _terrainTouch;
        final wasLocal = _local != null;
        _terrainOff();
        if (wasTouch && _local == null && _planet == null && !_solar && _hist == null && _scan == null && _eic == null) {
          if (mounted) setState(() {});
          await s.speaker.say('Đã thoát. Kéo tay lại xoay quả cầu như cũ.', 'Done. Drag to rotate the globe again.');
          return;
        }
        _leaveModes();
        s.speaker.resetQuick();
        await s.speaker.say(
            wasLocal ? 'Đã thoát rê tay, về quả địa cầu. Kéo tay để xoay quả cầu như cũ.' : 'Về quả địa cầu.',
            wasLocal ? 'Left the touch map. Back to the globe.' : 'Back to the globe.');
      case WKind.history:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _goTo(loc);
        await _history(loc);
      case WKind.nasaSound:
        if (c.aspect == 'game') {
          await _nasaSoundGame(c.target);
        } else {
          await _nasaSound(c.target);
        }
      case WKind.weatherHistory:
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : (await _resolve(c.target) ?? await _guess(c.raw));
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _goTo(loc);
        await _weatherHistory(loc, c);
      case WKind.planets:
        await _enterSection('space');
      case WKind.planet:
        if (c.aspect == 'fact') {
          await _funFact(c.target);
          return;
        }
        final p = planetIn(c.target);
        if (p == null) return;
        if (_planet != p) setState(() => _planet = p);
        if (c.aspect == 'sound') {
          s.audio.planet(p.sound, amp: 0.35);
          await s.speaker.say('Đây là âm thanh đặc trưng của ${p.vi}.', 'This is the sound of ${planetNamesEn[p.sound] ?? p.en}.');
          return;
        }
        final rawNorm = normVi(c.raw).trim();
        final isShortNameOnly = rawNorm == normVi(p.vi) || rawNorm == normVi(p.en) || rawNorm == 'mat trang' || rawNorm == 'the moon';
        final wantsStory = isShortNameOnly ||
            RegExp(r'\b(ke chuyen|nghe chuyen|ke ve|ke cho|tap truyen|truyen ve|gioi thieu|tell (me )?a story|story)\b')
                .hasMatch(rawNorm);

        // Nếu có số liệu NASA khớp câu hỏi thì trả lời ngay
        final localAns = planetAnswer(p.sound, p.vi, planetNamesEn[p.sound] ?? p.en, c.raw, en: s.lang == 'en');
        if (localAns != null) {
          if (_planet != p) setState(() => _planet = p);
          await _askPlanet(p, c.raw);
          return;
        }

        // Nếu là câu hỏi hoặc đàm thoại tự nhiên, giao cho AI phân tích cả câu và trả lời thay vì tự ý đọc 5 tập truyện
        if (!wantsStory) {
          if (_planet != p) setState(() => _planet = p);
          await _askPlanet(p, c.raw);
          return;
        }
        await _story(p);
      case WKind.game:
        await _playGame(c.target);
      case WKind.landmark:
        await _landmark(c);
      case WKind.landmarks:
        await _landmarkList(c.raw);
      case WKind.apod:
        await _apod();
      case WKind.ignore:
        if (c.target == 'gameHelp') {
          _await('game');
          await s.speaker.say(
              'Bạn chọn trò nào: một đố vui, hai tôi là ai, hay ba nghe tiếng đoán hành tinh? Hoặc nói: thoát, để về quả địa cầu.',
              'Which game: one quiz, two who am I, or three guess by sound? Or say exit.');
        }
        if (c.target == 'who') {
          await s.speaker.say(
              'Mình là Lắng, quả địa cầu biết nói. Mình kể thời tiết khắp thế giới, địa lý quanh bạn, và chuyện các hành tinh. '
                  'Bạn cứ hỏi tự nhiên, ví dụ: thời tiết Hà Nội, quanh đây có gì, hay kể chuyện Sao Hỏa.',
              'I am Lang, a talking globe: weather anywhere, the land around you, and stories of the planets. '
                  'Just ask, for example: weather in Hanoi, or tell me about Mars.');
        }
        if (c.target == 'time' || c.target == 'date') {
          final n = DateTime.now();
          const thu = ['thứ hai', 'thứ ba', 'thứ tư', 'thứ năm', 'thứ sáu', 'thứ bảy', 'chủ nhật'];
          const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          final mm = n.minute == 0 ? '' : ' ${n.minute} phút';
          await s.speaker.say(
              c.target == 'time'
                  ? 'Bây giờ là ${n.hour} giờ$mm.'
                  : 'Hôm nay là ${thu[n.weekday - 1]}, ngày ${n.day} tháng ${n.month} năm ${n.year}.',
              c.target == 'time'
                  ? 'It is ${n.hour}:${n.minute.toString().padLeft(2, '0')}.'
                  : 'Today is ${days[n.weekday - 1]}, ${n.day}/${n.month}/${n.year}.');
        }
        if (c.target == 'thanks') {
          await s.speaker.say('Không có gì. Bạn cần gì cứ nói nhé.', 'You are welcome. Just ask any time.');
        }
      case WKind.language:
        if (c.target == 'en' && !await VoiceListener.modelReady('en')) {
          // lần đầu dùng tiếng Anh: tải bộ nghe tiếng Anh (~130 MB) trong lúc vẫn nghe tiếng Việt
          await s.speaker.say(
              'Lần đầu dùng tiếng Anh, mình cần tải bộ nghe tiếng Anh, khoảng 130 mê ga bai, cần mạng, mất một đến vài phút. '
                  'Trong lúc tải, bạn vẫn hỏi bằng tiếng Việt được.',
              'Downloading the English recogniser, about 130 megabytes.');
          var said = 0;
          s.listener.onDownload = (p) {
            if (p >= said + 25 && p < 100) {
              said = p - p % 25;
              if (!s.speaker.busy) unawaited(s.speaker.say('Đã tải $said phần trăm bộ nghe tiếng Anh.', '', false));
            }
          };
          final ok = await s.listener.prepareLang('en');
          s.listener.onDownload = null;
          if (!ok) {
            s.earcon('err');
            await s.speaker.say(
                'Chưa tải được bộ nghe tiếng Anh, có thể do mạng. Mình vẫn dùng tiếng Việt. Lát nữa bạn nói lại: chuyển sang tiếng Anh.',
                'Could not download the English recogniser.');
            return;
          }
        }
        await s.setLang(c.target);
        await s.speaker.say(
            'Đã chuyển sang tiếng Việt. Muốn đổi sang tiếng Anh, nói: chuyển sang tiếng Anh.',
            'Switched to English. Say "Vietnamese" to switch back.');
      case WKind.unknown:
        await _unknown(c.raw);
    }
  }

  /// Thoát bản đồ chạm / màn vũ trụ, về quả địa cầu.
  void _leaveModes() {
    _storyStop = true;
    _closeHistory();
    _closeScan();
    _closeEic();
    _s.ai.reset();
    if (_local != null || _planet != null || _solar) {
      setState(() {
        _local = null;
        _planet = null;
        _solar = false;
        _solarHi = null;
      });
    }
    _s.audio.voiceMute();
  }

  // ======================= Địa hình =======================
  bool _terrainTouch = false; // chế độ chạm địa hình trên quả cầu
  bool _fingerTerrain = false; // ngón đang rê là để nghe độ cao (không xoay)
  int _tBand = -99;
  String _tForm = '';
  DateTime _tWave = DateTime.fromMillisecondsSinceEpoch(0);
  (double, double)? _tAt; // (vĩ độ, kinh độ) ngón tay vừa rê qua

  void _terrainOff() {
    _terrainTouch = false;
    _fingerTerrain = false;
    _tAt = null;
    _s.audio.voiceMute();
  }

  Future<void> _terrainCmd(WCmd c) async {
    final s = _s;
    if (c.aspect != 'touch' && c.aspect != 'off' && (_planet != null || _solar || _local != null)) _leaveModes();
    switch (c.aspect) {
      case 'off':
        final wasLocal = _local != null;
        _terrainOff();
        if (wasLocal) _leaveModes();
        if (mounted) setState(() {});
        await s.speaker.say(wasLocal ? 'Đã thoát rê tay, về quả địa cầu.' : 'Đã thoát. Kéo tay lại xoay quả cầu như cũ.',
            wasLocal ? 'Left the touch map.' : 'Done.');
      case 'touch':
        // "chạm địa hình" (chế độ cũ trên quả cầu) đã gộp vào RÊ TAY KHÁM PHÁ: mở bản đồ địa hình thật quanh nơi đang xem
        _terrainOff();
        final loc = c.target.isNotEmpty ? await _resolve(c.target) : await _exploreHere(c.raw);
        if (loc == null) return _notFound(c.target, raw: c.raw);
        await _around(loc, explore: true, raw: c.raw);
      case 'overview':
        final world = c.target == 'world';
        _pin = null;
        unawaited(_flyTo(world ? _cam.copyWith(zoom: 1.0) : const GlobeCamera(16, 106, 2.4)));
        final o = world ? terrainOverviewWorld : terrainOverviewVn;
        await s.speaker.say(o.$1, o.$2);
      case 'spine':
        await _terrainPath(
          [for (final p in vnSpine) (p.$3, p.$4)],
          names: [for (final p in vnSpine) (p.$1, p.$2, p.$3, p.$4)],
          titleVi: 'Đi dọc Việt Nam, từ Lũng Cú ở cực bắc đến mũi Cà Mau ở cực nam',
          titleEn: 'Along Viet Nam, from Lung Cu in the far north to Ca Mau Cape in the far south',
          fromVi: 'Lũng Cú',
          fromEn: 'Lung Cu',
        );
      case 'path':
        final parts = c.target.split('|');
        final a = await _resolve(parts.first), b = parts.length > 1 ? await _resolve(parts[1]) : null;
        if (a == null) return _notFound(parts.first);
        if (b == null) return _notFound(parts.length > 1 ? parts[1] : '');
        await _terrainPath([(a.lat, a.lon), (b.lat, b.lon)],
            names: [(a.vi, a.en, a.lat, a.lon), (b.vi, b.en, b.lat, b.lon)],
            titleVi: 'Lát cắt địa hình từ ${a.vi} đến ${b.vi}',
            titleEn: 'Terrain from ${a.en} to ${b.en}',
            fromVi: a.vi,
            fromEn: a.en);
      case 'scan':
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : await _resolve(c.target);
        if (loc == null) return _notFound(c.target);
        await _terrainScan(loc);
      case 'profile':
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : await _resolve(c.target);
        if (loc == null) return _notFound(c.target);
        final ns = c.period == 'ns';
        // nửa chiều dài theo độ phóng của nơi đó: thành phố ~60 km, một nước ~400 km
        final half = (2400 / math.max(1.0, loc.zoom)).clamp(25.0, 900.0);
        final a = offsetKm(loc.lat, loc.lon, half, ns ? 0 : 270), b = offsetKm(loc.lat, loc.lon, half, ns ? 180 : 90);
        await _terrainPath([a, b],
            names: [(loc.vi, loc.en, loc.lat, loc.lon)],
            titleVi: 'Lát cắt địa hình qua ${loc.vi}, ${ns ? 'từ bắc xuống nam' : 'từ tây sang đông'}',
            titleEn: 'Terrain across ${loc.en}, ${ns ? 'north to south' : 'west to east'}',
            fromVi: ns ? 'đầu phía bắc' : 'đầu phía tây',
            fromEn: ns ? 'northern end' : 'western end');
      case 'peak':
        // target: 'world' | 'vn' | '' | tên tiếng Anh của một đỉnh (núi cao nhất châu Phi → Kilimanjaro…)
        final world = c.target == 'world';
        final want = world ? 'Mount Everest' : (c.target == 'vn' || c.target.isEmpty ? 'Fansipan' : c.target);
        final p = peaks.firstWhere((x) => x.en == want, orElse: () => peaks.first);
        await _terrainPeak(p,
            extraVi: world
                ? ' Ở Việt Nam, cao nhất là đỉnh Phan Xi Păng 3.143 mét.'
                : ' Còn cao nhất thế giới là núi Everest, 8.849 mét, trên dãy Himalaya.',
            extraEn: world ? ' In Viet Nam the highest is Fansipan, 3,143 metres.' : ' The highest on Earth is Mount Everest, 8,849 metres.');
      case 'deep':
        _focus = _Loc('rãnh Mariana', 'Mariana Trench', deepest.lat, deepest.lon, 6);
        _pin = GlobePin(deepest.lon, deepest.lat, s.lang == 'en' ? 'Challenger Deep' : 'Vực Challenger');
        await _flyTo(GlobeCamera(deepest.lat, deepest.lon, 6));
        await _terrainTone([-200, -2000, -5000, -8000, -10900]);
        await s.speaker.say(
            'Nơi sâu nhất là ${deepest.vi}, sâu khoảng ${groupNum(-deepest.h)} mét dưới mặt biển, giữa Thái Bình Dương, phía đông Philippines. '
                'Nếu đặt núi Everest xuống đó, đỉnh núi vẫn còn cách mặt nước hơn 2 nghìn mét.',
            'The deepest place is ${deepest.en}, about ${groupNum(-deepest.h, en: true)} metres below sea level, in the Pacific east of the Philippines. '
                'If Mount Everest stood there, its top would still be over 2,000 metres under water.');
      case 'height':
        final pk = peakIn(c.target);
        if (pk != null) {
          await _terrainPeak(pk);
          return;
        }
        final at = _tAt;
        final loc = c.target.isEmpty
            ? (_terrainTouch && at != null ? _Loc('chỗ ngón tay vừa chạm', 'where your finger was', at.$1, at.$2, _cam.zoom) : _here())
            : await _resolve(c.target);
        if (loc == null) return _notFound(c.target);
        await _goTo(loc);
        final e = await _terrain.precise(loc.lat, loc.lon);
        if (e.isNaN) return _terrainNoData();
        await _terrainTone([e]);
        final a = heightAnswer(loc.vi, loc.en, loc.lat, loc.lon, e);
        await s.speaker.say(a.$1, a.$2);
      default: // describe
        final loc = c.target.isEmpty ? await _hereFor(c.raw) : await _resolve(c.target);
        if (loc == null) return _notFound(c.target);
        await _goTo(loc);
        final km = loc.zoom >= 18 ? 8.0 : (loc.zoom >= 9 ? 20.0 : 60.0);
        final z = km < 10 ? 11 : (km < 30 ? 10 : 8);
        final ce = await _terrain.precise(loc.lat, loc.lon, z: z);
        if (ce.isNaN) return _terrainNoData();
        final ring = await _terrain.ring(loc.lat, loc.lon, km, z: z);
        // nghe một vòng: bắc → đông → nam → tây (trái / phải theo hướng)
        await _terrainTone([ce, ...ring], pans: [0.0, for (var i = 0; i < 8; i++) math.sin(i * math.pi / 4) * 0.9]);
        final a = reliefAnswer(loc.vi, loc.en, loc.lat, loc.lon, ce, ring, km);
        await s.speaker.say(a.$1, a.$2);
    }
  }

  // ---------------- #14 MÁY HÁT TRÁI ĐẤT ----------------
  void _closeEic() {
    final p = _eic;
    if (p == null) return;
    _eic = null;
    p.stop();
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => p.dispose());
  }

  String _eicListVi(EicLibrary lib) => [for (final s in lib.sets) s.titleVi].join('; ');
  String _eicListEn(EicLibrary lib) => [for (final s in lib.sets) s.titleEn].join('; ');

  /// Trả về true nếu câu [nb] (đã bỏ dấu) là lệnh của máy hát.
  Future<bool> _eicRoute(String nb) async {
    final lib = _eicLib ??= await EicLibrary.load();
    if (lib.sets.isEmpty) return false;
    final s = _s;
    final p = _eic;
    if (p == null) {
      final c = parseEicOpen(nb, lib);
      if (c == null) return false;
      if (c.act == EicAct.list) {
        await s.speaker.say('Máy hát Trái Đất có ${lib.sets.length} hình của NASA: ${_eicListVi(lib)}. Nói "nghe" kèm tên hình, ví dụ: nghe sét.',
            'The Earth Jukebox has ${lib.sets.length} NASA visualizations: ${_eicListEn(lib)}. Say "listen to" and a name, for example: listen to lightning.');
        return true;
      }
      await _eicOpen(lib, c.target, first: true);
      return true;
    }
    final c = parseEicInside(nb, lib);
    if (c == null) {
      // lệnh khác (thời tiết, hành tinh…): rời máy hát rồi làm lệnh đó
      _closeEic();
      return false;
    }
    switch (c.act) {
      case EicAct.pause:
        p.pause();
        await s.speaker.say('Tạm dừng. Nói "tiếp tục" để nghe tiếp, hoặc rê tay lên hình.', 'Paused. Say "continue", or slide a finger over the picture.');
      case EicAct.resume:
        await p.resume();
      case EicAct.faster:
      case EicAct.slower:
        final v = p.changeSpeed(c.act == EicAct.faster ? 1 : -1);
        if (!p.running) await s.speaker.say('Tốc độ ${v + 1} trên 5.', 'Speed ${v + 1} of 5.');
      case EicAct.replay:
        await p.run(intro: false);
      case EicAct.why:
        p.pause();
        await s.speaker.say(p.ds.whyVi, p.ds.whyEn);
      case EicAct.describe:
        p.pause();
        await s.speaker.say('${p.ds.describeVi} Đang ở ${p.frame.labelVi}. ${p.frameVi(p.frame)}',
            '${p.ds.describeEn} Now at ${p.frame.labelEn}. ${p.frameEn(p.frame)}');
      case EicAct.legend:
        p.pause();
        await s.speaker.say(p.ds.legendVi, p.ds.legendEn);
      case EicAct.source:
        p.pause();
        await s.speaker.say('Nguồn: ${p.ds.source}${p.ds.svsId.isEmpty ? '' : ', mã SVS ${p.ds.svsId}'}.',
            'Source: ${p.ds.source}${p.ds.svsId.isEmpty ? '' : ', SVS ${p.ds.svsId}'}.');
      case EicAct.next:
      case EicAct.prev:
        await p.jump(p.index + (c.act == EicAct.next ? 1 : -1));
      case EicAct.year:
        final i = p.findFrame(nb);
        if (i == null) {
          await s.speaker.say('Hình này có từ ${p.ds.frames.first.labelVi} đến ${p.ds.frames.last.labelVi}.',
              'This one runs from ${p.ds.frames.first.labelEn} to ${p.ds.frames.last.labelEn}.');
        } else {
          await p.jump(i);
        }
      case EicAct.list:
        p.pause();
        await s.speaker.say('Các hình: ${_eicListVi(lib)}.', 'Visualizations: ${_eicListEn(lib)}.');
      case EicAct.open:
        if (c.target == null || c.target == p.ds.id) {
          await p.run(intro: false);
        } else {
          await _eicOpen(lib, c.target);
        }
    }
    return true;
  }

  Future<void> _eicOpen(EicLibrary lib, String? id, {bool first = false}) async {
    final s = _s;
    final ds = (id == null ? null : lib.byId(id)) ?? lib.sets.first;
    _leaveModes();
    _storyStop = false;
    final p = EicPlayer(audio: s.audio, say: (vi, en) => s.speaker.say(vi, en), ds: ds);
    setState(() => _eic = p);
    Stats.instance.track('eic');
    s.earcon('tick');
    if (first && id == null && lib.sets.length > 1) {
      await s.speaker.say(
          'Máy hát Trái Đất: nghe các hình ảnh dữ liệu của NASA bằng âm thanh. Có ${lib.sets.length} hình: ${_eicListVi(lib)}. '
              'Bắt đầu với ${ds.titleVi}. Lúc nào cũng có thể nói: dừng, tiếp tục, nhanh hơn, chậm lại, giải thích, hoặc tên hình khác.',
          'Earth Jukebox: NASA data visualizations turned into sound. ${lib.sets.length} to choose from: ${_eicListEn(lib)}. '
              'Starting with ${ds.titleEn}. Say stop, continue, faster, slower, explain, or another name at any time.');
      if (_eic != p) return;
    }
    await p.run();
  }

  void _closeScan() {
    final sc = _scan;
    if (sc == null) return;
    _scan = null;
    sc.stop();
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => sc.dispose());
  }

  /// F3 — Quét mặt cắt địa hình: lấy bản đồ độ cao quanh [loc], quét Bắc → Nam rồi Tây → Đông (mỗi lượt ≤ 8 giây),
  /// vẽ mặt cắt của lát đang quét, tiếng sáo theo độ cao trung bình của lát.
  Future<void> _terrainScan(_Loc loc) async {
    final s = _s;
    _closeScan();
    _closeEic();
    _closeHistory();
    _storyStop = false;
    await _goTo(loc);
    s.earcon('tick');
    // cỡ vùng theo độ phóng của nơi đó: thành phố ~50 km, tỉnh ~150 km, nước ~800 km
    final half = (1600 / math.max(1.0, loc.zoom)).clamp(15.0, 600.0);
    final n = offsetKm(loc.lat, loc.lon, half, 0), so = offsetKm(loc.lat, loc.lon, half, 180);
    final w = offsetKm(loc.lat, loc.lon, half, 270), e = offsetKm(loc.lat, loc.lon, half, 90);
    const rows = 26, cols = 26;
    final z = half < 30 ? 11 : (half < 80 ? 10 : (half < 250 ? 8 : 6));
    final g = await _terrain.grid(n.$1, so.$1, w.$2, e.$2, rows, cols, z: z);
    if (!mounted || _storyStop) return;
    final grid = ElevGrid(g, n.$1, so.$1, w.$2, e.$2);
    if (sliceMean([for (final r in g) ...r]).isNaN) return _terrainNoData();
    final p = TerrainScanPlayer(
      audio: s.audio,
      say: (vi, en) => s.speaker.say(vi, en),
      grid: grid,
      placeVi: loc.vi,
      placeEn: loc.en,
      widthKm: 2 * half,
      heightKm: 2 * half,
    );
    setState(() => _scan = p);
    Stats.instance.track('scan');
    await p.run();
    if (_scan == p && p.phase == 'done') {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (_scan == p) _closeScan();
    }
  }

  Future<void> _terrainNoData() async {
    _s.earcon('err');
    await _s.speaker.say('Chưa có số liệu độ cao ở đây.', 'No elevation data here yet.');
  }

  /// Bay tới một đỉnh núi, nghe tiếng đàn đi lên tới đỉnh, rồi đọc độ cao chính thức.
  Future<void> _terrainPeak(Peak p, {String extraVi = '', String extraEn = ''}) async {
    final s = _s;
    _focus = _Loc(p.vi, p.en, p.lat, p.lon, 14);
    _pin = GlobePin(p.lon, p.lat, s.lang == 'en' ? p.en : p.vi);
    Haptics.medium();
    await _flyTo(GlobeCamera(p.lat, p.lon, 14));
    await _terrainTone([for (var k = 0; k <= 6; k++) p.h * k / 6]);
    final a = heightAnswer(p.vi, p.en, p.lat, p.lon, p.h.toDouble(), peak: p);
    await s.speaker.say('${a.$1}$extraVi', '${a.$2}$extraEn');
  }

  /// Chuỗi nốt đàn bầu theo độ cao (biển: tiếng sóng). [pans] = vị trí trái / phải từng nốt.
  Future<void> _terrainTone(List<double> elev, {List<double>? pans, int stepMs = 260}) async {
    if (elev.isEmpty) return;
    final a = _s.audio;
    double f(double e) => toScale(0.06 + 0.9 * elevTone(e));
    final ph = await a.phraseStart(f(elev.first), pan: pans?.first ?? 0, amp: 0.2);
    for (var i = 0; i < elev.length; i++) {
      if (_storyStop) break;
      final pan = pans != null && i < pans.length ? pans[i] : 0.0;
      if (elev[i] < -1) a.song(0.12 + 0.12 * math.min(1.0, -elev[i] / 8000), pan);
      ph?.to(f(elev[i]), pan: pan, stepMs: stepMs);
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
    ph?.end();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Lát cắt địa hình dọc đường gấp khúc: ghim chạy dọc đường, tiếng đàn lên xuống theo độ cao, rồi đọc tóm tắt.
  Future<void> _terrainPath(List<(double, double)> pts,
      {required List<(String, String, double, double)> names,
      required String titleVi,
      required String titleEn,
      required String fromVi,
      required String fromEn}) async {
    final s = _s;
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += distKm(pts[i - 1].$1, pts[i - 1].$2, pts[i].$1, pts[i].$2);
    }
    // khung nhìn bao cả đường
    var la0 = 90.0, la1 = -90.0;
    for (final p in pts) {
      la0 = math.min(la0, p.$1);
      la1 = math.max(la1, p.$1);
    }
    final mid = samplePath(pts, 3)[1];
    final ext = math.max(len / 111, 0.3);
    unawaited(_flyTo(GlobeCamera(mid.$1, mid.$2, (110 / ext).clamp(1.2, 30.0))));
    const n = 40;
    final z = len < 60 ? 11 : (len < 250 ? 10 : (len < 800 ? 8 : 7));
    final elev = await _terrain.line(pts, n, z: z);
    final along = samplePath(pts, n);
    // ghim chạy dọc đường cùng tiếng đàn
    final a = s.audio;
    double f(double e) => toScale(0.06 + 0.9 * elevTone(e));
    final ph = await a.phraseStart(f(elev.first.isNaN ? 0 : elev.first), pan: -0.8, amp: 0.2);
    for (var i = 0; i < n; i++) {
      if (_storyStop || !mounted) break;
      final e = elev[i].isNaN ? 0.0 : elev[i];
      final pan = -0.8 + 1.6 * i / (n - 1);
      setState(() => _pin = GlobePin(along[i].$2, along[i].$1, ''));
      if (e < -1 && i % 3 == 0) a.song(0.14, pan);
      if (i > 0 && bandOf(e) != bandOf(elev[i - 1].isNaN ? 0 : elev[i - 1])) Haptics.light();
      ph?.to(f(e), pan: pan, stepMs: 200);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    ph?.end();
    if (_storyStop || !mounted) return;
    // nơi có tên gần đỉnh cao nhất
    var hi = 0;
    for (var i = 0; i < n; i++) {
      if (!elev[i].isNaN && (elev[hi].isNaN || elev[i] > elev[hi])) hi = i;
    }
    String nearVi = '', nearEn = '';
    if (names.length > 1) {
      var best = double.infinity;
      for (final nm in names) {
        final d = distKm(along[hi].$1, along[hi].$2, nm.$3, nm.$4);
        if (d < best && d < 120) {
          best = d;
          nearVi = ' Chỗ cao nhất gần ${nm.$1}.';
          nearEn = ' The highest part is near ${nm.$2}.';
        }
      }
    }
    final sum = profileSummary(elev, len, fromVi: fromVi, fromEn: fromEn);
    _pin = null;
    if (mounted) setState(() {});
    await s.speaker.say('${sum.$1}$nearVi', '${sum.$2}$nearEn');
  }

  /// Chạm địa hình: ngón tay đang ở [o] — tiếng đàn theo độ cao, sóng nếu là biển, rung khi đổi dải độ cao.
  void _terrainFinger(Offset o, Size size) {
    final ll = GlobeProjection(_cam, size).unproject(o);
    final a = _s.audio;
    if (ll == null) {
      a.voiceMute();
      return;
    }
    final (lon, lat) = ll;
    _tAt = (lat, lon);
    final e = _terrain.at(lat, lon);
    if (e.isNaN) return;
    final pan = ((o.dx - size.width / 2) / (size.width / 2)).clamp(-1.0, 1.0);
    final now = DateTime.now();
    if (e < 0) {
      a.voiceMute();
      if (now.difference(_tWave).inMilliseconds > 650) {
        _tWave = now;
        a.song(0.1 + 0.12 * math.min(1.0, -e / 6000), pan);
      }
    } else {
      // F3: tiếng SÁO, đất càng cao sáo càng cao
      a.voiceStart(instrument: 'sao');
      a.voiceSet(freq: fluteFreq(e), pan: pan, gain: 0.08);
      // F3: số liệu thật (lưới data_nasa) nếu có ở đây, không thì ước lượng
      final real = TouchGrid.loaded?.sample(lat, lon);
      final hasReal = real != null && !real.sea;
      var slopeEst = double.nan;
      if (!hasReal || real.slope == null) {
        final stepKm = (25 / math.max(1.0, _cam.zoom)).clamp(0.12, 25.0);
        final dLat = stepKm / 110.57, dLon = stepKm / (111.32 * math.max(0.05, math.cos(lat * math.pi / 180)));
        slopeEst = slopeDegrees(_terrain.at(lat + dLat, lon), _terrain.at(lat - dLat, lon), _terrain.at(lat, lon + dLon),
            _terrain.at(lat, lon - dLon), stepKm);
      }
      final cue = fingerCue(
        hasReal: hasReal,
        realSlope: real?.slope,
        realWater: real?.water,
        realPop: real?.pop,
        waterThreshold: TouchGrid.loaded?.waterThreshold ?? 0.5,
        urbanEstimate: hasReal ? 0 : _urban.at(lat, lon),
        slopeEstimate: slopeEst,
      );
      // khu dân cư → tiếng xe cộ (càng đông dân càng to)
      if (cue.trafficAmp > 0 && now.difference(_tTraffic).inMilliseconds > 1500) {
        _tTraffic = now;
        a.ambient('traffic', amp: cue.trafficAmp, pan: pan);
      }
      if (cue.urban && !_inUrban) _s.speaker.quick('khu dân cư', 'built-up area');
      _inUrban = cue.urban;
      // sông, hồ lớn → tiếng nước
      if (cue.inlandWater && now.difference(_tWave).inMilliseconds > 900) {
        _tWave = now;
        a.song(0.08, pan);
        if (!_inWater) _s.speaker.quick('sông hồ', 'river or lake');
      }
      _inWater = cue.inlandWater;
      // rung theo ĐỘ DỐC
      if (now.difference(_tSlope).inMilliseconds > 160 && Haptics.slope(cue.slopeDeg)) _tSlope = now;
    }
    final band = bandOf(e);
    final form = landformAt(lat, lon, e: e);
    final formKey = form?.vi ?? '';
    if (band != _tBand || formKey != _tForm) {
      if (band != _tBand && band < 3) Haptics.light(); // ra / vào biển; trên đất liền máy rung theo độ dốc
      final bn = bandName(band);
      final newForm = formKey != _tForm && form != null;
      _tBand = band;
      _tForm = formKey;
      _s.speaker.quick(newForm ? '${form.vi}, ${bn.$1}' : bn.$1, newForm ? '${form.en}, ${bn.$2}' : bn.$2);
    }
  }

  /// Đọc độ cao một điểm (nhấc tay / chạm một lần trong chế độ chạm địa hình).
  Future<void> _terrainSay(double lat, double lon) async {
    final n = _world?.placeName(lon, lat) ?? ('chỗ này', 'here');
    final e = await _terrain.precise(lat, lon, z: _cam.zoom > 12 ? 11 : 9);
    if (e.isNaN || !mounted) return;
    final (pv, pe) = elevPhrase(e);
    final f = landformAt(lat, lon, e: e);
    await _s.speaker.say('${n.$1.isEmpty ? 'Chỗ này' : n.$1}: $pv${f == null ? '' : ', ${f.vi}'}.',
        '${n.$2.isEmpty ? 'Here' : n.$2}: $pe${f == null ? '' : ', ${f.en}'}.');
  }

  // ======================= Địa lý quanh ta =======================
  // vị trí GPS gần nhất (giữ 3 phút: hỏi liền nhiều câu không phải chờ định vị lại)
  (double, double)? _gpsLast;
  DateTime _gpsAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// "Nơi tôi đứng" theo GPS của máy: nói ngay mình đang ở gần xã, phường nào (danh bạ hành chính, không cần mạng).
  /// [say]: đọc vị trí lên (câu "tôi đang ở đâu"); false khi chỉ cần toạ độ cho câu hỏi khác ("thời tiết chỗ tôi").
  Future<_Loc?> _gpsLoc({bool say = true}) async {
    final s = _s;
    double? lat, lon;
    final last = _gpsLast;
    if (last != null && DateTime.now().difference(_gpsAt).inMinutes < 3) {
      (lat, lon) = last;
    } else {
      final (pos, fail) = await locateMe();
      if (pos == null) {
        final f = _focus;
        if (!say) return null; // câu hỏi khác ("thời tiết chỗ tôi"): lặng lẽ dùng nơi đang xem / nơi của bạn
        if (f != null) {
          // máy tính thường không có GPS: dùng nơi vừa nói tới thay vì dừng lại
          await s.speaker.say('Chưa lấy được vị trí của máy, mình dùng nơi vừa xem: ${f.vi}.', 'No device location; using ${f.en}.');
          return f;
        }
        s.earcon('err');
        await s.speaker.say(
            switch (fail) {
              LocateFail.off => 'Máy đang tắt định vị. Hãy bật định vị, tức GPS, rồi nói lại.',
              LocateFail.denied => kIsWeb
                  ? 'Trang web chưa được phép dùng vị trí. Nhờ người đi cùng bấm biểu tượng ổ khóa cạnh địa chỉ trang, '
                      'chọn Vị trí, Cho phép, rồi tải lại trang. Hoặc nói tên nơi bạn ở, ví dụ: thời tiết xã Gia Lâm.'
                  : 'Ứng dụng chưa được phép dùng vị trí. Hãy cho phép trong cài đặt của máy, mục Ứng dụng, Lắng, Quyền, Vị trí, rồi nói lại.',
              _ => 'Chưa lấy được vị trí. Bạn ra chỗ thoáng hoặc nói tên một nơi, ví dụ: thời tiết xã Gia Lâm.',
            },
            'Could not get your location.');
        return null;
      }
      lat = pos.lat;
      lon = pos.lon;
      _gpsLast = (lat, lon);
      _gpsAt = DateTime.now();
    }
    final gz = await VnGazetteer.load();
    final near = gz?.nearest(lat, lon);
    final String vi, en;
    if (near != null) {
      final (h, km) = near;
      vi = 'chỗ bạn đứng, gần ${h.label}';
      en = 'where you are, near ${h.label}';
      if (say) {
        final dist = km < 1 ? 'chưa tới 1 ki lô mét' : 'khoảng ${km.round()} ki lô mét';
        await s.speaker.say('Bạn đang ở gần ${h.label}, cách trụ sở ủy ban $dist.',
            'You are near ${h.label}, about ${km < 1 ? 'less than 1' : km.round()} kilometres from its office.');
      }
    } else {
      final n = _world?.placeName(lon, lat) ?? ('', '');
      vi = 'nơi bạn đang đứng${n.$1.isEmpty ? '' : ', ở ${n.$1}'}';
      en = 'where you are${n.$2.isEmpty ? '' : ', in ${n.$2}'}';
      if (say) await s.speaker.say('Bạn đang ở ${n.$1.isEmpty ? 'ngoài Việt Nam' : n.$1}.', 'You are in ${n.$2}.');
    }
    return _Loc(vi, en, lat, lon, 30);
  }

  /// Câu hỏi về "chỗ tôi", "nơi tôi đứng", "ở đây", "quanh đây" mà không nói tên nơi → dùng GPS của máy (nếu lấy được),
  /// còn lại dùng nơi đang xem / nơi của bạn như trước.
  static final _meRe = RegExp(r'\b(cho toi|noi toi|cho minh|noi minh|toi dang dung|minh dang dung|vi tri cua toi|vi tri hien tai|'
      r'o day|quanh day|xung quanh day|cho nay|noi nay|khu nay|quanh toi|xung quanh toi|gan toi|ngoai troi|here|my location|near me|around me)\b');

  /// Nơi mở bản đồ RÊ TAY khi người dùng không nói tên nơi. KHÔNG lấy tâm quả cầu đang quay (dễ rơi vào một chỗ
  /// ngẫu nhiên mà tên đọc lại là "Việt Nam" → dữ liệu không khớp nơi người dùng nghĩ). Thứ tự: nói "quanh tôi" →
  /// GPS; nơi vừa hỏi; GPS; nơi đã lưu trong Cài đặt; cuối cùng Hà Nội — và nói rõ đang mở ở đâu.
  Future<_Loc> _exploreHere(String raw) async {
    if (_meRe.hasMatch(normVi(raw))) {
      final g = await _gpsLoc(say: false);
      if (g != null) return g;
    }
    final f = _focus;
    if (f != null) return f;
    final g = await _gpsLoc(say: false);
    if (g != null) return g;
    final h = _s.home;
    if (h != null) return _Loc(h.name, h.name, h.lat, h.lon, 9);
    _exploreNote = true;
    return const _Loc('Hà Nội', 'Hanoi', 21.0285, 105.8542, 9);
  }

  /// lời nhắc một lần trong câu giới thiệu rê tay: chưa biết nơi của bạn nên mở ở Hà Nội
  bool _exploreNote = false;

  Future<_Loc> _hereFor(String raw) async {
    if (_meRe.hasMatch(normVi(raw))) {
      final g = await _gpsLoc(say: false);
      if (g != null) return g;
    }
    return _here();
  }

  Future<void> _around(_Loc loc, {bool explore = false, String raw = ''}) async {
    final s = _s;
    final near = loc.zoom < 18 ? _Loc(loc.vi, loc.en, loc.lat, loc.lon, 30) : loc;
    if (!explore) {
      final hg = buildHanoiGuide(loc.vi, loc.en, lat: near.lat, lon: near.lon, raw: raw);
      if (hg != null) {
        await _goTo(near);
        if (!mounted) return;
        final gz = await VnGazetteer.load();
        final adm = gz?.nearest(near.lat, near.lon);
        var viText = hg.$1;
        var enText = hg.$2;
        final nLoc = normVi(loc.vi);
        if (adm != null &&
            nLoc != 'ha noi' &&
            nLoc != 'thanh pho ha noi' &&
            !nLoc.startsWith('cho ban dung') &&
            !nLoc.startsWith('noi ban dang dung') &&
            !RegExp(r'\b(xa|phuong|thi tran)\b').hasMatch(nLoc)) {
          final (h, km) = adm;
          if (km < 3.5) {
            viText = '$viText Địa điểm này gần ${h.label}.';
            enText = '$enText Located near ${h.label}.';
          }
        }
        viText = '$viText Bạn có thể hỏi tiếp: thời tiết ở đây, hoặc hỏi một xã, phường khác ở Hà Nội.';
        enText = '$enText You can also ask for the weather here, or another ward in Hanoi.';
        await s.speaker.say(viText, enText);
        return;
      }
    }
    final f = _geo.load(near.lat, near.lon, grid: explore, osmWait: Duration(seconds: explore ? 28 : 10));
    if (explore) {
      // RÊ TAY: mở bản đồ địa hình thật NGAY (độ cao + lớp phủ tự tải trong bản đồ), lớp OpenStreetMap (tên sông,
      // đường, khu dân cư) thêm vào khi máy chủ trả lời — máy chủ OSM công cộng có lúc chậm tới vài chục giây
      await _goTo(near);
      if (!mounted) return;
      final placeholder = AroundData(near.lat, near.lon, 1200, const [], null, List.filled(8, double.nan), null, 10);
      setState(() {
        _local = placeholder;
        _localName = loc.vi;
      });
      unawaited(f.then((d) {
        if (mounted && identical(_local, placeholder)) setState(() => _local = d);
      }).catchError((Object e) {
        CrashGuard.log('[rê tay] OSM: $e');
      }));
      final note = _exploreNote;
      _exploreNote = false;
      await s.speaker.say(
          '${note ? 'Mình chưa biết vị trí của bạn nên mở quanh Hà Nội; muốn nơi khác, nói: rê tay kèm tên nơi, ví dụ: rê tay Đà Lạt. ' : ''}'
              'Bản đồ quanh ${loc.vi}, khoảng 2 cây số mỗi chiều, phía bắc ở trên, bạn đang ở vị trí trung tâm bản đồ. '
              'Rê ngón tay để nghe: tiếng sóng là sông hồ, tiếng lá xào xạc là cây xanh, tiếng xe cộ là khu dân cư, tiếng trống là đồng ruộng, '
              'tiếng sáo càng cao là đất càng cao, máy rung mạnh dần theo độ dốc. Nói "thoát" để về quả địa cầu.',
          'Map around ${loc.en}, about 2 km each way, north at the top, you are at the centre. '
              'Drag your finger to explore: waves for water, rustling leaves for trees, traffic for built-up areas, a flute rising with elevation, and vibration following the slope. Say "exit" to go back.');
      return;
    }
    await _goTo(near);
    // địa danh có sẵn trong app ở gần (không cần mạng) — đọc kèm, kể cả khi bản đồ mở không tải được
    final lm = nearbyLandmarksText(near.lat, near.lon, km: 15);
    AroundData d;
    try {
      d = await f;
    } catch (e) {
      CrashGuard.log('[quanh đây] $e');
      d = AroundData(near.lat, near.lon, 1000, const [], null, List.filled(8, double.nan), null, 10);
    }
    if (!mounted) return;
    if (explore) {
      setState(() {
        _local = d;
        _localName = loc.vi;
      });
      final note = _exploreNote;
      _exploreNote = false;
      await s.speaker.say(
          '${note ? 'Mình chưa biết vị trí của bạn nên mở quanh Hà Nội; muốn nơi khác, nói: rê tay kèm tên nơi, ví dụ: rê tay Đà Lạt. ' : ''}'
              'Bản đồ quanh ${loc.vi}, khoảng 2 cây số mỗi chiều, phía bắc ở trên, bạn đang ở vị trí trung tâm bản đồ. '
              'Rê ngón tay để nghe: tiếng sóng là sông hồ, tiếng lá xào xạc là cây xanh, tiếng xe cộ là khu dân cư, tiếng trống là đồng ruộng, '
              'tiếng sáo càng cao là đất càng cao, máy rung mạnh dần theo độ dốc. Nói "thoát" để về quả địa cầu.',
          'Map around ${loc.en}, about 2 km each way, north at the top, you are at the centre. '
              'Drag your finger to explore: waves for water, rustling leaves for trees, traffic for built-up areas, a flute rising with elevation, and vibration following the slope. Say "exit" to go back.');
      return;
    }
    final desc = describeAround(d, loc.vi);
    final gz = await VnGazetteer.load();
    final adm = gz?.nearest(near.lat, near.lon);
    final bVi = StringBuffer();
    final bEn = StringBuffer();
    if (desc.isNotEmpty) {
      bVi.write(desc);
      bEn.write(describeAroundEn(d, loc.en));
    }
    if (d.features.isEmpty && adm != null) {
      final (h, km) = adm;
      final dist = km < 1 ? 'chưa tới 1 ki lô mét' : 'khoảng ${km.round()} ki lô mét';
      bVi.write(' Khu vực này gần ${h.label}, cách trụ sở ủy ban $dist.');
      bEn.write(' This area is near ${h.label}.');
    }
    if (lm.$1.isNotEmpty) {
      bVi.write(' ${lm.$1}');
      bEn.write(' ${lm.$2}');
    }
    final satScene = NasaNormalizedRepo.cached?.dalatScene;
    if (satScene != null && satScene.contains(near.lat, near.lon)) {
      final cell = satScene.cellAt(near.lat, near.lon);
      if (cell != null) {
        bVi.write(' ${cell.spokenSummary(en: false)}');
        bEn.write(' ${cell.spokenSummary(en: true)}');
      }
    }
    await s.speaker.say(bVi.toString().trim(), bEn.toString().trim());
    await s.speaker.say(
        'Bạn có thể hỏi tiếp: thời tiết ở đây, hoặc nói: xưa và nay.',
        'You can also ask: weather here, or say: past and present.');
  }

  /// Đóng bộ phát lại lịch sử (nếu đang mở).
  void _closeHistory() {
    final h = _hist;
    if (h == null) return;
    _hist = null;
    h.stop();
    if (mounted) setState(() {});
    // huỷ sau khung hình kế (lớp hiển thị còn đang nghe nó)
    WidgetsBinding.instance.addPostFrameCallback((_) => h.dispose());
  }

  /// F1 — Lịch sử thời tiết & thiên tai: dựng bản ghi theo tháng (≤ 3 năm) hoặc theo năm (> 3 năm) rồi phát lại.
  Future<void> _weatherHistory(_Loc loc, WCmd c) async {
    final s = _s;
    _closeHistory();
    _storyStop = false;
    s.earcon('tick');
    final mode = c.aspect ?? 'both';
    NasaClimate clim;
    try {
      clim = await _nasa.climate(loc.lat, loc.lon);
    } on LiveError catch (e) {
      s.earcon('err');
      await s.speaker.say(e.vi, e.en);
      return;
    } catch (e) {
      CrashGuard.log('[lịch sử thời tiết] $e');
      s.earcon('err');
      await s.speaker.say('Chưa lấy được số liệu lịch sử thời tiết. Kiểm tra mạng rồi thử lại.', 'Could not get the weather history.');
      return;
    }
    if (!mounted || _storyStop) return;
    final range = resolveRange(spanMonths: c.spanMonths, from: c.from, to: c.to, dataY0: clim.y0, dataY1: clim.y1);
    // hỏi khoảng ngoài dữ liệu (vd "năm 2026", "thập niên 70") → nói rõ đã chốt lại
    final asked = c.from ?? c.to;
    final clipped = asked != null &&
        ((c.from != null && (c.from!.year < clim.y0 || c.from!.year > clim.y1)) || (c.to != null && c.to!.year > clim.y1));
    var events = <HazardEvent>[];
    if (mode != 'weather') {
      events = await _hazHist
          .around(loc.lat, loc.lon, DateTime(range.y0, range.m0), DateTime(range.y1, range.m1 + 1))
          .timeout(const Duration(seconds: 20), onTimeout: () => <HazardEvent>[]);
    }
    if (!mounted || _storyStop) return;
    final recs = buildRecords(tempMonth: clim.tempMonth, rainMonth: clim.rainMonth, range: range, events: events);
    if (recs.isEmpty) {
      await s.speaker.say('Không có số liệu cho khoảng thời gian này.', 'No data for that period.');
      return;
    }
    if (clipped) {
      await s.speaker.say('Số liệu NASA có từ năm ${clim.y0} đến năm ${clim.y1}, mình phát phần có số liệu.',
          'NASA data covers ${clim.y0} to ${clim.y1}; playing the part with data.');
      if (!mounted || _storyStop) return;
    }
    final p = HistoryPlayer(
      audio: s.audio,
      say: (vi, en) => s.speaker.say(vi, en),
      quick: (vi, en) => s.speaker.quick(vi, en),
      stopSpeech: () => s.speaker.stop(),
      lang: () => s.lang,
      placeVi: loc.vi,
      placeEn: loc.en,
      range: range,
      records: recs,
      mode: mode,
    );
    setState(() => _hist = p);
    Stats.instance.track('history');
    await p.start();
    // phát xong: giữ màn hình cuối thêm một lúc rồi đóng
    if (_hist == p && p.finished) {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (_hist == p) _closeHistory();
    }
  }

  Future<void> _history(_Loc loc) async {
    final s = _s;
    try {
      // xưa – nay: MỘT nguồn thống nhất (ERA5) cho nhiệt độ, mưa, ngày nóng — chuỗi NASA POWER ở Việt Nam có bước nhảy
      // theo thời gian nên không dùng để nói xu hướng (xem NasaPowerService.extremes)
      final x = await _nasa.extremes(loc.lat, loc.lon);
      if (!mounted) return;
      final (t0, t1, r0, r1) = (x.t0, x.t1, x.rain0, x.rain1);
      final rainPhrase = (r1 - r0).abs() < 0.05 * r0
          ? 'gần như không đổi, khoảng ${_n(r1)} mi-li-mét'
          : (r1 > r0 ? 'tăng từ ${_n(r0)} lên ${_n(r1)} mi-li-mét' : 'giảm từ ${_n(r0)} xuống ${_n(r1)} mi-li-mét');
      final hotExtraVi = ' Trong đó số ngày nắng nóng gay gắt từ 37 độ trở lên: trước kia khoảng ${_dec(x.hot37_0)} ngày, nay khoảng ${_dec(x.hot37_1)} ngày; '
          'đặc biệt gay gắt từ 39 độ trở lên: trước kia ${_dec(x.hot39_0)} ngày, nay ${_dec(x.hot39_1)} ngày mỗi năm.';
      const globalCtxVi = ' Đặt cạnh bức tranh toàn cầu theo NASA GISTEMP v4, Trái Đất đã ấm lên hơn 1,2 độ C so với thời kỳ tiền công nghiệp.';
      await s.speaker.say(
          'Xưa và nay ở ${loc.vi}. So sánh thập niên 1980 với 10 năm gần đây, từ năm ${x.b0} đến năm ${x.b1}. '
              'Nhiệt độ trung bình ${(t1 - t0).abs() < 0.05 ? 'gần như không đổi, khoảng ${_dec(t1)} độ' : 'từ ${_dec(t0)} độ ${t1 > t0 ? 'lên' : 'xuống'} ${_dec(t1)} độ, ${t1 > t0 ? 'ấm hơn' : 'mát hơn'} ${_dec((t1 - t0).abs())} độ'}. '
              'Số ngày nắng nóng trên 35 độ mỗi năm: trước kia khoảng ${x.hot0.round()} ngày, nay khoảng ${x.hot1.round()} ngày.$hotExtraVi '
              'Số ngày mưa rất to trên 50 mi-li-mét mỗi năm: trước kia ${_dec(x.wet0)} ngày, nay ${_dec(x.wet1)} ngày. '
              'Lượng mưa cả năm $rainPhrase.$globalCtxVi '
              '${DataCard.audioIntroVi('app_sonification')} '
              'Nguồn so sánh xưa và nay: dữ liệu tái phân tích khí hậu ERA5 của châu Âu, một nguồn thống nhất cho cả 45 năm; '
              'bối cảnh toàn cầu: NASA GISTEMP v4. Bây giờ nghe nhiệt độ từng năm.',
          'Past and present in ${loc.en}, 1980s versus ${x.b0} to ${x.b1}: average temperature from ${_dec(t0)} to ${_dec(t1)} degrees; '
              'days above 35 degrees per year from ${x.hot0.round()} to ${x.hot1.round()}; yearly rain from ${_n(r0)} to ${_n(r1)} millimetres. '
              '${DataCard.audioIntroEn('app_sonification')} Source: ERA5 climate reanalysis, one consistent record for all years; '
              'global context: NASA GISTEMP v4.');
      if (!mounted) return;
      await _sound.years(x.asYears(loc.lat, loc.lon));
    } on LiveError catch (e) {
      s.earcon('err');
      await s.speaker.say(e.vi, e.en);
    } catch (e) {
      CrashGuard.log('[xưa và nay] $e');
      s.earcon('err');
      await s.speaker.say('Chưa lấy được dữ liệu xưa và nay. Kiểm tra mạng rồi thử lại.', 'Could not get the data.');
    }
  }

  // ======================= Vũ trụ =======================
  Future<void> _story(Planet p) async {
    final s = _s;
    _storyStop = false;
    _focus = null;
    _pin = null;
    setState(() {
      _local = null;
      _solar = false;
      _solarHi = null;
      _planet = p;
      _spaceN.value = 0;
    });
    Stats.instance.track('lesson');
    s.audio.planet(p.sound);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    final chapters = s.lang == 'en' ? (planetStoriesEn[p.sound] ?? p.chapters) : p.chapters;
    for (var k = 0; k < chapters.length; k++) {
      if (!mounted || _storyStop) return;
      await s.speaker.say(chapters[k], chapters[k]);
      if (!mounted || _storyStop) return;
      if (k == chapters.length - 1) break;
      s.audio.planet(p.sound, amp: 0.12);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  static Future<void> _loadNasaSounds() async {
    if (NasaSound.loaded.isNotEmpty) return;
    try {
      NasaSound.loaded = NasaSound.parseCatalog(await rootBundle.loadString('assets/sounds/nasa/catalog.json'));
    } catch (e) {
      CrashGuard.log('[âm thanh NASA] $e');
    }
  }

  /// F2: phát một bản ghi âm thật của NASA rồi giải thích; [id] rỗng → đọc danh sách các bản ghi.
  Future<void> _nasaSound(String id) async {
    final s = _s;
    await _loadNasaSounds();
    final all = NasaSound.loaded;
    if (all.isEmpty) {
      await s.speaker.say('Chưa nạp được các bản ghi âm của NASA.', 'NASA recordings are not available.');
      return;
    }
    final snd = all.where((x) => x.id == id).firstOrNull;
    if (snd == null) {
      await s.speaker.say(
          'Có ${all.length} bản ghi âm thật của NASA: ${all.map((x) => x.titleVi).join('; ')}. '
              'Nói tên một bản ghi để nghe, ví dụ: nghe tiếng Sputnik, hoặc: âm thanh Apollo 11.',
          'There are ${all.length} real NASA recordings: ${all.map((x) => x.titleEn).join('; ')}. '
              'Say one to hear it, for example: play the Sputnik sound.');
      return;
    }
    _storyStop = false;
    Stats.instance.track('nasa_sound');
    await s.speaker.say('Bản ghi âm thật của NASA: ${snd.titleVi}.', 'A real NASA recording: ${snd.titleEn}.');
    if (!mounted || _storyStop) return;
    final ok = await _playNasaRecording(snd);
    if (!mounted || _storyStop) return;
    await s.speaker.say('${snd.introVi} Nguồn: ${snd.credit}.${ok ? '' : ' Máy này chưa phát được bản ghi.'}',
        '${snd.introEn} Credit: ${snd.credit}.');
  }

  /// Phát bản ghi [snd] và chờ hết (dừng được giữa chừng). false nếu máy không phát được.
  Future<bool> _playNasaRecording(NasaSound snd) async {
    final ok = await _s.audio.playRecording(snd.file, () async => (await rootBundle.load(snd.assetPath)).buffer.asUint8List());
    if (!ok) return false;
    final end = DateTime.now().add(Duration(milliseconds: (snd.durationS * 1000).round() + 400));
    while (mounted && !_storyStop && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  /// F2 — trò "Đố âm thanh NASA" (theo khung truyện / minigame của data_nasa): mỗi lượt dẫn chuyện → nghe bản ghi
  /// THẬT của NASA → câu hỏi hai lựa chọn → đúng / sai / hết giờ → giải thích. [id] rỗng: một lượt 3 bản ghi ngẫu nhiên.
  Future<void> _nasaSoundGame(String id) async {
    final s = _s;
    final en = s.lang == 'en';
    await _loadNasaSounds();
    final all = NasaSound.loaded;
    final picked = id.isEmpty ? nasaGameRound(_rng, all) : [for (final x in all) if (x.id == id && x.quiz != null) x];
    if (picked.isEmpty) {
      await s.speaker.say('Chưa có trò chơi âm thanh NASA.', 'The NASA sound game is not available.');
      return;
    }
    _storyStop = false;
    _gameOn = true;
    _gameQuit = false;
    _gameTypedPending = null;
    Stats.instance.track('nasa_game');
    var score = 0, asked = 0;
    try {
      await _gameSay(
          'Đố âm thanh NASA: ${picked.length} bản ghi thật. Nghe xong, trả lời một hoặc hai, hoặc nói luôn đáp án.',
          'NASA sound quiz: ${picked.length} real recordings. After each, answer one or two, or say the answer.');
      for (final snd in picked) {
        if (!mounted || _storyStop) break;
        final q = snd.quiz!.shuffled(_rng);
        final opts = en ? q.optsEn : q.optsVi;
        await _gameSay('Hãy nghe: ${snd.titleVi}.', 'Listen: ${snd.titleEn}.');
        if (!mounted || _storyStop) break;
        final played = await _playNasaRecording(snd);
        if (!mounted || _storyStop) break;
        String ask() => en ? '${q.qEn} One: ${opts[0]}. Two: ${opts[1]}.' : '${q.qVi} Một: ${opts[0]}. Hai: ${opts[1]}.';
        await _gameSay('${played ? '' : 'Máy chưa phát được bản ghi. '}${ask()}', ask());
        asked++;
        int? pick;
        for (var tries = 0; tries < 2 && pick == null && mounted && !_storyStop; tries++) {
          final h = await _gameHear();
          if (h == null) break; // hết giờ
          final ctl = gameControl(h);
          if (ctl == 'stop') {
            _storyStop = true;
            break;
          }
          if (ctl == 'repeat') {
            await _gameSay(ask(), ask());
            continue;
          }
          if (ctl == 'skip') break;
          pick = matchOption(h, opts);
          if (pick == null && tries == 0) await _gameSay('Bạn chọn một hay hai?', 'One or two?');
        }
        if (!mounted || _storyStop) break;
        if (pick == q.answer) {
          score++;
          s.earcon('ok');
          await _gameSay('Chính xác! ${snd.introVi}', 'Correct! ${snd.introEn}');
        } else {
          s.earcon(pick == null ? 'tick' : 'err');
          await _gameSay('${pick == null ? 'Hết giờ.' : 'Chưa đúng.'} Đáp án là ${opts[q.answer]}. ${snd.introVi}',
              '${pick == null ? 'Time is up.' : 'Not quite.'} The answer is ${opts[q.answer]}. ${snd.introEn}');
        }
      }
    } finally {
      _gameOn = false;
    }
    if (!mounted || asked == 0) return;
    await _gameSay('Bạn đúng $score trên $asked câu. Nguồn âm thanh: NASA Historical Sounds. Nói: đố âm thanh NASA, để chơi lại.',
        'You got $score out of $asked. Sounds: NASA Historical Sounds. Say "NASA sound quiz" to play again.');
  }

  PlanetFact? _lastFact;
  final _factRng = math.Random();

  /// F2: "sự thật thú vị về <thiên thể>" — một bản ghi sự thật NGẪU NHIÊN của thiên thể đó (planets_nasa.json, NASA Science).
  /// Không nói tên: thiên thể đang xem, nếu không thì chọn ngẫu nhiên.
  Future<void> _funFact(String target) async {
    final s = _s;
    if (PlanetBody.loaded.isEmpty) await NasaNormalizedRepo.load();
    Planet? p = target.isEmpty ? null : planetIn(target);
    p ??= _planet ?? planets[_factRng.nextInt(planets.length)];
    final body = PlanetBody.bySound(p.sound);
    final fact = body?.randomFact(_factRng, avoid: _lastFact, en: s.lang == 'en');
    if (body == null || fact == null) {
      await s.speaker.say('Mình chưa có sự thật thú vị nào về ${p.vi}.', 'No fun fact about ${p.en} yet.');
      return;
    }
    _lastFact = fact;
    if (_local != null || _solar) _leaveModes();
    _storyStop = false;
    if (_planet != p) setState(() => _planet = p);
    Stats.instance.track('fact');
    s.audio.planet(p.sound, amp: 0.22);
    final nameEn = planetNamesEn[p.sound] ?? p.en;
    await s.speaker.say('Sự thật thú vị về ${p.vi}: ${fact.vi} Theo NASA. Muốn nghe thêm, nói: một sự thật nữa.',
        'Fun fact about $nameEn: ${fact.en} Source: NASA. Say "another fun fact" for more.');
  }

  Future<void> _askPlanet(Planet p, String question) async {
    final s = _s;
    s.audio.planet(p.sound, amp: 0.28);
    // số liệu có sẵn trong app: trả lời ngay, không cần mạng hay khoá AI
    final local = planetAnswer(p.sound, p.vi, planetNamesEn[p.sound] ?? p.en, question, en: s.lang == 'en');
    if (local != null) {
      await s.speaker.say(local, local);
      return;
    }
    final repo = NasaNormalizedRepo.cached ?? await NasaNormalizedRepo.load();
    final qaHit = repo.matchQa(question);
    if (qaHit != null) {
      final ans = qaHit.spokenAnswer(en: s.lang == 'en');
      await s.speaker.say(ans, ans);
      return;
    }
    if (!s.ai.enabled) {
      await s.speaker.say(planetHint(false), planetHint(true));
      return;
    }
    Stats.instance.track('ai');
    try {
      final ragContext = EarthRag.extractContext(question, lang: s.lang);
      final a = await s.ai.ask(question,
          lang: s.lang,
          ragContext: ragContext,
          toolHandler: _executeAgentTool,
          context: s.lang == 'en'
              ? 'The listener is blind and is hearing a story about ${planetNamesEn[p.sound]}. Answer briefly and vividly, '
                  'compare with familiar objects; do not talk about weather. Story facts: ${(planetStoriesEn[p.sound] ?? p.chapters).join(' ')}'
              : 'Người nghe là người khiếm thị đang nghe tập truyện về ${p.vi}. Trả lời ngắn, dễ hình dung, '
                  'dùng so sánh với đồ vật quen thuộc; không nói về thời tiết. Thông tin của tập: ${p.facts}',
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      await s.speaker.say(a, a);
    } catch (e) {
      CrashGuard.log('[AI vũ trụ] $e');
      s.earcon('err');
      await s.speaker.say('Trợ lý AI chưa trả lời được. ${planetHint(false)}', 'The AI could not answer. ${planetHint(true)}');
    }
  }

  Future<void> _apod() async {
    final s = _s;
    Apod a;
    try {
      a = await _apodSvc.today();
    } catch (e) {
      CrashGuard.log('[APOD] $e');
      s.earcon('err');
      await s.speaker.say('Chưa lấy được ảnh thiên văn hôm nay. Có thể đã hết lượt dùng thử, thử lại sau nhé.',
          'Could not get today\'s astronomy picture.');
      return;
    }
    if (!mounted) return;
    final kind = a.mediaType == 'video' ? 'một đoạn video' : 'một bức ảnh';
    // NASA chưa đăng ảnh hôm nay → app lấy ảnh hôm trước: nói đúng là "gần nhất", không nói "hôm nay"
    final u = DateTime.now().toUtc().subtract(const Duration(hours: 5)); // NASA đăng theo giờ miền đông Mỹ
    final todayYmd = '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
    final ymd = a.date.split('-');
    final when = a.date.isEmpty || a.date == todayYmd || ymd.length != 3
        ? 'hôm nay'
        : 'gần nhất, ngày ${int.tryParse(ymd[2]) ?? ymd[2]} tháng ${int.tryParse(ymd[1]) ?? ymd[1]}';
    // NASA đôi khi trả lời hỏng cho bài là video nhúng (tên "NASA Science", giải thích "To view this video please
    // enable JavaScript…") → không đưa cho AI kể bừa
    final broken = a.explanation.length < 80 || RegExp(r'enable JavaScript|upgrading to a web browser', caseSensitive: false).hasMatch(a.explanation);
    if (broken) {
      s.earcon('err');
      await s.speaker.say(
          'NASA chưa có lời giải thích cho ảnh thiên văn $when, đây là một đoạn video. Bạn thử lại sau nhé, '
              'hoặc nghe kể chuyện các hành tinh: nói, kể chuyện Sao Hỏa.',
          'NASA has no description for the latest astronomy picture yet. Please try again later.');
      return;
    }
    if (s.ai.enabled) {
      try {
        final d = await s.ai.ask(
            s.lang == 'en'
                ? 'Retell this for a blind listener in 5 to 7 warm, simple sentences: today NASA features "${a.title}". '
                    'Describe what is in the picture (shapes, colours, size compared with familiar things) and why it is interesting. '
                    'NASA\'s original explanation: ${a.explanation}'
                : 'Hãy kể lại bằng tiếng Việt cho người khiếm thị, 5 đến 7 câu, giọng ấm áp: hôm nay NASA giới thiệu $kind tên "${a.title}". '
                    'Tả những gì có trong hình (hình dạng, màu sắc, kích thước so với đồ vật quen thuộc) và vì sao nó thú vị. '
                    'Lời giải thích gốc của NASA: ${a.explanation}',
            lang: s.lang,
            context: 'Đây là ảnh thiên văn trong ngày (APOD) của NASA, không liên quan thời tiết.',
            lookup: (_) async => null);
        if (!mounted) return;
        await s.speaker.say('Ảnh thiên văn $when của NASA: ${a.title}. $d', '${a.title}. $d');
        return;
      } catch (e) {
        CrashGuard.log('[APOD AI] $e');
      }
    }
    await s.speaker.say(
        'Ảnh thiên văn $when của NASA là $kind tên: ${a.title}. Lời mô tả gốc bằng tiếng Anh. '
            'Muốn nghe kể lại bằng tiếng Việt, cần bật trợ lý AI trong cài đặt.',
        'NASA astronomy picture of the day: ${a.title}. ${a.explanation}');
  }

  void _stopSound() {
    _storyStop = true;
    _closeHistory();
    _closeScan();
    _closeEic();
    _sound.stop();
    _s.stopAll();
    _ignoreHeardUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    _wokeAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _notFound(String target, {String raw = ''}) async {
    final s = _s;
    if (raw.isNotEmpty && s.ai.enabled) {
      await _unknown(raw);
      return;
    }
    _s.earcon('err');
    await _s.speaker.say('Mình không tìm thấy nơi tên $target. Bạn nói lại tên khác nhé.',
        'I could not find a place called $target. Please try another name.');
  }

  /// Chỗ đang xem: nơi vừa nói tới, hoặc tâm quả cầu nếu đã phóng to, hoặc nơi của bạn.
  _Loc _here() {
    final f = _focus;
    if (f != null) return f;
    if (_cam.zoom >= 3) {
      final n = _world?.placeName(_cam.lon, _cam.lat) ?? ('chỗ này', 'here');
      return _Loc(n.$1, n.$2, _cam.lat, _cam.lon, _cam.zoom);
    }
    final h = _s.home;
    return _Loc(h?.name ?? 'Hà Nội', h?.name ?? 'Hanoi', h?.lat ?? 21.03, h?.lon ?? 105.85, 9);
  }

  // ---------- Tìm nơi ----------
  static double _zoomFor(double extentDeg) {
    final half = (extentDeg / 2).clamp(0.3, 80) * math.pi / 180;
    return (0.8 / (0.88 * math.sin(half))).clamp(1.1, 30.0);
  }

  /// [strict]: câu chỉ có một cụm (có thể là tiếng ồn) → chỉ nhận địa danh tìm được ĐÚNG tên đã nói,
  /// không nhận kiểu "all" → "Albenga, Ý".
  Future<_Loc?> _resolve(String target, {bool strict = false}) async {
    final t = normVi(target);
    if (t.isEmpty) return null;
    // Hoàng Sa, Trường Sa: của Việt Nam
    if (RegExp(r'\b(hoang sa|paracel)\b').hasMatch(t)) {
      return const _Loc('quần đảo Hoàng Sa, Việt Nam', 'the Hoang Sa Islands, Viet Nam', 16.45, 111.95, 14);
    }
    if (RegExp(r'\b(truong sa|spratly)\b').hasMatch(t)) {
      return const _Loc('quần đảo Trường Sa, Việt Nam', 'the Truong Sa Islands, Viet Nam', 9.8, 113.6, 7);
    }
    if (t == 'bien dong') return const _Loc('Biển Đông', 'the East Sea', 13.5, 113.5, 3.2);
    if (RegExp(r'\b(bac cuc|bac bang duong|arctic|north pole)\b').hasMatch(t)) {
      return const _Loc('Bắc Cực', 'the Arctic', 84, 0, 2.2);
    }
    if (RegExp(r'\b(nam cuc|antarctica|south pole)\b').hasMatch(t)) {
      return const _Loc('Nam Cực', 'Antarctica', -82, 0, 2.2);
    }
    final w = _world;
    // thành phố lớn trên thế giới có tên kiểu Việt (Thượng Hải, Bắc Kinh, Tokyo, Paris...)
    // hoặc cụm có cả thành phố lẫn nước ("Thượng Hải Trung Quốc", "Tokyo Nhật Bản")
    // → ưu tiên thành phố trước khi tìm xã/làng nhỏ ở Việt Nam
    String? worldCity = cityAliases[t];
    if (worldCity == null) {
      for (final entry in cityAliases.entries) {
        if (entry.key.length >= 4 && ' $t '.contains(' ${entry.key} ')) {
          worldCity = entry.value;
          break;
        }
      }
    }
    if (worldCity != null) {
      _s.earcon('tick');
      final g = await _s.weather.geocodeWorld(worldCity, preferEnglish: _s.lang == 'en');
      if (g != null) {
        final cn = w?.countryAt(g.lon, g.lat);
        final cVi = cn?.vi ?? g.country, cEn = cn?.en ?? g.country;
        final same = normVi(g.name) == normVi(cVi);
        final zoom = g.pop > 1000000 ? 18.0 : 24.0;
        return _Loc(same ? g.name : '${g.name}, $cVi', same ? g.name : '${g.name}, $cEn', g.lat, g.lon, zoom);
      }
    }
    // nước
    final country = w?.findCountry(target);
    if (country != null) {
      return _Loc(country.vi, country.en, country.ly, country.lx, _zoomFor(country.extent));
    }
    // địa danh nổi bật có sẵn trong app (Vịnh Hạ Long, Sa Pa, Mũi Né…): toạ độ chuẩn, khỏi chờ mạng
    final lm = landmarkIn(target);
    if (lm != null && lm.aliases.any((a) => t == a || (t.contains(a) && a.length >= t.length - 6))) {
      return _Loc(landmarkPlaceVi(lm), lm.en, lm.lat, lm.lon, 30);
    }
    // xã, phường, thị trấn… ở Việt Nam ("xã Tân Lập", "phường Bến Nghé, Thành phố Hồ Chí Minh")
    if (_vnAdminRe.hasMatch(t)) {
      final v = await _vnPlace(target);
      if (v != null) return v;
    }
    // địa danh Việt Nam có sẵn trong app (toạ độ chuẩn, khỏi chờ mạng)
    final p = parseCommand(target).place;
    if (p != null && normVi(p.name).contains(t.split(' ').first)) {
      return _Loc(p.name, p.name, p.lat, p.lon, 22);
    }
    // tên tiếng Việt (có dấu): xã, phường, huyện cũ… trong danh bạ hành chính có sẵn → trước khi tìm khắp thế giới
    // (nếu chỉ là một tên trơ trọi strict: true thì chỉ nhận khi có chữ chỉ đơn vị hành chính "xã/phường...", tránh nhận nhầm câu nói chuyện)
    if (_looksVietnamese(target) && (!strict || _vnAdminRe.hasMatch(t))) {
      final gz = await VnGazetteer.load();
      if (gz != null && gz.find(target).isNotEmpty) {
        final v = await _vnPlace(target);
        if (v != null) return v;
      }
    }
    // Các khu vực, quận huyện, làng nghề hoặc điểm vui chơi ở Hà Nội (Cầu Giấy, Tây Hồ, Bát Tràng, Đường Lâm...)
    if (!strict) {
      final hz = findHanoiZone(name: target, matchKeywordOnly: true);
      if (hz != null) {
        return _Loc(hz.nameVi, hz.nameEn, hz.lat, hz.lon, 28);
      }
    }
    // thành phố trên thế giới
    _s.earcon('tick');
    if (strict && t.replaceAll(' ', '').length < 4) return null;
    // hồ, chùa, công viên, phố… là ĐỊA ĐIỂM (không phải thành phố) → tìm trên bản đồ mở trước
    final landmark = RegExp(r'^(ho|song|nui|chua|den|cho|cong vien|pho|duong|bai bien|bien|vinh|dao|cau|ga|san bay|bao tang|'
            r'truong|benh vien|nha tho|lang|thap|thac|hang|dong|deo|quang truong|van mieu|hoang thanh|khu|toa nha|sieu thi)\s')
        .hasMatch(t);
    if (landmark) {
      final poi = await _poi(target, t, strict);
      if (poi != null) return poi;
    }
    final g0 = await _s.weather.geocodeWorld(cityAliases[t] ?? target, preferEnglish: _s.lang == 'en');
    var g = g0;
    if (g != null && strict && normVi(g.name) != t && _sim(normVi(g.name), t) < 0.8) {
      CrashGuard.log('[tìm nơi] bỏ "${g.name}" — không khớp "$target"');
      g = null;
    }
    // tên tiếng Việt nghe nhầm ("Hà Lội") mà bản đồ trả về một xóm nhỏ ở Việt Nam tên chẳng giống ("Xóm Côi")
    // → bỏ, để bước đoán tên gần đúng ra "Hà Nội"
    if (g != null && !strict && g.cc == 'VN' && _looksVietnamese(target) && g.pop < 50000 && _sim(normVi(g.name), t) < 0.6) {
      CrashGuard.log('[tìm nơi] bỏ "${g.name}" — không giống "$target"');
      g = null;
    }
    // chỉ nói mỗi một tên (không có "đi tới", "thời tiết ở"…) mà lại là nơi nhỏ ở nước ngoài → nhiều khả năng nghe nhầm
    // ("mona" → Mona, Bờ Biển Ngà; "which" → Whichello, Úc): bỏ qua, không bay lung tung
    if (g != null && strict && g.cc != 'VN' && g.pop < 50000) {
      CrashGuard.log('[tìm nơi] bỏ "${g.name}" (${g.pop} dân) — chỉ nghe một tên lẻ, có thể nghe nhầm');
      g = null;
    }
    // tên có dấu tiếng Việt mà không ra nơi ở Việt Nam → thử tìm xã / phường / làng ở Việt Nam trước
    // (câu chỉ có một tên lẻ thì không: tiếng ồn bị nghe thành chữ tiếng Việt dễ trùng tên một làng nào đó)
    if (!strict && (g == null || g.cc != 'VN') && _looksVietnamese(target)) {
      final v = await _vnPlace(target);
      if (v != null) return v;
    }
    // KHÔNG tìm bừa trên bản đồ mở (từng ra "salon tóc", "cảng nội địa…"): chỉ trả lời nơi hành chính hoặc địa danh
    // người dùng nói rõ loại (hồ, chùa, núi…) — đã thử ở trên.
    // "cảng nội địa Gia Lâm", "chợ đêm Đà Lạt": bỏ phần địa điểm phía trước, lấy xã / phường / tỉnh có tên ở cuối câu
    if (g == null) {
      final tail = await _adminTail(target);
      if (tail != null) return tail;
    }
    if (g == null) return null;
    final inHs = g.lon >= hoangSaBox.$1 && g.lon <= hoangSaBox.$3 && g.lat >= hoangSaBox.$2 && g.lat <= hoangSaBox.$4;
    final inTs = g.lon >= truongSaBox.$1 && g.lon <= truongSaBox.$3 && g.lat >= truongSaBox.$2 && g.lat <= truongSaBox.$4;
    if (inHs) return const _Loc('quần đảo Hoàng Sa, Việt Nam', 'the Hoang Sa Islands, Viet Nam', 16.45, 111.95, 14);
    if (inTs) return const _Loc('quần đảo Trường Sa, Việt Nam', 'the Truong Sa Islands, Viet Nam', 9.8, 113.6, 7);
    // tên nước theo bản đồ của app (đúng với biên giới đang vẽ)
    final cn = w?.countryAt(g.lon, g.lat);
    final cVi = cn?.vi ?? g.country, cEn = cn?.en ?? g.country;
    final same = normVi(g.name) == normVi(cVi);
    final zoom = g.pop > 1000000 ? 18.0 : 24.0;
    return _Loc(same ? g.name : '${g.name}, $cVi', same ? g.name : '${g.name}, $cEn', g.lat, g.lon, zoom);
  }

  /// Phần CUỐI câu là tên một đơn vị hành chính (≥ 2 tiếng, khớp cả dấu) → nơi đó, kèm lời nói rõ app chỉ tra đến xã.
  Future<_Loc?> _adminTail(String target) async {
    final gz = await VnGazetteer.load();
    if (gz == null) return null;
    final words = target.trim().split(RegExp(r'\s+'));
    for (var k = 1; k <= words.length - 2; k++) {
      final tail = words.sublist(k).join(' ');
      if (!gz.knowsExact(stripAdminPrefix(tail)) && gz.provinceHit(tail) == null) continue;
      if (gz.find(tail).isEmpty) continue;
      final head = words.sublist(0, k).join(' ');
      final v = await _vnPlace(tail);
      if (v == null) return null;
      await _s.speaker.say('Mình lấy khu vực ${v.vi} cho $head.',
          'Using ${v.en} for $head.');
      return v;
    }
    return null;
  }

  static final _vnAdminRe = RegExp(r'^(xa|phuong|thi tran|thi xa|huyen|quan|thon|lang|ban|ap|khom|dac khu)\s');
  static final _viMarks = RegExp('[ăâđêôơưàáạảãằắặẳẵầấậẩẫèéẹẻẽềếệểễìíịỉĩòóọỏõồốộổỗờớợởỡùúụủũừứựửữỳýỵỷỹ]', caseSensitive: false);
  static bool _looksVietnamese(String s) => _viMarks.hasMatch(s);

  /// Xã / phường / thị trấn / làng ở Việt Nam (bản đồ mở, chỉ tìm trong Việt Nam).
  /// Nhiều tỉnh có xã trùng tên ("Tân Lập") → chọn nơi gần chỗ đang xem / nơi của bạn, rồi nói rõ đã chọn tỉnh nào
  /// và cách chọn nơi khác (nói kèm tên tỉnh). Đơn vị cũ trước sáp nhập 2025 vẫn tìm được và được nói rõ là "cũ".
  Future<_Loc?> _vnPlace(String target) async {
    final s = _s;
    final sp = splitProvince(target);
    // 1) danh bạ hành chính có sẵn trong app (đủ 3.321 xã, phường mới + tên cũ), không cần mạng
    final gz = await VnGazetteer.load();
    var hits = gz?.find(target) ?? const <VnHit>[];
    // 2) không có trong danh bạ (thôn, làng, ấp, bản…) → bản đồ mở, chỉ nhận đơn vị hành chính / làng xóm
    if (hits.isEmpty) {
      final all = await s.weather.geocodeVnAll(target);
      final want = normVi(stripAdminPrefix(sp.place));
      hits = [
        for (final v in all)
          // bản đồ mở hay trả về nơi tên chẳng giống ("Hà Lội" → "Xóm Côi") → chỉ nhận tên gần giống câu nói
          if (_sim(normVi(stripAdminPrefix(v.name)), want) >= 0.6)
          VnHit('${v.name}${v.current ? '' : ' cũ'}${v.province.isEmpty ? '' : ', ${v.province}'}', stripAdminPrefix(v.name),
              v.province, v.lat, v.lon, v.current ? 'ward' : 'oldWard')
      ];
    }
    if (hits.isEmpty && sp.province != null) {
      // có tên tỉnh mà không thấy ở tỉnh đó → xem nơi trùng tên ở tỉnh khác để báo cho rõ
      final elsewhere = gz?.provincesWith(sp.place) ?? const <String>[];
      final name = stripAdminPrefix(sp.place);
      final tinh = sp.oldProvince == null ? sp.province! : '${sp.oldProvince}, nay thuộc ${sp.province}';
      await s.speaker.say(
          elsewhere.isEmpty
              ? 'Mình không tìm thấy $name ở $tinh.'
              : 'Mình không thấy $name ở $tinh. Có nơi tên $name ở ${elsewhere.take(4).join(', ')}.',
          'I could not find $name in ${sp.province}.');
      return null;
    }
    if (hits.isEmpty) return null;
    var v = hits.first;
    final provinces = hits.map((x) => x.province).toSet().toList();
    if (hits.length > 1) {
      // gần nơi đang xem / nơi của bạn / mặc định (Hà Nội) nhất (nếu trong vòng ~150 km)
      final ref = _focus ?? (s.homePlace == null ? null : _resolveHomeSync()) ?? _here();
      double d(VnHit x) => math.sqrt(math.pow(x.lat - ref.lat, 2) + math.pow((x.lon - ref.lon) * math.cos(ref.lat * math.pi / 180), 2));
      final near = hits.reduce((p, q) => d(p) <= d(q) ? p : q);
      if (d(near) < 1.4) v = near;
      if (provinces.length > 1) {
        final others = provinces.where((p) => p != v.province).take(3).join(', ');
        await s.speaker.say(
            'Có ${hits.length} nơi tên ${v.short}, ở ${v.province} và $others. Mình lấy ${v.label}. '
                'Muốn nơi khác thì nói kèm tên tỉnh, ví dụ: thời tiết ${v.short}, ${provinces.firstWhere((p) => p != v.province)}.',
            'There are ${hits.length} places called ${v.short}. I picked the one in ${v.province}. '
                'Say the province name to choose another.');
      }
    }
    CrashGuard.log('[tìm xã/phường] "$target" → ${v.label} (${v.lat}, ${v.lon})');
    return _Loc(v.label, v.label, v.lat, v.lon, v.zoom);
  }

  /// Toạ độ "nơi của bạn" (có sẵn trong danh sách tỉnh, thành của app) — không gọi mạng.
  _Loc? _resolveHomeSync() {
    final h = _s.homePlace;
    if (h == null) return null;
    final p = parseCommand(h).place;
    return p == null ? null : _Loc(p.name, p.name, p.lat, p.lon, 22);
  }

  // ======================= TRÒ CHƠI TÌM HIỂU HỆ MẶT TRỜI (chơi bằng giọng nói) =======================
  bool _gameOn = false;
  bool _gameQuit = false; // vẽ chữ Z / "về màn hình chính" giữa trò chơi → dừng trò
  String? _lastGame;

  // ======================= VỀ MÀN HÌNH CHÍNH (chữ Z hoặc "về màn hình chính") =======================
  final _zg = ZGesture();
  DateTime _homeAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ======================= VUỐT HAI NGÓN (quay lại / đổi phần) =======================
  final _sw2 = TwoFingerSwipe();

  Future<void> _onSwipe2(Swipe2 d) async {
    switch (d) {
      case Swipe2.down:
        // như nói "quay lại": rời rê tay / máy hát / lịch sử / vũ trụ…, ở quả cầu thì lùi ra
        Haptics.medium();
        await _onHeard(_s.lang == 'en' ? 'go back' : 'quay lại', typed: true);
      case Swipe2.left:
        await _switchSection(1);
      case Swipe2.right:
        await _switchSection(-1);
      case Swipe2.up:
        break;
    }
  }

  /// Đổi nhanh giữa các phần: thời tiết → địa lý → vũ trụ → máy hát Trái Đất → (vòng lại).
  Future<void> _switchSection(int dir) async {
    const order = ['weather', 'geo', 'space', 'jukebox'];
    final cur = _eic != null
        ? 3
        : (_planet != null || _solar)
            ? 2
            : (_local != null || _terrainTouch || _scan != null)
                ? 1
                : 0;
    final next = order[(cur + dir + order.length) % order.length];
    Haptics.light();
    _s.audio.earcon('tick');
    _stopSound();
    _s.speaker.stop();
    _awaiting = null;
    _terrainOff();
    _leaveModes();
    _ignoreHeardUntil = DateTime.now();
    if (next == 'jukebox') {
      await _onHeard(_s.lang == 'en' ? 'earth jukebox' : 'máy hát trái đất', typed: true);
    } else {
      await _enterSection(next);
    }
  }

  // ======================= GIỮ ĐỂ NÓI (push-to-talk) =======================
  // Chạm GIỮ YÊN một ngón ≥ 350 ms (lệch ≤ 15 px) ở bất kỳ đâu: ngắt ngay âm thanh / giọng đang đọc, rung nhẹ + tiếng tít,
  // mở nghe; nhấc tay là xong câu (nhận dạng ngay, không chờ im lặng). Tắt ở các màn RÊ TAY (giữ ngón để nghe tên vùng).
  Timer? _holdTimer;
  int? _holdPtr;
  Offset? _holdAt;
  bool _holdOn = false, _holdUsed = false;
  int _pointers = 0;

  bool get _holdAllowed => _local == null && !_terrainTouch && _eic == null && _scan == null;

  /// Đang khám phá bằng tay (bản đồ chạm, chạm địa hình, quét lát cắt): ngón tay dùng để rê / kéo bản đồ.
  bool get _touchExploring => _local != null || _terrainTouch || _scan != null;

  void _holdDown(PointerDownEvent e) {
    _pointers++;
    _holdTimer?.cancel();
    _holdUsed = false;
    if (_pointers != 1 || !_holdAllowed) {
      _holdPtr = null;
      return;
    }
    _holdPtr = e.pointer;
    _holdAt = e.position;
    _holdTimer = Timer(const Duration(milliseconds: 350), _holdStart);
  }

  void _holdMove(PointerMoveEvent e) {
    final at = _holdAt;
    if (e.pointer != _holdPtr || _holdOn || at == null) return;
    if ((e.position - at).distance > 15) {
      _holdTimer?.cancel();
      _holdPtr = null;
    }
  }

  void _holdUp(int pointer) {
    _pointers = math.max(0, _pointers - 1);
    if (pointer != _holdPtr) return;
    _holdTimer?.cancel();
    _holdPtr = null;
    if (_holdOn) {
      _holdOn = false;
      _s.listener.finishNow(); // nhấc tay = nói xong
    }
  }

  void _holdStart() {
    if (_holdPtr == null || !mounted) return;
    _holdOn = true;
    _holdUsed = true; // lần chạm này không phải "chạm để nghe nơi này"
    Haptics.light();
    _stopSound();
    _s.speaker.stop();
    _s.audio.earcon('tick');
    _paused = false; // đang "tạm nghỉ" mà giữ để nói → nghe lại
    _ignoreHeardUntil = DateTime.now(); // _stopSound chặn nghe 1,5 giây: ở đây người dùng muốn nói ngay
    _touchedAt = DateTime.now();
    if (!_loopOn) _startLoop();
  }

  /// Về màn hình chính của nhánh đang dùng: nhánh VŨ TRỤ (hành tinh, trò chơi) → bản đồ Hệ Mặt Trời;
  /// nhánh TRÁI ĐẤT (rê tay, quét lát cắt, lịch sử, đang xem một nơi) → quả địa cầu toàn cảnh, Việt Nam ở giữa.
  Future<void> _goHome({bool byGesture = false}) async {
    if (DateTime.now().difference(_homeAt).inMilliseconds < 1500) return;
    _homeAt = DateTime.now();
    final space = _planet != null || _solar || _gameOn;
    _s.audio.earcon('ok');
    if (byGesture) Haptics.medium();
    _stopSound();
    _s.speaker.stop();
    _s.speaker.resetQuick();
    _awaiting = null;
    if (_gameOn) {
      _gameQuit = true;
      unawaited(_s.listener.cancel());
    }
    _terrainOff();
    _storyStop = true;
    _closeHistory();
    _closeScan();
    _closeEic();
    _s.ai.reset();
    if (!mounted) return;
    setState(() {
      _local = null;
      _planet = null;
      _solar = space;
      _solarHi = null;
      _focus = null;
      _pin = null;
    });
    if (!space) unawaited(_flyTo(GlobeCamera.start));
    await _s.speaker.say(
        space
            ? 'Màn hình chính vũ trụ: Hệ Mặt Trời. Nói tên một hành tinh, hoặc nói: trò chơi.'
            : 'Màn hình chính: quả địa cầu, Việt Nam ở giữa. Nói tên một nơi, hoặc nói: rê tay khám phá.',
        space
            ? 'Space home: the Solar System. Say a planet, or say: play a game.'
            : 'Home: the globe with Viet Nam in the middle. Say a place, or say: touch explore.');
  }
  final _rng = math.Random();

  Future<void> _gameSay(String vi, String en) => _s.speaker.say(vi, en);

  /// Nghe một câu trả lời trong lúc chơi; null nếu im lặng / không nghe được.
  Future<String?> _gameHear() async {
    if (_gameQuit) return 'dừng';
    // câu trả lời GÕ / BẤM NÚT trong lúc app đang đọc câu hỏi (chưa kịp nghe) → dùng luôn
    final early = _gameTypedPending;
    if (early != null) {
      _gameTypedPending = null;
      return early;
    }
    final typed = _gameTyped = Completer<String>();
    final t0 = DateTime.now();
    final listenF = _s.listener.listen(waitSeconds: 7, maxSeconds: 6).then<String?>((r) {
      if (r.end == ListenEnd.heard && r.text.trim().isNotEmpty) return r.text;
      return null;
    }).catchError((Object _) => null);
    var ans = await Future.any<String?>([listenF, typed.future]);
    // không có mic (máy không cho dùng micro, trình duyệt chặn): nghe trả về ngay → chờ câu gõ thêm một lúc
    if (ans == null && !typed.isCompleted && DateTime.now().difference(t0).inMilliseconds < 1500) {
      ans = await typed.future.timeout(const Duration(seconds: 12), onTimeout: () => '');
      if (ans.isEmpty) ans = null;
    }
    if (typed.isCompleted) unawaited(_s.listener.cancel()); // trả lời bằng gõ: thôi nghe
    _gameTyped = null;
    if (!mounted) return null;
    if (_gameQuit) return 'dừng';
    if (ans != null && ans.trim().isNotEmpty) {
      _heard.value = ans;
      CrashGuard.log('[trò chơi] ${typed.isCompleted ? 'gõ' : 'nghe'}: "$ans"');
      return ans;
    }
    return null;
  }

  /// Câu gõ / nút bấm trong lúc chơi: đưa vào trò chơi như câu trả lời nói.
  Completer<String>? _gameTyped;
  String? _gameTypedPending;
  void _feedGame(String text) {
    final c = _gameTyped;
    if (c != null && !c.isCompleted) {
      c.complete(text);
    } else {
      _gameTypedPending = text;
    }
  }

  Future<void> _playGame(String kind) async {
    final s = _s;
    final en = s.lang == 'en';
    if (kind.isEmpty) {
      await _gameSay(
          'Có ba trò chơi tìm hiểu Hệ Mặt Trời. Một: đố vui, trả lời câu hỏi ba lựa chọn. '
              'Hai: tôi là ai, nghe gợi ý rồi đoán tên hành tinh, đoán càng sớm càng nhiều điểm. '
              'Ba: nghe tiếng đoán hành tinh, mỗi thiên thể có một tiếng nhạc riêng. Bạn chọn trò nào? Nói: một, hai, hoặc ba.',
          'There are three Solar System games. One: quiz, questions with three choices. '
              'Two: who am I, guess the planet from clues, the earlier the more points. '
              'Three: guess the planet from its sound. Which one? Say one, two or three.');
      _await('game');
      return;
    }
    if (kind == 'sound' && !s.audio.ready) {
      await _gameSay('Trò nghe tiếng cần bật âm thanh nhạc cụ, mà hiện âm thanh chưa sẵn sàng. Mình chơi đố vui nhé.',
          'The sound game needs instrument sounds, which are not ready. Let\'s play the quiz instead.');
      kind = 'quiz';
    }
    _lastGame = kind;
    _gameOn = true;
    _gameQuit = false;
    _gameTypedPending = null;
    Stats.instance.track('game');
    setState(() {
      _local = null;
      _planet = null;
      _solar = true;
      _solarHi = null;
    });
    var score = 0, max = 0;
    var stopped = false;
    try {
      switch (kind) {
        case 'riddle':
          (score, max, stopped) = await _riddleGame(en);
        case 'sound':
          (score, max, stopped) = await _soundGame(en);
        default:
          (score, max, stopped) = await _quizGame(en);
      }
    } finally {
      _gameOn = false;
    }
    if (!mounted) return;
    if (stopped && max == 0) return;
    // kỉ lục của từng trò (lưu trên máy)
    final key = 'gameBest_$kind';
    final best = int.tryParse(s.pref(key) ?? '') ?? -1;
    final record = score > best && score > 0;
    if (record) await s.setPref(key, '$score');
    final f = finalWords(score, max);
    s.earcon('ok');
    if (record) s.audio.planet(7, amp: 0.2); // tiếng chuông lấp lánh mừng kỉ lục
    await _gameSay(
        '${stopped ? 'Dừng chơi. ' : 'Hết lượt. '}Bạn được $score trên $max điểm. ${f.$1}'
            '${record && best >= 0 ? ' Kỉ lục mới của bạn!' : ''} '
            'Nói: chơi lại, hoặc chọn trò khác: một đố vui, hai tôi là ai, ba nghe tiếng đoán hành tinh.',
        '${stopped ? 'Game stopped. ' : 'Round over. '}You scored $score out of $max. ${f.$2}${record && best >= 0 ? ' A new record!' : ''} '
            'Say play again, or pick another game: one, two or three.');
    _await('game');
  }

  /// Hết hơi: im lặng ba lần liền → dừng chơi (người dùng có thể đã đi chỗ khác).
  Future<bool> _gameSilent(int n, bool en) async {
    if (n >= 3) {
      await _gameSay('Mình không nghe thấy gì, mình tạm dừng trò chơi nhé.', 'I can\'t hear you, so I\'ll pause the game.');
      return true;
    }
    return false;
  }

  Future<(int, int, bool)> _quizGame(bool en) async {
    final qs = buildQuiz(_rng);
    var score = 0, max = 0;
    await _gameSay(
        'Đố vui Hệ Mặt Trời: ${qs.length} câu. Trả lời bằng số một, hai, ba, hoặc nói luôn đáp án. '
            'Nói "nhắc lại" để nghe lại câu hỏi, "gợi ý" để bớt một đáp án sai, "bỏ qua" để nghe đáp án.',
        'Solar System quiz: ${qs.length} questions. Answer one, two or three, or say the answer. '
            'Say "repeat", "hint" or "skip" any time.');
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      final opts = en ? q.optsEn : q.opts;
      max++;
      String ask() => en
          ? 'Question ${i + 1}. ${q.qEn} One: ${opts[0]}. Two: ${opts[1]}. Three: ${opts[2]}.'
          : 'Câu ${i + 1}. ${q.q} Một: ${opts[0]}. Hai: ${opts[1]}. Ba: ${opts[2]}.';
      await _gameSay(ask(), ask());
      var tries = 0, silent = 0;
      final removed = <int>{};
      while (mounted) {
        final h = await _gameHear();
        if (!mounted) return (score, max, true);
        if (h == null) {
          if (await _gameSilent(++silent, en)) return (score, max - 1, true);
          await _gameSay('Bạn nói số một, hai hay ba nhé. Hoặc nói: nhắc lại.', 'Say one, two or three. Or say: repeat.');
          continue;
        }
        silent = 0;
        final ctl = gameControl(h);
        if (ctl == 'stop') return (score, max - 1, true);
        if (ctl == 'repeat') {
          await _gameSay(ask(), ask());
          continue;
        }
        if (ctl == 'hint') {
          final wrong = [for (var k = 0; k < opts.length; k++) if (k != q.answer && !removed.contains(k)) k];
          if (wrong.length <= 1 && removed.isNotEmpty) {
            await _gameSay('Chỉ còn hai đáp án thôi, bạn chọn đi.', 'Only two choices are left, pick one.');
          } else {
            final w = wrong[_rng.nextInt(wrong.length)];
            removed.add(w);
            await _gameSay('Gợi ý: đáp án không phải là ${opts[w]}.', 'Hint: it is not ${opts[w]}.');
          }
          continue;
        }
        if (ctl == 'skip') {
          _s.earcon('tick');
          await _gameSay('Đáp án là ${opts[q.answer]}. ${q.why}', 'The answer is ${opts[q.answer]}. ${q.whyEn}');
          break;
        }
        var pick = matchOption(h, opts);
        if (pick == null && matchBody(h) != null) pick = -1; // gọi tên một hành tinh không có trong đáp án → sai
        if (pick == null) {
          await _gameSay('Mình chưa nghe rõ. Bạn chọn một, hai hay ba?', 'I didn\'t catch that. One, two or three?');
          continue;
        }
        if (pick == q.answer) {
          _s.earcon('ok');
          if (tries == 0 && removed.isEmpty) score++;
          final k = _rng.nextInt(praiseVi.length);
          await _gameSay('${praiseVi[k]} ${q.why}', '${praiseEn[k]} ${q.whyEn}');
          break;
        }
        _s.earcon('err');
        tries++;
        if (pick >= 0) removed.add(pick);
        if (tries >= 2) {
          await _gameSay('Chưa đúng. Đáp án là ${opts[q.answer]}. ${q.why}', 'Not quite. The answer is ${opts[q.answer]}. ${q.whyEn}');
          break;
        }
        await _gameSay('Chưa đúng rồi. Thử lại một lần nữa nhé.', 'Not quite. Try once more.');
      }
    }
    return (score, max, false);
  }

  Future<(int, int, bool)> _riddleGame(bool en) async {
    final rs = buildRiddles(_rng);
    var score = 0, max = 0;
    await _gameSay(
        'Trò tôi là ai: ${rs.length} câu đố. Mình nói gợi ý, bạn đoán là hành tinh nào, hay Mặt Trời, Mặt Trăng. '
            'Đoán đúng ngay gợi ý đầu được 3 điểm, gợi ý thứ hai 2 điểm, gợi ý cuối 1 điểm. Nói "gợi ý" để nghe gợi ý tiếp.',
        'Who am I: ${rs.length} riddles. Guess the planet, the Sun or the Moon. '
            'Right on the first clue scores 3, second clue 2, last clue 1. Say "hint" for the next clue.');
    for (var i = 0; i < rs.length; i++) {
      final rd = rs[i];
      final clues = en ? rd.cluesEn : rd.clues;
      final name = bodyName(rd.sound, en: en);
      max += 3;
      var c = 0, silent = 0;
      await _gameSay('Câu đố ${i + 1}. Tôi là ai? ${clues[0]}', 'Riddle ${i + 1}. Who am I? ${clues[0]}');
      while (mounted) {
        final h = await _gameHear();
        if (!mounted) return (score, max, true);
        if (h == null) {
          if (await _gameSilent(++silent, en)) return (score, max - 3, true);
          await _gameSay('Bạn đoán tên một hành tinh nhé, hoặc nói: gợi ý.', 'Guess a planet name, or say: hint.');
          continue;
        }
        silent = 0;
        final ctl = gameControl(h);
        if (ctl == 'stop') return (score, max - 3, true);
        if (ctl == 'repeat') {
          await _gameSay('Các gợi ý: ${clues.take(c + 1).join(' ')}', 'Clues: ${clues.take(c + 1).join(' ')}');
          continue;
        }
        final guess = ctl == null ? matchBody(h) : null;
        if (ctl == null && guess == null) {
          await _gameSay('Bạn đoán tên một hành tinh, Mặt Trời hoặc Mặt Trăng nhé.', 'Guess a planet, the Sun or the Moon.');
          continue;
        }
        if (guess == rd.sound) {
          final pts = 3 - c;
          score += pts;
          _s.earcon('ok');
          setState(() => _solarHi = rd.sound);
          _s.audio.planet(rd.sound, amp: 0.2);
          await _gameSay('Đúng rồi, mình là $name! Bạn được $pts điểm.', 'Yes, I am $name! You get $pts points.');
          break;
        }
        if (guess != null) _s.earcon('err');
        c++;
        if (c >= clues.length || ctl == 'skip') {
          setState(() => _solarHi = rd.sound);
          await _gameSay('${guess != null ? 'Chưa đúng. ' : ''}Mình là $name.', '${guess != null ? 'Not quite. ' : ''}I am $name.');
          break;
        }
        await _gameSay('${guess != null ? 'Chưa đúng. ' : ''}Gợi ý tiếp: ${clues[c]}', '${guess != null ? 'Not quite. ' : ''}Next clue: ${clues[c]}');
      }
    }
    return (score, max, false);
  }

  Future<(int, int, bool)> _soundGame(bool en) async {
    final s = _s;
    final g = buildSoundGame(_rng);
    var score = 0, max = 0;
    Future<void> play(int k) async {
      setState(() => _solarHi = null);
      s.audio.planet(k, amp: 0.32);
      await Future<void>.delayed(const Duration(milliseconds: 3400));
    }

    final names = [for (final k in g.learn) bodyName(k, en: en)];
    await _gameSay(
        'Nghe tiếng đoán hành tinh. Trước hết, làm quen với tiếng của ba thiên thể: ${names.join(', ')}.',
        'Guess by sound. First, meet the sounds of three bodies: ${names.join(', ')}.');
    for (final k in g.learn) {
      if (!mounted) return (score, max, true);
      await _gameSay('Đây là tiếng của ${bodyName(k)}.', 'This is ${bodyName(k, en: true)}.');
      setState(() => _solarHi = k);
      s.audio.planet(k, amp: 0.32);
      await Future<void>.delayed(const Duration(milliseconds: 3400));
      await _gameSay(soundWhy[k]!.$1, soundWhy[k]!.$2);
    }
    await _gameSay('Giờ mình phát một tiếng, bạn nói đó là ${names.join(', hay ')}. Nói "nghe lại" để nghe lần nữa.',
        'Now I play a sound, and you say which one it is: ${names.join(', or ')}. Say "repeat" to hear it again.');
    for (var i = 0; i < g.asks.length; i++) {
      final k = g.asks[i];
      max++;
      var tries = 0, silent = 0;
      await _gameSay('Lượt ${i + 1}. Nghe nhé.', 'Round ${i + 1}. Listen.');
      await play(k);
      while (mounted) {
        final h = await _gameHear();
        if (!mounted) return (score, max, true);
        if (h == null) {
          if (await _gameSilent(++silent, en)) return (score, max - 1, true);
          await _gameSay('Đó là ${names.join(', ')}? Hay nói: nghe lại.', 'Is it ${names.join(', ')}? Or say: repeat.');
          continue;
        }
        silent = 0;
        final ctl = gameControl(h);
        if (ctl == 'stop') return (score, max - 1, true);
        if (ctl == 'repeat' || ctl == 'hint') {
          await play(k);
          continue;
        }
        final guess = ctl == 'skip' ? -1 : matchBody(h);
        if (guess == null) {
          await _gameSay('Bạn nói tên một trong ba: ${names.join(', ')}.', 'Say one of: ${names.join(', ')}.');
          continue;
        }
        if (guess == k) {
          _s.earcon('ok');
          if (tries == 0) score++;
          setState(() => _solarHi = k);
          final p = _rng.nextInt(praiseVi.length);
          await _gameSay('${praiseVi[p]} Đó là ${bodyName(k)}. ${soundWhy[k]!.$1}', '${praiseEn[p]} It is ${bodyName(k, en: true)}. ${soundWhy[k]!.$2}');
          break;
        }
        if (guess >= 0) _s.earcon('err');
        tries++;
        if (tries >= 2 || guess < 0) {
          setState(() => _solarHi = k);
          await _gameSay('Đó là ${bodyName(k)}. ${soundWhy[k]!.$1}', 'It was ${bodyName(k, en: true)}. ${soundWhy[k]!.$2}');
          break;
        }
        await _gameSay('Chưa đúng. Nghe lại nhé.', 'Not quite. Listen again.');
        await play(k);
      }
    }
    return (score, max, false);
  }

  /// Giới thiệu một địa danh Việt Nam: bay tới, đọc vài câu, gợi ý hỏi tiếp.
  Future<void> _landmark(WCmd c) async {
    final s = _s;
    var l = c.target.isEmpty ? null : landmarkIn(c.target);
    // "kể về đây": địa danh đang xem (hoặc gần chỗ đang xem nhất, trong vòng ~15 km)
    if (l == null) {
      final f = _focus ?? _here();
      l = landmarkIn(f.vi);
      if (l == null) {
        Landmark? best;
        var bd = 0.15;
        for (final x in vnLandmarks) {
          final d = math.sqrt(math.pow(x.lat - f.lat, 2) + math.pow(x.lon - f.lon, 2));
          if (d < bd) {
            bd = d;
            best = x;
          }
        }
        l = best;
      }
      if (l == null) {
        await s.speaker.say('Mình chưa có giới thiệu về ${f.vi}. Bạn thử hỏi: quanh đây có gì, hoặc thời tiết ở đây.',
            'I have no description of ${f.en} yet. Try: what is around here, or the weather here.');
        return;
      }
    }
    final loc = _Loc(landmarkPlaceVi(l), l.en, l.lat, l.lon, 30);
    await _goTo(loc);
    unawaited(s.weather.get(loc.lat, loc.lon, lang: s.lang).then<void>((_) {}, onError: (Object _) {})); // tải sẵn
    final reg = regionNamesVi[l.region]!;
    await s.speaker.say(
        '${l.name}, ở ${l.province}, $reg. ${l.vi} Bạn hỏi tiếp được: thời tiết ở đây, hoặc quanh đây có gì.',
        '${l.en}, ${regionNamesEn[l.region]}. ${l.enText} You can ask: the weather here, or what is around.');
  }

  /// Kể tên địa danh nổi bật theo vùng ("miền Trung có gì đẹp") hoặc theo tỉnh ("ở Quảng Ninh có gì").
  Future<void> _landmarkList(String raw) async {
    final s = _s;
    final byProvince = landmarksOfProvinceIn(raw);
    final region = regionIn(raw);
    (String, String) text;
    if (byProvince.length > 8) {
      // nhiều nơi (Hà Nội): chia trong trung tâm / xa hơn cho dễ nhớ, mỗi nhóm một câu
      final p = byProvince.first.province;
      final c = byProvince.first;
      double d(Landmark l) => math.sqrt(math.pow(l.lat - c.lat, 2) + math.pow((l.lon - c.lon) * math.cos(c.lat * math.pi / 180), 2)) * 111.2;
      final near = [for (final l in byProvince) if (d(l) <= 8) l.name];
      final far = [for (final l in byProvince) if (d(l) > 8) l.name];
      text = (
        '$p có ${byProvince.length} địa danh mình kể được. Trong trung tâm: ${near.join(', ')}. '
            '${far.isEmpty ? '' : 'Xa hơn ở ngoại thành: ${far.join(', ')}. '}'
            'Bạn muốn nghe về nơi nào? Ví dụ nói: kể về ${near.first}. Đang đứng ở trung tâm thì nói: quanh đây có gì.',
        landmarkListText(p, p, byProvince).$2
      );
    } else if (byProvince.isNotEmpty) {
      final p = byProvince.first.province;
      text = landmarkListText(p, p, byProvince);
    } else if (region != null) {
      text = landmarkListText(_cap(regionNamesVi[region]!), regionNamesEn[region]!, landmarksOfRegion(region));
    } else {
      text = landmarkOverviewText();
    }
    await s.speaker.say(text.$1, text.$2);
    _await('landmark');
  }

  static String _cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);

  /// Địa điểm cụ thể (hồ, chùa, phố…) trên bản đồ mở. strict: tên phải khớp (câu chỉ có một tên, dễ là nghe nhầm).
  Future<_Loc?> _poi(String target, String t, bool strict) async {
    if (t.replaceAll(' ', '').length < 4) return null;
    // gần nơi đang xem (hoặc vừa xem) nhất; chưa xem nơi nào thì lấy nơi nổi tiếng nhất
    final f = _focus;
    final p = await _s.weather.geocodePoi(target, nearLat: f?.lat, nearLon: f?.lon);
    if (p == null || p.lat.isNaN || p.lon.isNaN) return null;
    final n = normVi(p.name);
    final matches = n == t || n.contains(t) || t.contains(n) || _sim(n, t) >= (strict ? 0.8 : 0.6);
    if (!matches) {
      CrashGuard.log('[tìm địa điểm] bỏ "${p.name}" — không khớp "$target"');
      return null;
    }
    CrashGuard.log('[tìm địa điểm] "$target" → ${p.name} (${p.lat}, ${p.lon})');
    final cn = _world?.countryAt(p.lon, p.lat);
    final where = cn == null || cn.a3 == 'VNM' ? '' : ', ${_s.lang == 'en' ? cn.en : cn.vi}';
    return _Loc('${p.name}$where', '${p.name}$where', p.lat, p.lon, 30);
  }

  /// Khi không tìm thấy đúng tên: tìm một địa danh BIẾT TRƯỚC nằm trong câu, hoặc tên gần giống nhất
  /// (bộ nhận giọng hay nghe nhầm một tiếng: "Hà Lội" → Hà Nội, "Nha Chang" → Nha Trang).
  Future<_Loc?> _guess(String raw) async {
    final t = normVi(raw);
    if (t.isEmpty) return null;
    final w = _world;
    final names = <(String, String)>[
      for (final p in places) (normVi(p.name.replaceAll('TP. ', '')), p.name),
      for (final k in cityAliases.keys) (k, cityAliases[k]!),
      if (w != null)
        for (final c in w.countries) (normVi(c.vi), c.vi),
      for (final k in countryAliases.keys) if (k.length >= 4) (k, k),
    ];
    // 1) tên nằm nguyên trong câu (ưu tiên thành phố trước nước, dài nhất trước)
    String? best;
    var bestLen = 0;
    for (final (n, show) in names) {
      // tên một tiếng ngắn (Ý, Pháp, Lào…) dễ trùng từ thường ("ý kiến", "giải pháp") → chỉ nhận tên dài / nhiều tiếng
      if ((n.contains(' ') || n.length >= 4) && n.length > bestLen && ' $t '.contains(' $n ')) {
        best = show;
        bestLen = n.length;
      }
    }
    if (best != null) return _resolve(best);
    // 2) gần giống theo từng tiếng (cùng số tiếng), đủ giống mới nhận
    final words = t.split(' ');
    var score = 0.0;
    for (final (n, show) in names) {
      final nw = n.split(' ');
      if (nw.length < 2) continue;
      for (var k = 0; k + nw.length <= words.length; k++) {
        var sum = 0.0;
        for (var j = 0; j < nw.length; j++) {
          sum += _sim(words[k + j], nw[j]);
        }
        final sc = sum / nw.length;
        if (sc > score) {
          score = sc;
          best = show;
        }
      }
    }
    if (best != null && score >= 0.8) {
      CrashGuard.log('[đoán nơi] "$raw" → $best (${score.toStringAsFixed(2)})');
      return _resolve(best);
    }
    return null;
  }

  static double _sim(String a, String b) {
    if (a == b) return 1;
    final m = math.max(a.length, b.length);
    if (m == 0) return 1;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(math.min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return 1 - prev[b.length] / m;
  }

  // ======================= Ăn uống & lưu trú Hà Nội (dữ liệu assets/data/hanoi_places.json) =======================
  List<(HnPlace, double?)>? _placeHits;
  PlaceQuery? _placeQ;
  int _placeFrom = 0;
  bool _placeHasLoc = false;
  DateTime _placeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// true nếu câu là hỏi chỗ ăn / chỗ ở ở Hà Nội (hoặc hỏi tiếp danh sách vừa đọc) và đã trả lời.
  Future<bool> _hanoiPlaces(String text) async {
    final db = await HanoiPlacesDb.load();
    if (db == null) return false;
    final s = _s;
    if (!kHanoiFoodStayEnabled) {
      // phần quán ăn, chỗ ở đang ẨN (hanoi_guide.dart): hỏi quán ăn / khách sạn thì nói ngắn, không để trợ lý AI
      // tự kể tên quán (dễ sai); hỏi tham quan, vui chơi vẫn trả lời bình thường
      if (parsePlaceQuery(text, db) == null) return false;
      await s.speaker.say(
          'Phần gợi ý quán ăn và chỗ ở đang tạm ẩn. Bạn có thể hỏi chỗ tham quan, vui chơi, ví dụ: Tây Hồ có gì chơi, hoặc quanh đây có gì.',
          'Food and accommodation suggestions are hidden for now. You can ask about places to visit, for example: what to do in Tay Ho.');
      return true;
    }
    final hits = _placeHits, pq = _placeQ;
    if (hits != null && pq != null && DateTime.now().difference(_placeAt) < const Duration(minutes: 3)) {
      final f = placeFollowUp(text);
      if (f != null) {
        _placeAt = DateTime.now();
        if (f.$1 == 'more') {
          final a = placesAnswer(db, pq, hits, from: _placeFrom, hasLoc: _placeHasLoc);
          _placeFrom += 3;
          await s.speaker.say(a.$1, a.$2);
        } else if (f.$2 < hits.length) {
          final (p, km) = hits[f.$2];
          _showPlace(p);
          final a = placeDetail(db, p, km: km);
          await s.speaker.say(a.$1, a.$2);
        } else {
          await s.speaker.say('Danh sách vừa rồi chỉ có ${hits.length} nơi.', 'The list has only ${hits.length} places.');
        }
        return true;
      }
    }
    final q = parsePlaceQuery(text, db);
    if (q == null) return false;
    double? lat, lon;
    if (q.near) {
      final g = await _gpsLoc(say: false);
      if (g != null) {
        lat = g.lat;
        lon = g.lon;
      }
      if (lat != null && lon != null && !isHanoiCoord(lat, lon)) {
        await s.speaker.say(
            'Dữ liệu quán ăn và chỗ ở của mình hiện mới có ở Hà Nội. Bạn có thể hỏi: quán phở ở phố cổ, hoặc khách sạn gần Hồ Tây.',
            'My places-to-eat and places-to-stay data covers Hanoi only for now.');
        return true;
      }
    }
    final res = searchPlaces(db, q, lat: lat, lon: lon);
    // khu ngoại thành chưa có quán trong dữ liệu: để cẩm nang theo khu (hanoi_guide) kể món đặc sản của khu đó
    if (res.isEmpty && q.type == 'food' && q.want.isEmpty && q.named == null) return false;
    await _sayPlaces(db, q, res, hasLoc: lat != null);
    return true;
  }

  Future<void> _sayPlaces(HanoiPlacesDb db, PlaceQuery q, List<(HnPlace, double?)> res, {bool hasLoc = false}) async {
    CrashGuard.log('[ăn ở Hà Nội] $q → ${res.length} nơi');
    _placeHits = res;
    _placeQ = q;
    _placeHasLoc = hasLoc;
    _placeAt = DateTime.now();
    _placeFrom = 3;
    // nơi vừa hỏi, để "ý tôi là thời tiết" hỏi thời tiết đúng khu đó
    final zid = q.zoneId ?? (res.isNotEmpty ? res.first.$1.zone : null);
    final z = hanoiZones.where((z) => z.id == zid).firstOrNull;
    if (z != null) _lastTargetText = z.titleVi.replaceFirst('khu vực ', '').split(RegExp(r'\s*[–-]\s*')).first;
    if (res.isNotEmpty) _showPlace(res.first.$1);
    final a = placesAnswer(db, q, res, hasLoc: hasLoc);
    await _s.speaker.say(a.$1, a.$2);
  }

  // ======================= Thời tiết hay Địa điểm: tách để nói không nhầm (intent_domain.dart) =======================
  Domain? _domain; // phần đang dùng
  DateTime _domainAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastTargetText = ''; // nơi vừa hỏi

  /// Phần đang dùng — quên sau 10 phút không hỏi gì thuộc phần đó.
  Domain? get _domainNow => DateTime.now().difference(_domainAt) < const Duration(minutes: 10) ? _domain : null;

  void _setDomain(Domain d) {
    _domain = d;
    _domainAt = DateTime.now();
  }

  /// Chọn phần cho câu vừa nghe. true nếu đã trả lời ở đây; false để bộ hiểu lệnh chung làm tiếp.
  Future<bool> _routeDomain(String text) async {
    final s = _s;
    final sw = domainSwitch(text);
    if (sw != null) {
      final (how, d) = sw;
      _setDomain(d);
      // chữa lại: làm lại câu vừa rồi (cùng nơi) ở phần kia
      if (how == 'fix' && _lastTargetText.isNotEmpty) {
        final t = _lastTargetText;
        CrashGuard.log('[phần] chữa lại → ${d.name}: "$t"');
        if (d == Domain.weather) {
          await _onHeard('thời tiết $t', typed: true);
        } else if (!await _placesForArea(t)) {
          await _onHeard('quanh $t có gì', typed: true);
        }
        return true;
      }
      if (d == Domain.places) {
        if (kHanoiFoodStayEnabled) {
          await s.speaker.say(
              'Phần địa điểm quanh Hà Nội: quán ăn, chỗ ở, chỗ chơi. Bạn hỏi, ví dụ: quán phở ở phố cổ, khách sạn gần Hồ Tây, '
                  'hoặc Tây Hồ có gì chơi. Trong phần này, chỉ cần nói tên một khu là mình kể chỗ ăn chơi ở đó. '
                  'Muốn hỏi thời tiết, nói: phần thời tiết.',
              'Places around Hanoi: food, places to stay and things to do. Ask, for example: pho in the Old Quarter. '
                  'Say "weather" to switch back.');
        } else {
          await s.speaker.say(
              'Phần địa điểm quanh Hà Nội: chỗ tham quan, vui chơi. Bạn hỏi, ví dụ: Tây Hồ có gì chơi, hay quanh đây có gì. '
                  'Trong phần này, chỉ cần nói tên một khu là mình kể chỗ tham quan ở đó. Muốn hỏi thời tiết, nói: phần thời tiết.',
              'Places around Hanoi: sights and things to do. Ask, for example: what to do in Tay Ho. Say "weather" to switch back.');
        }
      } else {
        await s.speaker.say(
            'Phần thời tiết. Bạn nói tên nơi, ví dụ: thời tiết Hà Nội, hay mai Huế có mưa không. '
                'Trong phần này, chỉ cần nói tên một nơi là mình đọc thời tiết ở đó. '
                '${kHanoiFoodStayEnabled ? 'Muốn hỏi quán ăn, chỗ ở' : 'Muốn hỏi chỗ tham quan, vui chơi'}, nói: phần địa điểm.',
            'Weather. Say a place, for example: weather in Hanoi. Say "places" for things to do.');
      }
      return true;
    }
    final dom = domainOf(text);
    if (dom == Domain.weather) {
      _setDomain(Domain.weather);
      return false; // câu thời tiết: KHÔNG tra quán ăn, để phần thời tiết trả lời
    }
    if (await _hanoiPlaces(text)) {
      _setDomain(Domain.places);
      return true;
    }
    if (dom == Domain.places) {
      _setDomain(Domain.places);
      return false; // "Tây Hồ có gì chơi", "quanh đây có gì": phần địa danh / cẩm nang sẵn có trả lời
    }
    // chỉ có tên nơi ("Tây Hồ", "còn Ba Đình thì sao"): theo phần đang dùng
    if (_domainNow == Domain.places && await _placesForBareArea(text)) return true;
    return false;
  }

  /// Đang ở phần địa điểm mà chỉ nói tên một khu Hà Nội → kể chỗ ăn chơi ở khu đó (giữ điều kiện của câu hỏi trước:
  /// "quán phở ở phố cổ" rồi "còn Tây Hồ thì sao" → quán phở ở Tây Hồ).
  Future<bool> _placesForBareArea(String text) async {
    final c0 = parseWorld(text);
    if (!((c0.kind == WKind.go && c0.bare) || c0.followUp)) return false;
    return _placesForArea(text, name: c0.target);
  }

  /// Kể chỗ ăn chơi ở khu Hà Nội nhắc trong [text]. false nếu không phải khu nào của Hà Nội.
  Future<bool> _placesForArea(String text, {String name = ''}) async {
    final z = findHanoiZone(raw: text, matchKeywordOnly: true);
    if (z == null) return false;
    final db = kHanoiFoodStayEnabled ? await HanoiPlacesDb.load() : null;
    final pq = _placeQ;
    if (db != null && pq != null) {
      final q = pq.inZone(z.id, text);
      final res = searchPlaces(db, q);
      if (res.isNotEmpty) {
        await _sayPlaces(db, q, res);
        return true;
      }
    }
    if (name.isEmpty) name = z.titleVi.replaceFirst('khu vực ', '');
    final hg = buildHanoiGuide(name, z.titleEn, lat: z.lat, lon: z.lon, raw: text);
    if (hg == null) return false;
    CrashGuard.log('[phần địa điểm] tên khu "$text" → cẩm nang ${z.id}');
    _lastTargetText = name;
    await _s.speaker.say(hg.$1, hg.$2);
    return true;
  }

  /// Ghim và bay tới một quán / khách sạn trên quả cầu (cho người đi cùng nhìn), không mở thẻ thời tiết.
  void _showPlace(HnPlace p) {
    if (_planet != null || _solar) _leaveModes();
    _focus = _Loc(p.name, p.name, p.lat, p.lon, 14);
    _pin = GlobePin(p.lon, p.lat, p.name);
    unawaited(_flyTo(GlobeCamera(p.lat, p.lon, 14)));
  }

  Future<void> _goTo(_Loc loc) async {
    if (_stale) return; // lệnh cũ đã bị thay: không bay, không đổi thẻ
    if (_planet != null || _solar) _leaveModes(); // hỏi một nơi trên Trái Đất → quay về quả địa cầu
    _focus = loc;
    _pin = GlobePin(loc.lon, loc.lat, _s.lang == 'en' ? loc.en : loc.vi);
    Haptics.medium();
    if (mounted) setState(() => _showWeatherCard = true);
    await _flyTo(GlobeCamera(loc.lat, loc.lon, loc.zoom));
  }

  Future<LiveWeather?> _weatherOf(_Loc loc) async {
    try {
      final w = await _s.weather.get(loc.lat, loc.lon, lang: _s.lang);
      if (_stale) return null; // lệnh cũ: đừng thay thẻ thời tiết của lệnh mới
      _focusWeather = w;
      _focusWeatherLoc = loc;
      if (mounted) setState(() => _showWeatherCard = true);
      return w;
    } on LiveError catch (e) {
      _s.earcon('err');
      await _s.speaker.say(e.vi, e.en);
    } catch (_) {
      _s.earcon('err');
      await _s.speaker.say('Chưa lấy được thời tiết. Kiểm tra mạng rồi thử lại.', 'Could not get the weather. Check the connection.');
    }
    return null;
  }

  // ---------- Đọc ----------
  static String _n(double x) => x.isNaN ? '?' : x.round().toString();
  static String _dec(double x) => x.isNaN ? '?' : x.toStringAsFixed(1).replaceAll('.', ',');

  /// Xác định xem địa điểm [loc] có phải là khu vực người dùng đang ở (GPS, nơi đặt làm nhà, hoặc câu hỏi "ở đây/chỗ tôi") không.
  bool _isLocalPlace(_Loc loc, [String raw = '']) {
    if (raw.isNotEmpty && _meRe.hasMatch(normVi(raw))) return true;
    if (loc.vi.startsWith('chỗ bạn đứng') || loc.vi.startsWith('nơi bạn đang đứng')) return true;
    final h = _s.home;
    if (h != null && distKm(loc.lat, loc.lon, h.lat, h.lon) < 25) return true;
    final g = _gpsLast;
    if (g != null && distKm(loc.lat, loc.lon, g.$1, g.$2) < 25) return true;
    return false;
  }

  /// Bay tới rồi đọc đủ các chỉ số + gợi ý thực tế + chơi nhạc cụ.
  Future<void> _goAndRead(_Loc loc, {bool short = false, bool? isLocal}) async {
    final s = _s;
    final local = isLocal ?? _isLocalPlace(loc);
    final wf = _weatherOf(loc); // tải song song lúc đang bay
    await _goTo(loc);
    final w = await wf;
    if (w == null || !mounted) return;
    // âm nền (mưa / gió / nắng / sấm) để cảm nhận nhanh trước khi nghe chi tiết
    if (await _ambient(w)) await Future<void>.delayed(const Duration(milliseconds: 600));
    final ind = _indices(loc, w, short: short, isLocal: local);
    await s.speaker.say(ind.$1, ind.$2);
    if (!mounted) return;
    await _alertNear(loc, km: 500);
    for (var i = 0; i < 20 && s.speaker.busy && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (mounted) await _sound.now(w);
  }

  /// Phát âm nền theo thời tiết bây giờ. true nếu có phát.
  Future<bool> _ambient(LiveWeather w) async {
    final n = w.now;
    String? kind;
    if (isThunder(n.code) || w.hours.take(2).any((h) => isThunder(h.code))) {
      _s.audio.ambient('thunder', amp: 0.3);
      kind = 'rain';
    } else if (isRainy(n.code) || n.precip > 0.1) {
      kind = 'rain';
    } else if (n.wind >= 25) {
      kind = 'wind';
    } else if (n.code <= 1 && (n.uv ?? 0) >= 3) {
      kind = 'sun';
    } else if (n.wind >= 12) {
      kind = 'wind';
    }
    if (kind == null) return false;
    _s.audio.ambient(kind, amp: kind == 'sun' ? 0.16 : 0.22);
    return true;
  }

  // ======================= Thiên tai (NASA EONET) =======================
  Future<void> _loadEvents() async {
    try {
      final ev = await _eonet.open();
      if (mounted) setState(() => _events = ev);
    } catch (e) {
      CrashGuard.log('[EONET] $e');
    }
  }

  /// Có thiên tai trong vòng [km] quanh nơi này mà chưa báo: còi + rung đặc biệt + đọc cảnh báo.
  // cảnh báo bằng hình cho người nghe kém / người đi cùng: viền đỏ nhấp nháy + dòng chữ lớn trong vài giây
  bool _alertOn = false;
  Timer? _alertTimer;
  void _flashAlert() {
    if (!mounted) return;
    setState(() => _alertOn = true);
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _alertOn = false);
    });
  }

  Future<void> _alertNear(_Loc loc, {double km = 500}) async {
    List<(NaturalEvent, double)> near;
    try {
      near = await _eonet.near(loc.lat, loc.lon, km: km).timeout(const Duration(seconds: 6));
    } catch (_) {
      return;
    }
    final fresh = [for (final e in near) if (!_alerted.contains(e.$1.id)) e];
    if (fresh.isEmpty || !mounted) return;
    for (final e in fresh) {
      _alerted.add(e.$1.id);
    }
    _s.audio.alarm();
    unawaited(Haptics.alert());
    _flashAlert();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final lines = [for (final e in fresh.take(3)) eventSentence(e.$1, e.$2, loc.lat, loc.lon)];
    final linesEn = [for (final e in fresh.take(3)) eventSentenceEn(e.$1, e.$2, loc.lat, loc.lon)];
    await _s.speaker.say('Cảnh báo thiên tai gần ${loc.vi}, theo vệ tinh NASA. ${lines.join(' ')} '
        'Hãy theo dõi thêm thông báo của cơ quan khí tượng và chính quyền địa phương.',
        'Natural hazard alert near ${loc.en}, from NASA satellites. ${linesEn.join(' ')} Please follow official local warnings.');
  }

  Future<void> _disasters(WCmd c) async {
    final s = _s;
    s.earcon('tick');
    List<NaturalEvent> all;
    try {
      all = await _eonet.open();
    } catch (_) {
      s.earcon('err');
      // mất mạng: vẫn kể được thiên tai đã xảy ra từ danh mục NASA có sẵn trong app
      final loc = c.aspect == 'world' ? null : (c.target.isEmpty ? await _hereFor(c.raw) : await _resolve(c.target));
      final past = loc == null ? ('', '') : await _pastDisasters(loc);
      if (loc != null && past.$1.isNotEmpty) await _goTo(loc);
      await s.speaker.say('Chưa lấy được tin thiên tai đang diễn ra của NASA. ${past.$1.isEmpty ? 'Kiểm tra mạng rồi thử lại.' : past.$1}',
          'Could not get live NASA hazard data. ${past.$2.isEmpty ? 'Check the connection.' : past.$2}');
      return;
    }
    if (mounted) setState(() => _events = all);
    if (c.aspect == 'world') {
      final counts = <String, int>{};
      for (final e in all) {
        counts[e.kindVi] = (counts[e.kindVi] ?? 0) + 1;
      }
      final storms = [for (final e in all) if (e.category == 'severeStorms') e];
      final top = <NaturalEvent>[...storms.take(3), ...all.where((e) => e.category == 'volcanoes').take(1)];
      _focus = null;
      _pin = null;
      await _flyTo(_cam.copyWith(zoom: 1.0));
      final parts = [
        for (final e in top) '${e.kindVi} ${e.title} ở ${_world?.placeName(e.lon, e.lat).$1 ?? ''}',
      ];
      final partsEn = [
        for (final e in top) '${e.title}, near ${_world?.placeName(e.lon, e.lat).$2 ?? 'open sea'}',
      ];
      // người khiếm thị không thấy chấm đỏ → nói vị trí bằng lời và cách hỏi tiếp
      await s.speaker.say(
          'Theo NASA EONET, trên thế giới đang theo dõi ${all.length} sự kiện: '
              '${counts.entries.map((e) => '${e.value} vụ ${e.key}').join(', ')}. '
              '${parts.isEmpty ? '' : 'Đáng chú ý: ${parts.join('; ')}. '}Muốn biết gần một nơi có gì, nói: thiên tai ở, rồi tên nơi đó.',
          'NASA is tracking ${all.length} natural events around the world. '
              '${partsEn.isEmpty ? '' : 'Notable: ${partsEn.join('; ')}. '}To check one place, say: disasters near, then the place.');
      return;
    }
    final loc = c.target.isEmpty ? await _hereFor(c.raw) : await _resolve(c.target);
    if (loc == null) return _notFound(c.target);
    await _goTo(loc);
    final near = await _eonet.near(loc.lat, loc.lon, km: 1000);
    if (near.isEmpty) {
      // không có sự kiện ĐANG diễn ra → kể luôn thiên tai ĐÃ xảy ra quanh đó (danh mục NASA đóng gói sẵn)
      final past = await _pastDisasters(loc);
      await s.speaker.say(
          'Theo NASA EONET, hiện không có bão, lũ, cháy rừng hay núi lửa nào đang được theo dõi trong vòng 1000 ki-lô-mét quanh ${loc.vi}. ${past.$1}',
          'NASA EONET shows no tracked storms, floods, wildfires or volcanoes within 1000 km of ${loc.en}. ${past.$2}');
      return;
    }
    if (near.first.$2 <= 500) {
      s.audio.alarm();
      unawaited(Haptics.alert());
      _flashAlert();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    for (final e in near) {
      _alerted.add(e.$1.id);
    }
    await s.speaker.say(
        'Quanh ${loc.vi}, NASA đang theo dõi ${near.length} sự kiện. '
            '${[for (final e in near.take(4)) eventSentence(e.$1, e.$2, loc.lat, loc.lon)].join(' ')}',
        'NASA is tracking ${near.length} natural events near ${loc.en}. '
            '${[for (final e in near.take(4)) eventSentenceEn(e.$1, e.$2, loc.lat, loc.lon)].join(' ')}');
  }

  /// Thiên tai ĐÃ xảy ra quanh một nơi, từ danh mục NASA đóng gói sẵn (vn_disasters_nasa.json: GDIS, GLC, EONET…).
  /// Trả về ('', '') nếu không có bản ghi nào (ví dụ nơi ở nước ngoài).
  Future<(String, String)> _pastDisasters(_Loc loc) async {
    final evs = vnCatalogEvents(await HazardHistoryService.vnCatalog(), loc.lat, loc.lon, DateTime(1900),
        DateTime.now().add(const Duration(days: 1)));
    if (evs.isEmpty) return ('', '');
    final counts = <HazardKind, int>{};
    var first = evs.first.date.year;
    for (final e in evs) {
      counts[e.kind] = (counts[e.kind] ?? 0) + 1;
      if (e.date.year < first) first = e.date.year;
    }
    final order = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final recent = ([...evs]..sort((a, b) => b.date.compareTo(a.date))).take(2).toList();
    final vi = 'Trong hồ sơ thiên tai của NASA từ năm $first, vùng quanh ${loc.vi} từng có '
        '${[for (final e in order) '${e.value} vụ ${hazardNameVi(e.key)}'].join(', ')}. '
        'Gần đây nhất: ${[for (final e in recent) e.yearOnly ? e.titleVi : '${e.titleVi}, tháng ${e.date.month} năm ${e.date.year}'].join('; ')}. '
        'Muốn nghe phát lại bằng âm thanh, nói: lịch sử thiên tai ${loc.vi}.';
    final en = 'In NASA disaster records since $first, the area around ${loc.en} has had '
        '${[for (final e in order) '${hazardNameEn(e.key)}: ${e.value}'].join(', ')}. '
        'Most recent: ${[for (final e in recent) e.yearOnly ? e.titleEn : '${e.titleEn}, ${e.date.month}/${e.date.year}'].join('; ')}. '
        'To replay it as sound, say: disaster history ${loc.en}.';
    return (vi, en);
  }

  // ======================= Bản tin =======================
  Future<void> _bulletin(_Loc loc) async {
    final s = _s;
    final wf = _weatherOf(loc);
    await _goTo(loc);
    final w = await wf;
    if (w == null || !mounted) return;
    if (await _ambient(w)) await Future<void>.delayed(const Duration(milliseconds: 900));
    final b = morningBulletin(loc.vi, loc.en, w);
    await s.speaker.say(b.$1, b.$2);
    if (!mounted || _storyStop) return;
    List<(NaturalEvent, double)> near = const [];
    try {
      near = await _eonet.near(loc.lat, loc.lon, km: 800).timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (near.isNotEmpty) {
      await _alertNear(loc, km: 800);
    } else {
      await s.speaker.say('Vệ tinh NASA chưa ghi nhận thiên tai lớn nào gần đây.', 'No major hazards nearby.');
    }
    if (!mounted || s.speaker.busy) return;
    await _sound.now(w);
  }

  /// Các chỉ số: nhiệt độ, cảm giác, trời, độ ẩm, gió, mưa hôm nay, UV, không khí, kèm gợi ý thực tế.
  (String, String) _indices(_Loc loc, LiveWeather w, {bool short = false, bool isLocal = false}) {
    final n = w.now;
    final today = w.days.isNotEmpty ? w.days.first : null;
    final vi = StringBuffer('${loc.vi}, bây giờ ${_n(n.temp)} độ');
    final en = StringBuffer('${loc.en}, now ${_n(n.temp)} degrees');
    if (n.desc.isNotEmpty) {
      vi.write(', ${n.desc}');
      en.write(', ${n.desc}');
    }
    if ((n.feels - n.temp).abs() >= 2) {
      vi.write(', cảm giác như ${_n(n.feels)} độ');
      en.write(', feels like ${_n(n.feels)}');
    }
    vi.write('. ');
    en.write('. ');
    if (today != null) {
      vi.write('Hôm nay từ ${_n(today.tmin)} đến ${_n(today.tmax)} độ');
      en.write('Today ${_n(today.tmin)} to ${_n(today.tmax)} degrees');
      if (today.rainProb != null) {
        vi.write(', khả năng mưa ${today.rainProb} phần trăm');
        en.write(', ${today.rainProb} percent chance of rain');
      }
      vi.write('. ');
      en.write('. ');
    }
    if (!short) {
      vi.write('Độ ẩm ${n.humidity} phần trăm. Gió ${_n(n.wind)} ki-lô-mét một giờ${n.windDir != null ? ', hướng ${n.windDir}' : ''}. ');
      en.write('Humidity ${n.humidity} percent. Wind ${_n(n.wind)} kilometres per hour. ');
      final uv = n.uv ?? today?.uv;
      if (uv != null) {
        vi.write('Chỉ số UV ${_n(uv)}${uv >= 6 ? ', cao, nên che nắng' : ''}. ');
        en.write('UV index ${_n(uv)}${uv >= 6 ? ', high' : ''}. ');
      }
      if (w.aqi != null) {
        final a = w.aqi!;
        final word = a > 150 ? 'xấu' : (a > 100 ? 'kém' : (a > 50 ? 'trung bình' : 'tốt'));
        vi.write('Không khí $word, chỉ số AQI $a. ');
        en.write('Air quality index $a. ');
      }
    }
    final r = rainNext(w, hours: 6);
    vi.write(r.$1);
    en.write(r.$2);
    if (!short) {
      final sug = contextualSuggestion(loc.vi, loc.en, w, day: 0, isLocal: isLocal);
      vi.write(' ${sug.$1}');
      en.write(' ${sug.$2}');
    }
    return (vi.toString().trim(), en.toString().trim());
  }

  Future<void> _readWeatherKind(WCmd c, _Loc loc, LiveWeather w) async {
    final s = _s;
    final isLocal = _isLocalPlace(loc, c.raw);
    switch (c.kind) {
      case WKind.forecast:
        // "3 ngày tới" → từ ngày mai, 3 ngày; "dự báo" không kèm số → 5 ngày từ hôm nay
        final n = c.liveDay;
        final t = c.aspect == 'weekend'
            ? weekendText(loc.vi, loc.en, w)
            : (n == null ? weekText(loc.vi, loc.en, w) : weekText(loc.vi, loc.en, w, days: n, from: 1));
        await s.speaker.say(t.$1, t.$2);
      case WKind.hours:
        await s.speaker.say('24 giờ tới ở ${loc.vi}: mỗi giờ một nốt đàn bầu từ trái sang phải, nốt cao là nóng, '
            'tiếng lách cách là có thể mưa.', 'Next 24 hours in ${loc.en}: one note per hour, left to right.');
        await _sound.hours(w);
      case WKind.music:
        await _sound.now(w);
      default:
        final day = c.liveDay;
        final dd = day ?? 0;
        // câu hỏi cần lời khuyên: nhờ trợ lý AI trả lời tự nhiên (nếu có), lỗi thì dùng lời khuyên có sẵn
        if ((c.aspect == 'advice' || c.aspect == 'outing') && s.ai.enabled && await _aiAnswer(c.raw, loc, w)) return;
        final parts = <(String, String)>[];
        switch (c.aspect) {
          case 'rain':
            parts.add(c.period != null
                ? periodRainAnswer(loc.vi, loc.en, w, dd, c.period!)
                : rainAnswer(loc.vi, loc.en, w, dd));
          case 'outing':
            parts.add(outingAnswer(loc.vi, loc.en, w, dd));
            parts.add(contextualSuggestion(loc.vi, loc.en, w, day: dd, isLocal: isLocal));
          // hỏi một chỉ số → chỉ trả lời chỉ số đó
          case 'temp':
            parts.add(tempAnswer(loc.vi, loc.en, w, dd, period: c.period));
          case 'sky':
            parts.add(skyAnswer(loc.vi, loc.en, w, dd, period: c.period));
          case 'sun':
            parts.add(sunAnswer(loc.vi, loc.en, w, dd));
          case 'dry':
            parts.add(dryAnswer(loc.vi, loc.en, w, dd));
          case 'humid':
            parts.add(humidAnswer(loc.vi, loc.en, w));
          case 'wind':
            parts.add(windAnswer(loc.vi, loc.en, w, dd));
          case 'uv':
            parts.add(uvAnswer(loc.vi, loc.en, w, dd));
          case 'air':
            parts.add(airAnswer(loc.vi, loc.en, w));
          case 'advice':
            if (w.days.length > dd) parts.add(dayText(loc.vi, loc.en, w.days[dd]));
            parts.add(contextualSuggestion(loc.vi, loc.en, w, day: dd, isLocal: isLocal));
          default:
            if (c.period != null) {
              parts.add(periodRainAnswer(loc.vi, loc.en, w, dd, c.period!));
            } else if (dd == 0) {
              parts.add(_indices(loc, w, isLocal: isLocal));
            } else if (w.days.length > dd) {
              parts.add(dayText(loc.vi, loc.en, w.days[dd]));
              parts.add(contextualSuggestion(loc.vi, loc.en, w, day: dd, isLocal: isLocal));
            }
        }
        await s.speaker.say(parts.map((e) => e.$1).join(' '), parts.map((e) => e.$2).join(' '));
        for (var i = 0; i < 20 && s.speaker.busy && mounted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        if (mounted) await _sound.now(w);
    }
  }

  /// So sánh thời tiết hai nơi ("Hà Nội và Đà Nẵng nơi nào nóng hơn").
  Future<void> _compare(WCmd c) async {
    final s = _s;
    final parts = c.target.split('|');
    if (parts.length != 2) return;
    final a = await _resolve(parts[0]), b = await _resolve(parts[1]);
    if (a == null) return _notFound(parts[0]);
    if (b == null) return _notFound(parts[1]);
    final wa = await _weatherOf(a), wb = await _weatherOf(b);
    if (wa == null || wb == null) return;
    await _goTo(b);
    final t = compareAnswer(a.vi, a.en, wa, b.vi, b.en, wb, c.liveDay ?? 0);
    await s.speaker.say(t.$1, t.$2);
  }

  /// Thực thi công cụ đa năng cho AI Agent (RAG theo yêu cầu).
  Future<Map<String, Object?>> _executeAgentTool(String name, Map<String, Object?> args) async {
    final s = _s;
    switch (name) {
      case 'lay_thoi_tiet':
        final place = '${args['noi'] ?? ''}'.trim();
        if (place.isEmpty) return {'loi': 'Tên địa danh không được để trống'};
        final l = await _resolve(place);
        if (l == null) return {'loi': 'Không tìm thấy địa danh "$place"'};
        final w = await s.weather.get(l.lat, l.lon, lang: s.lang);
        return {'noi': l.vi, 'thoi_tiet': w.toJson()};
      case 'tra_cuu_dia_danh':
        final ten = '${args['ten_hoac_vung'] ?? args['ten'] ?? ''}'.trim();
        return EarthRag.lookupLandmark(ten);
      case 'tra_cuu_dia_hinh':
        final ten = '${args['dia_diem'] ?? args['ten'] ?? ''}'.trim();
        return EarthRag.lookupTerrain(ten);
      case 'tra_cuu_vu_tru':
        final ten = '${args['doi_tuong'] ?? args['ten'] ?? ''}'.trim();
        return EarthRag.lookupSpace(ten);
      case 'tra_cuu_khi_hau_nasa':
        final noi = '${args['noi'] ?? ''}'.trim();
        final l = noi.isNotEmpty ? await _resolve(noi) : _here();
        if (l == null) return {'loi': 'Không tìm thấy địa danh "$noi" để lấy dữ liệu khí hậu NASA'};
        return EarthRag.lookupNasaClimate(l.lat, l.lon, l.vi, _nasa);
      default:
        return {'loi': 'Không hỗ trợ công cụ $name'};
    }
  }

  /// Trợ lý AI trả lời câu hỏi tự do bằng số liệu thật đã có + RAG. true nếu đã trả lời.
  Future<bool> _aiAnswer(String question, _Loc loc, LiveWeather w) async {
    final s = _s;
    final isLocal = _isLocalPlace(loc, question);
    final homeName = s.home?.name ?? '';
    Stats.instance.track('ai');
    final now = DateTime.now();
    final ragContext = EarthRag.extractContext(question, place: loc.vi, lat: loc.lat, lon: loc.lon, lang: s.lang);
    try {
      final answer = await s.ai.ask(question,
          known: {loc.vi: w},
          ragContext: ragContext,
          lang: s.lang,
          context: 'Bây giờ là ${now.hour} giờ ${now.minute}, ngày ${now.day}/${now.month}/${now.year}. '
              'Người hỏi là người khiếm thị: trả lời ngắn (2-4 câu), sinh động, trực quan. '
              'Nơi đang xem: ${loc.vi} (tọa độ ${loc.lat.toStringAsFixed(2)}, ${loc.lon.toStringAsFixed(2)}). '
              '${isLocal ? 'Đây là khu vực người dùng đang ở: hãy gợi ý ngắn gọn người dùng cần chuẩn bị gì hoặc lưu ý gì khi ra ngoài.' : 'Đây là nơi khác${homeName.isNotEmpty ? ' (nhà của người dùng ở $homeName)' : ''}: hãy gợi ý ngắn gọn hành trang hoặc lưu ý cần thiết nếu người dùng đến nơi này hoặc ra ngoài tại đây.'} '
              'Hoàng Sa và Trường Sa là của Việt Nam.',
          toolHandler: _executeAgentTool,
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return true;
      await s.speaker.say(answer, answer);
      for (var i = 0; i < 20 && s.speaker.busy && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (mounted) await _sound.now(w);
      return true;
    } catch (e) {
      CrashGuard.log('[trợ lý AI] $e → dùng lời khuyên có sẵn');
      return false;
    }
  }

  Future<void> _readAt(double lat, double lon) async {
    final n = _world?.placeName(lon, lat) ?? ('chỗ này', 'here');
    await _goAndRead(_Loc(n.$1, n.$2, lat, lon, math.max(_cam.zoom, 3)));
  }

  Future<void> _sayWhere() async {
    final n = _world?.placeName(_cam.lon, _cam.lat) ?? ('', '');
    final z = _cam.zoom;
    final level = z < 1.3 ? ('cả quả địa cầu', 'the whole globe') : (z < 4 ? ('một vùng lớn', 'a large region') : (z < 12 ? ('một nước', 'a country') : ('một thành phố', 'a city')));
    final f = _focus;
    await _s.speaker.say(
        'Đang xem ${level.$1}, ở giữa là ${n.$1}${f != null && z > 3 ? '. Nơi vừa nói tới: ${f.vi}' : ''}.',
        'Showing ${level.$2}, centred on ${n.$2}${f != null && z > 3 ? '. Last place: ${f.en}' : ''}.');
  }

  // ---------- Khí hậu NASA ----------
  Future<void> _climate(_Loc loc, int? month, int? year) async {
    final s = _s;
    Stats.instance.track('map');
    NasaClimate c;
    try {
      c = await _nasa.climate(loc.lat, loc.lon);
    } on LiveError catch (e) {
      s.earcon('err');
      await s.speaker.say(e.vi, e.en);
      return;
    }
    if (!mounted) return;
    const mVi = 'tháng';
    if (year != null && (year < c.y0 || year > c.y1)) {
      await s.speaker.say('Dữ liệu NASA ở đây có từ năm ${c.y0} đến năm ${c.y1}.', 'NASA data here covers ${c.y0} to ${c.y1}.');
      return;
    }
    if (month != null) {
      final y = year ?? c.y1;
      final t = c.tempMonth[y]![month], r = c.rainMonth[y]![month];
      final tn = c.monthNormal(c.tempMonth, month), rn = c.monthNormal(c.rainMonth, month);
      final dt = t - tn;
      final dr = rn > 1 ? (r / rn - 1) * 100 : double.nan;
      await s.speaker.say(
          'Theo NASA, $mVi ${month + 1} năm $y ở ${loc.vi}: nhiệt độ trung bình ${_dec(t)} độ, '
              '${dt.abs() < 0.2 ? 'gần bằng' : (dt > 0 ? 'cao hơn ${_dec(dt)} độ so với' : 'thấp hơn ${_dec(-dt)} độ so với')} '
              'trung bình các năm. Mưa ${_n(r)} mi-li-mét'
              '${dr.isNaN ? '' : (dr.abs() < 10 ? ', gần bằng bình thường' : (dr > 0 ? ', nhiều hơn bình thường ${_n(dr)} phần trăm' : ', ít hơn bình thường ${_n(-dr)} phần trăm'))}. '
              'Bây giờ nghe 12 tháng của năm $y.',
          'NASA: month ${month + 1} of $y in ${loc.en}: average ${_dec(t)} degrees, ${dt >= 0 ? '${_dec(dt)} above' : '${_dec(-dt)} below'} normal. '
              'Rain ${_n(r)} millimetres. Now the 12 months of $y.');
      await _sound.months(c.tempMonth[y]!, c.rainMonth[y]!);
      return;
    }
    if (year != null) {
      final k = year - c.y0;
      final t = c.tempYear[k], r = c.rainYear[k];
      final tAll = c.tempYear.where((x) => !x.isNaN), rAll = c.rainYear.where((x) => !x.isNaN);
      final tm = tAll.reduce((a, b) => a + b) / tAll.length, rm = rAll.reduce((a, b) => a + b) / rAll.length;
      await s.speaker.say(
          'Theo NASA, năm $year ở ${loc.vi}: nhiệt độ trung bình ${_dec(t)} độ, ${t >= tm ? 'cao hơn' : 'thấp hơn'} '
              'trung bình các năm ${_dec((t - tm).abs())} độ. Tổng mưa ${_n(r)} mi-li-mét, trung bình các năm ${_n(rm)}. '
              'Nghe 12 tháng của năm $year.',
          'NASA, $year in ${loc.en}: average ${_dec(t)} degrees, ${_dec((t - tm).abs())} ${t >= tm ? 'above' : 'below'} normal. '
              'Rain ${_n(r)} millimetres. The 12 months of $year.');
      await _sound.months(c.tempMonth[year]!, c.rainMonth[year]!);
      return;
    }
    // xu hướng dài hạn: ERA5 (một nguồn thống nhất); chuỗi NASA POWER ở Việt Nam có bước nhảy theo thời gian.
    // Không lấy được ERA5 (mất mạng) thì chỉ đọc mức gần đây của NASA POWER, KHÔNG nói xu hướng.
    EraTrend? tr;
    try {
      tr = await _nasa.extremes(loc.lat, loc.lon);
    } catch (_) {}
    if (!mounted) return;
    final rt = c.recent(c.tempYear), rr = c.recent(c.rainYear);
    if (tr == null) {
      await s.speaker.say(
          'Khí hậu ở ${loc.vi} theo NASA POWER: mười năm gần đây trung bình ${_dec(rt)} độ, mưa khoảng ${_n(rr)} mi-li-mét một năm. '
              'Cần mạng để so sánh xưa và nay bằng một nguồn số liệu thống nhất. Bây giờ nghe 12 tháng trung bình.',
          'Climate of ${loc.en} from NASA POWER: the last ten years averaged ${_dec(rt)} degrees and about ${_n(rr)} millimetres of rain a year. '
              'Comparing past and present needs a connection. Now the 12 average months.');
      if (!mounted) return;
      await _sound.months([for (var m = 0; m < 12; m++) c.monthNormal(c.tempMonth, m)], [for (var m = 0; m < 12; m++) c.monthNormal(c.rainMonth, m)]);
      return;
    }
    final t = tr;
    final dt = t.t1 - t.t0;
    final dr = t.rain0 > 1 ? (t.rain1 / t.rain0 - 1) * 100 : double.nan;
    await s.speaker.say(
        'Khí hậu ở ${loc.vi}, từ năm ${t.y0} đến năm ${t.y1}. '
            'Mười năm gần đây trung bình ${_dec(t.t1)} độ, '
            '${dt.abs() < 0.1 ? 'gần như không đổi so với thập niên 1980' : (dt > 0 ? 'ấm hơn thập niên 1980 ${_dec(dt)} độ' : 'mát hơn thập niên 1980 ${_dec(-dt)} độ')}. '
            'Năm nóng nhất là năm ${t.hottestYear()}. '
            'Mưa trung bình ${_n(t.rain1)} mi-li-mét một năm'
            '${dr.isNaN || dr.abs() < 5 ? '' : (dr > 0 ? ', nhiều hơn thập niên 1980 ${_n(dr)} phần trăm' : ', ít hơn thập niên 1980 ${_n(-dr)} phần trăm')}. '
            '${DataCard.audioIntroVi('app_sonification')} '
            'Nguồn xu hướng: dữ liệu tái phân tích khí hậu ERA5, một nguồn thống nhất cho cả chuỗi năm; '
            'NASA POWER cho số liệu từng tháng; bối cảnh toàn cầu: NASA GISTEMP v4. '
            'Bây giờ nghe ${t.y1 - t.y0 + 1} năm: mỗi năm một nốt đàn bầu từ trái sang phải, nốt càng cao năm càng nóng, '
            'tiếng mõ đánh dấu mỗi mười năm, tiếng lách cách là năm mưa nhiều.',
        'Climate of ${loc.en}, ${t.y0} to ${t.y1}. The last ten years averaged ${_dec(t.t1)} degrees, '
            '${dt >= 0 ? '${_dec(dt)} warmer' : '${_dec(-dt)} cooler'} than the 1980s. The hottest year was ${t.hottestYear()}. '
            '${DataCard.audioIntroEn('app_sonification')} Trend source: ERA5 climate reanalysis (one consistent record); '
            'monthly values: NASA POWER; global context: NASA GISTEMP v4. '
            'Now ${t.y1 - t.y0 + 1} years, one note each, left to right; higher means hotter, the wood block marks each decade.');
    if (!mounted) return;
    await _sound.years(t.asYears(loc.lat, loc.lon));
  }

  Future<void> _day(_Loc loc, DateTime d) async {
    final s = _s;
    try {
      final r = await _nasa.day(loc.lat, loc.lon, d);
      if (!mounted) return;
      final today = DateTime.now();
      final past = DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day));
      await s.speaker.say(
          'Ngày ${d.day} tháng ${d.month} năm ${d.year} ở ${loc.vi}: ${r.desc.isEmpty ? '' : '${r.desc}, '}'
              'từ ${_n(r.tmin)} đến ${_n(r.tmax)} độ, ${past ? 'mưa' : 'dự báo mưa'} ${_n(r.rain)} mi-li-mét, '
              'gió mạnh nhất ${_n(r.wind)} ki-lô-mét một giờ.',
          '${d.day}/${d.month}/${d.year} in ${loc.en}: ${_n(r.tmin)} to ${_n(r.tmax)} degrees, '
              'rain ${_n(r.rain)} millimetres, wind up to ${_n(r.wind)} kilometres per hour.');
      await _sound.day(r);
    } on LiveError catch (e) {
      s.earcon('err');
      await s.speaker.say(e.vi, e.en);
    }
  }

  // ---------- Không hiểu: nhờ trợ lý AI (nếu có), tránh nói "chưa hiểu" liên tục vì tiếng ồn ----------
  bool _inCanon = false;
  int _goHints = 0;

  /// Hỏi cửa hàng, công ty… (app vẫn gợi ý ẩm thực, địa điểm ăn uống vui chơi theo từng xã, phường).
  static final _shopRe = RegExp(r'\b(salon|tiem|cua hang|'
      r'sieu thi|tap hoa|cay xang|atm|ngan hang|khach san|nha nghi|cong ty|van phong|cang noi dia|kho hang|shop|spa|'
      r'gym|phong kham|nha thuoc|hieu thuoc|karaoke|quan bar)\b');

  /// Xử lý trực tiếp các truy vấn thuộc bộ dữ liệu chuẩn hóa NASA:
  ///  1) "nguồn dữ liệu" / "dữ liệu lấy ở đâu" / "data source" → đọc to thẻ nguồn dữ liệu (Data Card)
  ///  2) Sự kiện thiên tai lịch sử (Siêu bão Yagi 09/2024, Mưa lũ lịch sử miền Trung 10/2020) → bay tới + đọc + phát nhạc cụ chuỗi ngày
  ///  3) Điểm cháy rừng theo mùa NASA FIRMS (MODIS MCD14ML) → đọc + phát nhạc cụ "tiếng lửa khô" 12 tháng
  ///  4) Chuỗi ấm lên toàn cầu NASA GISTEMP v4 (1880–2025) → đọc + phát đàn bầu 146 năm
  ///  5) Âm thanh vũ trụ & mô tả trợ năng chuẩn Mục 508 (space_media.json) → đọc lời giới thiệu audio_kind + mô tả + phát âm thanh
  ///  6) Câu hỏi kiểm chứng / đính chính nhận thức sai trong qa_bank.json → đọc trả lời chuẩn + nguồn NASA
  Future<bool> _handleNasaNormalizedQuery(String raw) async {
    final s = _s;
    final en = s.lang == 'en';
    final q = normVi(raw);
    if (q.isEmpty) return false;
    final repo = NasaNormalizedRepo.cached ?? await NasaNormalizedRepo.load();
    if (!mounted) return false;

    // 1. Khẩu lệnh hỏi "nguồn dữ liệu" / "dữ liệu lấy ở đâu" / "data source"
    if (RegExp(r'\b(nguon du lieu|du lieu lay o dau|du lieu tu dau|nguon cua du lieu|the nguon du lieu|data source|where is the data from|data card)\b')
        .hasMatch(q)) {
      if (_planet != null || _solar) {
        final msgVi = '${repo.planetCard.spokenSummary(en: false)} ${repo.qaCard.spokenSummary(en: false)}';
        final msgEn = '${repo.planetCard.spokenSummary(en: true)} ${repo.qaCard.spokenSummary(en: true)}';
        await s.speaker.say(msgVi, msgEn);
      } else if (_local != null || _terrainTouch) {
        await s.speaker.say(repo.dalatScene.dataCard.spokenSummary(en: false), repo.dalatScene.dataCard.spokenSummary(en: true));
      } else {
        final msgVi =
            '${repo.climateCard.spokenSummary(en: false)} ${repo.gistempCard.spokenSummary(en: false)} ${repo.firmsCard.spokenSummary(en: false)} ${repo.dalatScene.dataCard.spokenSummary(en: false)}';
        final msgEn =
            '${repo.climateCard.spokenSummary(en: true)} ${repo.gistempCard.spokenSummary(en: true)} ${repo.firmsCard.spokenSummary(en: true)} ${repo.dalatScene.dataCard.spokenSummary(en: true)}';
        await s.speaker.say(msgVi, msgEn);
      }
      return true;
    }

    // 2. Sự kiện thiên tai lịch sử có chuỗi ngày chuẩn hóa NASA POWER (Siêu bão Yagi 2024, Mưa lũ lịch sử miền Trung 2020)
    final histEv = repo.matchHistoricalEvent(raw);
    if (histEv != null) {
      final loc = _Loc(histEv.titleVi, histEv.titleVi, histEv.lat, histEv.lon, 18);
      await _goTo(loc);
      if (!mounted) return true;
      await s.speaker.say(histEv.spokenSummary(en: false), histEv.spokenSummary(en: true));
      if (!mounted) return true;
      await _sound.eventDays(histEv.days);
      return true;
    }

    // 3. Điểm cháy rừng theo mùa NASA FIRMS (MODIS Collection 6.1 MCD14ML)
    if (RegExp(r'\b(diem chay|mua chay rung|du lieu chay rung|firms|mcd14ml|chay rung theo mua|chay rung o tay nguyen|chay rung tay nguyen|chay rung tay bac|chay rung bac trung bo|chay rung dong nam bo)\b')
        .hasMatch(q)) {
      final fr = repo.findFirmsRegion(raw);
      await s.speaker.say(fr.spokenSummary(en: false), fr.spokenSummary(en: true));
      if (!mounted) return true;
      await _sound.fireHotspots(fr.monthlyHotspots);
      return true;
    }

    // 4. Chuỗi dị thường nhiệt độ toàn cầu NASA GISTEMP v4 (1880–2025)
    if (RegExp(r'\b(gistemp|nong len toan cau|am len toan cau|nhiet do toan cau|di thuong nhiet do|trai dat nong len|trai dat am len|global warming|global temperature)\b')
        .hasMatch(q)) {
      await s.speaker.say(repo.gistempSummaryText(en: false), repo.gistempSummaryText(en: true));
      if (!mounted) return true;
      await _sound.gistempYears(repo.gistempSeries);
      return true;
    }

    // 5. Âm thanh vũ trụ & mô tả trợ năng chuẩn Mục 508 (space_media.json)
    final media = repo.matchSpaceMedia(raw);
    if (media != null && media.id == 'voyager_interstellar_plasma') {
      await _nasaSound('interstellar_plasma'); // có bản ghi thật của NASA → phát bản thật
      return true;
    }
    if (media != null) {
      final soundIdx = q.contains('sao hoa') || q.contains('perseverance')
          ? 5
          : q.contains('mat trang') || q.contains('apollo')
              ? 4
              : q.contains('trai dat') || q.contains('vien bi xanh')
                  ? 3
                  : 6;
      s.audio.planet(soundIdx, amp: 0.32);
      await s.speaker.say(media.spokenIntro(en: false), media.spokenIntro(en: true));
      return true;
    }

    // 6. Các câu hỏi đính chính nhận thức sai / câu hỏi khoa học đặc thù trong qa_bank.json
    if (RegExp(r'\b(trai dat (co )?phang|tron hay phang|nong hon|nong nhat|vanh dai|diem vuong|pluto|nam anh sang|tu phat sang|ai quay quanh|vi sao co mua|nguyen nhan cac mua|phang hay tron|hinh cau|im lang|chan khong|lo den|hut bui|sao bac cuc|van ly truong thanh|thien thach|mat toi|nua toi|mau vang hay trang|mat troi mau gi|cac mua trong nam|nuoc bien dang|hieu ung nha kinh|voyager|parker|ingenuity|artemis|james webb|srtm|modis)\b')
        .hasMatch(q)) {
      final qa = repo.matchQa(raw);
      if (qa != null) {
        final ans = qa.spokenAnswer(en: en);
        await s.speaker.say(ans, ans);
        return true;
      }
    }

    return false;
  }

  Future<void> _unknown(String raw) async {
    final s = _s;
    final words = normVi(raw).split(' ').where((w) => w.isNotEmpty).length;
    // chỉ là tiếng ậm ừ lúc nghĩ ("ừm à ờ", "uh hmm") → im lặng chờ câu thật, không nói "chưa hiểu"
    if (isFillerOnly(raw)) {
      CrashGuard.log('[lệnh] bỏ qua tiếng ậm ừ: "$raw"');
      return;
    }
    // Kiểm tra ngân hàng Hỏi – Đáp kiểm chứng NASA (qa_bank.json) trước khi gọi AI
    final repo = NasaNormalizedRepo.cached ?? await NasaNormalizedRepo.load();
    final qaHit = repo.matchQa(raw);
    if (qaHit != null) {
      final ans = qaHit.spokenAnswer(en: s.lang == 'en');
      await s.speaker.say(ans, ans);
      return;
    }
    // Nếu hỏi món ngon / đặc sản / ăn uống vui chơi ở Hà Nội (vd: "Hà Nội có món gì ngon") → trả lời ngay cẩm nang Hà Nội
    if (RegExp(r'\b(mon gi|dac san|co gi ngon|an gi|an uong|vui choi|dia diem)\b').hasMatch(normVi(raw)) &&
        (RegExp(r'\b(ha noi|thu do)\b').hasMatch(normVi(raw)) || findHanoiZone(name: raw, matchKeywordOnly: true) != null)) {
      final hz = findHanoiZone(name: raw, matchKeywordOnly: true);
      final hg = buildHanoiGuide(
        hz?.nameVi ?? 'Hà Nội',
        hz?.nameEn ?? 'Hanoi',
        lat: hz?.lat ?? 21.0285,
        lon: hz?.lon ?? 105.8542,
        raw: raw,
      );
      if (hg != null) {
        await s.speaker.say(hg.$1, hg.$2);
        return;
      }
    }
    if (_shopRe.hasMatch(normVi(raw))) {
      s.earcon('err');
      await s.speaker.say(
          'Mình không tra địa chỉ tiệm, khách sạn, ngân hàng hay công ty riêng lẻ, nhưng có thể gợi ý các địa điểm vui chơi, du lịch và thời tiết tại từng xã, phường. '
              'Bạn thử nói: phường Hoàn Kiếm có gì chơi, hoặc thời tiết chỗ tôi.',
          'I do not look up individual shops, hotels or offices, but I can suggest places to visit and the weather for each ward or commune. '
              'Try: what to do in Hoan Kiem ward, or weather here.');
      return;
    }
    // NÓI KHÁC CÁCH (đồng nghĩa): nhờ AI đổi thành một câu lệnh chuẩn trong danh sách, rồi bộ hiểu lệnh của app kiểm tra
    // lại câu chuẩn đó ("harness") — AI không thể bắt app làm gì ngoài các lệnh có sẵn
    if (words >= 2 && s.ai.enabled && !_inCanon) {
      _inCanon = true;
      try {
        final canon = await s.ai.canonicalCommand(raw, lang: s.lang);
        if (canon != null && mounted) {
          final c = parseWorld(canon);
          CrashGuard.log('[AI hiểu lệnh] "$raw" → "$canon" → $c');
          if (c.kind != WKind.unknown && c.kind != WKind.ignore) {
            if (c.kind != WKind.unknown) _lastCmd = c;
            await _run(c);
            return;
          }
        }
      } finally {
        _inCanon = false;
      }
    }
    final pl = _planet;
    if (pl != null && words >= 2) return _askPlanet(pl, raw);
    if (words >= 1 && s.ai.enabled) {
      Stats.instance.track('ai');
      final loc = _here();
      final known = <String, LiveWeather>{};
      final w = _weatherAt(loc) ?? await _weatherOf(loc);
      if (w != null) known[loc.vi] = w;
      final now = DateTime.now();
      final ragContext = EarthRag.extractContext(raw, place: loc.vi, lat: loc.lat, lon: loc.lon, lang: s.lang);
      try {
        final isLocal = _isLocalPlace(loc, raw);
        final homeName = s.home?.name ?? '';
        final answer = await s.ai.ask(raw,
            known: known,
            ragContext: ragContext,
            lang: s.lang,
            context: 'Bây giờ là ${now.hour} giờ ${now.minute}, ngày ${now.day}/${now.month}/${now.year}. '
                'Người dùng là người khiếm thị, đang dùng quả địa cầu nói; nơi đang xem: ${loc.vi} '
                '(tọa độ ${loc.lat.toStringAsFixed(2)}, ${loc.lon.toStringAsFixed(2)}). '
                '${isLocal ? 'Đây là khu vực người dùng đang ở.' : (homeName.isNotEmpty ? 'Nơi ở của người dùng là $homeName.' : '')} '
                'Hoàng Sa và Trường Sa là của Việt Nam.',
            lookup: (name) async {
              final l = await _resolve(name);
              if (l == null) return null;
              return (l.vi, await s.weather.get(l.lat, l.lon, lang: s.lang));
            },
            lookupLandmark: (query) async {
              final l = landmarkIn(query);
              if (l != null) return '${l.name} (${l.province}): ${s.lang == 'en' ? l.enText : l.vi}';
              final prov = landmarksOfProvinceIn(query);
              if (prov.isNotEmpty) {
                return 'Các địa danh ở ${prov.first.province}: ${prov.map((x) => x.name).join(', ')}.';
              }
              final reg = regionIn(query);
              if (reg != null) {
                final rList = landmarksOfRegion(reg);
                return 'Các địa danh ở ${regionNamesVi[reg] ?? reg}: ${rList.take(6).map((x) => x.name).join(', ')}.';
              }
              final normQ = normVi(query);
              final matches = vnLandmarks.where((x) => normVi(x.name).contains(normQ) || normVi(x.vi).contains(normQ)).take(3).toList();
              if (matches.isNotEmpty) {
                return matches.map((x) => '${x.name}: ${s.lang == 'en' ? x.enText : x.vi}').join('\n');
              }
              return null;
            },
            lookupSpace: (target) async {
              final p = planetIn(target);
              if (p != null) return 'Thiên thể ${s.lang == 'en' ? p.en : p.vi}: ${p.facts}';
              return null;
            },
            lookupTerrain: (query) async {
              final p = peakIn(query);
              if (p != null) return '${s.lang == 'en' ? p.en : p.vi}: cao ${p.h} mét. ${s.lang == 'en' ? p.noteEn : p.noteVi}.';
              final normQ = normVi(query);
              if (normQ.contains('mariana') || normQ.contains('vuc') || normQ.contains('challenger')) {
                return '${deepest.vi}: sâu khoảng 10.935 mét dưới mực nước biển, điểm sâu nhất trên Trái Đất.';
              }
              for (final lf in landforms) {
                if (normVi(lf.vi).contains(normQ) || normVi(lf.en).contains(normQ)) {
                  return '${s.lang == 'en' ? lf.en : lf.vi}: ${s.lang == 'en' ? lf.noteEn : lf.noteVi}.';
                }
              }
              return null;
            },
            handleAction: (action, target) async {
              switch (action) {
                case 'bay_toi':
                  final l = await _resolve(target);
                  if (l != null) {
                    _focus = l;
                    _pin = GlobePin(l.lon, l.lat, s.lang == 'en' ? l.en : l.vi);
                    await _flyTo(GlobeCamera(l.lat, l.lon, l.zoom));
                    return 'Đã bay tới ${l.vi}';
                  }
                  return 'Không tìm thấy nơi $target';
                case 'phong_to':
                  await _flyTo(_cam.copyWith(zoom: math.min(40, _cam.zoom * 3)), ms: 900);
                  return 'Đã phóng to';
                case 'thu_nho':
                  await _flyTo(_cam.copyWith(zoom: math.max(1.0, _cam.zoom / 3)), ms: 900);
                  return 'Đã thu nhỏ';
                case 'xem_ca_qua_cau':
                  _leaveModes();
                  _focus = null;
                  _pin = null;
                  await _flyTo(_cam.copyWith(zoom: 1.0));
                  return 'Đã về toàn cảnh quả địa cầu';
                case 'nghe_nhac':
                  if (target.isNotEmpty) {
                    final l = await _resolve(target);
                    if (l != null) {
                      _focus = l;
                      await _flyTo(GlobeCamera(l.lat, l.lon, l.zoom));
                    }
                  }
                  await _run(WCmd(WKind.music, target: target, raw: target));
                  return 'Đang phát nhạc cụ';
                case 'kham_pha_cham':
                  final l = target.isEmpty ? _here() : await _resolve(target);
                  if (l != null) {
                    await _around(l, explore: true);
                    return 'Đã mở bản đồ khám phá bằng chạm tại ${l.vi}';
                  }
                  return 'Chưa tìm thấy nơi để khám phá';
                default:
                  return null;
              }
            });
        if (!mounted) return;
        await s.speaker.say(answer, answer);
        return;
      } on LiveError catch (e) {
        // trợ lý AI lỗi / quá tải: KHÔNG đọc mã lỗi cho người dùng — nói gợi ý dễ hiểu như khi app không hiểu
        CrashGuard.log('[trợ lý AI] lỗi: ${e.vi}');
        s.earcon('err');
        _lastConfused = DateTime.now();
        await s.speaker.say(
            'Mình nghe là: $raw. Trợ lý AI đang bận nên mình chưa trả lời được câu này. '
                'Bạn thử hỏi: thời tiết Hà Nội, độ cao đỉnh Phan Xi Păng, hoặc kể về Sao Hỏa.',
            'I heard: $raw. The AI helper is busy right now. Try: weather in Hanoi, or tell me about Mars.');
      }
      return;
    }
    // không hiểu: luôn trả lời (trừ tiếng ồn một tiếng), nhắc lại điều đã nghe để người dùng biết vì sao
    s.earcon('err');
    if (words >= 2 && DateTime.now().difference(_lastConfused).inSeconds > 6) {
      _lastConfused = DateTime.now();
      await s.speaker.say(
          'Mình nghe là: $raw. Mình chưa hiểu câu này. Bạn thử nói: thời tiết Hà Nội, ngày mai có mưa không, hoặc trợ giúp.',
          'I heard: $raw. I did not understand. Try: weather in Hanoi, or help.');
    }
  }

  // ======================= Chạm / bàn phím (cho người đi cùng) =======================
  Offset? _lastFocal;
  double _startZoom = 1;

  /// Quả cầu lúc ĐẶT NGÓN. Tap chỉ được báo khi nhấc tay (chờ thêm ~0,3 giây để phân biệt chạm đôi); trong lúc đó
  /// quả cầu có thể đang tự quay / đang bay → tính chỗ chạm theo quả cầu lúc đặt ngón mới đúng nơi người dùng chạm.
  GlobeCamera? _tapCam;

  void _onTapDown(TapDownDetails d) {
    _tapCam = _cam;
    _touchedAt = DateTime.now();
  }

  /// Chạm trúng (hoặc sát) tên một nước đang hiện trên quả cầu → (kinh độ, vĩ độ) điểm đặt tên của nước đó.
  /// Người đi cùng hay chạm vào chữ "Mexico", "Chile"… mà chữ nằm một phần trên biển.
  (double, double)? _labelNear(GlobeProjection pr, Offset o) {
    final w = _world;
    if (w == null) return null;
    var best = 28.0;
    (double, double)? hit;
    for (final c in w.countries) {
      final (x, y, vis) = pr.project(c.lx, c.ly);
      if (!vis) continue;
      final dd = (Offset(x, y) - o).distance;
      if (dd < best) {
        best = dd;
        hit = (c.lx, c.ly);
      }
    }
    return hit;
  }

  void _onTapUp(TapUpDetails d, Size size) {
    final cam = _tapCam ?? _cam;
    _tapCam = null;
    if (_holdUsed) {
      _holdUsed = false; // vừa "giữ để nói": không đọc nơi dưới ngón tay
      return;
    }
    _touchedAt = DateTime.now();
    if (!_loopOn) _startLoop(); // web/micro bị từ chối: chạm để bật lại nghe
    if (_planet != null || _solar) {
      _stopSound();
      return;
    }
    if (_s.speaker.busy || _sound.playing) {
      _stopSound();
      return;
    }
    final pr = GlobeProjection(cam, size);
    final hit = pr.unproject(d.localPosition);
    if (hit == null) return;
    var ll = hit;
    if (!_terrainTouch && _world != null && _world!.countryAt(ll.$1, ll.$2) == null) {
      ll = _labelNear(pr, d.localPosition) ?? ll;
    }
    if (_terrainTouch) {
      unawaited(_terrainSay(ll.$2, ll.$1));
      return;
    }
    if (_s.speaker.busy || _sound.playing) _stopSound();
    _busy = true;
    late final int myGen;
    _fresh(() {
      myGen = _cmdGen;
      return _readAt(ll.$2, ll.$1);
    }).whenComplete(() {
      if (myGen == _cmdGen) _busy = false;
    });
  }

  Widget _buildGlassBtn({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: const Color(0xC80B151A),
            child: InkWell(
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x66E4BB63), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFFE4BB63)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final en = _s.lang == 'en';
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xF50B151A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x66E4BB63), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.hearing_rounded, color: Color(0xFFE4BB63), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                en ? 'About Lắng' : 'Về Lắng',
                style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  en
                      ? 'Lắng transforms NASA climate and planetary data into traditional Vietnamese instrument sounds (Đàn Bầu, Đàn Tranh, Sáo Trúc) — primarily designed for visually impaired users to perceive Earth through sound and touch.'
                      : 'Lắng là ứng dụng chuyển hóa dữ liệu khí hậu Trái Đất và vũ trụ của NASA thành âm nhạc dân tộc Việt Nam (Đàn Bầu, Đàn Tranh, Sáo Trúc) — phục vụ chính cho người khiếm thị cảm nhận thế giới qua thính giác và xúc giác.',
                  style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Text(
                  en ? '1. For the Visually Impaired (Audio & Touch):' : '1. Dành cho người khiếm thị (Thính giác & Xúc giác):',
                  style: const TextStyle(color: Color(0xFFE4BB63), fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  en
                      ? '• Drag & Touch: Hear flute pitch rising with SRTM elevation, haptic vibration scaling with terrain slope, waves at sea, and traffic in built-up areas.\n'
                        '• Weather & Disaster History (F1): Replay monthly/annual NASA climate & disaster timelines with spatial sound & visual effects.\n'
                        '• Space & Real NASA Audio (F2): Hear 10 Solar System stories, NASA Space Place fun facts, and real NASA mission recordings (Sputnik, Apollo 11, Perseverance...).\n'
                        '• Terrain Cross-Section Scan (F3): Sweep North → South and West → East to hear elevation profiles.\n'
                        '• Earth Jukebox (Challenge #14): Hear 5 NASA visualizations as sound (night lights, lightning, CO₂, sea temperature, forest height), with image descriptions, voice control and finger exploration. Say "Earth Jukebox".\n'
                        '• Compatible with TalkBack, VoiceOver and screen readers.'
                      : '• Rê tay khám phá (F3): Bản đồ địa hình thật (độ cao SRTM, lớp phủ rừng, nước, ruộng, đô thị của NASA MODIS); rê ngón tay nghe tiếng sáo theo độ cao, rung theo độ dốc. Vẽ chữ Z (dưới 1 giây) để về màn hình chính.\n'
                        '• Phát lại lịch sử thời tiết & thiên tai (F1): Nghe và xem diễn biến nhiệt độ, lượng mưa, bão lũ theo tháng/năm từ NASA POWER, GDIS, GLC và EONET.\n'
                        '• Vũ trụ & Âm thanh thật của NASA (F2): 10 tập truyện Hệ Mặt Trời, sự thật thú vị NASA Space Place và bản ghi âm thật (Sputnik, Apollo 11, Perseverance...).\n'
                        '• Quét mặt cắt địa hình (F3): Quét Bắc → Nam và Tây → Đông để nghe hình dáng địa hình khu vực.\n'
                        '• Máy hát Trái Đất (thử thách #14): Nghe 5 hình ảnh dữ liệu NASA bằng âm thanh (ánh đèn ban đêm, sét, khí CO₂, nhiệt độ biển, chiều cao rừng), có lời mô tả hình, điều khiển bằng giọng và rê tay trên hình. Nói: máy hát Trái Đất.\n'
                        '• Tương thích hoàn toàn với trình đọc màn hình TalkBack và VoiceOver.',
                  style: const TextStyle(color: Color(0xFFE0E5EA), fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                Text(
                  en ? '2. Visual & Text Aids (Multimodal / Hard of Hearing):' : '2. Bổ trợ trực quan (Khiếm thính / Môi trường yên tĩnh):',
                  style: const TextStyle(color: Color(0xFF43D8A0), fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  en
                      ? '• Keyboard button (⌨️): Type search queries when you cannot speak aloud.\n'
                        '• Visual Weather Card: Clear display of temperature, humidity, wind, UV, and AQI.\n'
                        '• Subtitles & History: Tap the bottom caption to review the full spoken transcript.\n'
                        '• Audio Wave Visualizer: Dancing bars indicate instrument playing and AI speech activity.'
                      : '• Nút Bàn phím (⌨️): Nhập câu hỏi bằng chữ khi không tiện dùng giọng nói.\n'
                        '• Thẻ thời tiết trực quan: Đọc các chỉ số rõ nét (Nhiệt độ, Độ ẩm, Gió, UV, AQI).\n'
                        '• Phụ đề & Lịch sử: Chạm vào dải phụ đề dưới đáy để xem lại toàn văn lời đọc.\n'
                        '• Sóng nhạc trực quan: Dải nhấp nháy báo hiệu khi đàn bầu đang tấu nhạc hoặc AI đang đọc.',
                  style: const TextStyle(color: Color(0xFFE0E5EA), fontSize: 13.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE4BB63)),
            onPressed: () => Navigator.pop(c),
            child: Text(en ? 'Got it' : 'Đã hiểu', style: const TextStyle(color: Color(0xFF0B151A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final en = _s.lang == 'en';
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xF50B151A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x66E4BB63), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFFE4BB63), size: 26),
            const SizedBox(width: 10),
            Text(
              en ? 'Search or Enter Command' : 'Tìm kiếm hoặc Gõ lệnh',
              style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: en ? 'e.g. Hanoi, Mars, tomorrow rain...' : 'VD: Hà Nội, Đà Nẵng, Sao Hỏa, ngày mai mưa...',
                  hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
                  filled: true,
                  fillColor: const Color(0x22FFFFFF),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE4BB63)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF43D8A0)),
                    onPressed: () {
                      final q = controller.text.trim();
                      if (q.isNotEmpty) {
                        Navigator.pop(c);
                        _onTyped(q);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onSubmitted: (q) {
                  final text = q.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(c);
                    _onTyped(text);
                  }
                },
              ),
              const SizedBox(height: 14),
              Text(
                en ? 'Quick Suggestions:' : 'Gợi ý nhanh:',
                style: const TextStyle(color: Color(0xFFE4BB63), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    (en ? 'Hanoi Weather' : 'Hà Nội', en ? 'weather in Hanoi' : 'thời tiết Hà Nội'),
                    (en ? 'Hue History (3y)' : 'Lịch sử Huế 3 năm', en ? 'weather history of Hue over the last 3 years' : 'lịch sử thời tiết Huế 3 năm qua'),
                    (en ? 'Mars Fun Fact' : 'Sự thật Sao Hỏa', en ? 'fun fact about Mars' : 'sự thật thú vị về Sao Hỏa'),
                    (en ? 'NASA Sounds' : 'Âm thanh NASA', en ? 'NASA sounds' : 'âm thanh thật của NASA'),
                    (en ? 'Scan Da Lat Terrain' : 'Quét địa hình Đà Lạt', en ? 'scan the terrain of Da Lat' : 'quét mặt cắt địa hình Đà Lạt'),
                    (en ? 'Touch Explore' : 'Rê tay khám phá', en ? 'touch terrain' : 'chạm địa hình'),
                    (en ? 'Disaster Alerts' : 'Cảnh báo thiên tai', en ? 'natural disasters' : 'cảnh báo thiên tai'),
                    (en ? 'Around me' : 'Quanh đây có gì', en ? 'where am i' : 'quanh đây có gì'),
                  ])
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(c);
                        _onTyped(item.$2);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x22E4BB63),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x44E4BB63)),
                        ),
                        child: Text(
                          item.$1,
                          style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 12.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final en = _s.lang == 'en';
    final chips = <(String, VoidCallback)>[
      if (_planet != null || _solar) ...[
        ('🌍 ${en ? 'Back to Earth' : 'Về Trái Đất'}', () => _onTyped(en ? 'exit' : 'về quả địa cầu')),
        if (_planet != null) ...[
          ('🪐 ${en ? 'Solar System' : 'Hệ Mặt Trời'}', () => _onTyped(en ? 'Solar System' : 'Hệ Mặt Trời')),
          ('✨ ${en ? 'Fun Fact' : 'Sự thật thú vị'}', () => _onTyped(en ? 'fun fact about ${_planet!.en}' : 'sự thật thú vị về ${_planet!.vi}')),
          ('🔊 ${en ? 'Planet Sound' : 'Tiếng hành tinh'}', () => _onTyped(en ? 'sound of ${_planet!.en}' : 'âm thanh của ${_planet!.vi}')),
        ] else ...[
          ('🚀 ${en ? 'Mars' : 'Sao Hỏa'}', () => _onTyped(en ? 'tell me about Mars' : 'kể về Sao Hỏa')),
          ('🪐 ${en ? 'Saturn' : 'Sao Thổ'}', () => _onTyped(en ? 'tell me about Saturn' : 'kể về Sao Thổ')),
          ('🌕 ${en ? 'The Moon' : 'Mặt Trăng'}', () => _onTyped(en ? 'tell me about the Moon' : 'kể về Mặt Trăng')),
          ('☀️ ${en ? 'The Sun' : 'Mặt Trời'}', () => _onTyped(en ? 'tell me about the Sun' : 'kể về Mặt Trời')),
        ],
        ('🎧 ${en ? 'NASA Sounds' : 'Âm thanh NASA'}', () => _onTyped(en ? 'real NASA sound' : 'âm thanh thật của NASA')),
        ('🎮 ${en ? 'NASA Sound Quiz' : 'Đố âm thanh NASA'}', () => _onTyped(en ? 'NASA sound quiz' : 'đố âm thanh NASA')),
        ('🎲 ${en ? 'Space Games' : 'Trò chơi vũ trụ'}', () => _onTyped(en ? 'play a game' : 'trò chơi')),
      ] else ...[
        ('📍 ${en ? 'My Location' : 'Vị trí của tôi'}', () => _onTyped(en ? 'where am i' : 'nơi tôi đứng')),
        ('⭐ ${en ? 'Hanoi' : 'Hà Nội'}', () => _onTyped(en ? 'weather in Hanoi' : 'thời tiết Hà Nội')),
        ('⭐ ${en ? 'Da Nang' : 'Đà Nẵng'}', () => _onTyped(en ? 'weather in Da Nang' : 'thời tiết Đà Nẵng')),
        ('⭐ ${en ? 'HCMC' : 'TP.HCM'}', () => _onTyped(en ? 'weather in Ho Chi Minh City' : 'thời tiết TP. Hồ Chí Minh')),
        ('📜 ${en ? 'Weather History' : 'Lịch sử thời tiết'}', () => _onTyped(en ? 'weather history of Hue' : 'lịch sử thời tiết Huế 3 năm qua')),
        ('⚠ ${en ? 'Disasters' : 'Thiên tai'}', () => _onTyped(en ? 'natural disasters' : 'cảnh báo thiên tai')),
        ('🎼 ${en ? 'Earth Jukebox' : 'Máy hát Trái Đất'}', () => _onTyped(en ? 'earth jukebox' : 'máy hát trái đất')),
        ('⛰️ ${en ? 'Terrain Scan' : 'Quét địa hình'}', () => _onTyped(en ? 'terrain cross section' : 'quét mặt cắt địa hình')),
        (
          _local != null ? '✖ ${en ? 'Exit Touch Map' : 'Thoát rê tay'}' : '🖐️ ${en ? 'Touch Explore' : 'Rê tay khám phá'}',
          () => _local != null ? _onTyped(en ? 'exit' : 'thoát rê tay') : _onTyped(en ? 'touch terrain' : 'chạm địa hình')
        ),
        ('🚀 ${en ? 'Mars' : 'Sao Hỏa'}', () => _onTyped(en ? 'tell me about Mars' : 'kể về Sao Hỏa')),
        ('🎧 ${en ? 'NASA Sounds' : 'Âm thanh NASA'}', () => _onTyped(en ? 'real NASA sound' : 'âm thanh thật của NASA')),
        ('🎮 ${en ? 'NASA Sound Quiz' : 'Đố âm thanh NASA'}', () => _onTyped(en ? 'NASA sound quiz' : 'đố âm thanh NASA')),
        ('🪐 ${en ? 'Solar System' : 'Hệ Mặt Trời'}', () => _onTyped(en ? 'Solar System' : 'Hệ Mặt Trời')),
        ('🌊 ${en ? 'Paracel Islands' : 'Hoàng Sa'}', () => _onTyped(en ? 'Paracel Islands' : 'Hoàng Sa')),
        ('🌊 ${en ? 'Spratly Islands' : 'Trường Sa'}', () => _onTyped(en ? 'Spratly Islands' : 'Trường Sa')),
        ('🌧️ ${en ? 'Rain forecast' : 'Dự báo mưa'}', () => _onTyped(en ? 'will it rain tomorrow' : 'ngày mai có mưa không')),
      ],
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final c = chips[idx];
          final cleanLabel = c.$1.replaceAll(RegExp(r'[^\w\s\u00C0-\u1EF9]'), '').trim();
          return Semantics(
            button: true,
            label: cleanLabel,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: c.$2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xC80B151A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66E4BB63), width: 1.1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Text(
                    c.$1,
                    style: const TextStyle(
                      color: Color(0xFFFBF4E4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Focus(
      focusNode: _keyFocus,
      autofocus: true,
      // CỬ CHỈ CỐ ĐỊNH: vẽ chữ Z (dưới 1 giây) ở BẤT KỲ màn nào → về màn hình chính của nhánh đang dùng.
      // Listener "nhìn" ngón tay mà không giành cử chỉ của bản đồ / quả cầu bên dưới.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (kIsWeb) WebSpeech.unlock(); // Safari / iPad: lần chạm đầu tiên mở khoá giọng đọc của trình duyệt
          _touchedAt = DateTime.now(); // quả cầu ngừng tự quay ngay khi đặt ngón
          _zg.down(e.pointer, e.position.dx, e.position.dy, e.timeStamp.inMilliseconds);
          _sw2.down(e.pointer, e.position.dx, e.position.dy, e.timeStamp.inMilliseconds);
          _holdDown(e);
        },
        onPointerMove: (e) {
          _zg.move(e.pointer, e.position.dx, e.position.dy, e.timeStamp.inMilliseconds);
          _sw2.move(e.pointer, e.position.dx, e.position.dy, e.timeStamp.inMilliseconds);
          _holdMove(e);
        },
        onPointerUp: (e) {
          _holdUp(e.pointer);
          final sw = _sw2.up(e.pointer, e.timeStamp.inMilliseconds);
          if (sw != null) {
            // đang RÊ TAY / quét địa hình: hai ngón là để kéo, phóng bản đồ → không coi là vuốt thoát / đổi phần
            if (!_touchExploring) unawaited(_onSwipe2(sw));
          } else if (_zg.up(e.pointer, e.timeStamp.inMilliseconds)) {
            unawaited(_goHome(byGesture: true));
          }
        },
        onPointerCancel: (e) {
          _zg.cancel();
          _sw2.cancel();
          _holdUp(e.pointer);
        },
        child: LayoutBuilder(builder: (context, box) {
        final size = box.biggest;
        final focusW = _weatherAt(_focus);
        return Semantics(
          label: _s.t('Quả địa cầu. Chạm, gõ lệnh hoặc nói tên một nơi để xem thời tiết.', 'Globe. Touch, type or say a place name to view weather.'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _local != null ? null : (d) => _onTapDown(d),
            onTapUp: _local != null ? null : (d) => _onTapUp(d, size),
            onDoubleTap: _local != null || _planet != null || _solar
                ? null
                : () {
              _touchedAt = DateTime.now();
              unawaited(_flyTo(_cam.copyWith(zoom: math.min(40, _cam.zoom * 2.5)), ms: 600));
            },
            onScaleStart: _local != null || _planet != null || _solar
                ? null
                : (d) {
              _stopFly();
              _touchedAt = DateTime.now();
              _lastFocal = d.localFocalPoint;
              _startZoom = _cam.zoom;
              // chạm địa hình: MỘT ngón rê = nghe độ cao; hai ngón vẫn xoay / phóng
              _fingerTerrain = _terrainTouch && d.pointerCount == 1;
              if (_fingerTerrain) _terrainFinger(d.localFocalPoint, size);
              // kéo quả cầu sang chỗ khác trong lúc app đang đọc / phát → ngắt ngay (không để âm thanh cũ đè lên)
              if (!_fingerTerrain && !_holdOn && (_s.speaker.busy || _sound.playing)) _stopSound();
            },
            onScaleEnd: _local != null || _planet != null || _solar
                ? null
                : (d) {
              if (!_fingerTerrain) return;
              _fingerTerrain = false;
              _s.audio.voiceMute();
              final at = _tAt;
              if (at != null) unawaited(_terrainSay(at.$1, at.$2));
            },
            onScaleUpdate: _local != null || _planet != null || _solar
                ? null
                : (d) {
              _touchedAt = DateTime.now();
              if (_fingerTerrain && d.pointerCount == 1) {
                _terrainFinger(d.localFocalPoint, size);
                return;
              }
              if (_fingerTerrain) {
                // thêm ngón thứ hai giữa chừng → chuyển sang xoay / phóng
                _fingerTerrain = false;
                _s.audio.voiceMute();
                _lastFocal = d.localFocalPoint;
                _startZoom = _cam.zoom / math.max(0.01, d.scale);
              }
              final lf = _lastFocal ?? d.localFocalPoint;
              final delta = d.localFocalPoint - lf;
              _lastFocal = d.localFocalPoint;
              final r = math.min(size.width, size.height) * 0.44 * _cam.zoom;
              final degPerPx = 180 / (math.pi * r);
              // kéo / chụm: chỉ lớp quả cầu vẽ lại (không dựng lại cả màn hình mỗi lần ngón tay nhích)
              _cam = GlobeCamera(
                (_cam.lat + delta.dy * degPerPx).clamp(-85.0, 85.0),
                wrapLon(_cam.lon - delta.dx * degPerPx / math.max(0.2, math.cos(_cam.lat * math.pi / 180))),
                (_startZoom * d.scale).clamp(0.9, 40.0),
              );
            },
            child: ValueListenableBuilder<Offset>(
              valueListenable: _hist?.shake ?? _noShake,
              builder: (context, off, child) => off == Offset.zero || _reduceMotion
                  ? child!
                  : Transform.translate(offset: off, child: child),
              child: Stack(fit: StackFit.expand, children: [
              if (_local != null)
                LocalMapView(
                  data: _local!,
                  placeVi: _localName,
                  onClose: () {
                    _leaveModes();
                    _s.speaker.stop();
                  },
                )
              else if (_planet != null)
                RepaintBoundary(child: CustomPaint(painter: PlanetPainter(_planet!, _spaceN, en: _s.lang == 'en'), size: Size.infinite))
              else if (_solar)
                RepaintBoundary(
                    child: CustomPaint(
                        painter: SolarPainter(_spaceN, highlight: _solarHi, en: _s.lang == 'en'), size: Size.infinite))
              else
              RepaintBoundary(
                child: CustomPaint(
                  painter: GlobePainter(
                      world: _world, camera: _camN, en: _s.lang == 'en', terrain: null, moving: _movingN),
                  size: Size.infinite,
                ),
              ),
              if (_local == null && _planet == null && !_solar)
                RepaintBoundary(
                  child: CustomPaint(
                    painter: GlobeFxPainter(
                        camera: _camN,
                        pulseN: _pulseN,
                        pin: _pin,
                        listening: _listening,
                        events: [for (final e in _events) (e.lon, e.lat, e.category)]),
                    size: Size.infinite,
                  ),
                ),
              // F3: quét mặt cắt địa hình
              if (_scan != null && _local == null && _planet == null && !_solar)
                Positioned.fill(
                  child: TerrainScanView(
                    key: ObjectKey(_scan),
                    player: _scan!,
                    en: _s.lang == 'en',
                    onClose: () {
                      _closeScan();
                      _closeEic();
                      _s.speaker.stop();
                    },
                  ),
                ),
              // #14: máy hát Trái Đất (khung hình NASA SVS + âm thanh + rê tay)
              if (_eic != null && _local == null && _planet == null && !_solar)
                Positioned.fill(
                  child: EicView(
                    key: ObjectKey(_eic),
                    player: _eic!,
                    en: _s.lang == 'en',
                    onClose: () {
                      _closeEic();
                      _s.speaker.stop();
                    },
                  ),
                ),
              // F1: phát lại lịch sử thời tiết & thiên tai (phủ lên quả cầu, dưới các nút)
              if (_hist != null && _local == null && _planet == null && !_solar)
                Positioned.fill(
                  child: HistoryPlayerView(
                    key: ObjectKey(_hist),
                    player: _hist!,
                    en: _s.lang == 'en',
                    onClose: () {
                      _closeHistory();
                      _s.speaker.stop();
                    },
                  ),
                ),
              if (_alertOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_alertTimer.hashCode),
                        tween: Tween(begin: 0, end: 8),
                        duration: const Duration(seconds: 8),
                        builder: (context, v, _) {
                          final on = (v * 2).floor().isEven; // nhấp nháy 2 lần mỗi giây
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: on ? const Color(0xFFFF3B30) : const Color(0x55FF3B30), width: 14),
                            ),
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(color: const Color(0xEEB3261E), borderRadius: BorderRadius.circular(12)),
                              child: Text(_s.t('⚠ CẢNH BÁO THIÊN TAI', '⚠ HAZARD ALERT'),
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // Nút trạng thái đang nghe ở giữa trên cùng (tự co giãn trên màn hình hẹp để không đè cụm nút góc phải)
              Positioned(
                top: 20,
                left: 16,
                right: size.width < 640 ? 168 : 16,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: size.width < 640 ? Alignment.centerLeft : Alignment.center,
                      child: AnimatedOpacity(
                        opacity: (_listening || _terrainTouch) && !_alertOn ? 1 : 0,
                        duration: const Duration(milliseconds: 240),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xC80B151A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xAA43D8A0), width: 1.2),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x3343D8A0), blurRadius: 16, spreadRadius: 1),
                                  BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(_terrainTouch ? Icons.touch_app_rounded : Icons.mic_rounded, size: 20, color: const Color(0xFF43D8A0)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                      _terrainTouch
                                          ? _s.t('Chạm địa hình · Rê 1 ngón nghe tiếng sáo', 'Terrain Touch · Drag 1 finger for flute')
                                          : _s.t('Đang nghe… cứ nói hoặc bấm ⌨️', 'Listening… speak or tap ⌨️'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFFF1E5CC),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2)),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Cụm nút thao tác mờ ở góc trên bên phải (Bàn phím/Tìm kiếm ⌨️, Trợ giúp ❓, Cài đặt ⚙️)
              Positioned(
                top: 18,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassBtn(
                      icon: Icons.keyboard_rounded,
                      tooltip: _s.lang == 'en' ? 'Type command / Search' : 'Gõ lệnh / Tìm kiếm',
                      onTap: _showSearchDialog,
                    ),
                    const SizedBox(width: 8),
                    _buildGlassBtn(
                      icon: Icons.help_outline_rounded,
                      tooltip: _s.lang == 'en' ? 'Help & Guide' : 'Hướng dẫn sử dụng',
                      onTap: _showHelpDialog,
                    ),
                    const SizedBox(width: 8),
                    _buildGlassBtn(
                      icon: Icons.settings_rounded,
                      tooltip: _s.lang == 'en' ? 'Settings' : 'Cài đặt',
                      onTap: () => unawaited(showSettings(context)),
                    ),
                  ],
                ),
              ),

              // Thẻ thời tiết trực quan Glassmorphism ở góc trên bên trái
              if (focusW != null && _planet == null && !_solar && _local == null && _hist == null && _scan == null && _eic == null)
                Positioned(
                  top: 72,
                  left: 16,
                  child: _showWeatherCard
                      ? LiveWeatherCard(
                          loc: _focus!,
                          weather: focusW,
                          isEn: _s.lang == 'en',
                          onClose: () => setState(() => _showWeatherCard = false),
                        )
                      : Semantics(
                          button: true,
                          label: _s.lang == 'en'
                              ? 'Weather: ${_focus!.en}, ${focusW.now.temp.round()} degrees Celsius. Double-tap to open details.'
                              : 'Thời tiết: ${_focus!.vi}, ${focusW.now.temp.round()} độ C. Nhấn đúp để mở chi tiết.',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => setState(() => _showWeatherCard = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xD80D151B),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0x66E4BB63), width: 1.2),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.wb_sunny_rounded, size: 18, color: Color(0xFFFFD166)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_s.lang == 'en' ? _focus!.en : _focus!.vi} • ${focusW.now.temp.round()}°C',
                                    style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.open_in_full_rounded, size: 14, color: Color(0xFFE4BB63)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),

              // Cụm dưới cùng: Hàng phím tắt gợi ý (Quick Action Chips) + Thanh phụ đề thông minh (Sticky Captions)
              // Xếp chung trong Column để khi phụ đề dài nhiều dòng, hàng phím tắt tự đẩy lên trên và không bao giờ bị đè lấp.
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_local == null)
                      ListenableBuilder(
                      listenable: Listenable.merge([_stickyCaption, _s.speaker.caption, _heard]),
                      builder: (context, _) {
                        final cap = _stickyCaption.value;
                        final heard = _heard.value;
                        final txt = cap.isNotEmpty ? cap : (heard.isEmpty ? '' : '“$heard”');
                        final isAudioPlaying = _sound.playing || _s.speaker.busy;
                        if (txt.isEmpty && !isAudioPlaying) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Semantics(
                                    button: true,
                                    label: txt.isNotEmpty
                                        ? (_s.lang == 'en'
                                            ? 'Caption: $txt. Double-tap to open full transcript.'
                                            : 'Phụ đề: $txt. Nhấn đúp để mở toàn bộ lịch sử trò chuyện.')
                                        : (_s.lang == 'en' ? 'Open transcript history' : 'Mở lịch sử trò chuyện'),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => showTranscriptSheet(
                                        context,
                                        _transcript,
                                        isEn: _s.lang == 'en',
                                        onClear: () => setState(() => _transcript.clear()),
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 820),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                        decoration: BoxDecoration(
                                          color: const Color(0xD80D151B),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0x66E4BB63), width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(color: Color(0x77000000), blurRadius: 28, offset: Offset(0, 8)),
                                            BoxShadow(color: Color(0x22E4BB63), blurRadius: 16, spreadRadius: -2),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            if (isAudioPlaying)
                                              AudioWaveVisualizer(
                                                isPlaying: true,
                                                label: _sound.playing
                                                    ? (_s.lang == 'en' ? 'Music' : 'Đàn bầu')
                                                    : (_s.lang == 'en' ? 'Speaking' : 'Đang đọc'),
                                              )
                                            else
                                              Container(
                                                padding: const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0x2EE4BB63),
                                                  border: Border.all(color: const Color(0x55E4BB63)),
                                                ),
                                                child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Color(0xFFE4BB63)),
                                              ),
                                            const SizedBox(width: 14),
                                            if (txt.isNotEmpty)
                                              Flexible(
                                                child: Text(
                                                  txt,
                                                  maxLines: 6,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.left,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFBF4E4),
                                                    fontSize: 17.5,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.45,
                                                    letterSpacing: 0.1,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 10),
                                            Tooltip(
                                              message: _s.lang == 'en' ? 'View transcript history' : 'Xem lịch sử hội thoại',
                                              child: const Icon(Icons.history_rounded, size: 18, color: Color(0xAAEDB854)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Hàng nút gợi ý nằm DƯỚI phụ đề, cố định sát đáy màn hình: phụ đề dài ngắn thế nào cũng không đẩy
                    // hàng nút lên xuống (trước đây nút bị dời chỗ ngay lúc đang bấm → bấm nhầm vào quả cầu / phụ đề).
                    if (_local == null && _hist == null && _scan == null && _eic == null)
                      Padding(padding: const EdgeInsets.only(top: 10), child: _buildQuickChips()),
                  ],
                ),
              ),
            ]),
            ),
          ),
        );
      }),
      ),
    );
  }
}
