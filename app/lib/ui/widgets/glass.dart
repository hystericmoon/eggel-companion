import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Dark base with three soft colored glows, drawn with radial gradients.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.palette, this.child});

  final EggelPalette palette;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: eggelBackground),
        _glow(const Alignment(-0.9, -1.0), palette.accent, 0.34, 1.1),
        _glow(const Alignment(1.0, -0.4), palette.glow2, 0.30, 1.0),
        _glow(const Alignment(-0.3, 1.0), palette.glow3, 0.18, 1.0),
        ?child,
      ],
    );
  }

  Widget _glow(Alignment at, Color color, double alpha, double radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: at,
          radius: radius,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Frosted card: blurred backdrop, faint fill, thin light edge.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round glass button used for previous, next and volume steps.
class GlassRoundButton extends StatelessWidget {
  const GlassRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 46,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              size: size * 0.46,
              color: enabled ? eggelText : eggelMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
