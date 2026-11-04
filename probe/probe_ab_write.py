"""Guarded write probe for the vendor service 0xAB00 (characteristic AB01).

Default is a DRY RUN: prints the plan and sends nothing.
Add --send to actually write.

Only ever writes to AB01. Never touches the Device Name characteristic, the
0xFD50 (Tuya) service, or anything that looks like OTA/DFU. Payloads are short
header-only probes, not set/config commands. After each write it listens 3 s on
AB02/AB03 and logs every response.

Usage: python probe/probe_ab_write.py <address> [--send]
Output: probe/ab-write-log.txt
"""
import asyncio
import sys
from datetime import datetime
from pathlib import Path

from bleak import BleakClient

AB01 = "0000ab01-0000-1000-8000-00805f9b34fb"
NOTIFY = ["0000ab02-0000-1000-8000-00805f9b34fb", "0000ab03-0000-1000-8000-00805f9b34fb"]
LISTEN_S = 3.0
OUT = Path(__file__).parent / "ab-write-log.txt"

# (label, bytes). Short, header-only, no length/command fields that could mean "set".
PLAN = [
    ("single 00", bytes.fromhex("00")),
    ("single 01", bytes.fromhex("01")),
    ("header 55 AA (matches USB usage 0x55AA)", bytes.fromhex("55aa")),
    ("header AA 55", bytes.fromhex("aa55")),
    ("header A5 5A", bytes.fromhex("a55a")),
]


def now():
    return datetime.now().isoformat(timespec="milliseconds")


async def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    address, send = sys.argv[1], "--send" in sys.argv
    print("MODE:", "SEND" if send else "DRY RUN (nothing is written)")
    for label, data in PLAN:
        print(f"  write to AB01: {data.hex(' ')}   # {label}   then listen {LISTEN_S:.0f}s")
    if not send:
        print("\nDry run only. Re-run with --send to write.")
        return

    log = open(OUT, "w", encoding="utf-8")

    def emit(msg):
        print(msg)
        log.write(msg + "\n")
        log.flush()

    def on_notify(char):
        def cb(_, data):
            emit(f"{now()}  NOTIFY {char[4:8]}  len={len(data)}  {bytes(data).hex(' ')}")
        return cb

    async with BleakClient(address) as client:
        for c in NOTIFY:
            await client.start_notify(c, on_notify(c))
        for label, data in PLAN:
            emit(f"{now()}  WRITE AB01 {data.hex(' ')}  # {label}")
            await client.write_gatt_char(AB01, data, response=True)
            await asyncio.sleep(LISTEN_S)
        emit(f"{now()}  done")
    log.close()


asyncio.run(main())
