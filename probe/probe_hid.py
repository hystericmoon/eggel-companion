"""Passive probe of the Eggel Active 3 vendor HID interface (MI_04).

READ-ONLY: reads the report descriptor and logs input reports. It never calls
write(), send_feature_report() or get_feature_report().

Run with: python probe/probe_hid.py [seconds]   (default 30)
Output:   probe/hid-descriptor.txt, probe/hid-input-log.txt
"""
import sys
import time
from datetime import datetime
from pathlib import Path

import hid

VID, PID = 0x8888, 0x1719
USAGE_PAGE, USAGE = 0xFF00, 0x55AA
OUT = Path(__file__).parent

# --- minimal HID report descriptor decoder -------------------------------
MAIN = {0x8: "Input", 0x9: "Output", 0xB: "Feature", 0xA: "Collection", 0xC: "End Collection"}
GLOBAL = {0x0: "Usage Page", 0x1: "Logical Min", 0x2: "Logical Max", 0x3: "Physical Min",
          0x4: "Physical Max", 0x5: "Unit Exponent", 0x6: "Unit", 0x7: "Report Size",
          0x8: "Report ID", 0x9: "Report Count", 0xA: "Push", 0xB: "Pop"}
LOCAL = {0x0: "Usage", 0x1: "Usage Min", 0x2: "Usage Max"}


def decode(desc):
    """Return (text lines, summary of reports) for a raw descriptor."""
    lines, i, depth = [], 0, 0
    g = {"size": 0, "count": 0, "id": 0}
    stack = []
    bits = {}  # (kind, report_id) -> total bits
    while i < len(desc):
        b = desc[i]
        size = {0: 0, 1: 1, 2: 2, 3: 4}[b & 3]
        typ, tag = (b >> 2) & 3, b >> 4
        data = int.from_bytes(desc[i + 1:i + 1 + size], "little")
        raw = " ".join(f"{x:02X}" for x in desc[i:i + 1 + size])
        i += 1 + size
        if typ == 0:
            name = MAIN.get(tag, f"Main?{tag:X}")
            if name == "End Collection":
                depth -= 1
            extra = ""
            if name in ("Input", "Output", "Feature"):
                kind = name
                bits[(kind, g["id"])] = bits.get((kind, g["id"]), 0) + g["size"] * g["count"]
                extra = f" (0x{data:02X}: {'Const' if data & 1 else 'Data'},{'Var' if data & 2 else 'Array'})"
            lines.append(f"{'  ' * max(depth, 0)}{raw:<14} {name}{extra}")
            if name == "Collection":
                depth += 1
        elif typ == 1:
            name = GLOBAL.get(tag, f"Global?{tag:X}")
            if name == "Report Size": g["size"] = data
            elif name == "Report Count": g["count"] = data
            elif name == "Report ID": g["id"] = data
            elif name == "Push": stack.append(dict(g))
            elif name == "Pop": g = stack.pop()
            lines.append(f"{'  ' * depth}{raw:<14} {name} = 0x{data:X} ({data})")
        elif typ == 2:
            name = LOCAL.get(tag, f"Local?{tag:X}")
            lines.append(f"{'  ' * depth}{raw:<14} {name} = 0x{data:X}")
        else:
            lines.append(f"{raw:<14} Long/reserved item")
    return lines, bits


def main():
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 30
    cands = [d for d in hid.enumerate(VID, PID)
             if d["usage_page"] == USAGE_PAGE and d["usage"] == USAGE]
    if not cands:
        sys.exit("MI_04 (usage page 0xFF00 / usage 0x55AA) not found. Is the speaker plugged in over USB-C?")
    info = cands[0]
    print("Opening", info["path"])

    dev = hid.device()
    dev.open_path(info["path"])
    try:
        print("Manufacturer:", dev.get_manufacturer_string())
        print("Product:     ", dev.get_product_string())

        desc = bytes(dev.get_report_descriptor())
        lines, bits = decode(desc)
        report = [f"Path: {info['path']!r}",
                  f"Descriptor length: {len(desc)} bytes",
                  "Raw: " + desc.hex(" "), "", *lines, "", "Report sizes (data bytes, excl. ID byte):"]
        for (kind, rid), n in sorted(bits.items()):
            report.append(f"  {kind:<8} report ID {rid}: {n} bits = {(n + 7) // 8} bytes")
        text = "\n".join(report)
        (OUT / "hid-descriptor.txt").write_text(text, encoding="utf-8")
        print(text)

        dev.set_nonblocking(True)
        print(f"\nListening passively for {seconds:.0f}s (no writes)...")
        t0 = time.time()
        n = 0
        with open(OUT / "hid-input-log.txt", "w", encoding="utf-8") as log:
            log.write(f"# MI_04 input log, started {datetime.now().isoformat()}\n")
            while time.time() - t0 < seconds:
                data = dev.read(256)
                if data:
                    n += 1
                    line = f"{datetime.now().isoformat(timespec='milliseconds')}  len={len(data)}  {bytes(data).hex(' ')}"
                    print(line)
                    log.write(line + "\n")
                    log.flush()
                else:
                    time.sleep(0.005)
            log.write(f"# done, {n} reports\n")
        print(f"Done. {n} input reports received.")
    finally:
        dev.close()


if __name__ == "__main__":
    main()
