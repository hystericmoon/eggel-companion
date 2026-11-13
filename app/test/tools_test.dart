import 'package:eggel_companion/settings/settings_store.dart';
import 'package:eggel_companion/speaker/fake_speaker.dart';
import 'package:eggel_companion/speaker/speaker.dart';
import 'package:eggel_companion/tools/tools_controller.dart';
import 'package:eggel_companion/ui/shell.dart';
import 'package:eggel_companion/ui/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  persistenceTests();
  test('sleep timer pauses when time is up', () {
    var now = DateTime(2026, 1, 1, 22);
    final s = FakeSpeaker();
    final t = ToolsController(s, now: () => now);
    t.startSleep(const Duration(minutes: 15));
    expect(t.sleepRemaining, const Duration(minutes: 15));
    now = now.add(const Duration(minutes: 14));
    t.tick();
    expect(s.calls, isEmpty);
    now = now.add(const Duration(minutes: 2));
    t.tick();
    expect(s.calls, ['pause']);
    expect(t.sleepRemaining, isNull);
    t.dispose();
  });

  test('cancelling the timer leaves playback alone', () {
    final s = FakeSpeaker();
    final t = ToolsController(s);
    t.startSleep(const Duration(minutes: 5));
    t.cancelSleep();
    expect(t.sleepRemaining, isNull);
    expect(s.calls, isEmpty);
    t.dispose();
  });

  test('volume cap limits new volumes and lowers a louder one', () async {
    final inner = FakeSpeaker(
      initial: const SpeakerState(connected: true, volume: 90),
    );
    final t = ToolsController(inner);
    final capped = CappedSpeaker(inner, t);
    t.setVolumeCap(70);
    await Future<void>.delayed(Duration.zero);
    expect(inner.state.volume, 70);
    await capped.setVolume(95);
    expect(inner.state.volume, 70);
    await capped.setVolume(40);
    expect(inner.state.volume, 40);
    t.setVolumeCap(null);
    await capped.setVolume(95);
    expect(inner.state.volume, 95);
    t.dispose();
  });

  test('alarm plays once at its time and then turns itself off', () {
    var now = DateTime(2026, 1, 5, 6, 59); // a Monday
    final s = FakeSpeaker(initial: const SpeakerState(connected: true));
    final t = ToolsController(s, now: () => now);
    t.configure(() {
      t.alarmOn = true;
      t.alarmMinutes = 7 * 60;
      t.alarmVolume = 25;
    });
    t.checkSchedules();
    expect(s.calls, isEmpty);
    now = DateTime(2026, 1, 5, 7, 0);
    t.checkSchedules();
    t.checkSchedules();
    expect(s.calls, ['volume:25.0', 'play']);
    expect(s.state.volume, 25);
    expect(t.alarmOn, isFalse);
    t.dispose();
  });

  test('repeating alarm skips days that are not picked', () {
    var now = DateTime(2026, 1, 6, 7, 0); // Tuesday
    final s = FakeSpeaker(initial: const SpeakerState(connected: true));
    final t = ToolsController(s, now: () => now);
    t.configure(() {
      t.alarmOn = true;
      t.alarmDays.add(DateTime.monday);
    });
    expect(s.calls, isEmpty);
    now = DateTime(2026, 1, 12, 7, 0); // next Monday
    t.checkSchedules();
    expect(s.calls, ['volume:30.0', 'play']);
    expect(t.alarmOn, isTrue);
    t.dispose();
  });

  test('night schedule caps volume across midnight', () {
    var now = DateTime(2026, 1, 5, 21, 0);
    final s = FakeSpeaker(
      initial: const SpeakerState(connected: true, volume: 60),
    );
    final t = ToolsController(s, now: () => now);
    t.configure(() {
      t.nightOn = true;
      t.nightCap = 30;
    });
    expect(t.nightActive, isFalse);
    expect(t.effectiveCap, isNull);
    now = DateTime(2026, 1, 5, 23, 30);
    t.checkSchedules();
    expect(t.nightActive, isTrue);
    expect(t.effectiveCap, 30);
    expect(s.state.volume, 30);
    now = DateTime(2026, 1, 6, 6, 0);
    expect(t.nightActive, isTrue);
    now = DateTime(2026, 1, 6, 8, 0);
    expect(t.nightActive, isFalse);
    t.dispose();
  });

  testWidgets('wide windows show one dashboard with everything on it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inner = FakeSpeaker();
    final tools = ToolsController(inner);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          speaker: CappedSpeaker(inner, tools),
          theme: ThemeController(),
          tools: tools,
        ),
      ),
    );
    expect(find.byKey(const Key('tab-tools')), findsNothing);
    expect(find.byKey(const Key('status')), findsOneWidget);
    expect(find.byKey(const Key('volume-up')), findsOneWidget);
    expect(find.byKey(const Key('preset-3')), findsOneWidget);
    expect(find.byKey(const Key('eq-note')), findsOneWidget);
    expect(find.byKey(const Key('bands-note')), findsOneWidget);
    expect(find.byKey(const Key('needs-link')), findsOneWidget);
    expect(find.byKey(const Key('sleep-30')), findsOneWidget);
    expect(find.byKey(const Key('cap-off')), findsOneWidget);
    expect(find.byKey(const Key('alarm-switch')), findsOneWidget);
    expect(find.byKey(const Key('night-switch')), findsOneWidget);
    expect(find.byKey(const Key('find-card')), findsOneWidget);
    expect(find.byKey(const Key('megaphone-card')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('sleep-30')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sleep-30')));
    await tester.pump();
    expect(find.byKey(const Key('sleep-remaining')), findsOneWidget);
    tools.dispose();
  });

  testWidgets('a medium window stacks the same dashboard in one column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inner = FakeSpeaker();
    final tools = ToolsController(inner);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          speaker: CappedSpeaker(inner, tools),
          theme: ThemeController(),
          tools: tools,
        ),
      ),
    );
    expect(find.byKey(const Key('volume-up')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tools.dispose();
  });

  testWidgets('tabs switch pages and the sleep timer starts from Tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inner = FakeSpeaker();
    final tools = ToolsController(inner);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          speaker: CappedSpeaker(inner, tools),
          theme: ThemeController(),
          tools: tools,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tab-tools')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sleep-30')));
    await tester.pump();
    expect(find.byKey(const Key('sleep-remaining')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sleep-cancel')));
    await tester.pump();
    expect(find.byKey(const Key('sleep-30')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-sound')));
    await tester.pump();
    expect(find.byKey(const Key('eq-note')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-speaker')));
    await tester.pump();
    expect(find.byKey(const Key('needs-link')), findsOneWidget);
    tools.dispose();
  });
}

void persistenceTests() {
  test('tools and theme settings survive a restart', () {
    final store = MemorySettingsStore();
    final s = FakeSpeaker();
    final t = ToolsController(s, settings: AppSettings(store));
    t.configure(() {
      t.alarmOn = true;
      t.alarmMinutes = 6 * 60 + 45;
      t.alarmDays.addAll([1, 3]);
      t.nightOn = true;
      t.nightCap = 25;
    });
    t.setVolumeCap(60);
    final theme = ThemeController(ember, AppSettings(store))..select(aqua);

    final again = ToolsController(s, settings: AppSettings(store));
    expect(again.alarmOn, isTrue);
    expect(again.alarmMinutes, 405);
    expect(again.alarmDays, {1, 3});
    expect(again.nightOn, isTrue);
    expect(again.nightCap, 25);
    expect(again.volumeCap, 60);
    expect(ThemeController(ember, AppSettings(store)).palette, aqua);
    t.dispose();
    again.dispose();
    theme.dispose();
  });
}
