import 'package:flutter/material.dart';

import '../link/speaker_link.dart';
import '../speaker/speaker.dart';
import '../speaker/volume_curve.dart';
import '../tools/tools_controller.dart';
import 'home_page.dart' show AccessBanner, Transport, outputLabel;
import 'speaker_page.dart' show LinkRename;
import 'theme/palette.dart';
import 'tools_cards.dart';
import 'widgets/eq_curve.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart' show GlowChip;
import 'widgets/visualizer.dart';
import 'widgets/volume_ring.dart';

/// Desktop dashboard: everything on one screen (replaces the tabs on wide
/// windows). Now playing, volume, sound, speaker and the app tools.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.speaker,
    required this.theme,
    required this.tools,
    this.link,
  });

  final Speaker speaker;
  final ThemeController theme;
  final ToolsController tools;
  final SpeakerLink? link;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([theme, ?link]),
      builder: (context, _) {
        final palette = theme.palette;
        return StreamBuilder<SpeakerState>(
          stream: speaker.states,
          initialData: speaker.state,
          builder: (context, snap) {
            final s = snap.data!;
            return Scaffold(
              backgroundColor: eggelBackground,
              body: AuroraBackground(
                palette: palette,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final compact = box.maxWidth < 600;
                          return SingleChildScrollView(
                            padding: compact
                                ? const EdgeInsets.fromLTRB(16, 16, 16, 32)
                                : const EdgeInsets.fromLTRB(32, 24, 32, 40),
                            child: _body(
                              context,
                              s,
                              palette,
                              box.maxWidth >= 1040,
                              compact,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    SpeakerState s,
    EggelPalette palette,
    bool wide,
    bool compact,
  ) {
    final l = link;
    final nowPlaying = _NowPlayingCard(
      speaker: speaker,
      state: s,
      palette: palette,
      compact: compact,
    );
    final volume = _VolumeCard(
      speaker: speaker,
      state: s,
      palette: palette,
      tools: tools,
      compact: compact,
    );
    final sound = _SoundCard(palette: palette, link: l);
    final speakerCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpeakerCard(state: s, palette: palette, link: l),
        const SizedBox(height: 20),
        const SoonCard(
          key: Key('find-card'),
          icon: Icons.search,
          title: 'Find my speaker',
          subtitle: 'Play a chime to locate it. Soon.',
        ),
        const SizedBox(height: 20),
        const SoonCard(
          key: Key('megaphone-card'),
          icon: Icons.mic_none,
          title: 'Megaphone',
          subtitle: 'Send your mic to the speaker. Soon.',
        ),
      ],
    );
    final toolCards = [
      SleepCard(tools: tools, palette: palette),
      CapCard(tools: tools, palette: palette),
      AlarmCard(tools: tools, palette: palette),
      NightCard(tools: tools, palette: palette),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(state: s, palette: palette, link: l, theme: theme),
        if (!s.mediaAccess) ...[
          const SizedBox(height: 16),
          AccessBanner(palette: palette, onAllow: speaker.requestMediaAccess),
        ],
        const SizedBox(height: 20),
        if (wide) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 7, child: nowPlaying),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: volume),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: sound),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: speakerCol),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < toolCards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 20),
                  Expanded(child: toolCards[i]),
                ],
              ],
            ),
          ),
        ] else ...[
          nowPlaying,
          const SizedBox(height: 20),
          volume,
          const SizedBox(height: 20),
          sound,
          const SizedBox(height: 20),
          speakerCol,
          for (final c in toolCards) ...[const SizedBox(height: 20), c],
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.palette,
    required this.link,
    required this.theme,
  });

  final SpeakerState state;
  final EggelPalette palette;
  final SpeakerLink? link;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final l = link;
    final name = l?.name ?? state.name;
    final out = outputLabel(state.name);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.5),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Icon(Icons.speaker_outlined, color: eggelOnAccent),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  key: const Key('speaker-name'),
                  style: const TextStyle(
                    fontFamily: kHeadingFont,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: eggelText,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Eggel companion',
                  style: TextStyle(fontSize: 13, color: eggelMuted),
                ),
              ],
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.connected ? palette.accent : eggelMuted,
                      shape: BoxShape.circle,
                      boxShadow: state.connected
                          ? [BoxShadow(color: palette.accent, blurRadius: 8)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.connected ? 'Connected' : 'Not connected',
                    key: const Key('status'),
                    style: const TextStyle(fontSize: 13, color: eggelText),
                  ),
                  if (out.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      out,
                      style: const TextStyle(fontSize: 13, color: eggelMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (l?.battery != null)
              _Pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.battery_5_bar, size: 18, color: eggelText),
                    const SizedBox(width: 6),
                    Text(
                      '${l!.battery}%',
                      key: const Key('battery'),
                      style: const TextStyle(fontSize: 13, color: eggelText),
                    ),
                  ],
                ),
              ),
            _Dots(theme: theme),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 999,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: child,
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.theme});
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in allPalettes)
          Tooltip(
            message: p.name,
            child: Semantics(
              button: true,
              selected: p == theme.palette,
              label: '${p.name} color',
              child: GestureDetector(
                key: Key('theme-${p.name.toLowerCase()}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => theme.select(p),
                child: SizedBox(
                  width: 36,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                        border: p == theme.palette
                            ? Border.all(color: eggelText, width: 2)
                            : null,
                        boxShadow: p == theme.palette
                            ? [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.7),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.speaker,
    required this.state,
    required this.palette,
    this.compact = false,
  });

  final Speaker speaker;
  final SpeakerState state;
  final EggelPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final art = compact ? 200.0 : 240.0;
    return GlassCard(
      padding: EdgeInsets.all(compact ? 18 : 24),
      radius: 24,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _art(art)),
                const SizedBox(height: 20),
                _info(),
              ],
            )
          : Row(
              children: [
                _art(art),
                const SizedBox(width: 28),
                Expanded(child: _info()),
              ],
            ),
    );
  }

  Widget _art(double art) {
    return Container(
      width: art,
      height: art,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, palette.glow2, palette.glow3],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.4),
            blurRadius: 48,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: art * 0.46,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x8C07080C), Color(0x0007080C)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Visualizer(
              color: Colors.white,
              active: state.connected && state.playing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (state.playing) ...[
                  _Tag('Live', color: palette.accent),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    compact
                        ? 'Now playing on this phone'
                        : 'Now playing on this computer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: eggelMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.title.isEmpty ? 'Nothing playing' : state.title,
              key: const Key('title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kHeadingFont,
                fontSize: compact ? 28 : 34,
                fontWeight: FontWeight.w700,
                color: eggelText,
                letterSpacing: -0.7,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: eggelMuted),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Transport(state: state, speaker: speaker, palette: palette),
        ),
      ],
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({
    required this.speaker,
    required this.state,
    required this.palette,
    required this.tools,
    this.compact = false,
  });

  final Speaker speaker;
  final SpeakerState state;
  final EggelPalette palette;
  final ToolsController tools;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) => _volumeBody(context),
    );
  }

  Widget _volumeBody(BuildContext context) {
    final on = state.connected;
    final cap = tools.effectiveCap;
    final ring = VolumeRing(
      value: state.volume,
      palette: palette,
      label: formatPercent(state.volume),
      pulsing: on && state.playing,
      size: compact ? 200 : 216,
    );
    Widget side(Widget body) => compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ring, const SizedBox(height: 20), body],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: 24),
              Flexible(child: body),
            ],
          );
    return GlassCard(
      padding: EdgeInsets.all(compact ? 18 : 24),
      radius: 24,
      child: side(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassRoundButton(
                  key: const Key('volume-down'),
                  icon: Icons.remove,
                  tooltip: 'Volume down',
                  onPressed: on
                      ? () => speaker.setVolume(
                          stepPercent(state.volume, up: false),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                GlassRoundButton(
                  key: const Key('volume-up'),
                  icon: Icons.add,
                  tooltip: 'Volume up',
                  onPressed: on
                      ? () => speaker.setVolume(
                          stepPercent(state.volume, up: true),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (outputLabel(state.name).isNotEmpty)
                  _Tag('${outputLabel(state.name)} output', color: eggelMuted),
                _Tag(
                  cap == null ? 'No cap' : 'Cap $cap',
                  color: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1 is just audible. Below the speaker\'s own lowest step the app quiets other apps instead.',
              style: TextStyle(fontSize: 13, color: eggelMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      ),
    ),
  );
}

/// Illustrative curves for the five presets (the speaker's real curves are
/// not known), shown on the EQ picture only.
const _previewShapes = <List<double>>[
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 3, 5, 7, 8],
  [0, 0, 0, 0, 0, -1, -3, -5, -7, -8],
  [8, 7, 5, 3, 1, 0, 0, 0, 0, 0],
  [-8, -7, -5, -3, -1, 0, 0, 0, 0, 0],
];

const _bandLabels = [
  '31',
  '62',
  '125',
  '250',
  '500',
  '1k',
  '2k',
  '4k',
  '8k',
  '16k',
];

class _SoundCard extends StatelessWidget {
  const _SoundCard({required this.palette, required this.link});

  final EggelPalette palette;
  final SpeakerLink? link;

  @override
  Widget build(BuildContext context) {
    final l = link;
    final live = l != null && l.status == LinkStatus.connected;
    final preset = (l?.eqPreset ?? 0).clamp(0, eqPresetNames.length - 1);
    final gains = _previewShapes[preset];
    final note = l == null
        ? 'The equalizer needs the speaker link, which is not available on this device yet.'
        : !l.available
        ? 'Add the speaker\'s Tuya key to settings.json to turn on the equalizer.'
        : live
        ? 'Presets change the speaker itself.'
        : '${l.detail.isEmpty ? 'Connecting to the speaker' : l.detail}. Presets turn on when it connects.';
    return GlassCard(
      padding: const EdgeInsets.all(24),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sound',
                style: TextStyle(
                  fontFamily: kHeadingFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: eggelText,
                ),
              ),
              const Spacer(),
              _Tag(
                live ? 'Live on the speaker' : 'Preview',
                color: palette.accent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note,
            key: const Key('eq-note'),
            style: const TextStyle(fontSize: 13, color: eggelMuted),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: live ? 1 : 0.55,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < eqPresetNames.length; i++)
                  GlowChip(
                    key: Key('preset-$i'),
                    label: eqPresetNames[i],
                    palette: palette,
                    selected: i == preset,
                    onTap: live
                        ? () => l.setEqPreset(i).catchError((_) {})
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Well(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: EqCurve(gains: gains, palette: palette, height: 150),
          ),
          const SizedBox(height: 20),
          _Well(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                disabledActiveTrackColor: palette.accent,
                disabledInactiveTrackColor: Colors.white.withValues(
                  alpha: 0.14,
                ),
                disabledThumbColor: palette.accent,
                thumbShape: const RoundSliderThumbShape(
                  disabledThumbRadius: 7,
                  enabledThumbRadius: 7,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 10; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${gains[i] > 0 ? '+' : ''}${gains[i].round()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: eggelText,
                            ),
                          ),
                          SizedBox(
                            height: 132,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: gains[i],
                                min: -12,
                                max: 12,
                                onChanged: null,
                              ),
                            ),
                          ),
                          Text(
                            _bandLabels[i],
                            style: const TextStyle(
                              fontSize: 11,
                              color: eggelMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoonTag(label: 'Needs decoding'),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom bands (31 Hz to 16 kHz, plus and minus 12 dB) need the speaker\'s band command, which is not decoded yet. The curve is a preview shape.',
                  key: Key('bands-note'),
                  style: TextStyle(
                    fontSize: 13,
                    color: eggelMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({
    required this.state,
    required this.palette,
    required this.link,
  });

  final SpeakerState state;
  final EggelPalette palette;
  final SpeakerLink? link;

  @override
  Widget build(BuildContext context) {
    final l = link;
    final live = l != null && l.status == LinkStatus.connected;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Speaker',
                style: TextStyle(
                  fontFamily: kHeadingFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: eggelText,
                ),
              ),
              const Spacer(),
              _Tag(live ? 'Live' : 'Link off', color: palette.accent),
            ],
          ),
          const SizedBox(height: 14),
          if (l?.battery != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${l!.battery}',
                  style: const TextStyle(
                    fontFamily: kHeadingFont,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: eggelText,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '% battery',
                  style: TextStyle(fontSize: 18, color: eggelMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (l.battery!.clamp(0, 100)) / 100,
                minHeight: 8,
                color: palette.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            const SizedBox(height: 16),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                l == null
                    ? 'Battery needs the speaker link, which is not available on this device yet.'
                    : !l.available
                    ? 'Add the speaker\'s Tuya key to settings.json for battery and rename.'
                    : (l.detail.isEmpty
                          ? 'Connecting to the speaker'
                          : l.detail),
                key: const Key('needs-link'),
                style: const TextStyle(fontSize: 13, color: eggelMuted),
              ),
            ),
          if (live) LinkRename(link: l, palette: palette, framed: false),
          const SizedBox(height: 8),
          for (final row in const [
            'Stereo pair',
            'Auto power-off',
            'Voice prompts',
          ])
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    row,
                    style: const TextStyle(fontSize: 14, color: eggelText),
                  ),
                  const Spacer(),
                  const SoonTag(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The dark inset box behind the EQ curve and the band sliders.
class _Well extends StatelessWidget {
  const _Well({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: child,
  );
}
