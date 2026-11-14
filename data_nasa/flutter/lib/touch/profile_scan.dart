// profile_scan.dart — chức năng mới F3: "Quét mặt cắt địa hình".
// Đầu vào: người dùng muốn nghe âm thanh địa hình của bản đồ đang mở (cả nước hoặc một tỉnh).
// Thực hiện:
//   1. Lấy bản đồ độ cao của khu vực (lớp elev của TouchMap đang mở).
//   2. Lát quét đi từ Bắc xuống Nam (mỗi lát là một hàng ô), rồi từ Tây sang Đông (mỗi lát là một cột).
//   3. Vẽ mặt cắt độ cao của lát đang quét + vạch quét trên bản đồ.
//   4. Phát nốt sáo theo độ cao TRUNG BÌNH của lát (chỉ tính ô đất liền; lát toàn biển phát tiếng sóng).
//   5. Mỗi lượt quét không quá 8 giây (sweepDuration).
// Dùng: Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScanPage(map: map, sound: sound)));
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'touch_map.dart';
import 'touch_rules.dart';
import 'touch_sound.dart';

enum ScanAxis { northSouth, westEast }

/// Số liệu của một lượt quét, tính sẵn một lần (không phụ thuộc giao diện để kiểm thử được).
class ScanData {
  ScanData(this.axis, this.profiles, this.positions)
      : means = [for (final p in profiles) meanOf(p)],
        maxElev = profiles.expand((p) => p).whereType<double>().fold(0.0, (a, b) => b > a ? b : a);

  /// axis = northSouth: lát thứ i là hàng i (vị trí = vĩ độ); westEast: cột i (vị trí = kinh độ).
  factory ScanData.fromMap(TouchMap m, ScanAxis axis) => axis == ScanAxis.northSouth
      ? ScanData(axis, [for (var r = 0; r < m.rows; r++) m.rowProfile(r)], [for (var r = 0; r < m.rows; r++) m.latOfRow(r)])
      : ScanData(axis, [for (var c = 0; c < m.cols; c++) m.colProfile(c)], [for (var c = 0; c < m.cols; c++) m.lonOfCol(c)]);

  final ScanAxis axis;
  final List<List<double?>> profiles; // độ cao từng ô của mỗi lát; null = biển
  final List<double> positions; // vĩ độ hoặc kinh độ của mỗi lát
  final List<double?> means; // độ cao trung bình phần đất liền của mỗi lát
  final double maxElev;

  int get slices => profiles.length;
  Duration get duration => sweepDuration(slices);

  /// Lát có độ cao trung bình lớn nhất (để tóm tắt sau khi quét).
  int? get highestSlice {
    int? best;
    for (var i = 0; i < slices; i++) {
      final m = means[i];
      if (m != null && (best == null || m > means[best]!)) best = i;
    }
    return best;
  }

  String get startWords => axis == ScanAxis.northSouth ? 'Quét từ Bắc xuống Nam.' : 'Quét từ Tây sang Đông.';

  String summary() {
    final i = highestSlice;
    if (i == null) return 'Khu vực này không có đất liền.';
    final pos = positions[i].toStringAsFixed(1).replaceAll('.', ' phẩy ');
    final where = axis == ScanAxis.northSouth ? 'vĩ độ $pos độ Bắc' : 'kinh độ $pos độ Đông';
    return 'Lát cao nhất ở $where, trung bình khoảng ${roundMeters(means[i]!)} mét.';
  }
}

class ProfileScanPage extends StatefulWidget {
  const ProfileScanPage({super.key, required this.map, required this.sound, this.title = ''});
  final TouchMap map;
  final TouchSound sound;
  final String title;

  @override
  State<ProfileScanPage> createState() => _ProfileScanPageState();
}

class _ProfileScanPageState extends State<ProfileScanPage> with SingleTickerProviderStateMixin {
  late final Map<ScanAxis, ScanData> data = {
    for (final a in ScanAxis.values) a: ScanData.fromMap(widget.map, a),
  };
  late final Ticker _ticker = createTicker(_onTick);
  ScanAxis _axis = ScanAxis.northSouth;
  int _slice = 0, _lastSounded = -1;
  bool _running = false, _cancelled = false;
  Completer<void>? _sweepDone;

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  Future<void> _runAll() async {
    if (_running) return;
    _running = true;
    final name = widget.title.isEmpty ? '' : ' ${widget.title}';
    await widget.sound.sayAndWait('Quét mặt cắt địa hình$name. Nốt sáo càng cao là lát cắt càng cao.');
    for (final axis in ScanAxis.values) {
      if (_cancelled) return;
      final d = data[axis]!;
      setState(() {
        _axis = axis;
        _slice = 0;
        _lastSounded = -1;
      });
      await widget.sound.sayAndWait(d.startWords);
      if (_cancelled) return;
      _sweepDone = Completer<void>();
      _ticker.start();
      await _sweepDone!.future;
      _ticker.stop();
      widget.sound.water(WaterKind.none);
      if (_cancelled) return;
      await widget.sound.sayAndWait(d.summary());
    }
    _running = false;
    if (!_cancelled) widget.sound.say('Xong. Chạm hai lần để quét lại.');
  }

