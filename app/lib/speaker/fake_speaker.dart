import 'dart:async';

import 'speaker.dart';

/// In-memory speaker for tests and for running the UI without hardware.
class FakeSpeaker implements Speaker {
  FakeSpeaker({SpeakerState? initial})
    : _state =
          initial ??
          const SpeakerState(
            connected: true,
            playing: true,
            volume: 35,
            title: 'Track title',
            artist: 'Artist',
          );

  final _controller = StreamController<SpeakerState>.broadcast();
  SpeakerState _state;

  /// Calls received, oldest first, for assertions in tests.
  final List<String> calls = [];

  @override
  SpeakerState get state => _state;

  @override
  Stream<SpeakerState> get states => _controller.stream;

  void _set(SpeakerState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _set(_state.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _set(_state.copyWith(playing: false));
  }

  @override
  Future<void> next() async => calls.add('next');

  @override
  Future<void> previous() async => calls.add('previous');

  @override
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 100.0);
    calls.add('volume:$v');
    _set(_state.copyWith(volume: v));
  }

  @override
  double get volumeExponent => 1;

  @override
  Future<void> requestMediaAccess() async => calls.add('requestMediaAccess');

  /// Simulates the speaker dropping or regaining its connection.
  void setConnected(bool connected) =>
      _set(_state.copyWith(connected: connected));

  @override
  void dispose() => _controller.close();
}
