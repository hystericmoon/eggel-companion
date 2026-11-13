"""Read-only Tuya BLE probe for the Eggel Active 3.

Connects over BLE (service 0xFD50), does the Tuya session handshake with the
local key from probe/tuya.env, asks for the device status and logs every
datapoint it reports. It never sends a datapoint-set command.

Run: python -I probe/probe_tuya.py        (speaker on, NOT connected to the phone)
Log: probe/tuya-log.txt  (never contains the local key)
"""
import asyncio
import hashlib
import secrets
import sys
import time
from pathlib import Path

from bleak import BleakClient, BleakScanner
from bleak.exc import BleakError
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

HERE = Path(__file__).parent
LOG = HERE / "tuya-log.txt"
WRITE = "00000001-0000-1001-8001-00805f9b07d0"
NOTIFY = "00000002-0000-1001-8001-00805f9b07d0"
SERVICE = "0000fd50-0000-1000-8000-00805f9b34fb"
MTU = 20


def log(msg):
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def load_env():
    env = {}
    for line in (HERE / "tuya.env").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v
    return env


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            low = crc & 1
            crc >>= 1
            if low:
                crc ^= 0xA001
    return crc


def pack_int(v):
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def unpack_int(data, pos):
    v = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        v |= (b & 0x7F) << shift
        if not b & 0x80:
            return v, pos
        shift += 7


def aes(key, iv, data, encrypt):
    c = Cipher(algorithms.AES(key), modes.CBC(iv))
    op = c.encryptor() if encrypt else c.decryptor()
    return op.update(data) + op.finalize()


class Session:
    def __init__(self, env):
        self.uuid = env["UUID"].encode()
        self.device_id = env["DEVICE_ID"].encode()
        self.local_key = env["LOCAL_KEY"][:6].encode()
        self.login_key = hashlib.md5(self.local_key).digest()
        self.session_key = None
        self.seq = 1
        self.proto = 2
        self.mtu = MTU
        self.buf = bytearray()
        self.expect = 0
        self.inbox = asyncio.Queue()

    def build(self, code, data=b""):
        iv = secrets.token_bytes(16)
        inp = bytearray()
        inp += self.seq.to_bytes(4, "big")
        inp += (0).to_bytes(4, "big")
        inp += code.to_bytes(2, "big")
        inp += len(data).to_bytes(2, "big")
        inp += data
        inp += crc16(inp).to_bytes(2, "big")
        while len(inp) % 16:
            inp += b"\x00"
        self.seq += 1
        if code == 0:
            flag, key = 4, self.login_key
        else:
            flag, key = 5, self.session_key
        enc = bytes([flag]) + iv + aes(key, iv, bytes(inp), True)
        packets, pos, n = [], 0, 0
        while pos < len(enc):
            p = bytearray(pack_int(n))
            if n == 0:
                p += pack_int(len(enc))
                p.append(self.proto << 4)
            part = enc[pos : pos + self.mtu - len(p)]
            p += part
            packets.append(bytes(p))
            pos += len(part)
            n += 1
        return packets

    def on_notify(self, _char, data):
        data = bytes(data)
        log(f"raw notify {data.hex()}")
        n, pos = unpack_int(data, 0)
        if n == 0:
            self.buf = bytearray()
            self.expect, pos = unpack_int(data, pos)
            pos += 1  # protocol version byte
        self.buf += data[pos:]
        if len(self.buf) >= self.expect:
            raw = bytes(self.buf[: self.expect])
            self.buf = bytearray()
            self.inbox.put_nowait(self.parse(raw))

    def parse(self, raw):
        flag, iv = raw[0], raw[1:17]
        key = self.login_key if flag == 4 else self.session_key
        if key is None:
            return ("nokey", flag, raw.hex())
        dec = aes(key, iv, raw[17:], False)
        seq = int.from_bytes(dec[0:4], "big")
        resp = int.from_bytes(dec[4:8], "big")
        code = int.from_bytes(dec[8:10], "big")
        ln = int.from_bytes(dec[10:12], "big")
        body = dec[12 : 12 + ln]
        ok = crc16(dec[: 12 + ln]) == int.from_bytes(dec[12 + ln : 14 + ln], "big")
        return (code, seq, resp, body, ok)


