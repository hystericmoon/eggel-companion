import 'package:eggel_companion/speaker/fake_speaker.dart';
import 'package:eggel_companion/speaker/speaker.dart';
import 'package:eggel_companion/tools/tools_controller.dart';
import 'package:eggel_companion/ui/shell.dart';
import 'package:eggel_companion/ui/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('tabs switch pages and the sleep timer starts from Tools', (
    tester,
  ) async {
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
