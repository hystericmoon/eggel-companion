import 'package:flutter/material.dart';

import '../link/speaker_link.dart';
import 'theme/palette.dart';
import 'widgets/eq_curve.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart';

/// Sound: EQ presets. Live when the speaker link is connected; otherwise a
/// preview that says why, so nothing pretends to change the sound.
class SoundPage extends StatelessWidget {
  const SoundPage({super.key, required this.palette, this.link});

  final EggelPalette palette;
  final SpeakerLink? link;

  @override
  Widget build(BuildContext context) {
    final l = link;
    if (l == null) return _build(context, null);
    return ListenableBuilder(listenable: l, builder: (c, _) => _build(c, l));
  }

  Widget _build(BuildContext context, SpeakerLink? l) {
    final live = l != null && l.status == LinkStatus.connected;
    final note = l == null
        ? 'The equalizer needs the speaker link, which is not available on this device yet. This is a preview.'
        : !l.available
        ? 'Add the speaker\'s Tuya key to settings.json to turn on the equalizer. This is a preview.'
        : live
        ? 'Presets change the speaker itself.'
        : '${l.detail.isEmpty ? 'Connecting to the speaker' : l.detail}. This is a preview until it connects.';
    return PageFrame(
      palette: palette,
      title: 'Sound',
      children: [
        GlassCard(
          child: Row(
            children: [
              Icon(
                live ? Icons.link : Icons.lock_outline,
                color: palette.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note,
                  key: const Key('eq-note'),
                  style: const TextStyle(fontSize: 13, color: eggelMuted),
                ),
              ),
            ],
          ),
        ),
        Opacity(
          opacity: live ? 1 : 0.55,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < eqPresetNames.length; i++)
                GlowChip(
                  key: Key('preset-$i'),
                  label: eqPresetNames[i],
                  palette: palette,
                  selected: i == (l?.eqPreset ?? 0),
                  onTap: live
                      ? () => l.setEqPreset(i).catchError((_) {})
                      : null,
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
