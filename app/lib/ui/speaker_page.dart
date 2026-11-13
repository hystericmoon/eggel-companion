import 'package:flutter/material.dart';

import '../link/speaker_link.dart';
import '../speaker/speaker.dart';
import 'theme/palette.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart';

/// Speaker: what the app really knows, and what waits for the speaker link.
class SpeakerPage extends StatelessWidget {
  const SpeakerPage({
    super.key,
    required this.speaker,
    required this.palette,
    required this.theme,
    this.link,
  });

  final SpeakerLink? link;
  final Speaker speaker;
  final EggelPalette palette;
  final ThemeController? theme;

  @override
  Widget build(BuildContext context) {
    final l = link;
    if (l == null) return _page(context);
    return ListenableBuilder(listenable: l, builder: (c, _) => _page(c));
  }

  List<Widget> _linkRows(SpeakerLink l) => [
    _Row(
      'Speaker link',
      l.status == LinkStatus.connected
          ? 'Connected'
          : l.available
          ? (l.detail.isEmpty ? 'Connecting' : l.detail)
          : 'Needs the Tuya key in settings.json',
    ),
    if (l.battery != null) _Row('Battery', '${l.battery}%'),
  ];

  Widget _page(BuildContext context) {
    return StreamBuilder<SpeakerState>(
      stream: speaker.states,
      initialData: speaker.state,
      builder: (context, snap) {
        final s = snap.data!;
        return PageFrame(
          palette: palette,
          title: 'Speaker',
          children: [
            GlassCard(
              child: Column(
                children: [
                  _Row('Name', s.name),
                  _Row('Status', s.connected ? 'Connected' : 'Not connected'),
                  _Row('Output', s.name),
                  if (link != null) ..._linkRows(link!),
                ],
              ),
            ),
            if (link?.status != LinkStatus.connected)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Needs the speaker link',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: eggelText,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Battery, rename, stereo pair, auto power-off and voice prompts.',
                      key: Key('needs-link'),
                      style: TextStyle(fontSize: 13, color: eggelMuted),
                    ),
                  ],
                ),
              ),
            if (theme != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App color',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: eggelText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in allPalettes)
                          GlowChip(
                            key: Key('color-${p.name.toLowerCase()}'),
                            label: p.name,
                            palette: palette,
                            selected: p == palette,
                            onTap: () => theme!.select(p),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: eggelText)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, color: eggelMuted),
            ),
          ),
        ],
      ),
    );
  }
}
