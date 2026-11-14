// KHÁM PHÁ BẰNG CHẠM: bản đồ quanh một điểm (khoảng 2,4 × 2,4 km, phía bắc ở trên).
// Rê ngón tay: mỗi loại địa hình một âm và một kiểu rung riêng, đọc tên khi sang chỗ mới.
//   sông, hồ, biển: tiếng sóng       · rừng, công viên: tiếng t'rưng trầm (lá xào xạc)
//   khu dân cư: tiếng xe cộ          · đồng ruộng: tiếng trống nhẹ · đường lớn: tiếng lách tách
//   độ cao: tiếng sáo liền hơi, càng cao sáo càng cao · máy rung theo độ dốc (dốc càng đứng rung càng mạnh)
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../audio/audio_engine.dart';
import '../../core/haptics.dart';
import '../../data/nasa_normalized_data.dart';
import '../../live/geo_around.dart';
import '../../live/terrain_tiles.dart';
import '../terrain_scan/terrain_sense.dart' show slopeDegrees;
import '../terrain_scan/touch_grid.dart';

class LocalMapView extends StatefulWidget {
  final AroundData data;
  final String placeVi;
  final VoidCallback? onClose;
  const LocalMapView({super.key, required this.data, required this.placeVi, this.onClose});

  @override
  State<LocalMapView> createState() => _LocalMapViewState();
}

