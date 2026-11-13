import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'link/ble_link.dart';
import 'link/speaker_link.dart';
import 'settings/settings_store.dart';
import 'speaker/channel_speaker.dart';
import 'speaker/fake_speaker.dart';
import 'speaker/speaker.dart';
import 'tools/tools_controller.dart';
import 'ui/shell.dart';
import 'ui/theme/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await FileSettingsStore.open();
  final settings = AppSettings(store ?? MemorySettingsStore());
  // Android, Windows and macOS share the native "eggel/media" channel.
  // The shown volume is geometric per output (volume_floor.dart), so the
  // slider itself is linear.
  final Speaker inner = Platform.isWindows
      ? ChannelSpeaker()
      : (Platform.isAndroid || Platform.isMacOS)
      ? ChannelSpeaker()
      : FakeSpeaker();
  // The speaker's own settings (battery, EQ) over Bluetooth LE. Windows only
  // for now; needs the Tuya credentials in settings.json (key 'tuya').
  final SpeakerLink? link = Platform.isWindows
      ? SpeakerLink(
          ChannelBleLink(),
          credentials: TuyaCredentials.fromMap(settings.get<Map>('tuya')),
        )
      : null;
  link?.start();
  final tools = ToolsController(inner, settings: settings)..startClock();
  runApp(
    EggelApp(
      speaker: CappedSpeaker(inner, tools),
      tools: tools,
      settings: settings,
      link: link,
    ),
  );
}

class EggelApp extends StatefulWidget {
  const EggelApp({
    super.key,
    required this.speaker,
    required this.tools,
    this.settings,
    this.link,
  });

  final SpeakerLink? link;
  final AppSettings? settings;
  final Speaker speaker;
  final ToolsController tools;

  @override
  State<EggelApp> createState() => _EggelAppState();
}

class _EggelAppState extends State<EggelApp> {
  late final ThemeController _theme = ThemeController(ember, widget.settings);

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
          fontFamily: 'Inter',
        ),
        home: AppShell(
          speaker: widget.speaker,
          theme: _theme,
          tools: widget.tools,
          link: widget.link,
        ),
      ),
    );
  }
}
