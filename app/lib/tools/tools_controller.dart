import 'dart:async';

import 'package:flutter/foundation.dart';

import '../speaker/speaker.dart';

/// App-side tools that need no speaker protocol: a sleep timer that pauses
/// playback, and a volume cap.
class ToolsController extends ChangeNotifier {
  ToolsController(this.speaker, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Speaker speaker;
  final DateTime Function() _now;

  Timer? _ticker;
  DateTime? _sleepEnds;
  int? _volumeCap;

  /// Time left on the sleep timer, or null when it is off.
  Duration? get sleepRemaining {
    final ends = _sleepEnds;
    if (ends == null) return null;
    final left = ends.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Highest volume the app will set (shown scale), or null for no cap.
  int? get volumeCap => _volumeCap;

  void startSleep(Duration d) {
    _ticker?.cancel();
    _sleepEnds = _now().add(d);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void cancelSleep() {
    _ticker?.cancel();
    _ticker = null;
    _sleepEnds = null;
    notifyListeners();
  }

  /// Visible for tests: advance the timer logic once.
  @visibleForTesting
  void tick() => _tick();

  void _tick() {
    final left = sleepRemaining;
    if (left == null) return;
    if (left <= Duration.zero) {
      cancelSleep();
      speaker.pause();
    } else {
      notifyListeners();
    }
  }

  /// Sets the cap (null removes it) and lowers the volume if it is above it.
  void setVolumeCap(int? cap) {
    _volumeCap = cap;
    if (cap != null && speaker.state.volume > cap) {
      speaker.setVolume(cap.toDouble());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Wraps a [Speaker] so volume changes never go above the cap.
class CappedSpeaker implements Speaker {
  CappedSpeaker(this.inner, this.tools);

  final Speaker inner;
  final ToolsController tools;

  @override
  SpeakerState get state => inner.state;
  @override
  Stream<SpeakerState> get states => inner.states;
  @override
  double get volumeExponent => inner.volumeExponent;

  @override
  Future<void> play() => inner.play();
  @override
  Future<void> pause() => inner.pause();
  @override
  Future<void> next() => inner.next();
  @override
  Future<void> previous() => inner.previous();

  @override
  Future<void> setVolume(double volume) {
    final cap = tools.volumeCap;
    return inner.setVolume(cap == null ? volume : volume.clamp(0, cap.toDouble()));
  }

  @override
  Future<void> requestMediaAccess() => inner.requestMediaAccess();

  @override
  void dispose() => inner.dispose();
}
