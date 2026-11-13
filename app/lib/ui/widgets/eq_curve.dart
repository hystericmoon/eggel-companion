import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Ten-band EQ drawn as a glowing curve. [gains] are dB, -12..+12.
/// Display only for now; dragging arrives with the speaker protocol.
class EqCurve extends StatelessWidget {
  const EqCurve({
    super.key,
    required this.gains,
    required this.palette,
    this.height = 220,
  });

  final List<double> gains;
  final EggelPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Equalizer curve',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _EqPainter(gains, palette.accent)),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.gains, this.color);

  final List<double> gains;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = gains.length;
    if (n < 2) return;
    const pad = 12.0;
    final w = size.width - pad * 2;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          pad + w * i / (n - 1),
          size.height / 2 -
              (gains[i].clamp(-12, 12) / 12) * (size.height / 2 - pad),
        ),
    ];

    canvas.drawLine(
      Offset(pad, size.height / 2),
      Offset(size.width - pad, size.height / 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < n - 1; i++) {
      final mid = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
        mid,
        pts[i].dy,
        mid,
        pts[i + 1].dy,
        pts[i + 1].dx,
        pts[i + 1].dy,
      );
    }

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.40), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    for (final p in pts) {
      canvas.drawCircle(p, 6, Paint()..color = eggelBackground);
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) =>
      old.gains != gains || old.color != color;
}
