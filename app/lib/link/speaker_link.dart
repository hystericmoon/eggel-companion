import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ble_link.dart';
import 'tuya_protocol.dart';

/// Credentials of the speaker's Tuya device (from the Tuya cloud project).
class TuyaCredentials {
  const TuyaCredentials({
    required this.uuid,
    required this.deviceId,
    required this.localKey,
  });

  final String uuid;
  final String deviceId;
  final String localKey;

  static TuyaCredentials? fromMap(Object? m) {
    if (m is! Map) return null;
    final u = m['uuid'], d = m['deviceId'], k = m['localKey'];
    if (u is String && d is String && k is String && k.length >= 6) {
      return TuyaCredentials(uuid: u, deviceId: d, localKey: k);
    }
    return null;
  }
}

enum LinkStatus { off, connecting, connected }

/// Datapoint ids on the Active 3 (decoded from the phone app, docs/protocol.md).
class Dp {
  static const volume = 5;
  static const eqOn = 20;
  static const eqPreset = 21;
  static const battery = 27;
  static const name = 32;
}

/// EQ presets in the app's order; the enum value is the datapoint value.
const eqPresetNames = [
  'Default',
  'Treble boost',
  'Treble reducer',
  'Bass boost',
  'Bass reducer',
];

/// The speaker's own settings over the Tuya BLE link. Keeps one connection and
/// reconnects after a drop. Never sends anything the phone app does not.
class SpeakerLink extends ChangeNotifier {
  SpeakerLink(
    this._ble, {
    TuyaCredentials? credentials,
    this.retryAfter = const Duration(seconds: 8),
  }) : _credentials = credentials;

  final BleLink _ble;
  final TuyaCredentials? _credentials;
  final Duration retryAfter;

  LinkStatus status = LinkStatus.off;
  String detail = '';
  int? battery;
  int? eqPreset;
  int? volume;
  String? name;

  /// True when credentials exist, so a link can be attempted.
  bool get available => _credentials != null;

  StreamSubscription<LinkEvent>? _sub;
  TuyaCodec? _codec;
  Completer<TuyaFrame>? _waiting;
  int _waitingCode = -1;
  bool _stopped = true;
  int _dpCounter = 1;
  bool _handshaking = false;

  Future<void> start() async {
    if (!available || !_stopped) return;
    _stopped = false;
    _sub = _ble.events.listen(_onEvent);
    await _attempt();
  }

  Future<void> stop() async {
    _stopped = true;
    await _sub?.cancel();
    _sub = null;
    _set(LinkStatus.off, '');
    try {
      await _ble.disconnect();
    } catch (_) {}
  }

  void _set(LinkStatus s, String d) {
    status = s;
    detail = d;
    notifyListeners();
  }

  Future<void> _attempt() async {
    if (_stopped) return;
    _set(LinkStatus.connecting, 'Looking for the speaker');
    final c = _credentials!;
    _codec = TuyaCodec(
      localKey: c.localKey,
      uuid: c.uuid,
      deviceId: c.deviceId,
    );
    try {
      await _ble.connect();
    } catch (e) {
      _scheduleRetry('Could not start: $e');
    }
  }

  Timer? _retry;
  void _scheduleRetry(String why) {
    if (_stopped) return;
    _set(LinkStatus.connecting, why);
    _retry?.cancel();
    _retry = Timer(retryAfter, _attempt);
  }

  void _onEvent(LinkEvent e) {
    if (e is LinkStatusEvent) {
      switch (e.state) {
        case 'connected':
          unawaited(_handshake());
        case 'failed':
        case 'disconnected':
          _handshaking = false;
          _waiting?.completeError(StateError('link lost'));
          _waiting = null;
          _scheduleRetry(e.message.isEmpty ? 'Reconnecting' : e.message);
        default:
          _set(LinkStatus.connecting, e.message.isEmpty ? e.state : e.message);
      }
    } else if (e is LinkDataEvent) {
      final frame = _codec?.feed(e.data);
      if (frame != null && frame.crcOk) _onFrame(frame);
    }
  }

  Future<TuyaFrame> _send(int code, List<int> data, {int waitFor = -1}) async {
    final codec = _codec!;
    Future<TuyaFrame>? reply;
    if (waitFor >= 0) {
      _waiting = Completer<TuyaFrame>();
      _waitingCode = waitFor;
      reply = _waiting!.future.timeout(const Duration(seconds: 8));
    }
    for (final p in codec.build(code, data, packetSize: _ble.packetSize)) {
      await _ble.write(p);
    }
    return reply ?? Future.value(TuyaFrame(code, 0, 0, Uint8List(0), true));
  }

