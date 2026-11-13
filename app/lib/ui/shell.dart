import 'package:flutter/material.dart';

import '../link/speaker_link.dart';
import '../speaker/speaker.dart';
import '../tools/tools_controller.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'sound_page.dart';
import 'speaker_page.dart';
import 'theme/palette.dart';
import 'tools_page.dart';

/// App frame: four pages and a bottom bar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.speaker,
    required this.theme,
    required this.tools,
    this.link,
  });

  final SpeakerLink? link;
  final Speaker speaker;
  final ThemeController theme;
  final ToolsController tools;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.graphic_eq, 'Sound'),
    (Icons.grid_view_rounded, 'Tools'),
    (Icons.speaker_outlined, 'Speaker'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.theme,
      builder: (context, _) {
        final palette = widget.theme.palette;
        final pages = IndexedStack(
          index: _index,
          children: [
            HomePage(speaker: widget.speaker, theme: widget.theme),
            SoundPage(palette: palette, link: widget.link),
            ToolsPage(tools: widget.tools, palette: palette),
            SpeakerPage(
              speaker: widget.speaker,
              palette: palette,
              theme: widget.theme,
              link: widget.link,
            ),
          ],
        );
        // Wide windows (desktop) get one dashboard instead of the tabs.
        if (MediaQuery.sizeOf(context).width >= 760) {
          return DashboardPage(
            speaker: widget.speaker,
            theme: widget.theme,
            tools: widget.tools,
            link: widget.link,
          );
        }
        return Scaffold(
          backgroundColor: eggelBackground,
          body: pages,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: eggelBackground,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == _index,
                        label: _items[i].$2,
                        child: GestureDetector(
                          key: Key('tab-${_items[i].$2.toLowerCase()}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _index = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _items[i].$1,
                                  color: i == _index
                                      ? palette.accent
                                      : eggelMuted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _items[i].$2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: i == _index
                                        ? palette.accent
                                        : eggelMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
