# Eggel Active 3 Companion App

## Goal
A new companion app for the Eggel Active 3 Bluetooth speaker, running on Android, Windows and macOS.
The official Eggel app is iPhone-only and closed source, so this is a new app, not a modification.

## Speaker facts (from eggeltech.com/products/eggelactive-3)
- Bluetooth 5.3, 10 m range
- TWS: two Active 3 speakers can play in stereo from one source
- USB-C wired audio input; IP67; 4500 mAh battery (~10 h at 50% volume)
- Official app features for this model: EQ (5 presets plus custom), TWS settings, rename device
- Chipset: not published. The control protocol is unknown.

## Findings
- USB (2026-11-04): speaker enumerates as composite device VID 0x8888, PID 0x1719, serial 20241218
  - MI_00: USB Audio ("Speaker"); MI_01/MI_02 presumably the audio streaming interfaces
  - MI_03: HID, usage page 0x000C usage 0x01 = consumer controls (media keys)
  - MI_04: HID, usage page 0xFF00 usage 0x55AA = vendor-defined channel. Prime candidate for EQ/TWS/name control over USB
  - VID 0x8888 does not identify the chip maker
- Python 3.12 is installed at C:\Users\Hosni\AppData\Local\Programs\Python\Python312\python.exe (not on PATH); hidapi installed
- USB MI_04 (2026-11-05): manufacturer string "MV-SILICON" (likely the chip maker). Descriptor (probe/hid-descriptor.txt): no report IDs; Input 256 bytes, Output 256 bytes, Feature 8 bytes, all opaque. Silent when idle and during use: looks like request/response. Never written to.
- BLE (2026-11-05): advertises as "Eggel" (GAP name "Active 3 ble") at DD:38:68:82:27:D4, with service 0xFD50 and manufacturer ID 2000 (0x07D0). It does NOT advertise while another device (phone app) holds the connection. GATT in probe/services.txt:
  - 0xAB00: AB01 (write, write-no-response, read), AB02 and AB03 (notify). No notifications seen; 5 tiny test writes to AB01 (00, 01, 55AA, AA55, A55A) got no reply and no visible effect.
  - 0xFD50 (Tuya BLE UUIDs ending 07d0): write-no-response, notify, read.
- Official app: Android package com.eggel 2.0.2 (APK in probe/apk). Built on the Tuya SDK (com.thingclips); its code references FD50 only, never AB00. So EQ/rename/TWS very likely use Tuya's encrypted BLE protocol, which needs a per-device key from Tuya's cloud.
- The speaker has no physical EQ button. Phone is a Samsung A55: its full Bluetooth HCI log is not readable without root (probe/bugreport has only advertisement summaries).
- App UI (screenshots): 5 EQ presets (Default, Treble Boost, Treble Reducer, Bass Boost, Bass Reducer) plus custom scenes; 10 bands (31 Hz to 16 kHz), +/-12 dB; volume shown 0-?; battery %; TWS "Start" opens pairing for 10 s.
- Open decision: pursue the Tuya cloud-key route, or build only what works without it (media keys, volume).
- App (2026-11-05): Flutter 3.47.9 installed at C:\dev\flutter (not on PATH; add C:\dev\flutter\bin per session). Project in app/ (android, windows, macos). Layout A (player first) built against a `Speaker` interface with a `FakeSpeaker`; `flutter analyze` clean, 4 tests pass. No real speaker backend yet. Toolchain: VS Build Tools 2022 (C++ workload) installed; Windows debug build works (app/build/windows/x64/runner/Debug/eggel_companion.exe). Android: JDK 17 at C:\dev\jdk17, SDK at C:\dev\android-sdk (platform 36, build-tools 36.0.0), Flutter configured for both; 7 Android licences still need the user to run `flutter doctor --android-licenses` before an Android build. Set JAVA_HOME=C:\dev\jdk17 in new shells.
- Android backend (2026-11-05): `AndroidSpeaker` (app/lib/speaker/android_speaker.dart) + Kotlin bridge in MainActivity.kt (channel "eggel/media"). Controls the phone's media sessions and media volume; "connected" = a Bluetooth audio output exists. Needs notification-listener access (MediaListenerService) to read title/artist; without it, falls back to plain media-key events and an in-app banner asks for access. Verified on the Samsung with the speaker connected (2026-11-05): connection status, now-playing, play/pause, skip and volume all work. Windows (2026-11-05): same channel in C++ (app/windows/runner/media_channel.cpp): WASAPI default-output volume (full float precision) + SMTC for now-playing/play/pause/skip, falling back to media keys. Both platforms use `ChannelSpeaker`; Windows uses a cubic slider (`volume_curve.dart`) so quiet levels get fine steps. Verified: launches, reads the default output name and the browser's track. Not yet tested against the Eggel as the default output, and the speaker's own quietest step may still be loud (see owner note below). macOS still uses FakeSpeaker.
- Owner note: even the lowest volume step is very loud on every device and app (owner works around it with the browser/YouTube volume at minimum). A finer slider cannot go below the speaker's lowest hardware step; the real fix would be digital attenuation (per-app session volume via ISimpleAudioVolume on Windows). Not built.
- Probe scripts in probe/: probe_hid.py, probe_ble.py (read-only), probe_ab_write.py (guarded, dry run by default).