class _LocalMapViewState extends State<LocalMapView> {
  Offset? _finger;
  String _lastKey = '';
  DateTime _lastSound = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSlope = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTraffic = DateTime.fromMillisecondsSinceEpoch(0);
  late AppState _s;
  double _eMin = 0, _eMax = 1;
  // BẢN ĐỒ ĐỊA HÌNH THẬT: độ cao SRTM + lớp phủ MODIS (rừng, nước, ruộng, đô thị), vẽ thành ảnh mượt có bóng đổ
  TerrainPatch? _patch;
  ui.Image? _img;
  bool _real = false; // true khi đã tải xong ô bản đồ thật (không chỉ lưới thô)
  bool _flatTold = false; // đã nói "vùng này bằng phẳng" (một lần) chưa

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = AppScope.read(context);
  }

  @override
  void initState() {
    super.initState();
    final g = widget.data.elevGrid;
    if (g != null) {
      final v = g.where((x) => !x.isNaN).toList();
      if (v.isNotEmpty) {
        _eMin = v.reduce(math.min);
        _eMax = math.max(_eMin + 1, v.reduce(math.max));
      }
    } else {
      // Dữ liệu dự phòng khi elevGrid offline: quét mẫu quanh tâm từ DalatScene hoặc TouchGrid
      final r = widget.data.radius;
      final samples = <double>[];
      final satScene = NasaNormalizedRepo.cached?.dalatScene;
      for (var dy = -r; dy <= r; dy += r / 3) {
        for (var dx = -r; dx <= r; dx += r / 3) {
          final lat = widget.data.lat + dy / 111320.0;
          final lon = widget.data.lon + dx / (111320.0 * math.cos(widget.data.lat * math.pi / 180));
          if (satScene != null && satScene.contains(lat, lon)) {
            final c = satScene.cellAt(lat, lon);
            if (c != null) samples.add(c.elevationM.toDouble());
          }
          final tg = TouchGrid.loaded?.sample(lat, lon);
          if (tg?.elev != null) samples.add(tg!.elev!);
        }
      }
      if (samples.isNotEmpty) {
        _eMin = samples.reduce(math.min);
        _eMax = math.max(_eMin + 1, samples.reduce(math.max));
      } else if (widget.data.elevCenter != null) {
        _eMin = widget.data.elevCenter!;
        _eMax = _eMin + 50;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _s.audio.voiceStart(instrument: 'sao');
    });
    // vẽ ngay bằng lưới độ cao sẵn có (nội suy mượt), rồi thay bằng bản đồ địa hình thật khi tải xong (thường < 1 giây)
    final d = widget.data;
    _usePatch(patchFromGrid(d.lat, d.lon, d.radius, d.elevGrid, d.gridN), real: false);
    loadTerrainPatch(d.lat, d.lon, d.radius).then((p) {
      if (p != null && mounted) _usePatch(p, real: true);
    });
  }

  Future<void> _usePatch(TerrainPatch? p, {required bool real}) async {
    if (p == null) return;
    final img = await terrainImage(p);
    if (!mounted || (_real && !real)) {
      img.dispose();
      return;
    }
    final (lo, hi) = p.relief();
    setState(() {
      _img?.dispose();
      _img = img;
      _patch = p;
      _real = real;
      _eMin = lo;
      _eMax = hi;
    });
  }

  @override
  void dispose() {
    _s.audio.voiceMute();
    _img?.dispose();
    super.dispose();
  }

  double? _elev(double x, double y) => _patch?.elevAt(x, y) ?? widget.data.elevAt(x, y);

  (double, double) _toMeters(Offset o, Size size) {
    final r = widget.data.radius;
    final s = math.min(size.width, size.height) / (2 * r);
    return ((o.dx - size.width / 2) / s, -(o.dy - size.height / 2) / s);
  }

  String _directionOf(double x, double y) {
    final dist = math.sqrt(x * x + y * y);
    if (dist < 180) return 'Khu vực trung tâm';
    final angle = math.atan2(y, x);
    final deg = (angle * 180 / math.pi + 360) % 360;
    if (deg >= 67.5 && deg < 112.5) return 'Phía bắc';
    if (deg >= 22.5 && deg < 67.5) return 'Phía đông bắc';
    if (deg >= 337.5 || deg < 22.5) return 'Phía đông';
    if (deg >= 292.5 && deg < 337.5) return 'Phía đông nam';
    if (deg >= 247.5 && deg < 292.5) return 'Phía nam';
    if (deg >= 202.5 && deg < 247.5) return 'Phía tây nam';
    if (deg >= 157.5 && deg < 202.5) return 'Phía tây';
    return 'Phía tây bắc';
  }

  String _directionOfEn(double x, double y) {
    final dist = math.sqrt(x * x + y * y);
    if (dist < 180) return 'Center area';
    final angle = math.atan2(y, x);
    final deg = (angle * 180 / math.pi + 360) % 360;
    if (deg >= 67.5 && deg < 112.5) return 'North';
    if (deg >= 22.5 && deg < 67.5) return 'North-East';
    if (deg >= 337.5 || deg < 22.5) return 'East';
    if (deg >= 292.5 && deg < 337.5) return 'South-East';
    if (deg >= 247.5 && deg < 292.5) return 'South';
    if (deg >= 202.5 && deg < 247.5) return 'South-West';
    if (deg >= 157.5 && deg < 202.5) return 'West';
    return 'North-West';
  }

  void _touch(Offset o, Size size) {
    setState(() => _finger = o);
    final (x, y) = _toMeters(o, size);
    final d = widget.data;
    if (x.abs() > d.radius || y.abs() > d.radius) {
      _s.audio.voiceMute();
      return;
    }
    final pan = (x / d.radius).clamp(-1.0, 1.0);
    final touchLat = d.lat + y / 111320.0;
    final touchLon = d.lon + x / (111320.0 * math.cos(d.lat * math.pi / 180));
    final satScene = NasaNormalizedRepo.cached?.dalatScene;
    final satCell = (satScene != null && satScene.contains(touchLat, touchLon)) ? satScene.cellAt(touchLat, touchLon) : null;
    final tg = TouchGrid.loaded?.sample(touchLat, touchLon);

    final (osmKind, f) = d.classify(x, y);
    var kind = osmKind;
    String name, nameEn;

    if (f != null && f.name.isNotEmpty) {
      name = f.name;
      nameEn = f.name;
    } else if (f != null) {
      name = kindVi(kind);
      nameEn = kindEn(kind);
    } else {
      final cov = _real ? _patch?.coverAt(x, y) : null;
      final ck = cov == null ? null : igbpKinds[cov];
      // thấp hơn mực nước biển rõ rệt (mặt sông, hồ, biển trên SRTM) — không gọi là "biển" vì sông cũng thế
      final lowWater = _real && (_patch?.elevAt(x, y) ?? 1) < -1;
      if (lowWater) {
        kind = 'water';
        name = 'Mặt nước';
        nameEn = 'Water';
      } else if (ck != null && ck.$1.isNotEmpty) {
        // lớp phủ đất thật (NASA MODIS): rừng, mặt nước, ruộng, khu dân cư…
        kind = ck.$1;
        name = ck.$2;
        nameEn = ck.$3;
      } else if (satCell != null && satCell.landCoverVi.isNotEmpty) {
      // Dữ liệu vệ tinh chuyên sâu từ NASA và TouchGrid
        name = satCell.landCoverVi;
        nameEn = satCell.landCoverEn;
        if (satCell.landCoverVi.contains('nước') || satCell.landCoverVi.contains('hồ')) {
          kind = 'water';
        } else if (satCell.landCoverVi.contains('rừng') || satCell.landCoverVi.contains('cây')) {
          kind = 'forest';
        } else if (satCell.landCoverVi.contains('cỏ') || satCell.landCoverVi.contains('hoa màu')) {
          kind = 'farmland';
        }
      } else if (tg != null && (tg.sea || (tg.water != null && tg.water! >= (TouchGrid.loaded?.waterThreshold ?? 0.5)))) {
        kind = 'water';
        name = tg.sea ? 'Vùng biển' : 'Mặt nước sông hồ';
        nameEn = tg.sea ? 'Sea' : 'Water body / Lake';
      } else if (tg != null && tg.pop != null && tg.pop! >= 400) {
        kind = 'residential';
        name = 'Khu dân cư';
        nameEn = 'Residential area';
      } else {
        name = _directionOf(x, y);
        nameEn = _directionOfEn(x, y);
      }
    }

    // F3: tiếng SÁO liền hơi theo độ cao (trong vùng nhỏ: so với thấp nhất – cao nhất của bản đồ để nghe rõ chênh lệch)
    final e = _elev(x, y) ?? satCell?.elevationM.toDouble() ?? tg?.elev;
    if (e != null) {
      final ex = ((e - _eMin) / math.max(1.0, _eMax - _eMin)).clamp(0.0, 1.0);
      _s.audio.voiceStart(instrument: 'sao');
      _s.audio.voiceSet(freq: 2 * toScale(0.1 + 0.8 * ex), pan: pan, gain: 0.08);
    }

    // F3: độ dốc thật (lưới độ cao, bước 60 m; vùng Đà Lạt có thêm độ dốc SRTM; hoặc từ TouchGrid) → rung theo độ dốc
    var sl = double.nan;
    final nowSlope = DateTime.now();
    if (nowSlope.difference(_lastSlope).inMilliseconds > 150) {
      const step = 60.0;
      sl = slopeDegrees(_elev(x, y + step) ?? double.nan, _elev(x, y - step) ?? double.nan,
          _elev(x + step, y) ?? double.nan, _elev(x - step, y) ?? double.nan, step / 1000);
      // đã có bản đồ địa hình thật (độ cao ~18 m) → chỉ dùng độ dốc tính từ nó; lưới thô ~1 km (Đà Lạt, TouchGrid)
      // chỉ là dự phòng — trước đây lấy GIÁ TRỊ LỚN NHẤT của các nguồn nên chỗ phẳng vẫn rung như dốc
      if (!_real) {
        if (satCell != null && (sl.isNaN || satCell.slopeDeg > sl)) sl = satCell.slopeDeg;
        if (tg?.slope != null && (sl.isNaN || tg!.slope! > sl)) sl = tg!.slope!;
      }
      if (kind != 'water' && kind != 'river' && !sl.isNaN && Haptics.slope(sl)) _lastSlope = nowSlope;
    }

    final key = f != null
        ? '$kind|${f.name}'
        : '$name|$kind|${e != null ? (e / 5).round() * 5 : 0}';
    final now = DateTime.now();
    if (key != _lastKey) {
      _lastKey = key;
      // rung nhẹ khi sang mặt nước / khu dân cư
      if (kind == 'water' || kind == 'river' || kind == 'residential') Haptics.terrain(kind);
      final effSlope = !sl.isNaN ? sl : (_real ? 0.0 : (satCell?.slopeDeg ?? tg?.slope ?? 0.0));
      final slopeVi = effSlope >= 8.0 ? ', dốc ${effSlope.round()} độ' : '';
      final coverVi = (!_real && f == null && satCell != null && name != satCell.landCoverVi) ? ', ${satCell.landCoverVi}' : '';
      final elevText = e != null ? ', cao ${e.round()} mét$slopeVi$coverVi' : '';
      final elevTextEn = e != null ? ', ${e.round()} metres' : '';
      // vùng gần như phẳng (nội thành, đồng bằng): nói thật một lần — tiếng sáo gần như đều là đúng, không phải lỗi
      var flatVi = '', flatEn = '';
      final pt = _patch;
      if (!_flatTold && _real && pt != null && pt.reliefSpan < 15) {
        _flatTold = true;
        flatVi = '. Vùng này khá bằng phẳng, cao thấp chỉ chênh khoảng ${math.max(1, pt.reliefSpan.round())} mét';
        flatEn = '. This area is quite flat, about ${math.max(1, pt.reliefSpan.round())} metres of relief';
      }
      _s.speaker.quick('$name$elevText$flatVi', '$nameEn$elevTextEn$flatEn');
      setState(() {
        _currentLabel = '$name${e != null ? ' • ${e.round()} m' : ''}${slopeVi.isNotEmpty ? ' • Dốc ${effSlope.round()}°' : ''}';
      });
    }
    if (now.difference(_lastSound).inMilliseconds > 260) {
      _lastSound = now;
      switch (kind) {
        case 'water':
        case 'river':
        case 'coast':
        case 'beach':
          _s.audio.song(0.18, pan);
        case 'forest':
        case 'park':
          _s.audio.trung(kind == 'forest' ? 392 : 784, 0.08, pan);
        case 'residential':
          // F3: khu dân cư → tiếng xe cộ (mẫu dài 3 giây: không phát chồng quá dày)
          if (now.difference(_lastTraffic).inMilliseconds > 1600) {
            _lastTraffic = now;
            _s.audio.ambient('traffic', amp: 0.2, pan: pan);
          }
        case 'farmland':
          _s.audio.trong(0.12, pan);
        case 'road':
          _s.audio.crackle(0.3, pan);
      }
    }
  }

  String _currentLabel = '';

  void _end() {
    setState(() {
      _finger = null;
      _currentLabel = '';
    });
    _s.audio.voiceMute();
    _s.speaker.resetQuick();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      return Semantics(
        label: _s.t('Bản đồ quanh ${widget.placeVi}. Rê ngón tay để nghe địa hình.',
            'Map around ${widget.placeVi}. Drag your finger to hear the terrain.'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _touch(d.localPosition, size),
          onPanUpdate: (d) => _touch(d.localPosition, size),
          onPanEnd: (_) => _end(),
          onTapDown: (d) => _touch(d.localPosition, size),
          onTapUp: (_) => _end(),
            // nền bản đồ vẽ MỘT lần (RepaintBoundary); rê ngón tay chỉ vẽ lại vòng tròn ngón tay ở lớp trên
            child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(
              child: CustomPaint(size: Size.infinite, painter: _LocalPainter(widget.data, widget.placeVi, _eMin, _eMax, en: _s.lang == 'en', img: _img)),
            ),
            CustomPaint(size: Size.infinite, painter: _FingerPainter(_finger)),

            // Thước đo độ cao (Legend) + Nút đóng góc trên
            Positioned(
              top: 68,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onClose != null)
                    Semantics(
                      button: true,
                      label: _s.t('Thoát bản đồ chạm', 'Exit touch map'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x66E4BB63)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFFE4BB63)),
                              const SizedBox(width: 5),
                              Text(_s.t('Thoát', 'Exit'),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFF1E5CC), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_eMin.round()}m', style: const TextStyle(fontSize: 11, color: Color(0xFFC2A67E), fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Container(
                          width: 44,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(colors: [Color(0xFF243A2E), Color(0xFF6E6040), Color(0xFFC4A868)]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${_eMax.round()}m', style: const TextStyle(fontSize: 11, color: Color(0xFFF1E5CC), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Thanh hướng dẫn & phản hồi vị trí chạm ở đáy màn hình
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xDD181410),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33E4BB63)),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentLabel.isNotEmpty) ...[
                      Text(
                        _currentLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFD57A),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFFE4BB63)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _currentLabel.isEmpty
                                ? _s.t('Rê ngón tay để nghe tiếng sáo theo độ cao và cảm nhận độ dốc',
                                    'Drag your finger to hear the flute rise with elevation and feel the slope')
                                : _s.t('Nói "thoát" hoặc vẽ chữ Z để quay lại', 'Say "exit" or draw a Z to go back'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFE0D5C1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _LocalPainter extends CustomPainter {
  final AroundData d;
  final String name;
  final double eMin, eMax;
  final bool en;
  final ui.Image? img; // bản đồ địa hình thật (mượt) — có thì vẽ ảnh này thay cho các ô
  _LocalPainter(this.d, this.name, this.eMin, this.eMax, {this.en = false, this.img});

  static const _col = {
    'water': Color(0xFF267DC0),
    'river': Color(0xFF3BA2E6),
    'coast': Color(0xFF6BB5DE),
    'beach': Color(0xFFE5D5A4),
    'forest': Color(0xFF2B7342),
    'park': Color(0xFF4C995A),
    'farmland': Color(0xFFA8A35E),
    'residential': Color(0xFF7D6E60),
    'place': Color(0xFF7D6E60),
    'road': Color(0xFFE6DFC8),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = d.radius;
    final s = math.min(size.width, size.height) / (2 * r);
    final c = size.center(Offset.zero);
    Offset o(double x, double y) => Offset(c.dx + x * s, c.dy - y * s);

    // Nền bản đồ trầm ấm hiện đại
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0F1416));

    // Nền địa hình DEM vệ tinh liên tục (Emerald trầm -> Đất nung -> Vàng kim)
    final g = d.elevGrid;
    final int n = (g != null && d.gridN > 1) ? d.gridN : 10;
    final cell = 2 * r / (n - 1);
    final range = math.max(1.0, eMax - eMin);
    final satScene = NasaNormalizedRepo.cached?.dalatScene;
    final tg = TouchGrid.loaded;

    double? getElev(int row, int col) {
      if (g != null) {
        final val = g[row * n + col];
        if (!val.isNaN) return val;
      }
      final x = -r + col * cell, y = r - row * cell;
      final lat = d.lat + y / 111320.0;
      final lon = d.lon + x / (111320.0 * math.cos(d.lat * math.pi / 180));
      if (satScene != null && satScene.contains(lat, lon)) {
        final c = satScene.cellAt(lat, lon);
        if (c != null) return c.elevationM.toDouble();
      }
      return tg?.sample(lat, lon)?.elev;
    }

    var hasTerrainGrid = false;
    final im = img;
    if (im != null) {
      // ảnh địa hình thật: phóng to bằng lọc mượt → sườn núi, thung lũng, mặt nước liền mạch (không thành ô)
      final dst = Rect.fromCenter(center: c, width: 2 * r * s, height: 2 * r * s);
      canvas.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.medium);
      hasTerrainGrid = true;
    }
    for (var row = 0; im == null && row < n; row++) {
      for (var col = 0; col < n; col++) {
        final e = getElev(row, col);
        if (e == null || e.isNaN) continue;
        hasTerrainGrid = true;
        final k = ((e - eMin) / range).clamp(0.0, 1.0);
        final x = -r + col * cell, y = r - row * cell;

        // Phối màu đa tầng mượt mà
        Color colTier;
        if (k < 0.35) {
          colTier = Color.lerp(const Color(0xFF14241F), const Color(0xFF2A4235), k / 0.35)!;
        } else if (k < 0.7) {
          colTier = Color.lerp(const Color(0xFF2A4235), const Color(0xFF635237), (k - 0.35) / 0.35)!;
        } else {
          colTier = Color.lerp(const Color(0xFF635237), const Color(0xFFB89A5A), (k - 0.7) / 0.3)!;
        }

        // Hiệu ứng Hillshade đổ bóng địa hình theo hướng ánh sáng Tây Bắc (-1, 1)
        double hillshade = 1.0;
        if (row > 0 && col < n - 1) {
          final eRight = getElev(row, col + 1);
          final eTop = getElev(row - 1, col);
          if (eRight != null && eTop != null && !eRight.isNaN && !eTop.isNaN) {
            final dx = (e - eRight) / range;
            final dy = (eTop - e) / range;
            hillshade = (1.0 + (dx + dy) * 0.4).clamp(0.75, 1.25);
          }
        }
        final rC = (colTier.r * hillshade).clamp(0.0, 1.0);
        final gC = (colTier.g * hillshade).clamp(0.0, 1.0);
        final bC = (colTier.b * hillshade).clamp(0.0, 1.0);
        final finalCol = Color.fromRGBO((rC * 255).round(), (gC * 255).round(), (bC * 255).round(), 1.0);

        // Vẽ các ô vuông liền mạch không có khoảng hở
        final rect = Rect.fromCenter(center: o(x, y), width: cell * s + 0.6, height: cell * s + 0.6);
        canvas.drawRect(rect, Paint()..color = finalCol);
      }
    }

    if (hasTerrainGrid) {
      // Đường viền tinh tế bao quanh khu vực bản đồ
      final mapRect = Rect.fromCenter(center: c, width: 2 * r * s, height: 2 * r * s);
      canvas.drawRect(
        mapRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0x33E4BB63),
      );
    }

    // Vòng tròn cự ly Radar (Range Rings): 400m, 800m, 1200m
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.08);

    for (final dist in [400.0, 800.0, 1200.0]) {
      if (dist <= r * 1.05) {
        canvas.drawCircle(c, dist * s, ringPaint);
      }
    }

    // Trục chữ thập định hướng tâm
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawLine(Offset(c.dx - r * s, c.dy), Offset(c.dx + r * s, c.dy), axisPaint);
    canvas.drawLine(Offset(c.dx, c.dy - r * s), Offset(c.dx, c.dy + r * s), axisPaint);

    // Đối tượng OpenStreetMap: vùng trước, đường nét sau
    // thứ tự vẽ vùng: đất ở / ruộng / cỏ / rừng trước, mặt nước sau cùng (không bị rừng, cỏ che mất)
    const zOrder = {'residential': 0, 'place': 0, 'farmland': 1, 'park': 2, 'forest': 3, 'beach': 4, 'water': 5, 'river': 6};
    final feats = [...d.features]..sort((a, b) => (zOrder[a.kind] ?? 3).compareTo(zOrder[b.kind] ?? 3));
    // chỉ vẽ trong khung bản đồ (đường phố, sông ngoài khung không tràn ra mép màn hình)
    canvas.save();
    canvas.clipRect(Rect.fromCenter(center: c, width: 2 * r * s, height: 2 * r * s));
    for (final pass in [true, false]) {
      for (final f in feats) {
        if (f.area != pass) continue;
        final col = _col[f.kind];
        if (col == null) continue;
        if (f.area && f.evenOdd) {
          // vùng có lỗ (đảo giữa hồ…): gộp mọi vòng vào một đường, tô chẵn–lẻ
          final path = Path()..fillType = PathFillType.evenOdd;
          for (final p in f.parts) {
            if (p.length < 6) continue;
            path.moveTo(o(p[0], p[1]).dx, o(p[0], p[1]).dy);
            for (var i = 2; i < p.length; i += 2) {
              final q = o(p[i], p[i + 1]);
              path.lineTo(q.dx, q.dy);
            }
            path.close();
          }
          canvas.drawPath(path, Paint()..color = col.withValues(alpha: im != null ? 0.55 : 0.82));
          continue;
        }
        for (final p in f.parts) {
          if (p.length < 4) continue;
          final path = Path()..moveTo(o(p[0], p[1]).dx, o(p[0], p[1]).dy);
          for (var i = 2; i < p.length; i += 2) {
            final q = o(p[i], p[i + 1]);
            path.lineTo(q.dx, q.dy);
          }
          if (f.area) {
            path.close();
            canvas.drawPath(path, Paint()..color = col.withValues(alpha: im != null ? 0.5 : 0.82));
          } else {
            canvas.drawPath(
                path,
                Paint()
                  ..style = PaintingStyle.stroke
                  // bề rộng nét theo bề rộng thật (sông lớn đậm, suối mảnh, phố nhỏ mảnh), tối thiểu dễ nhìn
                  ..strokeWidth = f.width != null
                      ? (f.width! * s).clamp(f.kind == 'road' ? 1.4 : 2.2, f.kind == 'river' ? 9.0 : 4.0)
                      : (f.kind == 'river' ? 5.5 : 3.2)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round
                  ..color = col);
          }
        }
      }
    }

    canvas.restore();

    // 4 Phương hướng chính (Cardinal Labels)
    const cardStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0x99E4BB63));
    void drawLabel(String txt, Offset pos, {bool centerX = true, bool centerY = true}) {
      final tp = TextPainter(text: TextSpan(text: txt, style: cardStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(centerX ? pos.dx - tp.width / 2 : pos.dx, centerY ? pos.dy - tp.height / 2 : pos.dy));
    }
    drawLabel(en ? 'NORTH ↑' : 'BẮC ↑', Offset(c.dx, math.max(16, c.dy - r * s + 12)));
    drawLabel(en ? 'SOUTH ↓' : 'NAM ↓', Offset(c.dx, math.min(size.height - 76, c.dy + r * s - 12)));
    drawLabel(en ? '← WEST' : '← TÂY', Offset(math.max(12, c.dx - r * s + 24), c.dy));
    drawLabel(en ? 'EAST →' : 'ĐÔNG →', Offset(math.min(size.width - 24, c.dx + r * s - 24), c.dy));

    // Điểm tâm (vị trí hiện tại): tâm sáng rực rỡ với quầng hào quang
    canvas.drawCircle(c, 14, Paint()..color = const Color(0x33E4BB63));
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFFFFD57A));
    canvas.drawCircle(c, 8, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..color = Colors.black);

    // Tiêu đề địa danh góc trên
    final titleTp = TextPainter(
      text: TextSpan(
          text: name,
          style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF1E5CC))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 120);
    titleTp.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(_LocalPainter o) => o.d != d || o.name != name || o.img != img;
}

class _FingerPainter extends CustomPainter {
  final Offset? finger;
  _FingerPainter(this.finger);

  @override
  void paint(Canvas canvas, Size size) {
    final f = finger;
    if (f == null) return;
    canvas.drawCircle(
        f,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(_FingerPainter o) => o.finger != finger;
}
