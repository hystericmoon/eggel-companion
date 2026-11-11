import 'dart:async';

import 'package:flutter/services.dart';

import 'speaker.dart';
import 'volume_floor.dart';

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

  // Last shown volume (see volume_floor.dart) and the output's name. When the
  // default output changes (USB <-> Bluetooth), the same shown level is applied
  // to the new output, so the number and the quietness stay the same.
  double? _carry;
  String? _lastName;
  double _floor = 0;

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
    final gen = _volumeGen;
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('getState');
      if (m == null) return;
      final name = (m['name'] as String?) ?? '';
      final connected = m['connected'] as bool? ?? false;
      final floor = audibleFloorFor(name);
      final sessionMin = (m['sessionMin'] as num?)?.toDouble() ?? 1;
      final sessionMax = (m['sessionMax'] as num?)?.toDouble() ?? 1;
      var volume = shownFromDevice(
        (m['volume'] as num?)?.toDouble() ?? 0,
        sessionMin,
        floor,
      );
      // Drop a poll that started before our latest volume change, and keep
      // our own value when the read-back is only rounding noise; otherwise
      // the + button steps from a slightly-off value and lands on the same
      // step again.
      if (gen != _volumeGen) return;
      final own = _carry;
      if (connected && own != null && (volume - own).abs() < 1.5) {
        volume = own;
      }
      if (connected) {
        final carry = _carry;
        if (_lastName != null && name != _lastName && carry != null) {
          volume = carry;
          await _apply(carry, floor);
        } else if (_wantScale < 1 && sessionMax > _wantScale + 1e-3) {
          // An app started after we attenuated: bring it down too.
          await _apply(_carry ?? volume, floor);
        }
        _lastName = name;
        _floor = floor;
        _carry = volume;
      }
      _set(
        SpeakerState(
          connected: connected,
          name: name.isEmpty ? 'Bluetooth speaker' : name,
          playing: m['playing'] as bool? ?? false,
          volume: volume,
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
    _carry = v;
    _volumeGen++;
    _set(_state.copyWith(volume: v)); // keep the slider smooth
    await _apply(v, _floor);
  }

  double _wantScale = 1;
  int _volumeGen = 0;

  Future<void> _apply(double shown, double floor) async {
    final plan = planVolume(shown, floor);
    _wantScale = plan.scale;
    await _channel.invokeMethod<void>('setVolume', {
      'volume': plan.endpoint,
      'sessionScale': plan.scale,
    });
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
