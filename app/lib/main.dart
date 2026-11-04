import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'speaker/channel_speaker.dart';
import 'speaker/fake_speaker.dart';
import 'speaker/speaker.dart';
import 'ui/home_page.dart';

void main() {
  // Android and Windows have a real backend; macOS still uses the fake one.
  // Windows gets a cubic slider so the quiet end has many small steps.
  final Speaker speaker = Platform.isAndroid
      ? ChannelSpeaker()
      : Platform.isWindows
      ? ChannelSpeaker(volumeExponent: 3)
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
