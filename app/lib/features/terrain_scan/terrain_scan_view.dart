// F3 — QUÉT MẶT CẮT ĐỊA HÌNH.
// Lấy bản đồ độ cao của khu vực rồi quét hai lượt, mỗi lượt KHÔNG QUÁ 8 GIÂY:
//   lượt 1: lát quét chạy từ BẮC xuống NAM (mỗi lát là một hàng tây → đông);
//   lượt 2: lát quét chạy từ TÂY sang ĐÔNG (mỗi lát là một cột bắc → nam), tiếng đi từ tai trái sang tai phải.
// Trong lúc quét: hình mặt cắt độ cao của lát hiện tại + vạch quét chạy trên bản đồ độ cao; tiếng SÁO liền hơi
// theo độ cao TRUNG BÌNH của lát (cao → sáo cao), lát toàn biển thêm tiếng sóng.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/audio_engine.dart';
import '../../core/format.dart' show fmtNum;
import '../../core/haptics.dart';
import '../globe/terrain.dart' show Terrain;
import '../globe/terrain_data.dart' show bandOf;
import 'terrain_sense.dart';

class TerrainScanPlayer extends ChangeNotifier {
  final AudioEngine audio;
  final Future<void> Function(String vi, String en) say;
  final ElevGrid grid;
  final String placeVi, placeEn;
  final double widthKm, heightKm;

  TerrainScanPlayer({
    required this.audio,
    required this.say,
    required this.grid,
    required this.placeVi,
    required this.placeEn,
    required this.widthKm,
    required this.heightKm,
  });

  /// 'ns' (bắc → nam) | 'ew' (tây → đông) | 'done'
  String phase = 'ns';
  int index = 0;
  bool running = false;
  final nsMeans = <double>[], ewMeans = <double>[];
  int _gen = 0;

  List<double> get slice => phase == 'ew' ? grid.col(index.clamp(0, grid.cols - 1)) : grid.row(index.clamp(0, grid.rows - 1));
  double get sliceMeanNow => sliceMean(slice);

  Future<void> run() async {
    final my = ++_gen;
    running = true;
    nsMeans
      ..clear()
      ..addAll([for (var r = 0; r < grid.rows; r++) sliceMean(grid.row(r))]);
    ewMeans
      ..clear()
      ..addAll([for (var c = 0; c < grid.cols; c++) sliceMean(grid.col(c))]);
    phase = 'ns';
    index = 0;
    notifyListeners();
    await say(
        'Quét mặt cắt địa hình quanh $placeVi, ${(widthKm - heightKm).abs() < 5 ? 'vùng rộng khoảng ${fmtNum(widthKm, 0)} ki-lô-mét mỗi chiều' : 'vùng ngang khoảng ${fmtNum(widthKm, 0)}, dọc khoảng ${fmtNum(heightKm, 0)} ki-lô-mét'}. '
            'Tiếng sáo cao thấp theo độ cao trung bình của lát quét. Lượt một: từ Bắc xuống Nam.',
        'Scanning the terrain around $placeEn, about ${fmtNum(widthKm, 0, lang: 'en')} by ${fmtNum(heightKm, 0, lang: 'en')} kilometres. '
            'The flute follows the average height of each slice. First pass: north to south.');
    if (my != _gen) return;
    await _sweep('ns', my);
    if (my != _gen) return;
    await say('Lượt hai: từ Tây sang Đông.', 'Second pass: west to east.');
    if (my != _gen) return;
    await _sweep('ew', my);
    if (my != _gen) return;
    phase = 'done';
    running = false;
    notifyListeners();
    await say(_summaryVi(), _summaryEn());
  }

  Future<void> _sweep(String ph, int my) async {
    phase = ph;
    final means = ph == 'ns' ? nsMeans : ewMeans;
    final n = means.length;
    final step = scanStepMs(n); // cả lượt ≤ 8 giây
    await audio.voiceStart(instrument: 'sao');
    var lastBand = -99;
    for (var k = 0; k < n && my == _gen; k++) {
      index = k;
      notifyListeners();
      final m = means[k];
      final pan = ph == 'ew' ? -0.9 + 1.8 * k / math.max(1, n - 1) : 0.0;
      if (!m.isNaN) {
        audio.voiceSet(freq: fluteFreq(m), pan: pan, gain: m < 0 ? 0.04 : 0.1);
        if (m < 0 && k % 3 == 0) audio.song(0.12, pan);
        final b = bandOf(m);
        if (b != lastBand && lastBand != -99) Haptics.light();
        lastBand = b;
      }
      await Future<void>.delayed(Duration(milliseconds: step));
    }
    audio.voiceMute();
  }

