"""Read-only BLE probe for the Eggel Active 3.

Usage:
  python probe/probe_ble.py scan [seconds]        list nearby BLE devices
  python probe/probe_ble.py probe <address> [s]   connect, dump GATT, log notifications

NEVER writes to any characteristic. Reads are skipped for anything whose
service/characteristic name hints at OTA/DFU/firmware.
Output: probe/scan.txt, probe/services.txt, probe/notify-log.txt
"""
import asyncio
import sys
from datetime import datetime
from pathlib import Path

from bleak import BleakClient, BleakScanner

OUT = Path(__file__).parent
RISKY = ("ota", "dfu", "firmware", "upgrade")


def now():
    return datetime.now().isoformat(timespec="milliseconds")


async def scan(seconds):
    print(f"Scanning {seconds:.0f}s...")
    found = await BleakScanner.discover(timeout=seconds, return_adv=True)
    rows = []
    for addr, (dev, adv) in sorted(found.items(), key=lambda kv: -kv[1][1].rssi):
        rows.append(f"{addr}  rssi={adv.rssi:>4}  name={dev.name or adv.local_name!r}  "
                    f"uuids={adv.service_uuids}  mfr={ {k: v.hex() for k, v in adv.manufacturer_data.items()} }")
    text = "\n".join(rows)
    (OUT / "scan.txt").write_text(f"# scan {now()}\n{text}\n", encoding="utf-8")
    print(text)


async def probe(address, seconds):
    lines, notif = [], open(OUT / "notify-log.txt", "w", encoding="utf-8")
    notif.write(f"# notify log {now()}\n")

    def on_notify(char):
        def cb(_, data):
            line = f"{now()}  {char.uuid}  len={len(data)}  {bytes(data).hex(' ')}"
            print(line)
            notif.write(line + "\n")
            notif.flush()
        return cb

    async with BleakClient(address) as client:
        print("Connected:", client.is_connected)
        for svc in client.services:
            lines.append(f"SERVICE {svc.uuid}  ({svc.description})")
            for ch in svc.characteristics:
                lines.append(f"  CHAR {ch.uuid}  handle={ch.handle}  props={','.join(ch.properties)}  ({ch.description})")
                risky = any(k in (ch.description + svc.description).lower() for k in RISKY)
                if "read" in ch.properties and not risky:
                    try:
                        val = await client.read_gatt_char(ch)
                        lines.append(f"    value: {bytes(val).hex(' ')}  {bytes(val)!r}")
                    except Exception as e:
                        lines.append(f"    read failed: {e}")
                elif risky:
                    lines.append("    skipped (looks like OTA/DFU)")
                if ("notify" in ch.properties or "indicate" in ch.properties) and not risky:
                    try:
                        await client.start_notify(ch, on_notify(ch))
                        lines.append("    subscribed")
                    except Exception as e:
                        lines.append(f"    subscribe failed: {e}")
                for d in ch.descriptors:
                    lines.append(f"    DESC {d.uuid}")
        (OUT / "services.txt").write_text(f"# {address} {now()}\n" + "\n".join(lines) + "\n", encoding="utf-8")
        print("\n".join(lines))
        print(f"\nListening {seconds:.0f}s (change volume/EQ on the speaker now)...")
        await asyncio.sleep(seconds)
    notif.close()


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("scan", "probe"):
        sys.exit(__doc__)
    if sys.argv[1] == "scan":
        asyncio.run(scan(float(sys.argv[2]) if len(sys.argv) > 2 else 10))
    else:
        asyncio.run(probe(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 30))
