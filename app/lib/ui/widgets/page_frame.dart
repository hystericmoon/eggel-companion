import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'glass.dart';

/// Shared page layout: aurora backdrop, centered column, big title.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.palette,
    required this.title,
    required this.children,
  });

  final EggelPalette palette;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      palette: palette,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: eggelText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final c in children) ...[c, const SizedBox(height: 12)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill button: filled and glowing when [selected].
class GlowChip extends StatelessWidget {
  const GlowChip({
    super.key,
    required this.label,
    required this.palette,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final EggelPalette palette;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? palette.accent
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.55),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? eggelOnAccent : eggelText,
            ),
          ),
        ),
      ),
    );
  }
}