  String _where(String ph, int k, bool en) {
    final n = ph == 'ns' ? grid.rows : grid.cols;
    final km = (ph == 'ns' ? heightKm : widthKm) * k / math.max(1, n - 1);
    if (en) return ph == 'ns' ? '${fmtNum(km, 0, lang: 'en')} km south of the northern edge' : '${fmtNum(km, 0, lang: 'en')} km east of the western edge';
    return ph == 'ns' ? 'cách mép bắc khoảng ${fmtNum(km, 0)} ki-lô-mét về phía nam' : 'cách mép tây khoảng ${fmtNum(km, 0)} ki-lô-mét về phía đông';
  }

  String _summaryVi() {
    final a = scanExtremes(nsMeans), b = scanExtremes(ewMeans);
    if (a.hi < 0) return 'Chưa có số liệu độ cao ở vùng này.';
    return 'Bắc xuống Nam: dải cao nhất ${_where('ns', a.hi, false)}, trung bình ${fmtNum(a.hiMean, 0)} mét; '
        'thấp nhất ${_where('ns', a.lo, false)}, ${fmtNum(a.loMean, 0)} mét. '
        'Tây sang Đông: dải cao nhất ${_where('ew', b.hi, false)}, trung bình ${fmtNum(b.hiMean, 0)} mét; '
        'thấp nhất ${_where('ew', b.lo, false)}, ${fmtNum(b.loMean, 0)} mét.';
  }

  String _summaryEn() {
    final a = scanExtremes(nsMeans), b = scanExtremes(ewMeans);
    if (a.hi < 0) return 'No elevation data here yet.';
    return 'North to south: highest band ${_where('ns', a.hi, true)}, averaging ${fmtNum(a.hiMean, 0, lang: 'en')} m. '
        'West to east: highest band ${_where('ew', b.hi, true)}, averaging ${fmtNum(b.hiMean, 0, lang: 'en')} m.';
  }

