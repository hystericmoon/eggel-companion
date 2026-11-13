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
                  const _Title(
                    'Sleep timer',
                    'Pauses playback when time is up',
                  ),
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
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    'Alarm',
                    tools.alarmOn
                        ? 'Plays at ${_clockText(tools.alarmMinutes)}, volume ${tools.alarmVolume}'
                        : 'Starts playback at a set time',
                    switchKey: const Key('alarm-switch'),
                    on: tools.alarmOn,
                    onChanged: (v) => tools.configure(() => tools.alarmOn = v),
                    palette: palette,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlowChip(
                        key: const Key('alarm-time'),
                        label: _clockText(tools.alarmMinutes),
                        palette: palette,
                        onTap: () async {
                          final t = await _pickTime(
                            context,
                            tools.alarmMinutes,
                          );
                          if (t != null) {
                            tools.configure(() => tools.alarmMinutes = t);
                          }
                        },
                      ),
                      for (var d = 1; d <= 7; d++)
                        GlowChip(
                          key: Key('alarm-day-$d'),
                          label: _days[d - 1],
                          palette: palette,
                          selected: tools.alarmDays.contains(d),
                          onTap: () => tools.configure(() {
                            if (!tools.alarmDays.remove(d))
                              tools.alarmDays.add(d);
                          }),
                        ),
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
                          onTap: () =>
                              tools.configure(() => tools.alarmVolume = v),
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
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    'Night schedule',
                    tools.nightOn
                        ? '${_clockText(tools.nightStart)} to ${_clockText(tools.nightEnd)}, max ${tools.nightCap}${tools.nightActive ? ' (active now)' : ''}'
                        : 'Quieter volume limit at night',
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
                          onTap: () =>
                              tools.configure(() => tools.nightCap = c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const GlassCard(
              child: _Title(
                'Find my speaker',
                'Needs the speaker link: the app cannot make the speaker ring yet.',
              ),
            ),
            const GlassCard(
              child: _Title(
                'Megaphone',
                'Needs microphone capture and a way to route it to the speaker. Not built.',
              ),
            ),
          ],
        );
      },
    );
  }

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static String _clockText(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static Future<int?> _pickTime(BuildContext context, int minutes) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _Header extends StatelessWidget {
  const _Header(
    this.title,
    this.subtitle, {
    required this.switchKey,
    required this.on,
    required this.onChanged,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final Key switchKey;
  final bool on;
  final ValueChanged<bool> onChanged;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Title(title, subtitle)),
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