def parse_dps(body):
    out, pos = [], 0
    while pos + 3 <= len(body):
        dp, typ, ln = body[pos], body[pos + 1], body[pos + 2]
        val = body[pos + 3 : pos + 3 + ln]
        pos += 3 + ln
        out.append((dp, typ, val))
    return out


async def find_address(env):
    log("scanning for the speaker (service 0xFD50)...")
    found = await BleakScanner.find_device_by_filter(
        lambda d, ad: SERVICE in [u.lower() for u in ad.service_uuids]
        or (d.name or "").lower().startswith(("eggel", "active 3")),
        timeout=15,
    )
    return found


async def main():
    env = load_env()
    dev = await find_address(env)
    if not dev:
        log("speaker not found. It must be on and NOT connected to the phone.")
        return 1
    log(f"found {dev.name} {dev.address}")
    s = Session(env)
    async with BleakClient(dev) as client:
        s.mtu = max(MTU, client.mtu_size - 3)
        log(f"mtu {client.mtu_size}, packet size {s.mtu}")
        await client.start_notify(NOTIFY, s.on_notify)
        for extra in ("0000ab02-0000-1000-8000-00805f9b34fb", "0000ab03-0000-1000-8000-00805f9b34fb"):
            try:
                await client.start_notify(extra, lambda c, d, e=extra: log(f"AB notify {e[4:8]} {bytes(d).hex()}"))
            except Exception as ex:
                log(f"could not subscribe {extra[4:8]}: {ex}")
        await asyncio.sleep(1.5)
        # The official SDK reads characteristic 0003 right after service
        # discovery (qddqppb.pdqppqb in the APK) before it does anything else.
        try:
            v = await client.read_gatt_char("00000003-0000-1001-8001-00805f9b07d0")
            log(f"read 0003: {bytes(v).hex()}")
        except Exception as ex:
            log(f"read 0003 failed: {ex!r}")

        async def send(code, data=b""):
            for p in s.build(code, data):
                log(f"write {p.hex()}")
                await client.write_gatt_char(WRITE, p, response=False)

        async def expect(timeout=8):
            return await asyncio.wait_for(s.inbox.get(), timeout)

        # 1. device info (login key)
        await send(0, client.mtu_size.to_bytes(2, "big"))  # the phone sends its MTU (00f3) here
        r = await expect()
        log(f"reply code={r[0]} crc_ok={r[-1]}")
        info = r[3]
        log(f"device info: {info.hex()}  (version {info[0]}.{info[1]}, "
            f"protocol {info[2]}.{info[3]}, flags {info[4]}, bound={info[5]})")
        s.session_key = hashlib.md5(s.local_key + info[6:12]).digest()

        # 2. pair / authenticate with the session key
        pair = (s.uuid + s.local_key + s.device_id).ljust(44, b"\x00") + b"\x00\x01"  # phone sends 46 bytes
        await send(1, pair)
        r = await expect()
        log(f"pair reply code={r[0]} data={r[3].hex()} crc_ok={r[-1]}")

        # 3. ask for the status; log everything that comes back
        await send(3)
        await asyncio.sleep(1)
        await send(0x60)  # refresh request the phone uses; answered by a full 0x8006 report
        log("listening for datapoints for 10 s...")
        end = time.time() + 10
        while time.time() < end:
            try:
                r = await expect(timeout=max(0.1, end - time.time()))
            except asyncio.TimeoutError:
                break
            if r[0] == "nokey":
                log(f"undecryptable: {r}")
                continue
            log(f"msg code=0x{r[0]:04x} data={r[3].hex()} crc_ok={r[4]}")
            if r[0] in (0x8001, 0x8006):
                for dp, typ, val in parse_dps(r[3]):
                    log(f"  dp {dp} type {typ} value {val.hex()}")
    return 0


async def main_retry():
    # Windows often reports "Unreachable" on a reconnect right after a previous
    # session; waiting and trying again usually works.
    for attempt in range(1, 6):
        try:
            return await main()
        except BleakError as ex:
            log(f"attempt {attempt} failed: {ex}")
            await asyncio.sleep(6)
    return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main_retry()))
