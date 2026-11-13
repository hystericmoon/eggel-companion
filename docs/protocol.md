# Eggel Active 3 control protocol

Status: **no control command is decoded yet.** This file records what is known, what has been tried, and what is open. Add each decoded command under "Commands" with its characteristic, byte layout, an example and its effect.

## Device identity

| Item | Value |
|---|---|
| USB | composite device, VID 0x8888, PID 0x1719, serial 20241218 |
| BLE advertised name | "Eggel" (GAP name "Active 3 ble") |
| BLE address | DD:38:68:82:27:D4 |
| BLE manufacturer ID | 2000 (0x07D0) |
| Chip maker | probably MV-SILICON (USB MI_04 manufacturer string) |

The speaker does not advertise over BLE while another device (such as the phone app) holds the connection.

## USB interfaces

- MI_00: USB Audio ("Speaker"); MI_01/MI_02 presumably the audio streaming interfaces.
- MI_03: HID, usage page 0x000C, usage 0x01 (consumer controls: media keys).
- MI_04: HID, usage page 0xFF00, usage 0x55AA (vendor-defined). No report IDs; Input 256 bytes, Output 256 bytes, Feature 8 bytes, all opaque. Silent when idle and during use, so it looks like request/response. **Never written to.** Descriptor: `probe/hid-descriptor.txt`.

## BLE GATT (full dump in `probe/services.txt`)

- Service 0xAB00
  - AB01: write, write-without-response, read
  - AB02, AB03: notify
  - Tried: five tiny writes to AB01 (`00`, `01`, `55AA`, `AA55`, `A55A`). No reply, no visible effect. No notifications ever seen.
- Service 0xFD50 (Tuya BLE UUIDs ending in 07d0): write-without-response, notify, read.

## What the official app does

The Android app (`com.eggel` 2.0.2, APK in `probe/apk`) is built on the Tuya SDK (`com.thingclips`). Its code references 0xFD50 only and never 0xAB00. EQ, rename and TWS therefore very likely use Tuya's encrypted BLE protocol, which needs a per-device key from Tuya's cloud.

Features seen in the app UI:

- 5 EQ presets (Default, Treble Boost, Treble Reducer, Bass Boost, Bass Reducer) plus custom scenes
- 10 EQ bands, 31 Hz to 16 kHz, +/-12 dB
- Volume, battery percentage
- TWS: "Start" opens pairing for 10 s
- Rename device

## Commands

None decoded yet.

<!-- Template:
### <name>
- Transport: BLE / USB HID
- Characteristic or report: <UUID or report>
- Layout: <byte layout>
- Example: `<hex>`
- Effect: <what the speaker does>
-->

## Open questions

1. Is the 0xFD50 traffic Tuya-encrypted, and can the device key be obtained (Tuya cloud account)?
2. Does AB00 carry a separate vendor protocol? Needs a capture of real traffic, not blind writes.
3. Does the USB vendor HID channel (MI_04) accept the same commands as BLE?
4. Can the phone's Bluetooth traffic be captured? The Samsung A55 cannot expose its HCI log without root.

## Safety rules

- Never write to anything that looks like OTA or DFU. Firmware updates are out of scope; a bad update can permanently break the speaker.
- Probe scripts: `probe/probe_hid.py` and `probe/probe_ble.py` are read-only; `probe/probe_ab_write.py` is guarded and dry-run by default.

## Tuya handshake attempts (2026-11-11 to 11-12)
- Local key and UUID obtained from the Tuya cloud project (stored in `probe/tuya.env`, not committed).
- `probe/probe_tuya.py` sends the Tuya BLE device-info request (frame: seq varint, length varint, protocol 2, then flag 4, 16-byte IV, AES-CBC of seq/response-to/code/length/data/CRC16, key = md5 of the first 6 local-key characters). The frame layout and UUIDs match the official SDK's.
- Result: the speaker accepts the writes but sends no notification on 0xFD50 (also subscribed to AB02/AB03). Reading 0xFD50 char 00000003 returns empty. The SDK reads that characteristic first; its code also checks `isPaired`, so the speaker may only answer on a bonded link.
- Open: get a BLE bond from Windows, or capture the phone's traffic.

## BLE bonding attempt (2026-11-13)
- `probe/probe_ble_bond.py` (WinRT custom pairing, ConfirmOnly, no GATT writes) bonds the BLE side from Windows: first attempt returned Paired, `is_paired` is True afterwards (address type 1 = random). bleak's own `pair()` had failed.
- After bonding, `probe_tuya.py` fails earlier than before: `start_notify` on 0xFD50 raises "operation cancelled" then "Unreachable". The Tuya handshake has not been retried successfully on the bonded link. Next: power-cycle the speaker, retry; if still unreachable, unpair (`probe_ble_bond.py unpair`) and compare.
- Retry after a speaker power-cycle (2026-11-13, bonded): connect, read 0003 (empty) and start_notify now succeed, the device-info request (2 packets) is written, and still no notification comes back (8 s timeout). So bonding alone does not make the speaker answer. The frame layout matches the Home Assistant tuya_ble implementation (login key md5(local_key[:6]), flag 4, 20-byte packets, protocol 2), so a wrong frame is less likely than a speaker that ignores the Tuya channel in this state.

## Phone capture decoded (2026-11-13) — the Tuya channel works, the probe was wrong
Full HCI snoop log from the Samsung (Developer options > HCI snoop log = Enabled; `adb bugreport`; file FS/data/log/bt/btsnoop_hci.log) decodes completely with our local key (`probe/decode_cap.py`, redacts the pair frame). The app talks on 0xFD50: writes to handle 0x000f (write-no-response), indications on 0x0011.
Why we got no reply: the phone's device-info request (code 0x0000) carries 2 data bytes, its MTU (`00f3`); we sent none. Also it sends one 36-byte write (MTU 243), not 20-byte fragments. The pair frame (code 0x0001) is uuid(16) + local key(6) + device id padded to 22 + `00 01` = 46 bytes; ours was 44. Reply to device info: version 0.1, protocol 4.4, flags, bound, srand(6) etc. Pair reply data `02`. Then phone sends code 0x0003 (status), speaker answers 0x8011 and 0x0003.
Datapoints (code 0x0027 write, 0x8006 report; dp = id, type, 2-byte length, value; 5-byte header then, in reports, 2 flag bytes `8000` = full report / `0000` = change):
- dp 21 (0x15) enum = EQ preset: 0 Default, 3 Bass Boost seen (others 1, 2, 4 presumably Treble Boost, Treble Reducer, Bass Reducer: unconfirmed)
- dp 20 (0x14) bool = 1 sent together with the preset (meaning unconfirmed, probably "EQ on")
- dp 32 (0x20) raw = device name, UTF-8 (set "Eggel Active 3", " Active 3 Test", "Active 3")
- dp 5 (0x05) value = volume (0x1a, 0x13, 0, 0x0d seen)
- dp 27 (0x1b) value = battery % (100 seen)
- dp 2 (0x02) bool and dp 29 (0x1d) bool: toggled during the TWS/other taps, meaning unconfirmed
- code 0x0060 (empty) is sent by the app now and then: reply is a full 0x8006 report (a refresh).
- Handshake confirmed (2026-11-13, probe_tuya.py with the phone's frames): device info reply (protocol 4.4, bound=1), pair reply `02`, status answers 0x8011 and 0x0003. Reconnecting right after a session fails with "Unreachable" on start_notify until the speaker is power-cycled (it works on the first connect after a power-cycle or radio toggle). The probe also sends 0x0060 to get the full 0x8006 datapoint report (not yet seen live).
