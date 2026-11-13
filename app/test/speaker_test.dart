import 'package:eggel_companion/speaker/fake_speaker.dart';
import 'package:eggel_companion/speaker/speaker.dart';
import 'package:eggel_companion/ui/home_page.dart';
import 'package:eggel_companion/ui/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeSpeaker', () {
    test('pause and play update state and emit', () async {
      final s = FakeSpeaker();
      final emitted = <bool>[];
      final sub = s.states.listen((st) => emitted.add(st.playing));
      await s.pause();
      await s.play();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [false, true]);
      expect(s.state.playing, isTrue);
      await sub.cancel();
      s.dispose();
    });

    test('volume is clamped to 0..100', () async {
      final s = FakeSpeaker();
      await s.setVolume(150);
      expect(s.state.volume, 100);
      await s.setVolume(-5);
      expect(s.state.volume, 0);
      s.dispose();
    });
  });

  group('HomePage', () {
    testWidgets('shows connection, title and toggles pause', (tester) async {
      final s = FakeSpeaker();
      await tester.pumpWidget(MaterialApp(home: HomePage(speaker: s)));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Track title'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(s.calls, ['pause']);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('shows an access banner until media access is granted', (
      tester,
    ) async {
      final s = FakeSpeaker(
        initial: const SpeakerState(connected: true, mediaAccess: false),
      );
      await tester.pumpWidget(MaterialApp(home: HomePage(speaker: s)));
      expect(find.byKey(const Key('access-banner')), findsOneWidget);
      await tester.tap(find.text('Allow'));
      expect(s.calls, ['requestMediaAccess']);
    });

    testWidgets('controls are disabled when not connected', (tester) async {
      final s = FakeSpeaker(initial: const SpeakerState());
      await tester.pumpWidget(MaterialApp(home: HomePage(speaker: s)));
      expect(find.text('Not connected'), findsOneWidget);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(s.calls, isEmpty);
    });
  });

  group('Theme picker', () {
    testWidgets('choosing a color changes the palette', (tester) async {
      final s = FakeSpeaker();
      final theme = ThemeController();
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(speaker: s, theme: theme),
        ),
      );
      expect(theme.palette.name, 'Ember');
      await tester.ensureVisible(find.byKey(const Key('theme-aqua')));
      await tester.tap(find.byKey(const Key('theme-aqua')));
      await tester.pump();
      expect(theme.palette.name, 'Aqua');
    });

    testWidgets('volume buttons step the speaker volume', (tester) async {
      final s = FakeSpeaker();
      await tester.pumpWidget(MaterialApp(home: HomePage(speaker: s)));
      final before = s.state.volume;
      await tester.tap(find.byKey(const Key('volume-up')));
      await tester.pump();
      expect(s.state.volume, greaterThan(before));
    });
  });
}
