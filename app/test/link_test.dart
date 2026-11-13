import 'dart:async';
import 'dart:typed_data';

import 'package:eggel_companion/link/ble_link.dart';
import 'package:eggel_companion/link/speaker_link.dart';
import 'package:eggel_companion/link/tuya_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

// A made-up key and ids: never the real speaker's.
const _creds = TuyaCredentials(
  uuid: 'uuidtest00000000',
  deviceId: 'devtest000000000',
  localKey: 'k3y!ab',
);

TuyaCodec _codec() => TuyaCodec(
  localKey: _creds.localKey,
  uuid: _creds.uuid,
  deviceId: _creds.deviceId,
  random: (n) => Uint8List(n),
);

/// Plays the speaker's side of the handshake over [BleLink].
class FakeBle implements BleLink {
  final _events = StreamController<LinkEvent>.broadcast();
  final _speaker = _codec();
  final received = <TuyaFrame>[];
  bool connected = false;

  @override
  Stream<LinkEvent> get events => _events.stream;
  @override
  int get packetSize => 20;

  @override
  Future<void> connect() async {
    scheduleMicrotask(() => _events.add(LinkStatusEvent('connected')));
  }

  void _emit(int code, List<int> body, {int responseTo = 0}) {
    for (final p in _speaker.build(
      code,
      body,
      packetSize: 20,
      responseTo: responseTo,
    )) {
      _events.add(LinkDataEvent(p));
    }
  }

  @override
  Future<void> write(Uint8List packet) async {
    final f = _speaker.feed(packet);
    if (f == null) return;
    received.add(f);
    if (f.code == TuyaCode.deviceInfo) {
      final info = Uint8List(40)..setAll(6, [1, 2, 3, 4, 5, 6]);
      _speaker.startSession(info);
      _emit(TuyaCode.deviceInfo, info, responseTo: f.seq);
    } else if (f.code == TuyaCode.pair) {
      _emit(TuyaCode.pair, [2], responseTo: f.seq);
    } else if (f.code == TuyaCode.refresh) {
      _emit(TuyaCode.dpReport, [
        0, 0, 0, 0, 0, 0x80, 0, //
        ...encodeDataPoints([
          DataPoint.enumeration(Dp.eqPreset, 3),
          DataPoint(Dp.battery, 2, Uint8List.fromList([0, 0, 0, 87])),
        ]),
      ]);
    }
  }

  @override
  Future<void> disconnect() async {}
  @override
  void dispose() => _events.close();
}

void main() {
  test('frames survive a round trip, split into 20-byte packets', () {
    final a = _codec();
    final b = _codec();
    final info = Uint8List(40)..setAll(6, [9, 8, 7, 6, 5, 4]);
    a.startSession(info);
    b.startSession(info);
    final body = List.generate(50, (i) => i);
    TuyaFrame? got;
    for (final p in a.build(TuyaCode.dpWrite, body, packetSize: 20)) {
      expect(p.length, lessThanOrEqualTo(20));
      got = b.feed(p) ?? got;
    }
    expect(got, isNotNull);
    expect(got!.crcOk, isTrue);
    expect(got.code, TuyaCode.dpWrite);
    expect(got.body, body);
  });

  test('parses the full report captured from the speaker', () {
    final body = Uint8List.fromList(
      _hex(
        '000000000080000201000100050200040000001a14010001011504000100'
        '1b02000400000064',
      ),
    );
    final dps = parseDataPoints(body, start: 7);
    expect(dps.map((d) => d.id), [2, 5, 20, 21, 27]);
    expect(dps[1].asInt, 26);
    expect(dps[3].asInt, 0);
    expect(dps[4].asInt, 100);
  });

  test('encodes the EQ write like the phone does', () {
    final dps = encodeDataPoints([
      DataPoint.boolean(20, true),
      DataPoint.enumeration(21, 3),
    ]);
    expect(dps, _hex('14010001011504000103'));
  });

  test('pair body is 46 bytes', () {
    expect(_codec().pairBody().length, 46);
  });

  test('link handshakes, shows battery and EQ, and writes a preset', () async {
    final ble = FakeBle();
    final link = SpeakerLink(ble, credentials: _creds);
    await link.start();
    for (var i = 0; i < 100 && link.battery == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(link.status, LinkStatus.connected);
    expect(link.battery, 87);
    expect(link.eqPreset, 3);

    await link.setEqPreset(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final write = ble.received.lastWhere((f) => f.code == TuyaCode.dpWrite);
    expect(write.body.sublist(5), _hex('14010001011504000101'));
    expect(link.eqPreset, 1);
    link.dispose();
  });

  test('without credentials the link stays off', () async {
    final link = SpeakerLink(FakeBle());
    expect(link.available, isFalse);
    await link.start();
    expect(link.status, LinkStatus.off);
    link.dispose();
  });
}

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];
