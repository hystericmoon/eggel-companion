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
- Repo: https://github.com/hystericmoon/eggel-companion (made public by the owner; contains the speaker serial and BLE address). gh is installed and logged in as hystericmoon. Latest pushed: see the volume work note below (2026-11-11).
- CI: build.yml passes on both Windows and macOS (run 41971190824 on 82b97ff).
- macOS backend (2026-11-05): `MediaChannel` in app/macos/Runner/MainFlutterWindow.swift (kept in that file to avoid editing the Xcode project). CoreAudio default-output volume ('vmvc'), private MediaRemote for now-playing and transport, media-key events as fallback; `main.dart` uses `ChannelSpeaker` on macOS. Compiles in CI but NOT yet run on a Mac. MediaRemote may be blocked on macOS 15.4+ (title/artist would stay empty).
- Two machines (Windows PC + owner's Mac): git is the only sync. `git pull` before starting, commit and push when stopping; no shared folders. Each machine has its own Flutter toolchain; the Mac needs Flutter and Xcode. Only the Mac can run the macOS build; the speaker probes run on Windows. `.gitattributes` normalises line endings.
- Mac setup (2026-11-05, done): repo cloned to ~/eggel-companion on the owner's MacBook (M2 Pro). Flutter and full Xcode were NOT installed yet; owner is installing Xcode (App Store), then Flutter (`brew install --cask flutter`), then `flutter doctor`, then `cd ~/eggel-companion/app && flutter run -d macos`. Owner has no speaker with them, so test volume, play/pause/skip and title/artist on any output.
- macOS first run (2026-11-05): Flutter 3.47.9, Xcode 27.2 and CocoaPods installed on the Mac (macOS 27.2); `flutter run -d macos` builds and launches. Result: play/pause did NOT work and artist did not show. Likely cause (unconfirmed): MediaRemote is restricted on macOS 27, `MRMediaRemoteSendCommand` returns true but does nothing (so the media-key fallback never ran), and the app sandbox probably blocks posted media keys too. Fix pushed in 90c8c90 and 18989a9 (CI green, NOT yet run on the Mac): transport and title/artist/playing now go to Music or Spotify through AppleScript (only if running; never launches them), via the temporary-exception Apple-events entitlement for com.apple.Music and com.spotify.client plus NSAppleEventsUsageDescription; other apps fall back to a media key, which may still do nothing. Browsers and other players show no title/artist on macOS. Volume was not reported on yet.
- Local-only files (gitignored, ~470 MB, exist only on the Windows PC): probe/apk, probe/bugreport, probe/dumpstate2, probe/bugreport.zip, probe/btsnoop_*, probe/scan.txt.
- docs/protocol.md exists: findings and open questions only, no decoded commands.
- Volume work (2026-11-11, Windows, tested by ear by the owner): the speaker over USB-C is "Speakers (Speaker)" and is audible from 0.5% system volume; over Bluetooth it is "Headphones (Active 3)" and is silent below 5.5%. `app/lib/speaker/volume_floor.dart` maps each output's audible floor to the bottom of a shown 0..100 scale (0 silent, 1 = just audible), geometric so each step is a similar loudness change (a linear scale made USB 5 ~10x louder than 1). `ChannelSpeaker` carries the shown level across output switches (USB <-> Bluetooth). Home page has a slider (linear) plus a - / readout / + stepper in fives (0, 5 ... 100). Latest pushed: 98a00f5. Analyze and 14 tests pass; the geometric scale was NOT yet re-checked by ear. Floors are hard-coded by device-name match; other outputs have no floor.
- Quiet range (2026-11-11, f6c5b77, Windows, NOT yet checked by ear): option B built. Below the output's floor the speaker's own volume stays at its floor and every other app's session volume is lowered (ISimpleAudioVolume in media_channel.cpp; plan/inverse in volume_floor.dart). Shown 1 = 0.5% effective on both outputs (`kQuietestPercent`); apps started later are brought down on the next 1 s poll. Android and unknown outputs stay linear.
- Tuya (2026-11-11): the owner made a Tuya cloud project `eggel-companion` (Singapore data center) and linked their Smart Life account; the speaker, paired in Smart Life (not the Eggel app), shows as device `a35e90latxsdh0hs` (product `4xohjxi5`, model B1, category loudspeaker_box). The local key and UUID are in probe/tuya.env (gitignored, never commit or print). probe/probe_tuya.py does the Tuya BLE handshake (device info, pair, status query; read-only) and logs to probe/tuya-log.txt. First run found no speaker: it must be on, with phone Bluetooth off and no other connection. The protocol code is from memory of the Tuya BLE format and is UNTESTED. The speaker may now be offline in the Eggel app until re-paired there.
- Design (2026-11-11): canvas https://claude.ai/artifact/XV683sJWnE9sBhUpSP92p4 (private) holds three directions (Dial, Studio, Soft), the mixed all-features design, a futuristic pass (aurora glow, glass cards, glowing accent) for Home, Sound, Tools, Speaker, desktop window and tray popup, and five color themes (Ember, Aqua, Violet, Mint, Rose). Feature split: works now = connection, now playing, transport, volume, USB/Bluetooth tag; needs the speaker link = EQ, battery, TWS, rename, auto power-off, voice prompts; app-only = sleep timer, alarm, megaphone, schedules, scenes. Looks borrowed from React Bits, shadcn/ui and Aceternity (web libraries), rebuilt natively; no UI packages added.
- Home built (2026-11-11, bafb315): lib/ui/home_page.dart, theme/palette.dart (ThemeController, in memory only, resets on restart), widgets/glass.dart, volume_ring.dart, visualizer.dart (decoration, not real audio). Scene chips and battery were left out (no backend); no tab bar until more screens exist. Analyze clean, 18 tests pass, Windows debug build runs; not yet looked at by the owner on screen.
- Curve retune (2026-11-11 night): the owner heard almost nothing at shown 40 on Bluetooth (pure geometric put 40 at ~4%, just under the 5.5% floor). `kShape = 0.55` in volume_floor.dart now bends the scale: shown 1 ~0.76%, 5 ~1.4%, 40 ~12%, 50 ~19% (USB floor). Not yet heard; tune `kShape` by ear (lower = louder middle, 1 = old geometric).
- Tuya probe result (2026-11-11 night): probe_tuya.py now finds and connects to the speaker (it advertises when free) and sends the device-info and pair writes, but the speaker sends NO notification back (raw notifies are logged). Windows bonding (`client.pair()`) fails and drops the link, so it was removed. Next ideas: check the 0xFD50 notify descriptor is really enabled, try the AB00 service again alongside, compare against the Smart Life app's own traffic, or confirm the Tuya BLE frame layout from the com.eggel APK (probe/apk, Windows PC only).
- Tuya APK check (2026-11-12): com.eggel's SDK (obfuscated; dexdump of probe/apk/classes6.dex) matches our frame layout and UUIDs. After service discovery it READS char 00000003 of 0xFD50 first (ours returns empty), and its code paths mention isPaired / 'HID and BT' connect stats, so the speaker may only answer the Tuya handshake on a bonded (system-paired) BLE link. Probe now reads 0003 and subscribes AB02/AB03: still no reply. Next ideas: get Windows to bond over BLE, or capture the phone's traffic.
- Shell and screens (2026-11-11 night): lib/ui/shell.dart has a four-tab bar (Home, Sound, Tools, Speaker). Tools works without the speaker: a sleep timer that pauses playback and a volume cap (`ToolsController` and `CappedSpeaker` in lib/tools/tools_controller.dart; the cap wraps the speaker in main.dart). Speaker shows real status and says battery, rename, TWS, auto power-off and voice prompts need the speaker link; it also holds the app color picker. Sound is a preview frame (flat 10-band `EqCurve`, locked note) until the protocol works. Alarm, megaphone, night schedule, find my speaker, desktop sidebar layout and tray popup are not built. 22 tests pass; Windows debug build OK; not yet looked at by the owner.
- Open items (2026-11-12): (1) owner checks the retuned volume scale by ear (40 clearly audible on Bluetooth, 1 to 5 quiet and steady; tune `kShape` if not); the + button fix (e56ce1c) was confirmed good; (2) Tuya handshake: speaker still silent, likely needs a bonded BLE link (see APK check note and docs/protocol.md); next try BLE bonding from Windows or capture phone traffic; EQ, battery, rename, TWS wait on it; (3) built since: alarm and night schedule (in-app, only while the app is open), desktop sidebar (width 760+), settings saved to a JSON file (theme, alarm, night, cap; lib/settings/settings_store.dart, no plugin because plugins need Windows Developer Mode, which is OFF); Find my speaker and Megaphone are placeholder cards; (4) not built: tray popup (needs a tray plugin, so Developer Mode), real EQ; (5) owner re-tests macOS after `git pull` (Music or Spotify: volume, play/pause/skip, title/artist; also that settings.json appears in ~/Library/Application Support/EggelCompanion); Android settings path (MainActivity 'storageDir') untested.
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
- Speaker link (2026-11-13, Windows, confirmed working by the owner): the Tuya handshake needed the phone's exact frames, found by decoding a full HCI snoop log from the phone (Developer options > HCI snoop log = Enabled, then `adb bugreport`; decoder probe/decode_cap.py, decoded datapoints in docs/protocol.md). App code: app/lib/link/ (tuya_protocol.dart, ble_link.dart, speaker_link.dart) plus app/windows/runner/ble_channel.cpp ("eggel/ble", Dart polls for events). Credentials live in %APPDATA%\EggelCompany\settings.json key `tuya` (uuid, deviceId, localKey; copied from probe/tuya.env; never commit). Live: battery, EQ presets (Bass boost = 3, Default = 0 confirmed; Treble boost 1, Treble reducer 2, Bass reducer 4 are guesses). Windows reconnects right after a session often fail ("Unreachable") until the speaker is power-cycled. Not built: rename (dp 32 raw UTF-8), volume dp 5, custom 10-band EQ, TWS (dp 2 and 29 unidentified), Android and macOS bridges, a UI to enter the Tuya key. Note: `dart format` reformatted several unrelated files in f28172b.
