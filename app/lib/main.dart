import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'speaker/channel_speaker.dart';
import 'speaker/fake_speaker.dart';
import 'speaker/speaker.dart';
import 'ui/home_page.dart';
import 'ui/theme/palette.dart';

void main() {
  // Android, Windows and macOS share the native "eggel/media" channel.
  // The shown volume is geometric per output (volume_floor.dart), so the
  // slider itself is linear.
  final Speaker speaker = Platform.isWindows
      ? ChannelSpeaker()
      : (Platform.isAndroid || Platform.isMacOS)
      ? ChannelSpeaker()
      : FakeSpeaker();
  runApp(EggelApp(speaker: speaker));
}

class EggelApp extends StatefulWidget {
  const EggelApp({super.key, required this.speaker});

  final Speaker speaker;

  @override
  State<EggelApp> createState() => _EggelAppState();
}

class _EggelAppState extends State<EggelApp> {
  final ThemeController _theme = ThemeController();

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The design is dark only; the chosen palette drives the accent.
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => MaterialApp(
        title: 'Eggel Companion',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          colorSchemeSeed: _theme.palette.accent,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: eggelBackground,
          useMaterial3: true,
        ),
        home: HomePage(speaker: widget.speaker, theme: _theme),
      ),
    );
  }
}
