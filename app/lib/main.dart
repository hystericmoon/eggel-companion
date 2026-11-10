import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'speaker/channel_speaker.dart';
import 'speaker/fake_speaker.dart';
import 'speaker/speaker.dart';
import 'ui/home_page.dart';

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

class EggelApp extends StatelessWidget {
  const EggelApp({super.key, required this.speaker});

  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eggel Companion',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CFF),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomePage(speaker: speaker),
    );
  }
}
