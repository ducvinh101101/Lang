// F1 — BỘ PHÁT LẠI LỊCH SỬ THỜI TIẾT & THIÊN TAI.
//
// Đi từ bản ghi sớm nhất đến bản ghi cuối:
//   • Thời tiết: âm nền phối theo số liệu — nắng nóng = nắng rát (hợp âm sáng + lách tách), lạnh = gió lạnh,
//     mưa = tiếng mưa to/nhỏ theo lượng mưa (mưa rất to có sấm). Loại CHIẾM CHỦ ĐẠO phát to, các loại phụ phát nhỏ.
//   • Thiên tai: phát lần lượt các thiên tai của bản ghi, từ NHẸ đến NẶNG, mỗi loại một tiếng riêng, đọc tên ngắn.
//   • Đồ hoạ khớp với âm: phủ sáng ấm khi nắng nóng, ám xanh khi lạnh, mưa rơi khi mưa nhiều, gió xoáy khi bão,
//     màn hình rung khi động đất / bão mạnh, lửa khi cháy rừng, nước dâng khi lũ.
//   • Thanh timeline chạy dần từ bản ghi đầu đến bản ghi cuối (chấm đỏ: bản ghi có thiên tai).
//   • Chạm màn hình khi đang phát → tạm dừng, đọc giải thích các giá trị của bản ghi đang phát, rồi phát tiếp.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/audio_engine.dart';
import '../../core/format.dart' show fmtNum;
import '../../core/haptics.dart';
import 'history_records.dart';

/// Hiệu ứng hình ảnh hiện tại (0..1 mỗi loại).
class HistoryFx {
  double heat = 0, cold = 0, rain = 0, storm = 0, quake = 0, fire = 0, flood = 0;
  void clear() => heat = cold = rain = storm = quake = fire = flood = 0;
}

class HistoryPlayer extends ChangeNotifier {
  final AudioEngine audio;
  final Future<void> Function(String vi, String en) say;
  final void Function(String vi, String en) quick;
  final Future<void> Function() stopSpeech;
  final String Function() lang;

  final String placeVi, placeEn;
  final HistoryRange range;
  final List<HistoryRecord> records;

  /// 'both' | 'weather' | 'disaster'
  final String mode;

  HistoryPlayer({
    required this.audio,
    required this.say,
    required this.quick,
    required this.stopSpeech,
    required this.lang,
    required this.placeVi,
    required this.placeEn,
    required this.range,
    required this.records,
    this.mode = 'both',
  });

  final fx = HistoryFx();

  /// Độ lệch rung màn hình (động đất / bão mạnh) — trang chứa bọc nội dung bằng Transform.translate theo giá trị này.
  final shake = ValueNotifier<Offset>(Offset.zero);

  int index = 0;
  bool playing = false;
  bool explaining = false;
  bool finished = false;
  Hazard? currentHazard;
  DateTime recordStart = DateTime.now();
  int recordMs = 1;

  int _gen = 0;
  Completer<void>? _resume;
  Timer? _shakeTimer;
  final _rng = math.Random();

  bool get weatherOn => mode != 'disaster';
  bool get hazardsOn => mode != 'weather';

  HistoryRecord get current => records[index.clamp(0, records.length - 1)];

  /// Tiến độ cả chuỗi 0..1 (dùng cho thanh timeline).
  double get progress {
    if (records.isEmpty) return 0;
    if (finished) return 1;
    final inRec = (DateTime.now().difference(recordStart).inMilliseconds / math.max(1, recordMs)).clamp(0.0, 1.0);
    return ((index + (explaining ? 0.5 : inRec)) / records.length).clamp(0.0, 1.0);
  }

  int get _weatherMs => range.monthly ? 2300 : 1900;
  int get _hazardMs => 1500;

