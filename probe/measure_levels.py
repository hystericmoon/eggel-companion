"""Measure how loud each Windows output is at each endpoint volume.

Keeps one continuous pink-noise stream playing through one output, steps the
Windows volume of that output, and records the PC microphone array at each
step. The level (dB) per step is written to probe/levels-<usb|bt>.json.

  python measure_levels.py usb      (speaker plugged in over USB-C)
  python measure_levels.py bt       (speaker connected over Bluetooth)
  python measure_levels.py bt 20    (stop at 20 %)

The source is -20 dBFS up to 13 % and -40 dBFS above, so the microphone does
not clip; the 20 dB is added back. Restores the original Windows volume.
Close the Eggel app first (it changes per-app volumes).
"""
import json
import sys
import time

import numpy as np
import sounddevice as sd
from comtypes import CLSCTX_ALL
from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume

OUT = {"usb": "Speakers (Speaker)", "bt": "Headphones (Active 3)"}
STEPS = [1, 2, 3, 4, 5, 6, 8, 10, 13, 16, 20, 25, 30, 38, 46, 55, 65, 75, 87, 100]
MIC_HINT = "Microphone Array (Realtek"
SWITCH_AT = 13  # steps above this use the quieter source


def endpoint(name):
    for d in AudioUtilities.GetAllDevices():
        if name.lower() in (d.FriendlyName or "").lower():
            if getattr(d.state, "name", "Active") != "Active":
                continue
            iface = d._dev.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
            return d.FriendlyName, iface.QueryInterface(IAudioEndpointVolume)
    raise SystemExit(f"output not found (is it connected?): {name}")


def find(kind, hint):
    wasapi = next(i for i, a in enumerate(sd.query_hostapis()) if "WASAPI" in a["name"])
    for i, d in enumerate(sd.query_devices()):
        if hint.lower() in d["name"].lower() and d["hostapi"] == wasapi and d["max_%s_channels" % kind] > 0:
            return i
    raise SystemExit(f"{kind} device not found: {hint}")


def pink(n, seed=1):
    spec = np.fft.rfft(np.random.default_rng(seed).standard_normal(n))
    out = np.fft.irfft(spec / np.sqrt(np.maximum(np.arange(len(spec)), 1)), n)
    return (out / np.max(np.abs(out))).astype("float32")


def level_db(x):
    x = x - np.mean(x)
    return float(20 * np.log10(np.sqrt(np.mean(x**2)) + 1e-12))


def main():
    which = sys.argv[1]
    top = float(sys.argv[2]) if len(sys.argv) > 2 else 100
    name, vol = endpoint(OUT[which])
    out_i, mic_i = find("output", OUT[which]), find("input", MIC_HINT)
    out_rate = int(sd.query_devices(out_i)["default_samplerate"])
    mic_rate = int(sd.query_devices(mic_i)["default_samplerate"])
    print("output:", name, "| rates", out_rate, mic_rate)

    loop = pink(out_rate * 4)  # 4 s of noise, repeated
    state = {"amp": 0.1, "pos": 0}

    def play_cb(outdata, frames, t, status):
        idx = (state["pos"] + np.arange(frames)) % len(loop)
        outdata[:, 0] = outdata[:, 1] = loop[idx] * state["amp"]
        state["pos"] += frames

    chunks = []

    def rec_cb(indata, frames, t, status):
        chunks.append(indata[:, 0].copy())

    def grab(seconds):
        chunks.clear()
        time.sleep(seconds)
        return np.concatenate(chunks)

    original = vol.GetMasterVolumeLevelScalar()
    results = []
    try:
        vol.SetMute(0, None)
        vol.SetMasterVolumeLevelScalar(0.0, None)
        with sd.InputStream(device=mic_i, samplerate=mic_rate, channels=1, callback=rec_cb):
            with sd.OutputStream(device=out_i, samplerate=out_rate, channels=2, callback=play_cb):
                time.sleep(3.0)  # let the output stream wake up
                floor = level_db(grab(1.5))
                print(f"room noise {floor:.1f} dB")
                for s in [v for v in STEPS if v <= top]:
                    vol.SetMasterVolumeLevelScalar(s / 100, None)
                    add = 0.0
                    state["amp"] = 0.1
                    if s > SWITCH_AT:
                        state["amp"], add = 0.01, 20.0
                    time.sleep(2.0)  # let the volume (and Bluetooth sync) settle
                    a = level_db(grab(1.0)) + add
                    b = level_db(grab(1.0)) + add
                    db = (a + b) / 2
                    print(f"{s:>4}%  {db:7.1f} dB   (readings {a:.1f}, {b:.1f})")
                    results.append({"percent": s, "db": db, "a": a, "b": b})
    finally:
        vol.SetMasterVolumeLevelScalar(original, None)
    path = f"C:/Projects/eggel-companion/probe/levels-{which}.json"
    json.dump({"floor": floor, "results": results}, open(path, "w"), indent=1)
    print("saved", path)


main()
