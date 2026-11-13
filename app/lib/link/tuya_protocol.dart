import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Tuya BLE frame format, as seen between the Eggel Active 3 and the phone app
/// (docs/protocol.md). Pure Dart, no I/O.

int crc16(List<int> data) {
  var crc = 0xFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      final low = crc & 1;
      crc >>= 1;
      if (low != 0) crc ^= 0xA001;
    }
  }
  return crc;
}

Uint8List md5(List<int> data) {
  final d = MD5Digest();
  return d.process(Uint8List.fromList(data));
}

Uint8List _aes(Uint8List key, Uint8List iv, Uint8List data, bool encrypt) {
  final c = CBCBlockCipher(AESEngine())
    ..init(encrypt, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(data.length);
  for (var o = 0; o < data.length; o += 16) {
    c.processBlock(data, o, out, o);
  }
  return out;
}

List<int> packInt(int v) {
  final out = <int>[];
  while (true) {
    final b = v & 0x7F;
    v >>= 7;
    if (v != 0) {
      out.add(b | 0x80);
    } else {
      out.add(b);
      return out;
    }
  }
}

/// Returns (value, next position).
(int, int) unpackInt(List<int> data, int pos) {
  var v = 0;
  var shift = 0;
  while (true) {
    final b = data[pos++];
    v |= (b & 0x7F) << shift;
    if ((b & 0x80) == 0) return (v, pos);
    shift += 7;
  }
}

/// Function codes seen on the wire.
class TuyaCode {
  static const deviceInfo = 0x0000;
  static const pair = 0x0001;
  static const status = 0x0003;
  static const dpWrite = 0x0027;
  static const refresh = 0x0060;
  static const timeRequest = 0x8011;
  static const dpReport = 0x8006;
}

class TuyaFrame {
  TuyaFrame(this.code, this.seq, this.responseTo, this.body, this.crcOk);
  final int code;
  final int seq;
  final int responseTo;
  final Uint8List body;
  final bool crcOk;
}

class DataPoint {
  const DataPoint(this.id, this.type, this.value);
  final int id;

  /// 0 raw, 1 bool, 2 value (int32), 3 string, 4 enum, 5 bitmap.
  final int type;
  final Uint8List value;

  int get asInt {
    var v = 0;
    for (final b in value) {
      v = (v << 8) | b;
    }
    return v;
  }

  bool get asBool => value.isNotEmpty && value.first != 0;
  String get asText => String.fromCharCodes(value);

  static DataPoint boolean(int id, bool v) =>
      DataPoint(id, 1, Uint8List.fromList([v ? 1 : 0]));
  static DataPoint enumeration(int id, int v) =>
      DataPoint(id, 4, Uint8List.fromList([v]));
  static DataPoint number(int id, int v) => DataPoint(
    id,
    2,
    Uint8List.fromList([v >> 24, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]),
  );
  static DataPoint raw(int id, List<int> bytes) =>
      DataPoint(id, 0, Uint8List.fromList(bytes));
}

/// A report or write body: 5-byte header, then (for reports) 2 flag bytes,
/// then datapoints of id, type, 2-byte length, value.
List<DataPoint> parseDataPoints(List<int> body, {required int start}) {
  final out = <DataPoint>[];
  var pos = start;
  while (pos + 4 <= body.length) {
    final len = (body[pos + 2] << 8) | body[pos + 3];
    if (pos + 4 + len > body.length) break;
    out.add(
      DataPoint(
        body[pos],
        body[pos + 1],
        Uint8List.fromList(body.sublist(pos + 4, pos + 4 + len)),
      ),
    );
    pos += 4 + len;
  }
  return out;
}

Uint8List encodeDataPoints(List<DataPoint> dps) {
  final out = BytesBuilder();
  for (final d in dps) {
    out
      ..addByte(d.id)
      ..addByte(d.type)
      ..addByte(d.value.length >> 8)
      ..addByte(d.value.length & 0xFF)
      ..add(d.value);
  }
  return out.toBytes();
}

/// One encrypted session with the speaker. [random] supplies IVs (injectable
/// for tests).
class TuyaCodec {
  TuyaCodec({
    required String localKey,
    required this.uuid,
    required this.deviceId,
    Uint8List Function(int n)? random,
    this.protocol = 2,
  }) : _localKey = Uint8List.fromList(localKey.codeUnits.take(6).toList()),
       _random = random ?? _secureRandom {
    _loginKey = md5(_localKey);
  }

  final String uuid;
  final String deviceId;
  final int protocol;
  final Uint8List _localKey;
  final Uint8List Function(int n) _random;
  late final Uint8List _loginKey;
  Uint8List? _sessionKey;
  int _seq = 1;

  static final _rng = Random.secure();

  static Uint8List _secureRandom(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  /// The pair frame body the phone sends: uuid, local key, device id padded to
  /// 22 bytes, then 00 01.
  Uint8List pairBody() {
    final b = BytesBuilder()
      ..add(uuid.codeUnits)
      ..add(_localKey)
      ..add(deviceId.codeUnits);
    final bytes = b.toBytes();
    final padded = Uint8List(44)..setAll(0, bytes);
    return Uint8List.fromList([...padded, 0, 1]);
  }

  /// After the device-info reply (6 bytes at offset 6 are the random part).
  void startSession(Uint8List deviceInfoBody) {
    _sessionKey = md5([..._localKey, ...deviceInfoBody.sublist(6, 12)]);
  }

  bool get hasSession => _sessionKey != null;

  /// Builds the wire packets (each at most [packetSize] bytes).
  List<Uint8List> build(
    int code,
    List<int> data, {
    required int packetSize,
    int responseTo = 0,
  }) {
    final inp = BytesBuilder()
      ..add(_u32(_seq))
      ..add(_u32(responseTo))
      ..add([code >> 8, code & 0xFF])
      ..add([data.length >> 8, data.length & 0xFF])
      ..add(data);
    final head = inp.toBytes();
    final withCrc = [...head, crc16(head) >> 8, crc16(head) & 0xFF];
    while (withCrc.length % 16 != 0) {
      withCrc.add(0);
    }
    _seq++;
    final iv = _random(16);
    final login = code == TuyaCode.deviceInfo;
    final key = login ? _loginKey : _sessionKey!;
    final enc = Uint8List.fromList([
      login ? 4 : 5,
      ...iv,
      ..._aes(key, iv, Uint8List.fromList(withCrc), true),
    ]);
    final packets = <Uint8List>[];
    var pos = 0;
    var n = 0;
    while (pos < enc.length) {
      final p = <int>[...packInt(n)];
      if (n == 0) {
        p
          ..addAll(packInt(enc.length))
          ..add(protocol << 4);
      }
      final end = (pos + packetSize - p.length).clamp(0, enc.length);
      p.addAll(enc.sublist(pos, end));
      packets.add(Uint8List.fromList(p));
      pos = end;
      n++;
    }
    return packets;
  }

  Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

  final List<int> _buf = [];
  int _expect = 0;

  /// Feed one notification; returns a frame once complete, else null.
  TuyaFrame? feed(List<int> packet) {
    var pos = 0;
    final (n, afterN) = unpackInt(packet, pos);
    pos = afterN;
    if (n == 0) {
      _buf.clear();
      final (len, afterLen) = unpackInt(packet, pos);
      _expect = len;
      pos = afterLen + 1; // protocol byte
    }
    _buf.addAll(packet.sublist(pos));
    if (_buf.length < _expect) return null;
    final raw = Uint8List.fromList(_buf.sublist(0, _expect));
    _buf.clear();
    return _parse(raw);
  }

  TuyaFrame? _parse(Uint8List raw) {
    final flag = raw[0];
    final iv = raw.sublist(1, 17);
    final key = flag == 4 ? _loginKey : _sessionKey;
    if (key == null) return null;
    final body = raw.sublist(17);
    if (body.isEmpty || body.length % 16 != 0) return null;
    final dec = _aes(key, iv, body, false);
    final bd = dec.buffer.asByteData();
    final code = bd.getUint16(8);
    final len = bd.getUint16(10);
    if (12 + len + 2 > dec.length) return null;
    final ok = crc16(dec.sublist(0, 12 + len)) == bd.getUint16(12 + len);
    return TuyaFrame(
      code,
      bd.getUint32(0),
      bd.getUint32(4),
      Uint8List.fromList(dec.sublist(12, 12 + len)),
      ok,
    );
  }
}