  /// Bắt đầu: đọc giới thiệu rồi phát.
  Future<void> start() async {
    final my = ++_gen;
    playing = true;
    finished = false;
    notifyListeners();
    final nHaz = records.fold<int>(0, (a, r) => a + r.hazards.length);
    final what = mode == 'weather' ? 'thời tiết' : (mode == 'disaster' ? 'thiên tai' : 'thời tiết và thiên tai');
    final whatEn = mode == 'weather' ? 'weather' : (mode == 'disaster' ? 'hazards' : 'weather and hazards');
    await say(
        'Lịch sử $what ở $placeVi, ${range.describeVi()}: ${records.length} bản ghi'
            '${hazardsOn ? ', $nHaz lần thiên tai' : ''}. '
            '${weatherOn ? 'Nắng nóng là tiếng nắng rát, lạnh là tiếng gió lạnh, mưa càng to tiếng mưa càng dày. ' : ''}'
            '${hazardsOn ? 'Thiên tai phát sau thời tiết của mỗi kỳ, từ nhẹ đến nặng. ' : ''}'
            'Chạm màn hình bất cứ lúc nào để nghe giải thích. Nói dừng để thôi.',
        '${whatEn[0].toUpperCase()}${whatEn.substring(1)} history of $placeEn, ${range.describeEn()}: ${records.length} records. '
            'Tap the screen any time to hear the details. Say stop to end.');
    if (my != _gen) return;
    await _run(my);
  }

  Future<void> _run(int my) async {
    while (index < records.length && my == _gen) {
      await _waitResume(my);
      if (my != _gen) return;
      final r = records[index];
      await _playRecord(r, my);
      if (my != _gen) return;
      if (explaining || _resume != null) continue; // bị chạm giữa chừng: phát tiếp sau khi giải thích (bản ghi kế)
      index++;
      if (index < records.length) notifyListeners();
    }
    if (my != _gen) return;
    finished = true;
    playing = false;
    fx.clear();
    currentHazard = null;
    notifyListeners();
    await say(_summaryVi(), _summaryEn());
  }

  Future<void> _waitResume(int my) async {
    final c = _resume;
    if (c != null) await c.future;
  }

  Future<void> _sleep(int ms, int my) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (my == _gen && DateTime.now().isBefore(end) && _resume == null) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  Future<void> _playRecord(HistoryRecord r, int my) async {
    final total = (weatherOn ? _weatherMs : 700) + (hazardsOn ? r.hazards.length * _hazardMs : 0);
    recordStart = DateTime.now();
    recordMs = total;
    currentHazard = null;
    final m = r.mix;
    fx
      ..clear()
      ..heat = weatherOn ? m.heat : 0
      ..cold = weatherOn ? m.cold : 0
      ..rain = weatherOn ? m.rain : 0;
    notifyListeners();
    // mõ đầu mỗi năm (bản ghi tháng) để biết đang ở đâu
    if (r.monthly && r.month == 1) audio.mo();
    if (weatherOn) {
      _weatherSound(r);
      await _sleep(_weatherMs, my);
    } else {
      audio.earcon('tick');
      await _sleep(700, my);
    }
    if (!hazardsOn) return;
    for (final h in r.hazards) {
      if (my != _gen || _resume != null) return;
      currentHazard = h;
      _hazardFx(h);
      notifyListeners();
      quick(h.nameVi, h.nameEn);
      _hazardSound(h);
      await _sleep(_hazardMs, my);
    }
  }

  /// Phối âm thời tiết: loại chủ đạo to, loại phụ nhỏ (chỉ khi đáng kể).
  void _weatherSound(HistoryRecord r) {
    final m = r.mix;
    final dom = m.dominant;
    double amp(String k, double level) => k == dom ? 0.16 + 0.2 * level : (level > 0.25 ? 0.05 + 0.08 * level : 0);
    final aHeat = amp('heat', m.heat), aCold = amp('cold', m.cold), aRain = amp('rain', m.rain);
    if (dom == 'mild') {
      // ôn hoà: một nốt đàn bầu êm theo nhiệt độ
      final x = r.temp.isNaN ? 0.5 : ((r.temp - 5) / 30).clamp(0.0, 1.0);
      unawaited(audio.danbauNote(toScale(0.2 + 0.6 * x), toScale(0.2 + 0.6 * x), 1.2, 0.18, 0));
    }
    if (aHeat > 0) {
      audio.ambient('sun', amp: aHeat, speed: 1 + 0.12 * m.heat);
      // nắng rát: tiếng lách tách khô
      if (m.heat > 0.6) {
        for (var k = 0; k < (m.heat * 6).round(); k++) {
          Future<void>.delayed(Duration(milliseconds: 200 + k * 230), () => audio.crackle(0.18 * m.heat, _rng.nextDouble() * 1.6 - 0.8));
        }
      }
    }
    if (aCold > 0) audio.ambient('wind', amp: aCold, speed: 0.95 + 0.2 * m.cold);
    if (aRain > 0) {
      audio.ambient('rain', amp: aRain, speed: 0.9 + 0.25 * m.rain);
      // giọt mưa dày theo lượng mưa
      final drops = (m.rain * 10).round();
      for (var k = 0; k < drops; k++) {
        Future<void>.delayed(Duration(milliseconds: 80 + _rng.nextInt(1700)), () => audio.trung(randHigh(), 0.06 + 0.06 * m.rain, _rng.nextDouble() * 1.8 - 0.9));
      }
      if (m.rain > 0.85) Future<void>.delayed(const Duration(milliseconds: 700), () => audio.ambient('thunder', amp: 0.14));
    }
  }

