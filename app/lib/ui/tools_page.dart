import 'package:flutter/material.dart';

import '../tools/tools_controller.dart';
import 'theme/palette.dart';
import 'tools_cards.dart';
import 'widgets/page_frame.dart';

/// App-side tools that work without the speaker protocol.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.tools, required this.palette});

  final ToolsController tools;
  final EggelPalette palette;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      palette: palette,
      title: 'Tools',
      children: [
        SleepCard(tools: tools, palette: palette),
        CapCard(tools: tools, palette: palette),
        AlarmCard(tools: tools, palette: palette),
        NightCard(tools: tools, palette: palette),
        const SoonCard(
          title: 'Find my speaker',
          subtitle: 'Needs the speaker link: the app cannot make the speaker ring yet.',
        ),
        const SoonCard(
          title: 'Megaphone',
          subtitle: 'Needs microphone capture and a way to route it to the speaker. Not built.',
        ),
      ],
    );
  }
}
