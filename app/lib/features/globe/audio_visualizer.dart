import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sóng nhạc trực quan (Audio Wave Visualizer) nhảy múa theo nhịp khi app phát nhạc cụ hoặc đọc dữ liệu.
/// Giúp người khiếm thính cảm nhận được nhịp điệu âm thanh và trạng thái phát nhạc.
class AudioWaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final String? label;

  const AudioWaveVisualizer({
    super.key,
    required this.isPlaying,
    this.label,
  });

  @override
  State<AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<AudioWaveVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _anim.repeat();
  }

  @override
  void didUpdateWidget(covariant AudioWaveVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!widget.isPlaying && _anim.isAnimating) {
      _anim.stop();
      _anim.reset();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
        final t = _anim.value * math.pi * 2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x33E4BB63),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x66E4BB63)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 5 vạch sóng nhạc chuyển động
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final h = 6.0 + 12.0 * (0.5 + 0.5 * math.sin(t * 2 + i * 1.1));
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      color: i.isEven ? const Color(0xFFE4BB63) : const Color(0xFF43D8A0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              if (widget.label != null && widget.label!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  widget.label!,
                  style: const TextStyle(
                    color: Color(0xFFFBF4E4),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ));
  }
}