  void _hazardFx(Hazard h) {
    final s = (h.severity / 5).clamp(0.2, 1.0);
    switch (h.kind) {
      case HazardKind.heat:
        fx.heat = math.max(fx.heat, 0.6 + 0.4 * s);
      case HazardKind.cold:
        fx.cold = math.max(fx.cold, 0.6 + 0.4 * s);
      case HazardKind.drought:
        fx
          ..heat = math.max(fx.heat, 0.5 * s + 0.3)
          ..rain = 0;
      case HazardKind.heavyRain:
        fx.rain = math.max(fx.rain, 0.7 + 0.3 * s);
      case HazardKind.storm:
        fx
          ..storm = s
          ..rain = math.max(fx.rain, 0.8);
        if (h.severity >= 3.5) _startShake(0.5 * s, 1200);
      case HazardKind.flood:
        fx
          ..flood = s
          ..rain = math.max(fx.rain, 0.6);
      case HazardKind.wildfire:
        fx.fire = s;
      case HazardKind.landslide:
        _startShake(0.4 * s, 900);
      case HazardKind.volcano:
        fx.fire = s;
        _startShake(0.5 * s, 1000);
      case HazardKind.earthquake:
        fx.quake = s;
        _startShake(s, 1300);
    }
  }

  void _hazardSound(Hazard h) {
    final a = 0.18 + 0.05 * h.severity;
    switch (h.kind) {
      case HazardKind.cold:
        audio.ambient('wind', amp: a, speed: 0.85);
      case HazardKind.heat:
        audio.ambient('sun', amp: a, speed: 1.2);
        for (var k = 0; k < 4; k++) {
          Future<void>.delayed(Duration(milliseconds: 150 + k * 250), () => audio.crackle(0.25, 0));
        }
      case HazardKind.drought:
        audio.ambient('wind', amp: a * 0.8, speed: 1.35);
        for (var k = 0; k < 5; k++) {
          Future<void>.delayed(Duration(milliseconds: 100 + k * 220), () => audio.crackle(0.2, _rng.nextDouble() - 0.5));
        }
      case HazardKind.heavyRain:
        audio.ambient('rain', amp: a + 0.1);
        audio.ambient('thunder', amp: a * 0.7);
      case HazardKind.storm:
        audio.ambient('wind', amp: a + 0.1, speed: 0.8);
        audio.ambient('rain', amp: a);
        Future<void>.delayed(const Duration(milliseconds: 300), () => audio.ambient('thunder', amp: a));
        if (h.severity >= 3.5) unawaited(Haptics.rumble(h.severity));
      case HazardKind.flood:
        for (var k = 0; k < 3; k++) {
          Future<void>.delayed(Duration(milliseconds: k * 380), () => audio.song(a, -0.6 + 0.6 * k));
        }
        audio.ambient('rain', amp: a * 0.6, speed: 0.85);
      case HazardKind.wildfire:
        for (var k = 0; k < 14; k++) {
          Future<void>.delayed(Duration(milliseconds: _rng.nextInt(1300)), () => audio.crackle(0.35, _rng.nextDouble() * 1.6 - 0.8));
        }
      case HazardKind.landslide:
        audio.ambient('quake', amp: a * 0.7, speed: 1.3);
        for (var k = 0; k < 5; k++) {
          Future<void>.delayed(Duration(milliseconds: k * 160), () => audio.trong(0.25, -0.5 + 0.25 * k));
        }
        unawaited(Haptics.rumble(h.severity * 0.7));
      case HazardKind.volcano:
        audio.ambient('thunder', amp: a);
        audio.ambient('quake', amp: a * 0.6);
        for (var k = 0; k < 8; k++) {
          Future<void>.delayed(Duration(milliseconds: 200 + k * 120), () => audio.crackle(0.3, 0));
        }
        unawaited(Haptics.rumble(h.severity));
      case HazardKind.earthquake:
        audio.ambient('quake', amp: a + 0.1, speed: 1.1 - 0.05 * h.severity);
        unawaited(Haptics.rumble(h.severity));
    }
  }