## Resume here (2026-11-05)
- Repo: https://github.com/hystericmoon/eggel-companion (made public by the owner; contains the speaker serial and BLE address). gh is installed and logged in as hystericmoon. Latest pushed: 3c534f8 (2026-11-05).
- CI: build.yml passes on both Windows and macOS (run 41971190824 on 82b97ff).
- macOS backend (2026-11-05): `MediaChannel` in app/macos/Runner/MainFlutterWindow.swift (kept in that file to avoid editing the Xcode project). CoreAudio default-output volume ('vmvc'), private MediaRemote for now-playing and transport, media-key events as fallback; `main.dart` uses `ChannelSpeaker` on macOS. Compiles in CI but NOT yet run on a Mac. MediaRemote may be blocked on macOS 15.4+ (title/artist would stay empty).
- docs/protocol.md exists: findings and open questions only, no decoded commands.
- Open items: (1) owner's quiet-end test with the Eggel as Windows default output; (2) per-app volume "extra quiet" mode, only if (1) shows it's needed; (3) decide the Tuya cloud-key route for EQ/rename/TWS/battery (needs the owner to create a Tuya cloud account), else stay a media and volume controller; (4) owner to test the macOS build on their Mac (any output works; only the speaker name needs the Eggel): volume, play/pause/skip, title/artist.
- Shell setup for builds: PATH needs C:\dev\flutter\bin and "C:\Program Files\GitHub CLI"; set JAVA_HOME=C:\dev\jdk17 and ANDROID_HOME=C:\dev\android-sdk. Phone adb serial RRCX5049JQF; the app installs as com.eggelcompanion.eggel_companion.

## Decisions so far
- Framework: Flutter (one codebase for Android, Windows and macOS)
- BLE plugin: a cross-platform one that covers Android, Windows and macOS (evaluate `universal_ble`)
- If the speaker uses classic Bluetooth serial (SPP) instead of BLE, Android gets it via a plugin and desktop needs a small native bridge
- Do not implement firmware (OTA) updates: a bad update can permanently break the speaker
- Windows and macOS release builds go through GitHub Actions

## Phase 1: protocol probe (do this first)
Find out how the official app controls the speaker.
0. USB check (speaker plugged into the PC over USB-C): list its USB vendor ID, product ID and interfaces (audio, HID, vendor-specific). The vendor ID often names the Bluetooth chip maker, and a HID or vendor interface may accept the same EQ commands as Bluetooth. Save to `probe/usb.txt`. Unplug the cable before the BLE scan, since USB audio mode may turn Bluetooth off.
1. On this Windows PC, write a Python probe using `bleak`:
   - scan for nearby BLE devices and find the Active 3 (name likely contains "Eggel" or "Active")
   - connect and list every GATT service and characteristic, with properties (read, write, notify)
   - read every readable characteristic and subscribe to every notify characteristic, logging bytes as hex with timestamps
   - save output to `probe/services.txt` and `probe/notify-log.txt`
2. If no vendor BLE service shows up, check whether the speaker exposes classic SPP (RFCOMM) instead.
3. If an iPhone and Mac are available: capture the official app's traffic with Apple's Bluetooth logging profile and PacketLogger while changing EQ presets, toggling TWS and renaming. Match the writes to each action.
4. Without an iPhone: try writing small test values to writable vendor characteristics and listen for responses. Never write to anything that looks like OTA or DFU.
5. Record every decoded command in `docs/protocol.md`: characteristic UUID, byte layout, example, effect.

## Phase 2: v1 app
- Connect, auto-reconnect, battery level, now playing, volume
- EQ presets plus custom bands
- Rename speaker, TWS on/off
- Sleep timer, saved EQ profiles
- Tests use a fake speaker that implements `docs/protocol.md`

## Phase 3: features competitors have that Eggel lacks
- Alarm that plays through the speaker (Android)
- Megaphone (phone mic to speaker)
- Desktop tray control, Android home-screen widget
- TWS stereo pair with L/R swap

## Owner context
- Product designer; works on Windows with the Claude Code desktop app
- Wants design decisions shown visually (before/after mockups, options drawn as UI), with a short summary in chat
