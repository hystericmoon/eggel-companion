import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something the native BLE side reports.
sealed class LinkEvent {}

/// State text from the native side: scanning, connecting, connected,
/// disconnected, failed.
class LinkStatusEvent extends LinkEvent {
  LinkStatusEvent(this.state, [this.message = '']);
  final String state;
  final String message;
}

class LinkDataEvent extends LinkEvent {
  LinkDataEvent(this.data);
  final Uint8List data;
}

/// Raw GATT access to the speaker's Tuya service (0xFD50). Platform code only
/// finds the speaker, connects, subscribes and moves bytes; the protocol lives
/// in Dart.
abstract class BleLink {
  Stream<LinkEvent> get events;

  /// Largest packet that fits one write.
  int get packetSize;

  /// Starts scanning and connecting; progress arrives on [events].
  Future<void> connect();
  Future<void> write(Uint8List packet);
  Future<void> disconnect();
  void dispose();
}

/// Native implementation over the "eggel/ble" method channel. The native side
/// works on its own thread and queues events, which are polled here.
class ChannelBleLink implements BleLink {
  ChannelBleLink({this.pollEvery = const Duration(milliseconds: 100)});

  static const _channel = MethodChannel('eggel/ble');
  final Duration pollEvery;
  final _controller = StreamController<LinkEvent>.broadcast();
  Timer? _timer;
  bool _polling = false;
  int _packetSize = 20;

  @override
  Stream<LinkEvent> get events => _controller.stream;

  @override
  int get packetSize => _packetSize;

  @override
  Future<void> connect() async {
    _timer ??= Timer.periodic(pollEvery, (_) => _poll());
    await _channel.invokeMethod<void>('connect');
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final events = await _channel.invokeListMethod<Map>('poll') ?? const [];
      for (final e in events) {
        switch (e['type']) {
          case 'status':
            _controller.add(
              LinkStatusEvent(
                e['state'] as String,
                (e['message'] as String?) ?? '',
              ),
            );
          case 'packetSize':
            _packetSize = (e['value'] as num).toInt();
          case 'data':
            _controller.add(LinkDataEvent(e['data'] as Uint8List));
        }
      }
    } on PlatformException catch (e) {
      debugPrint('ble poll failed: $e');
    } on MissingPluginException {
      _timer?.cancel();
      _timer = null;
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> write(Uint8List packet) =>
      _channel.invokeMethod<void>('write', {'data': packet});

  @override
  Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