  Future<void> _handshake() async {
    if (_handshaking || _stopped) return;
    _handshaking = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final mtu = _ble.packetSize + 3;
      final info = await _send(TuyaCode.deviceInfo, [
        mtu >> 8,
        mtu & 0xFF,
      ], waitFor: TuyaCode.deviceInfo);
      _codec!.startSession(info.body);
      await _send(TuyaCode.pair, _codec!.pairBody(), waitFor: TuyaCode.pair);
      await _send(TuyaCode.status, const []);
      await Future<void>.delayed(const Duration(seconds: 1));
      await _send(TuyaCode.refresh, const []);
      _set(LinkStatus.connected, '');
    } catch (e) {
      _handshaking = false;
      try {
        await _ble.disconnect();
      } catch (_) {}
      _scheduleRetry('Handshake failed: $e');
    }
  }

  void _onFrame(TuyaFrame f) {
    final w = _waiting;
    if (w != null && !w.isCompleted && f.code == _waitingCode) {
      w.complete(f);
      _waiting = null;
      return;
    }
    switch (f.code) {
      case TuyaCode.timeRequest:
        final ms = DateTime.now().millisecondsSinceEpoch.toString();
        final tz = (DateTime.now().timeZoneOffset.inMinutes * 100 / 60).round();
        unawaited(
          _reply(TuyaCode.timeRequest, f.seq, [
            ...ms.codeUnits,
            (tz >> 8) & 0xFF,
            tz & 0xFF,
          ]),
        );
      case TuyaCode.dpReport:
        if (f.body.length < 7) return;
        applyReport(parseDataPoints(f.body, start: 7));
        // The phone acknowledges change reports (flags 0000), not full ones.
        if (f.body[5] == 0 && f.body[6] == 0) {
          unawaited(
            _reply(TuyaCode.dpReport, f.seq, [
              ...f.body.sublist(0, 5),
              0,
              0,
              0,
            ]),
          );
        }
    }
  }

  Future<void> _reply(int code, int responseTo, List<int> data) async {
    final codec = _codec;
    if (codec == null || !codec.hasSession) return;
    for (final p in codec.build(
      code,
      data,
      packetSize: _ble.packetSize,
      responseTo: responseTo,
    )) {
      await _ble.write(p);
    }
  }

  /// Applies datapoints from a report (also used by tests).
  @visibleForTesting
  void applyReport(List<DataPoint> dps) {
    for (final d in dps) {
      switch (d.id) {
        case Dp.battery:
          battery = d.asInt;
        case Dp.eqPreset:
          eqPreset = d.asInt;
        case Dp.volume:
          volume = d.asInt;
        case Dp.name:
          name = d.asText;
      }
    }
    notifyListeners();
  }

  Future<void> _writeDps(List<DataPoint> dps) async {
    if (status != LinkStatus.connected) {
      throw StateError('speaker link is not connected');
    }
    _dpCounter = (_dpCounter + 1) & 0xFF;
    final body = <int>[0, 0, 0, 0, _dpCounter, ...encodeDataPoints(dps)];
    await _send(TuyaCode.dpWrite, body);
  }

  /// Picks an EQ preset (index into [eqPresetNames]).
  Future<void> setEqPreset(int index) async {
    if (index < 0 || index >= eqPresetNames.length) {
      throw RangeError.index(index, eqPresetNames, 'index');
    }
    await _writeDps([
      DataPoint.boolean(Dp.eqOn, true),
      DataPoint.enumeration(Dp.eqPreset, index),
    ]);
    eqPreset = index;
    notifyListeners();
  }

  /// The most bytes the speaker name may take (the phone app wrote 14; this
  /// is a cautious cap, not a known limit).
  static const maxNameBytes = 24;

  /// Renames the speaker (datapoint 32, UTF-8 text, as the phone app does).
  Future<void> rename(String newName) async {
    final trimmed = newName.trim();
    final bytes = utf8.encode(trimmed);
    if (bytes.isEmpty || bytes.length > maxNameBytes) {
      throw ArgumentError('The name must be 1 to $maxNameBytes bytes');
    }
    await _writeDps([DataPoint.raw(Dp.name, bytes)]);
    name = trimmed;
    notifyListeners();
  }

  /// Sets the speaker's own volume, 0 to 100 (datapoint 5). The phone app
  /// never wrote this in the capture, so the range is read from reports only.
  Future<void> setSpeakerVolume(int v) async {
    final clamped = v.clamp(0, 100);
    await _writeDps([DataPoint.number(Dp.volume, clamped)]);
    volume = clamped;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopped = true;
    _retry?.cancel();
    _sub?.cancel();
    _ble.dispose();
    super.dispose();
  }
}
