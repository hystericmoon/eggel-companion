import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Big circular volume readout: a tick ring, a track and a glowing arc.
/// [value] is 0..100. When [pulsing] is true the glow breathes slowly.
class VolumeRing extends StatefulWidget {
  const VolumeRing({
    super.key,
    required this.value,
    required this.palette,
    required this.label,
    this.pulsing = false,
    this.size = 176,
  });

  final double value;
  final EggelPalette palette;
  final String label;
  final bool pulsing;
  final double size;

  @override
  State<VolumeRing> createState() => _VolumeRingState();
}

class _VolumeRingState extends State<VolumeRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(VolumeRing old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.pulsing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: widget.value.clamp(0, 100) / 100),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (context, fraction, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _RingPainter(
                fraction: fraction,
                color: widget.palette.accent,
                pulse: _pulse,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                key: const Key('volume-readout'),
                style: TextStyle(
                  fontSize: widget.size * 0.26,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: eggelText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Volume',
                style: TextStyle(fontSize: 13, color: eggelMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.pulse,
  }) : super(repaint: pulse);

  final double fraction;
  final Color color;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Outer tick ring.
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      final a = i / ticks * 2 * math.pi;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - 2);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - 7);
      canvas.drawLine(p1, p2, tick);
    }

    final ringR = r - 22;
    final rect = Rect.fromCircle(center: c, radius: ringR);
    final stroke = size.width * 0.057;

    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    if (fraction <= 0) return;
    final sweep = 2 * math.pi * fraction;
    final glow = 6 + pulse.value * 8;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55 + pulse.value * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
