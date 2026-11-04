import 'dart:async';

import 'package:flutter/services.dart';

import 'speaker.dart';

/// Real backend for Android and Windows: both implement the same native
/// "eggel/media" channel (media session + system volume).
///
/// This is the device's playback and volume, not the speaker's own settings.
/// Battery, EQ, rename and TWS need the speaker protocol.
class ChannelSpeaker implements Speaker {
  ChannelSpeaker({
    this.volumeExponent = 1,
    this.pollEvery = const Duration(seconds: 1),
  }) {
    _refresh();
    _timer = Timer.periodic(pollEvery, (_) => _refresh());
  }

  static const _channel = MethodChannel('eggel/media');

  @override
  final double volumeExponent;
  final Duration pollEvery;
  final _controller = StreamController<SpeakerState>.broadcast();
  SpeakerState _state = const SpeakerState();
  Timer? _timer;

  @override
  SpeakerState get state => _state;

  @override
  Stream<SpeakerState> get states => _controller.stream;

  void _set(SpeakerState next) {
    if (next == _state) return;
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  Future<void> _refresh() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('getState');
      if (m == null) return;
      final name = (m['name'] as String?) ?? '';
      _set(
        SpeakerState(
          connected: m['connected'] as bool? ?? false,
          name: name.isEmpty ? 'Bluetooth speaker' : name,
          playing: m['playing'] as bool? ?? false,
          volume: (m['volume'] as num?)?.toDouble() ?? 0,
          title: m['title'] as String? ?? '',
          artist: m['artist'] as String? ?? '',
          mediaAccess: m['mediaAccess'] as bool? ?? false,
        ),
      );
    } on PlatformException {
      // Keep the last known state; try again on the next tick.
    }
  }

  Future<void> _command(String method) async {
    await _channel.invokeMethod<void>(method);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _refresh();
  }

  @override
  Future<void> play() => _command('play');

  @override
  Future<void> pause() => _command('pause');

  @override
  Future<void> next() => _command('next');

  @override
  Future<void> previous() => _command('previous');

  @override
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 100.0);
    _set(_state.copyWith(volume: v)); // keep the slider smooth
    await _channel.invokeMethod<void>('setVolume', {'volume': v});
  }

  @override
  Future<void> requestMediaAccess() async {
    try {
      await _channel.invokeMethod<void>('openAccessSettings');
    } on MissingPluginException {
      // Not needed on this platform.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
