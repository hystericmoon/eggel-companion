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
                  _Row('Name', link?.name ?? s.name),
                  _Row('Status', s.connected ? 'Connected' : 'Not connected'),
                  _Row('Output', s.name),
                  if (link != null) ..._linkRows(link!),
                ],
              ),
            ),
            if (link?.status == LinkStatus.connected)
              _LinkControls(link: link!, palette: palette),
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

/// Rename and the speaker's own volume, shown only while the link is up.
class _LinkControls extends StatefulWidget {
  const _LinkControls({required this.link, required this.palette});

  final SpeakerLink link;
  final EggelPalette palette;

  @override
  State<_LinkControls> createState() => _LinkControlsState();
}

class _LinkControlsState extends State<_LinkControls> {
  late final _name = TextEditingController(text: widget.link.name ?? '');
  String? _error;
  double? _dragging;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await widget.link.rename(_name.text);
      setState(() => _error = null);
    } catch (e) {
      setState(
        () => _error = e is ArgumentError ? '${e.message}' : 'Could not rename',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.link;
    final vol = l.volume;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Speaker settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: eggelText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('rename-field'),
                  controller: _name,
                  maxLength: SpeakerLink.maxNameBytes,
                  style: const TextStyle(color: eggelText),
                  decoration: InputDecoration(
                    labelText: 'Speaker name',
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 12),
              GlowChip(
                key: const Key('rename-save'),
                label: 'Rename',
                palette: widget.palette,
                selected: true,
                onTap: _save,
              ),
            ],
          ),
          if (vol != null) ...[
            const SizedBox(height: 16),
            Text(
              'Speaker volume  ${(_dragging ?? vol.toDouble()).round()}',
              style: const TextStyle(fontSize: 13, color: eggelMuted),
            ),
            Slider(
              key: const Key('speaker-volume'),
              value: (_dragging ?? vol.toDouble()).clamp(0, 100),
              min: 0,
              max: 100,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) async {
                await l.setSpeakerVolume(v.round()).catchError((_) {});
                if (mounted) setState(() => _dragging = null);
              },
            ),
          ],
        ],
      ),
    );
  }
}
