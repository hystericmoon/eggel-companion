import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings/settings_store.dart';
import '../speaker/speaker.dart';

/// App-side tools that need no speaker protocol: a sleep timer that pauses
/// playback, and a volume cap.
class ToolsController extends ChangeNotifier {
  ToolsController(this.speaker, {DateTime Function()? now, this.settings})
    : _now = now ?? DateTime.now {
    final s = settings;
    if (s != null) {
      _volumeCap = s.get<int>('cap');
      alarmOn = s.get<bool>('alarmOn') ?? alarmOn;
      alarmMinutes = s.get<int>('alarmMinutes') ?? alarmMinutes;
      alarmVolume = s.get<int>('alarmVolume') ?? alarmVolume;
      alarmDays.addAll(
        (s.get<List<dynamic>>('alarmDays') ?? const []).whereType<int>(),
      );
      nightOn = s.get<bool>('nightOn') ?? nightOn;
      nightStart = s.get<int>('nightStart') ?? nightStart;
      nightEnd = s.get<int>('nightEnd') ?? nightEnd;
      nightCap = s.get<int>('nightCap') ?? nightCap;
    }
  }

  final AppSettings? settings;

  void _persist() {
    final s = settings;
    if (s == null) return;
    s.set('cap', _volumeCap);
    s.set('alarmOn', alarmOn);
    s.set('alarmMinutes', alarmMinutes);
    s.set('alarmVolume', alarmVolume);
    s.set('alarmDays', alarmDays.toList()..sort());
    s.set('nightOn', nightOn);
    s.set('nightStart', nightStart);
    s.set('nightEnd', nightEnd);
    s.set('nightCap', nightCap);
  }

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

  // ---- Alarm and night schedule (time of day as minutes since midnight) ----
  // Both only run while the app is open: nothing is registered with the OS.

  Timer? _clock;
  bool alarmOn = false;
  int alarmMinutes = 7 * 60;
  int alarmVolume = 30;

  /// Weekdays 1 (Mon) to 7 (Sun); empty means once.
  final Set<int> alarmDays = {};
  String? _alarmFiredKey;

  bool nightOn = false;
  int nightStart = 22 * 60;
  int nightEnd = 7 * 60;
  int nightCap = 30;
  bool _wasNight = false;

  /// Starts the once-a-second check that fires the alarm and night mode.
  void startClock() {
    _clock ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => checkSchedules(),
    );
  }

  bool get nightActive {
    if (!nightOn) return false;
    final m = _minutesNow();
    return nightStart <= nightEnd
        ? m >= nightStart && m < nightEnd
        : m >= nightStart || m < nightEnd;
  }

  /// The cap in force now: the lower of the manual cap and the night cap.
  int? get effectiveCap {
    final night = nightActive ? nightCap : null;
    if (night == null) return _volumeCap;
    final manual = _volumeCap;
    return manual == null || night < manual ? night : manual;
  }

  int _minutesNow() {
    final n = _now();
    return n.hour * 60 + n.minute;
  }

  void configure(void Function() change) {
    change();
    _alarmFiredKey = null;
    checkSchedules();
    _persist();
    notifyListeners();
  }

  /// Visible for tests: run the alarm and night checks once.
  void checkSchedules() {
    final n = _now();
    final night = nightActive;
    if (night && !_wasNight) {
      final cap = effectiveCap;
      if (cap != null && speaker.state.volume > cap) {
        speaker.setVolume(cap.toDouble());
      }
    }
    if (night != _wasNight) {
      _wasNight = night;
      notifyListeners();
    }
    if (alarmOn && _minutesNow() == alarmMinutes) {
      final today = alarmDays.isEmpty || alarmDays.contains(n.weekday);
      final key = '${n.year}-${n.month}-${n.day}-$alarmMinutes';
      if (today && _alarmFiredKey != key) {
        _alarmFiredKey = key;
        if (alarmDays.isEmpty) alarmOn = false;
        final cap = effectiveCap;
        final v = cap != null && alarmVolume > cap ? cap : alarmVolume;
        speaker.setVolume(v.toDouble());
        speaker.play();
        notifyListeners();
      }
    }
  }

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
    _persist();
    if (cap != null && speaker.state.volume > cap) {
      speaker.setVolume(cap.toDouble());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock?.cancel();
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
    final cap = tools.effectiveCap;
    return inner.setVolume(
      cap == null ? volume : volume.clamp(0, cap.toDouble()),
    );
  }

  @override
  Future<void> requestMediaAccess() => inner.requestMediaAccess();

  @override
  void dispose() => inner.dispose();
}
