import 'package:flutter/material.dart';

import '../tools/tools_controller.dart';
import 'theme/palette.dart';
import 'widgets/glass.dart';
import 'widgets/page_frame.dart' show GlowChip;

/// The app-side tool cards, shared by the Tools page and the desktop
/// dashboard. Each one listens to [ToolsController] itself.

class SleepCard extends StatelessWidget {
  const SleepCard({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) {
        final left = tools.sleepRemaining;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title(
                'Sleep timer',
                'Pauses playback when time is up',
                icon: Icons.bedtime_outlined,
                tag: 'App',
              ),
              const SizedBox(height: 12),
              if (left == null) const Text('Off', style: _bigValue),
              if (left != null) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
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
                        label: m < 60
                            ? '$m min'
                            : '${m ~/ 60} h${m % 60 == 0 ? '' : ' 30'}',
                        palette: palette,
                        onTap: () => tools.startSleep(Duration(minutes: m)),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class CapCard extends StatelessWidget {
  const CapCard({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(
                'Volume cap',
                tools.volumeCap == null
                    ? 'No limit'
                    : 'The app never goes above ${tools.volumeCap}',
                icon: Icons.equalizer,
                tag: 'App',
              ),
              const SizedBox(height: 12),
              Text(
                tools.volumeCap == null ? 'No cap' : 'Max ${tools.volumeCap}',
                style: _bigValue,
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
        );
      },
    );
  }
}

class AlarmCard extends StatelessWidget {
  const AlarmCard({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                'Alarm',
                tools.alarmOn
                    ? 'Plays at ${_clockText(tools.alarmMinutes)}, volume ${tools.alarmVolume}'
                    : 'Starts playback at a set time',
                icon: Icons.notifications_none,
                switchKey: const Key('alarm-switch'),
                on: tools.alarmOn,
                onChanged: (v) => tools.configure(() => tools.alarmOn = v),
                palette: palette,
              ),
              const SizedBox(height: 12),
              GlowChip(
                key: const Key('alarm-time'),
                label: _clockText(tools.alarmMinutes),
                palette: palette,
                onTap: () async {
                  final t = await _pickTime(context, tools.alarmMinutes);
                  if (t != null) {
                    tools.configure(() => tools.alarmMinutes = t);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    if (d > 1) const SizedBox(width: 4),
                    Expanded(
                      child: GlowChip(
                        key: Key('alarm-day-$d'),
                        label: _days[d - 1],
                        palette: palette,
                        compact: true,
                        selected: tools.alarmDays.contains(d),
                        onTap: () => tools.configure(() {
                          if (!tools.alarmDays.remove(d)) {
                            tools.alarmDays.add(d);
                          }
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tools.alarmDays.isEmpty
                    ? 'No days picked: rings once.'
                    : 'Repeats on the days shown.',
                style: const TextStyle(fontSize: 12, color: eggelMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in [10, 20, 30, 40, 50])
                    GlowChip(
                      key: Key('alarm-vol-$v'),
                      label: 'Vol $v',
                      palette: palette,
                      selected: tools.alarmVolume == v,
                      onTap: () => tools.configure(() => tools.alarmVolume = v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Needs the app open and something to play (it presses play). It does not wake a closed app.',
                style: TextStyle(fontSize: 12, color: eggelMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NightCard extends StatelessWidget {
  const NightCard({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tools,
      builder: (context, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                'Night schedule',
                tools.nightOn
                    ? '${_clockText(tools.nightStart)} to ${_clockText(tools.nightEnd)}, max ${tools.nightCap}${tools.nightActive ? ' (active now)' : ''}'
                    : 'Quieter volume limit at night',
                icon: Icons.schedule,
                switchKey: const Key('night-switch'),
                on: tools.nightOn,
                onChanged: (v) => tools.configure(() => tools.nightOn = v),
                palette: palette,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GlowChip(
                    key: const Key('night-start'),
                    label: 'From ${_clockText(tools.nightStart)}',
                    palette: palette,
                    onTap: () async {
                      final t = await _pickTime(context, tools.nightStart);
                      if (t != null) {
                        tools.configure(() => tools.nightStart = t);
                      }
                    },
                  ),
                  GlowChip(
                    key: const Key('night-end'),
                    label: 'To ${_clockText(tools.nightEnd)}',
                    palette: palette,
                    onTap: () async {
                      final t = await _pickTime(context, tools.nightEnd);
                      if (t != null) {
                        tools.configure(() => tools.nightEnd = t);
                      }
                    },
                  ),
                  for (final c in [20, 30, 40, 50])
                    GlowChip(
                      key: Key('night-cap-$c'),
                      label: 'Max $c',
                      palette: palette,
                      selected: tools.nightCap == c,
                      onTap: () => tools.configure(() => tools.nightCap = c),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A card for something that is not built yet or needs the speaker link.
class SoonCard extends StatelessWidget {
  const SoonCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 24,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: eggelMuted),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(child: _Title(title, subtitle)),
        const SizedBox(width: 12),
        const SoonTag(),
      ],
    ),
  );
}

/// A small pill with a dashed outline: "Soon" or "Needs decoding".
class SoonTag extends StatelessWidget {
  const SoonTag({super.key, this.label = 'Soon'});

  final String label;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPill(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: eggelMuted,
        ),
      ),
    ),
  );
}

class _DashedPill extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(size.height / 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.3);
    final path = Path()..addRRect(rect);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPill old) => false;
}

const _bigValue = TextStyle(
  fontFamily: kHeadingFont,
  fontSize: 30,
  fontWeight: FontWeight.w600,
  color: eggelText,
);

const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _clockText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

Future<int?> _pickTime(BuildContext context, int minutes) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

String _format(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Header extends StatelessWidget {
  const _Header(
    this.title,
    this.subtitle, {
    this.icon,
    required this.switchKey,
    required this.on,
    required this.onChanged,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Key switchKey;
  final bool on;
  final ValueChanged<bool> onChanged;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Title(title, subtitle, icon: icon)),
        Switch(
          key: switchKey,
          value: on,
          activeThumbColor: palette.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle, {this.icon, this.tag});

  final String title;
  final String subtitle;
  final IconData? icon;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: kHeadingFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: eggelText,
                ),
              ),
            ),
            if (tag != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: eggelText,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: eggelMuted)),
      ],
    );
  }
}