  void _onTick(Duration elapsed) {
    final d = data[_axis]!;
    final i = sliceAt(elapsed, d.duration, d.slices);
    if (i != _slice) setState(() => _slice = i);
    if (i != _lastSounded) {
      _lastSounded = i;
      final m = d.means[i];
      if (m == null) {
        widget.sound.water(WaterKind.sea);
      } else {
        widget.sound.water(WaterKind.none);
        widget.sound.elevNote(m); // tự giới hạn 8 nốt/giây
      }
    }
    if (elapsed >= d.duration) _sweepDone?.complete();
  }

  @override
  void dispose() {
    _cancelled = true;
    if (_sweepDone?.isCompleted == false) _sweepDone!.complete();
    _ticker.dispose();
    widget.sound.silence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.map, d = data[_axis]!;
    final mean = d.means[_slice];
    final label = '${_axis == ScanAxis.northSouth ? 'Bắc → Nam' : 'Tây → Đông'} · '
        '${mean == null ? 'biển' : 'trung bình ${roundMeters(mean)} m'}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title.isEmpty ? 'Quét mặt cắt địa hình' : 'Mặt cắt · ${widget.title}')),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _running ? null : _runAll,
          child: Semantics(
            label: 'Mặt cắt địa hình. $label',
            liveRegion: true,
            child: Column(children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: m.aspect,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(m.basemapAsset, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                      CustomPaint(painter: _ScanLinePainter(_axis, _slice, d.slices)),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(label, style: Theme.of(context).textTheme.titleMedium),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ProfilePainter(d.profiles[_slice], d.maxElev),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Vạch quét trên bản đồ: ngang khi quét Bắc - Nam, dọc khi quét Tây - Đông.
class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter(this.axis, this.slice, this.slices);
  final ScanAxis axis;
  final int slice, slices;

  @override
  void paint(Canvas canvas, Size size) {
    final band = Paint()..color = const Color(0x55FF5722);
    final line = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2;
    if (axis == ScanAxis.northSouth) {
      final h = size.height / slices, y = slice * h;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h.clamp(2, double.infinity)), band);
      canvas.drawLine(Offset(0, y + h / 2), Offset(size.width, y + h / 2), line);
    } else {
      final w = size.width / slices, x = slice * w;
      canvas.drawRect(Rect.fromLTWH(x, 0, w.clamp(2, double.infinity), size.height), band);
      canvas.drawLine(Offset(x + w / 2, 0), Offset(x + w / 2, size.height), line);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.slice != slice || old.axis != axis;
}

/// Mặt cắt của lát hiện tại: đất nâu theo độ cao, biển xanh ở mực 0.
class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.profile, this.maxElev);
  final List<double?> profile;
  final double maxElev;

  @override
  void paint(Canvas canvas, Size size) {
    final top = maxElev <= 0 ? 1.0 : maxElev;
    final base = size.height * 0.9; // chừa 10% dưới cho mặt biển
    final dx = size.width / profile.length;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F1EA));
    final land = Path()..moveTo(0, size.height);
    for (var i = 0; i < profile.length; i++) {
      final v = profile[i];
      final y = v == null ? size.height : base - (v / top) * base * 0.95;
      land
        ..lineTo(i * dx, y)
        ..lineTo((i + 1) * dx, y);
      if (v == null) {
        canvas.drawRect(Rect.fromLTRB(i * dx, base, (i + 1) * dx + 0.5, size.height), Paint()..color = const Color(0xFF7FB2E5));
      }
    }
    land
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(land, Paint()..color = const Color(0xFFA9774A));
    canvas.drawLine(Offset(0, base), Offset(size.width, base), Paint()..color = const Color(0x66000000));
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) => !identical(old.profile, profile) || old.maxElev != maxElev;
}
