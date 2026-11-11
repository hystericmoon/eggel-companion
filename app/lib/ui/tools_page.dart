import 'package:flutter/material.dart';

import '../tools/tools_controller.dart';
import 'theme/palette.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart';

/// App-side tools that work without the speaker protocol.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) {
        final left = tools.sleepRemaining;
        return PageFrame(
          palette: palette,
          title: 'Tools',
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Title('Sleep timer', 'Pauses playback when time is up'),
                  const SizedBox(height: 12),
                  if (left != null) ...[
                    Row(
                      children: [
                        Text(
                          _format(left),
                          key: const Key('sleep-remaining'),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: palette.accent,
                          ),
                        ),
                        const Spacer(),
                        GlowChip(
                          key: const Key('sleep-cancel'),
                          label: 'Cancel',
                          palette: palette,
                          onTap: tools.cancelSleep,
                        ),
                      ],
                    ),
                  ] else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in [15, 30, 60, 90])
                          GlowChip(
                            key: Key('sleep-$m'),
                            label: m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' 30'}',
                            palette: palette,
                            onTap: () => tools.startSleep(Duration(minutes: m)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Title(
                    'Volume cap',
                    tools.volumeCap == null
                        ? 'No limit'
                        : 'The app never goes above ${tools.volumeCap}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlowChip(
                        key: const Key('cap-off'),
                        label: 'Off',
                        palette: palette,
                        selected: tools.volumeCap == null,
                        onTap: () => tools.setVolumeCap(null),
                      ),
                      for (final c in [50, 60, 70, 80, 90])
                        GlowChip(
                          key: Key('cap-$c'),
                          label: '$c',
                          palette: palette,
                          selected: tools.volumeCap == c,
                          onTap: () => tools.setVolumeCap(c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const GlassCard(
              child: Text(
                'Coming next: alarm, megaphone, night schedule and find my speaker.',
                style: TextStyle(fontSize: 13, color: eggelMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: eggelText,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: eggelMuted)),
      ],
    );
  }
}