  void _startShake(double strength, int ms) {
    _shakeTimer?.cancel();
    final end = DateTime.now().add(Duration(milliseconds: ms));
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      final left = end.difference(DateTime.now()).inMilliseconds;
      if (left <= 0) {
        t.cancel();
        shake.value = Offset.zero;
        return;
      }
      final k = 14 * strength * (left / ms);
      shake.value = Offset((_rng.nextDouble() * 2 - 1) * k, (_rng.nextDouble() * 2 - 1) * k);
    });
  }

  /// Chạm màn hình: tạm dừng, đọc giải thích bản ghi đang phát, rồi phát tiếp từ bản ghi kế.
  /// Đang giải thích mà chạm nữa → bỏ qua phần giải thích, phát tiếp ngay.
  Future<void> tap() async {
    if (finished || records.isEmpty) return;
    if (explaining) {
      await stopSpeech();
      return;
    }
    final my = _gen;
    explaining = true;
    _resume = Completer<void>();
    audio.stopAll();
    _shakeTimer?.cancel();
    shake.value = Offset.zero;
    notifyListeners();
    final r = current;
    await say(r.explainVi(), r.explainEn());
    if (my != _gen) return;
    explaining = false;
    // bản ghi vừa giải thích coi như đã nghe xong (bản ghi cuối → kết thúc, đọc tổng kết)
    index++;
    final c = _resume;
    _resume = null;
    notifyListeners();
    c?.complete();
  }

  void stop() {
    _gen++;
    playing = false;
    explaining = false;
    _shakeTimer?.cancel();
    shake.value = Offset.zero;
    final c = _resume;
    _resume = null;
    c?.complete();
    audio.stopAll();
    notifyListeners();
  }

  String _summaryVi() {
    final valid = records.where((r) => !r.temp.isNaN).toList();
    if (valid.isEmpty) return 'Hết phần phát lại.';
    final hot = valid.reduce((a, b) => b.temp > a.temp ? b : a);
    final wet = records.where((r) => !r.rain.isNaN).fold<HistoryRecord?>(null, (a, b) => a == null || b.rain > a.rain ? b : a);
    final worst = [for (final r in records) for (final h in r.hazards) (r, h)]..sort((a, b) => b.$2.severity.compareTo(a.$2.severity));
    final b = StringBuffer('Hết phần phát lại. ');
    b.write('${hot.labelVi.replaceAll('/', ' năm ')} nóng nhất, ${fmtNum(hot.temp, 1)} độ. ');
    if (wet != null) b.write('${wet.labelVi.replaceAll('/', ' năm ')} mưa nhiều nhất, ${fmtNum(wet.rain, 0)} mi-li-mét. ');
    if (hazardsOn && worst.isNotEmpty) b.write('Thiên tai nặng nhất: ${worst.first.$2.vi}, ${worst.first.$1.labelVi.replaceAll('/', ' năm ')}.');
    return b.toString();
  }

  String _summaryEn() {
    final valid = records.where((r) => !r.temp.isNaN).toList();
    if (valid.isEmpty) return 'Playback finished.';
    final hot = valid.reduce((a, b) => b.temp > a.temp ? b : a);
    return 'Playback finished. Hottest: ${hot.labelEn}, ${fmtNum(hot.temp, 1, lang: 'en')} °C.';
  }

  @override
  void dispose() {
    stop();
    shake.dispose();
    super.dispose();
  }
}

/// Lớp hiển thị phủ lên quả địa cầu khi đang phát lại lịch sử.
class HistoryPlayerView extends StatefulWidget {
  final HistoryPlayer player;
  final VoidCallback onClose;
  final bool en;
  const HistoryPlayerView({super.key, required this.player, required this.onClose, this.en = false});

  @override
  State<HistoryPlayerView> createState() => _HistoryPlayerViewState();
}

