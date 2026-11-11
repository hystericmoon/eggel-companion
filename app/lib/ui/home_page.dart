import 'package:flutter/material.dart';

import '../speaker/speaker.dart';
import '../speaker/volume_curve.dart';
import 'theme/palette.dart';
import 'widgets/glass.dart';
import 'widgets/visualizer.dart';
import 'widgets/volume_ring.dart';

/// Home: speaker status, now playing, transport, volume ring and color theme.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.speaker, this.theme});

  final Speaker speaker;

  /// Optional: when given, the color theme picker is shown and the page
  /// follows the chosen palette. Without it the default palette is used.
  final ThemeController? theme;

  @override
  Widget build(BuildContext context) {
    final controller = theme;
    if (controller == null) return _build(context, ember);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context, controller.palette),
    );
  }

  Widget _build(BuildContext context, EggelPalette palette) {
    return StreamBuilder<SpeakerState>(
      stream: speaker.states,
      initialData: speaker.state,
      builder: (context, snapshot) {
        final s = snapshot.data!;
        return Scaffold(
          backgroundColor: eggelBackground,
          body: AuroraBackground(
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
                        _Header(state: s, palette: palette),
                        if (!s.mediaAccess) ...[
                          const SizedBox(height: 12),
                          _AccessBanner(
                            palette: palette,
                            onAllow: speaker.requestMediaAccess,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _NowPlaying(state: s, palette: palette),
                        const SizedBox(height: 18),
                        _Transport(state: s, speaker: speaker, palette: palette),
                        const SizedBox(height: 18),
                        _VolumeSection(
                          state: s,
                          speaker: speaker,
                          palette: palette,
                        ),
                        if (theme != null) ...[
                          const SizedBox(height: 22),
                          _ThemePicker(controller: theme!),
                        ],
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

String _outputLabel(String name) {
  final n = name.toLowerCase();
  if (n.contains('active 3')) return 'Bluetooth';
  if (n.contains('(speaker)')) return 'USB-C';
  return '';
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.palette});

  final SpeakerState state;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    final dot = state.connected ? const Color(0xFF4ADE80) : Colors.redAccent;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: eggelText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: dot, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.connected ? 'Connected' : 'Not connected',
                    key: const Key('status'),
                    style: const TextStyle(fontSize: 13, color: eggelMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_outputLabel(state.name).isNotEmpty)
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _outputLabel(state.name),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.palette, required this.onAllow});

  final EggelPalette palette;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const Key('access-banner'),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show what\'s playing',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: eggelText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Allow access so the app can read the track and control playback.',
                  style: TextStyle(fontSize: 13, color: eggelMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAllow,
            style: TextButton.styleFrom(foregroundColor: palette.accent),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.state, required this.palette});

  final SpeakerState state;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: palette.accent.withValues(alpha: 0.14),
              border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.35),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Icon(Icons.speaker_outlined, size: 32, color: palette.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title.isEmpty ? 'Nothing playing' : state.title,
                  key: const Key('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: eggelText,
                  ),
                ),
                Text(
                  state.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: eggelMuted),
                ),
                const SizedBox(height: 8),
                Visualizer(
                  color: palette.accent,
                  active: state.connected && state.playing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.speaker,
    required this.palette,
  });

  final SpeakerState state;
  final Speaker speaker;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    final on = state.connected;
    final tooltip = state.playing ? 'Pause' : 'Play';
    final action = on ? (state.playing ? speaker.pause : speaker.play) : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassRoundButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Previous',
          onPressed: on ? speaker.previous : null,
        ),
        const SizedBox(width: 26),
        Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            enabled: on,
            label: tooltip,
            child: GestureDetector(
              onTap: action,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? palette.accent
                      : palette.accent.withValues(alpha: 0.3),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.65),
                            blurRadius: 34,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 34,
                  color: eggelOnAccent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 26),
        GlassRoundButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Next',
          onPressed: on ? speaker.next : null,
        ),
      ],
    );
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({
    required this.state,
    required this.speaker,
    required this.palette,
  });

  final SpeakerState state;
  final Speaker speaker;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    final on = state.connected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassRoundButton(
          key: const Key('volume-down'),
          icon: Icons.remove,
          tooltip: 'Volume down',
          onPressed: on
              ? () => speaker.setVolume(stepPercent(state.volume, up: false))
              : null,
        ),
        const SizedBox(width: 20),
        VolumeRing(
          value: state.volume,
          palette: palette,
          label: formatPercent(state.volume),
          pulsing: on && state.playing,
        ),
        const SizedBox(width: 20),
        GlassRoundButton(
          key: const Key('volume-up'),
          icon: Icons.add,
          tooltip: 'Volume up',
          onPressed: on
              ? () => speaker.setVolume(stepPercent(state.volume, up: true))
              : null,
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Color', style: TextStyle(fontSize: 13, color: eggelMuted)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final p in allPalettes) ...[
              Tooltip(
                message: p.name,
                child: Semantics(
                  button: true,
                  selected: p == controller.palette,
                  label: '${p.name} color',
                  child: GestureDetector(
                    key: Key('theme-${p.name.toLowerCase()}'),
                    onTap: () => controller.select(p),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                        border: p == controller.palette
                            ? Border.all(color: eggelText, width: 2)
                            : null,
                        boxShadow: p == controller.palette
                            ? [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.7),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
