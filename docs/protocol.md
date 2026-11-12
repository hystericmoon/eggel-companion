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