class _HistoryPlayerViewState extends State<HistoryPlayerView> with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: widget.en
          ? 'Weather history playback. Tap anywhere to hear details of the current record.'
          : 'Đang phát lịch sử thời tiết. Chạm bất cứ đâu để nghe giải thích bản ghi đang phát.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(p.tap()),
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _FxPainter(p, _tick, reduce: reduce),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([p, _tick]),
            builder: (context, _) => _hud(context, p),
          ),
        ]),
      ),
    );
  }

  Widget _hud(BuildContext context, HistoryPlayer p) {
    final en = widget.en;
    final r = p.records.isEmpty ? null : p.current;
    final h = p.currentHazard;
    const txt = Color(0xFFFBF4E4);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
        child: Column(children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B151A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x5543D8A0)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(en ? 'History · ${p.placeEn}' : 'Lịch sử · ${p.placeVi}',
                          style: const TextStyle(color: Color(0xFF43D8A0), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: en ? 'Close' : 'Đóng',
                      icon: const Icon(Icons.close_rounded, color: txt),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                  if (r != null) ...[
                    Text(en ? r.labelEn : r.labelVi,
                        style: const TextStyle(color: txt, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 14, runSpacing: 4, children: [
                      _chip(Icons.thermostat_rounded, '${fmtNum(r.temp, 1, lang: en ? 'en' : 'vi')} °C'),
                      _chip(Icons.water_drop_rounded, '${fmtNum(r.rain, 0, lang: en ? 'en' : 'vi')} mm'),
                      _chip(Icons.graphic_eq_rounded, en ? r.mix.dominantEn : r.mix.dominantVi),
                    ]),
                  ],
                  if (h != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xDDB3261E), borderRadius: BorderRadius.circular(8)),
                      child: Text('⚠ ${en ? h.en : h.vi}',
                          maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ],
                  if (p.explaining) ...[
                    const SizedBox(height: 8),
                    Text(en ? 'Explaining… tap again to continue' : 'Đang giải thích… chạm lần nữa để phát tiếp',
                        style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 13)),
                  ],
                ]),
              ),
            ),
          ),
          const Spacer(),
          _timeline(p, en),
          const SizedBox(height: 6),
          Text(en ? 'Tap anywhere for details' : 'Chạm màn hình để nghe giải thích',
              style: const TextStyle(color: Color(0xAAFBF4E4), fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _chip(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 18, color: const Color(0xFFFFD27A)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _timeline(HistoryPlayer p, bool en) {
    final first = p.records.isEmpty ? '' : (en ? p.records.first.labelEn : p.records.first.labelVi);
    final last = p.records.isEmpty ? '' : (en ? p.records.last.labelEn : p.records.last.labelVi);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(color: const Color(0xCC0B151A), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 26,
            child: CustomPaint(painter: _TimelinePainter(p), size: const Size(double.infinity, 26)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(first,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xCCFBF4E4), fontSize: 12)),
            ),
            Text('${math.min(p.index + 1, p.records.length)} / ${p.records.length}',
                style: const TextStyle(color: Color(0xFF43D8A0), fontSize: 12, fontWeight: FontWeight.w700)),
            Expanded(
              child: Text(last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Color(0xCCFBF4E4), fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final HistoryPlayer p;
  _TimelinePainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final n = p.records.length;
    if (n == 0) return;
    final y = size.height / 2;
    final track = Paint()
      ..color = const Color(0x55FBF4E4)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), track);
    final x = size.width * p.progress;
    canvas.drawLine(
        Offset(0, y),
        Offset(x, y),
        Paint()
          ..color = const Color(0xFF43D8A0)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    // vạch từng bản ghi + chấm đỏ nếu có thiên tai
    for (var k = 0; k < n; k++) {
      final cx = size.width * (k + 0.5) / n;
      final r = p.records[k];
      if (r.hazards.isNotEmpty) {
        final worst = r.hazards.last.severity;
        canvas.drawCircle(Offset(cx, y - 9), 1.6 + worst * 0.6, Paint()..color = const Color(0xFFFF6B5E));
      }
      if (n <= 60) {
        canvas.drawLine(Offset(cx, y + 5), Offset(cx, y + 9), Paint()..color = const Color(0x66FBF4E4)..strokeWidth = 1);
      }
    }
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = const Color(0xFFFBF4E4));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}

/// Vẽ hiệu ứng thời tiết / thiên tai toàn màn hình.
class _FxPainter extends CustomPainter {
  final HistoryPlayer p;
  final Animation<double> t;
  final bool reduce;
  _FxPainter(this.p, this.t, {this.reduce = false}) : super(repaint: Listenable.merge([p, t]));

  // giữ trạng thái làm mượt giữa các khung hình
  static double _heat = 0, _cold = 0, _rain = 0, _storm = 0, _fire = 0, _flood = 0, _quake = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final f = p.fx;
    double ease(double cur, double target) => cur + (target - cur) * 0.08;
    _heat = ease(_heat, f.heat);
    _cold = ease(_cold, f.cold);
    _rain = ease(_rain, f.rain);
    _storm = ease(_storm, f.storm);
    _fire = ease(_fire, f.fire);
    _flood = ease(_flood, f.flood);
    _quake = ease(_quake, f.quake);
    final time = t.value * 10; // giây
    final rect = Offset.zero & size;
    // nền mờ để chữ và hiệu ứng nổi trên quả cầu
    canvas.drawRect(rect, Paint()..color = const Color(0x55050B10));
    // nắng nóng: phủ sáng vàng cam từ trên xuống
    if (_heat > 0.02) {
      canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, -1.1),
              radius: 1.4,
              colors: [
                Color.fromRGBO(255, 214, 102, 0.55 * _heat),
                Color.fromRGBO(255, 140, 50, 0.28 * _heat),
                const Color(0x00FF8C32),
              ],
              stops: const [0, 0.45, 1],
            ).createShader(rect));
    }
    // lạnh: ám xanh lam, viền sương
    if (_cold > 0.02) {
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(120, 180, 255, 0.22 * _cold));
      canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 1.0,
              colors: [const Color(0x00FFFFFF), Color.fromRGBO(220, 240, 255, 0.35 * _cold)],
              stops: const [0.6, 1],
            ).createShader(rect));
    }
    // mưa: các vệt rơi, dày theo lượng mưa, nghiêng theo bão
    if (_rain > 0.03) {
      final n = reduce ? (40 * _rain).round() : (30 + 170 * _rain).round();
      final slant = 0.15 + 0.6 * _storm;
      final paint = Paint()
        ..color = Color.fromRGBO(190, 220, 255, 0.25 + 0.45 * _rain)
        ..strokeWidth = 1.2 + 0.8 * _rain
        ..strokeCap = StrokeCap.round;
      final len = 14 + 22 * _rain;
      for (var k = 0; k < n; k++) {
        final seed = (k * 7919) % 1000 / 1000.0;
        final seed2 = (k * 104729) % 997 / 997.0;
        final speed = 0.9 + seed2 * 0.8;
        final yy = ((reduce ? seed2 : (seed2 + time * speed)) % 1.0) * (size.height + len) - len;
        final xx = seed * (size.width + 200) - 100 + yy * slant;
        canvas.drawLine(Offset(xx, yy), Offset(xx - len * slant, yy - len), paint);
      }
    }
    // bão: gió xoáy (các cung xoắn quay quanh tâm)
    if (_storm > 0.03) {
      final c = size.center(Offset.zero);
      final rot = reduce ? 0.0 : -time * (1.2 + 2 * _storm);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final maxR = size.shortestSide * 0.48;
      for (var arm = 0; arm < 3; arm++) {
        for (var k = 0; k < 7; k++) {
          final r = maxR * (0.15 + k * 0.12);
          final start = rot + arm * 2 * math.pi / 3 + k * 0.35;
          arc.color = Color.fromRGBO(220, 235, 255, (0.5 - k * 0.05) * _storm);
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, 1.1, false, arc);
        }
      }
      canvas.drawCircle(c, 10, Paint()..color = Color.fromRGBO(255, 255, 255, 0.5 * _storm));
    }
    // lũ: nước dâng từ đáy, mặt sóng
    if (_flood > 0.03) {
      final level = size.height * (1 - 0.35 * _flood);
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 12) {
        path.lineTo(x, level + 8 * math.sin(x / 40 + (reduce ? 0 : time * 3)));
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = Color.fromRGBO(60, 130, 200, 0.45 * _flood));
    }
    // cháy rừng / núi lửa: lửa bập bùng ở đáy
    if (_fire > 0.03) {
      final flick = reduce ? 1.0 : 0.75 + 0.25 * math.sin(time * 17) * math.sin(time * 7.3);
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color.fromRGBO(255, 90, 20, 0.6 * _fire * flick), const Color(0x00FF5A14)],
              stops: const [0, 0.45],
            ).createShader(rect));
    }
    // động đất: các vết nứt / sóng chấn động lan ra từ tâm
    if (_quake > 0.03) {
      final c = size.center(Offset.zero);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      for (var k = 0; k < 4; k++) {
        final ph = ((reduce ? k / 4 : time * 0.8 + k / 4) % 1.0);
        ring.color = Color.fromRGBO(255, 190, 120, (1 - ph) * 0.6 * _quake);
        canvas.drawCircle(c, size.shortestSide * 0.5 * ph, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}
