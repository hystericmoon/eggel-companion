"""Decode Tuya BLE frames from an Android btsnoop log using probe/tuya.env.
Usage: python -I probe/decode_cap.py <btsnoop_hci.log>   (prints no key material)"""
import hashlib, struct, sys, datetime
from probe_tuya import load_env, aes, unpack_int, crc16, parse_dps
EPOCH = 0x00E03AB44A676000
env = load_env()
lk = env["LOCAL_KEY"][:6].encode()
login = hashlib.md5(lk).digest()
f = open(sys.argv[1], "rb").read()
pos = 16
bufs = {"TX": [None, 0, bytearray()], "RX": [None, 0, bytearray()]}
sess = None
def handle(d, t, dirn):
    global sess
    flag, iv = d[0], d[1:17]
    key = login if flag == 4 else sess
    if key is None: print(t, dirn, "no key flag", flag); return
    dec = aes(key, iv, d[17:], False)
    seq, resp, code, ln = struct.unpack(">IIHH", dec[:12])
    body = dec[12:12+ln]
    ok = crc16(dec[:12+ln]) == int.from_bytes(dec[12+ln:14+ln], "big")
    if code == 0 and dirn == "RX" and ok:
        sess = hashlib.md5(lk + body[6:12]).digest()
    shown = "<redacted pair body, %d bytes>" % len(body) if code == 1 and dirn == "TX" else body.hex()
    print(t, dirn, f"code=0x{code:04x} seq={seq} resp={resp} crc={ok} data={shown}")
    if code in (0x8001, 0x8006, 0x0002, 0x0003, 0x000d) and len(body) > 4:
        pass
while pos + 24 <= len(f):
    ol, il, fl, dr, ts = struct.unpack(">IIIIq", f[pos:pos+24]); pos += 24
    d = f[pos:pos+il]; pos += il
    if len(d) < 13 or d[0] != 2 or struct.unpack("<H", d[7:9])[0] != 4: continue
    op = d[9]
    if op not in (0x52, 0x12, 0x1b): continue
    if op == 0x12: continue
    dirn = "TX" if op == 0x52 else "RX"
    h = struct.unpack("<H", d[10:12])[0]
    p = d[12:]
    t = datetime.datetime.fromtimestamp((ts-EPOCH)/1e6, datetime.timezone.utc).strftime("%H:%M:%S")
    b = bufs[dirn]
    n, q = unpack_int(p, 0)
    if n == 0:
        b[2] = bytearray(); b[1], q = unpack_int(p, q); q += 1
    b[2] += p[q:]
    if len(b[2]) >= b[1]:
        try: handle(bytes(b[2][:b[1]]), t, dirn)
        except Exception as e: print(t, dirn, "decode error", e)
        b[2] = bytearray()
