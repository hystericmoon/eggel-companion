import 'package:flutter/material.dart';

import '../speaker/speaker.dart';
import '../speaker/volume_curve.dart';

/// Main screen, layout A (player first).
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.speaker});

  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpeakerState>(
      stream: speaker.states,
      initialData: speaker.state,
      builder: (context, snapshot) {
        final s = snapshot.data!;
        final theme = Theme.of(context);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  Text(
                                    s.connected ? 'Connected' : 'Not connected',
                                    key: const Key('status'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: s.connected
                                          ? Colors.green
                                          : theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () {},
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ],
                        ),
                        if (!s.mediaAccess) ...[
                          const SizedBox(height: 12),
                          Card(
                            key: const Key('access-banner'),
                            child: ListTile(
                              title: const Text('Show what\'s playing'),
                              subtitle: const Text(
                                'Allow access so the app can read the track and control playback.',
                              ),
                              trailing: TextButton(
                                onPressed: speaker.requestMediaAccess,
                                child: const Text('Allow'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Now playing'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.title.isEmpty ? 'Nothing playing' : s.title,
                          key: const Key('title'),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(s.artist, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              iconSize: 32,
                              onPressed: s.connected ? speaker.previous : null,
                              icon: const Icon(Icons.skip_previous),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filled(
                              tooltip: s.playing ? 'Pause' : 'Play',
                              iconSize: 36,
                              onPressed: s.connected
                                  ? (s.playing ? speaker.pause : speaker.play)
                                  : null,
                              icon: Icon(
                                s.playing ? Icons.pause : Icons.play_arrow,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Next',
                              iconSize: 32,
                              onPressed: s.connected ? speaker.next : null,
                              icon: const Icon(Icons.skip_next),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.volume_up_outlined),
                            Expanded(
                              child: Slider(
                                key: const Key('volume'),
                                value: percentToSlider(
                                  s.volume,
                                  speaker.volumeExponent,
                                ),
                                label: formatPercent(s.volume),
                                onChanged: s.connected
                                    ? (v) => speaker.setVolume(
                                        sliderToPercent(
                                          v,
                                          speaker.volumeExponent,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.outlined(
                              key: const Key('volume-down'),
                              tooltip: 'Volume down',
                              onPressed: s.connected
                                  ? () => speaker.setVolume(
                                      stepPercent(s.volume, up: false),
                                    )
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            SizedBox(
                              width: 96,
                              child: Text(
                                '${formatPercent(s.volume)}%',
                                key: const Key('volume-readout'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            IconButton.outlined(
                              key: const Key('volume-up'),
                              tooltip: 'Volume up',
                              onPressed: s.connected
                                  ? () => speaker.setVolume(
                                      stepPercent(s.volume, up: true),
                                    )
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'EQ, rename and TWS arrive once the speaker protocol is known.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
