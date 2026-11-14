// MÁY HÁT TRÁI ĐẤT — màn hình: khung hình NASA SVS đang hát + vạch tiến trình + rê tay để nghe từng nơi.
import 'package:flutter/material.dart';

import '../../core/format.dart' show fmtNum;
import 'eic_player.dart';

class EicView extends StatelessWidget {
  final EicPlayer player;
  final VoidCallback onClose;
  final bool en;
  const EicView({super.key, required this.player, required this.onClose, this.en = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final p = player;
        final s = p.ds;
        final f = p.frame;
        final title = en ? s.titleEn : s.titleVi;
        final label = en ? f.labelEn : f.labelVi;
        final status = p.done
            ? (en ? 'done' : 'xong')
            : p.running
                ? (en ? 'playing' : 'đang hát')
                : (en ? 'paused' : 'tạm dừng');
        return Container(
          color: const Color(0xE6050B10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Semantics(
                    button: true,
                    label: en ? 'Exit Earth Jukebox' : 'Thoát máy hát Trái Đất',
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
                    child: Text('${en ? 'Earth Jukebox' : 'Máy hát Trái Đất'} · $title',
                        style: const TextStyle(color: Color(0xFF43D8A0), fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('$label · $status',
                    style: const TextStyle(color: Color(0xFFFBF4E4), fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                // khung hình: bản đồ phẳng 2:1, rê tay để nghe
                AspectRatio(
                  aspectRatio: 2,
                  child: LayoutBuilder(builder: (context, c) {
                    void at(Offset o) => p.touchAt((o.dx / c.maxWidth).clamp(0.0, 1.0), (o.dy / c.maxHeight).clamp(0.0, 1.0));
                    return Semantics(
                      image: true,
                      label: en ? s.describeEn : s.describeVi,
                      hint: en ? 'Slide a finger to hear each place' : 'Rê tay để nghe từng nơi',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) async {
                          await p.touchStart();
                          at(d.localPosition);
                        },
                        onPanUpdate: (d) => at(d.localPosition),
                        onPanEnd: (_) => p.touchEnd(),
                        onTapDown: (d) async {
                          await p.touchStart();
                          at(d.localPosition);
                        },
                        onTapUp: (_) => p.touchEnd(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.asset(f.image, fit: BoxFit.fill, gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF111A22))),
                            if (p.touch != null)
                              Positioned(
                                left: p.touch!.x * c.maxWidth - 14,
                                top: p.touch!.y * c.maxHeight - 14,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFFE066), width: 3),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                // tiến trình: mỗi khung một vạch, cao theo giá trị v
                SizedBox(height: 56, child: CustomPaint(painter: _BarsPainter(p), size: Size.infinite)),
                const SizedBox(height: 8),
                if (p.touch != null)
                  Text(
                    p.touchValue == null
                        ? (en ? 'No data here' : 'Không có số liệu')
                        : (en ? p.valueEn(p.touchValue!) : p.valueVi(p.touchValue!)),
                    style: const TextStyle(color: Color(0xFFFFE066), fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      '${en ? s.legendEn : s.legendVi}\n\n${en ? 'Source' : 'Nguồn'}: ${s.source}'
                      '${s.svsId.isNotEmpty ? ' · SVS ${s.svsId}' : ''}\n'
                      '${en ? 'Speed' : 'Tốc độ'} ${p.speed + 1}/5 · ${en ? 'frame' : 'khung'} ${p.index + 1}/${p.count}'
                      ' · v ${fmtNum(f.v, 2, lang: en ? 'en' : 'vi')}',
                      style: const TextStyle(color: Color(0xCCFBF4E4), fontSize: 13, height: 1.4),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _BarsPainter extends CustomPainter {
  final EicPlayer p;
  _BarsPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final n = p.count;
    if (n == 0) return;
    final w = size.width / n;
    for (var i = 0; i < n; i++) {
      final v = p.ds.frames[i].v.clamp(0.0, 1.0);
      final h = 4 + (size.height - 4) * v;
      final cur = i == p.index;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * w + 1, size.height - h, w - 2, h), const Radius.circular(3)),
        Paint()..color = cur ? const Color(0xFFFFE066) : (i < p.index ? const Color(0xFF43D8A0) : const Color(0x5543D8A0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
