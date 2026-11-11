import 'package:flutter/material.dart';

import 'theme/palette.dart';
import 'widgets/eq_curve.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart';

/// Sound: the EQ screen frame. Controls are off until the speaker protocol
/// is decoded, so nothing here pretends to change the sound.
class SoundPage extends StatelessWidget {
  const SoundPage({super.key, required this.palette});

  final EggelPalette palette;

  static const _presets = [
    'Default',
    'Bass boost',
    'Bass reducer',
    'Treble boost',
    'Treble reducer',
  ];

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      palette: palette,
      title: 'Sound',
      children: [
        GlassCard(
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: palette.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'The equalizer needs the speaker link, which is not set up yet. This is a preview.',
                  key: Key('eq-note'),
                  style: TextStyle(fontSize: 13, color: eggelMuted),
                ),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: 0.55,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _presets.length; i++)
                GlowChip(
                  label: _presets[i],
                  palette: palette,
                  selected: i == 0,
                ),
            ],
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Column(
            children: [
              EqCurve(gains: List.filled(10, 0), palette: palette),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Band('31'),
                  _Band('62'),
                  _Band('125'),
                  _Band('250'),
                  _Band('500'),
                  _Band('1k'),
                  _Band('2k'),
                  _Band('4k'),
                  _Band('8k'),
                  _Band('16k'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: const TextStyle(fontSize: 11, color: eggelMuted));
}