  void stop() {
    _gen++;
    running = false;
    audio.voiceMute();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Hình ảnh hoá: bản đồ độ cao với vạch quét + mặt cắt độ cao của lát hiện tại.
class TerrainScanView extends StatelessWidget {
  final TerrainScanPlayer player;
  final VoidCallback onClose;
  final bool en;
  const TerrainScanView({super.key, required this.player, required this.onClose, this.en = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: en ? 'Terrain cross-section scan' : 'Đang quét mặt cắt địa hình',
      child: AnimatedBuilder(
        animation: player,
        builder: (context, _) {
          final p = player;
          final ns = p.phase != 'ew';
          final n = ns ? p.grid.rows : p.grid.cols;
          final m = p.sliceMeanNow;
          return Container(
            color: const Color(0xB3050B10),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
                child: Column(children: [
                  Row(children: [
                    // nút THOÁT to, ở góc TRÁI (xa cụm nút Gõ lệnh / Hướng dẫn / Cài đặt ở góc phải — tránh bấm nhầm)
                    Semantics(
                      button: true,
                      label: en ? 'Exit terrain scan' : 'Thoát quét địa hình',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onClose,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x66E4BB63)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFE4BB63)),
                            const SizedBox(width: 6),
                            Text(en ? 'Exit' : 'Thoát',
                                style: const TextStyle(fontSize: 13, color: Color(0xFFF1E5CC), fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        en
                            ? 'Terrain scan · ${p.placeEn} · ${p.phase == 'done' ? 'done' : (ns ? 'north → south' : 'west → east')}'
                            : 'Quét mặt cắt · ${p.placeVi} · ${p.phase == 'done' ? 'xong' : (ns ? 'Bắc → Nam' : 'Tây → Đông')}',
                        style: const TextStyle(color: Color(0xFF43D8A0), fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(painter: _MapPainter(p, en: en), size: Size.infinite),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xCC0B151A), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          en
                              ? 'Slice ${math.min(p.index + 1, n)}/$n · average ${fmtNum(m, 0, lang: 'en')} m'
                              : 'Lát ${math.min(p.index + 1, n)}/$n · trung bình ${fmtNum(m, 0)} m',
                          style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Expanded(child: CustomPaint(painter: _ProfilePainter(p, en: en), size: Size.infinite)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final TerrainScanPlayer p;
  final bool en;
  _MapPainter(this.p, {this.en = false});

  @override
  void paint(Canvas canvas, Size size) {
    final g = p.grid;
    if (g.rows == 0 || g.cols == 0) return;
    final cw = size.width / g.cols, ch = size.height / g.rows;
    final paint = Paint();
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final e = g.z[r][c];
        paint.color = e.isNaN ? const Color(0xFF222222) : Color(Terrain.hypso(e) | 0xFF000000);
        canvas.drawRect(Rect.fromLTWH(c * cw, r * ch, cw + 0.5, ch + 0.5), paint);
      }
    }
    // nhãn hướng
    void label(String t, Offset o) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    label(en ? 'N' : 'B', Offset(size.width / 2, 10));
    label(en ? 'S' : 'N', Offset(size.width / 2, size.height - 10));
    label(en ? 'W' : 'T', Offset(10, size.height / 2));
    label(en ? 'E' : 'Đ', Offset(size.width - 10, size.height / 2));
    if (p.phase == 'done') return;
    // vạch quét
    final line = Paint()
      ..color = const Color(0xFFFFE066)
      ..strokeWidth = 3;
    final glow = Paint()..color = const Color(0x44FFE066);
    if (p.phase == 'ns') {
      final y = (p.index + 0.5) * ch;
      canvas.drawRect(Rect.fromLTWH(0, y - ch / 2, size.width, ch), glow);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    } else {
      final x = (p.index + 0.5) * cw;
      canvas.drawRect(Rect.fromLTWH(x - cw / 2, 0, cw, size.height), glow);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

class _ProfilePainter extends CustomPainter {
  final TerrainScanPlayer p;
  final bool en;
  _ProfilePainter(this.p, {this.en = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = p.slice;
    if (s.isEmpty) return;
    final (lo0, hi0) = p.grid.range();
    final lo = math.min(lo0, 0.0), hi = math.max(hi0, lo + 1);
    double y(double e) => size.height - (e - lo) / (hi - lo) * size.height;
    // mực nước biển
    final sea = y(0);
    canvas.drawLine(Offset(0, sea), Offset(size.width, sea), Paint()..color = const Color(0x664FA3D1)..strokeWidth = 1);
    final path = Path()..moveTo(0, size.height);
    for (var k = 0; k < s.length; k++) {
      final x = size.width * k / math.max(1, s.length - 1);
      path.lineTo(x, y(s[k].isNaN ? lo : s[k]));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC8A060), Color(0xFF3E7D3A)],
          ).createShader(Offset.zero & size));
    // độ cao trung bình của lát
    final m = sliceMean(s);
    if (!m.isNaN) {
      final my = y(m);
      final dash = Paint()
        ..color = const Color(0xFFFFE066)
        ..strokeWidth = 2;
      for (var x = 0.0; x < size.width; x += 12) {
        canvas.drawLine(Offset(x, my), Offset(math.min(size.width, x + 6), my), dash);
      }
    }
    void label(String t, Offset o) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: const TextStyle(color: Color(0xCCFBF4E4), fontSize: 11)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o);
    }

    label('${fmtNum(hi, 0)} m', const Offset(2, 0));
    label('${fmtNum(lo, 0)} m', Offset(2, size.height - 14));
    final ew = p.phase == 'ew';
    label(ew ? (en ? 'N' : 'Bắc') : (en ? 'W' : 'Tây'), Offset(2, size.height / 2));
    label(ew ? (en ? 'S' : 'Nam') : (en ? 'E' : 'Đông'), Offset(size.width - 30, size.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) => true;
}
