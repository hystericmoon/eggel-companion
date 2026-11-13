"""Try to bond (system-pair) the speaker's BLE side on Windows.

Uses WinRT custom pairing so no Settings dialog is needed. It only pairs; it
writes nothing to the speaker's GATT. Run with the speaker on and free:
    python -I probe/probe_ble_bond.py [unpair]
"""
import asyncio
import sys

from bleak import BleakScanner
from winrt.windows.devices.bluetooth import BluetoothLEDevice
from winrt.windows.devices.enumeration import (
    DevicePairingKinds,
    DevicePairingProtectionLevel,
)

SERVICE = "0000fd50-0000-1000-8000-00805f9b34fb"


async def main():
    dev = await BleakScanner.find_device_by_filter(
        lambda d, ad: SERVICE in [u.lower() for u in ad.service_uuids], timeout=15
    )
    if not dev:
        print("speaker not found (must be on and free)")
        return 1
    print("found", dev.name, dev.address)
    addr = int(dev.address.replace(":", ""), 16)
    le = await BluetoothLEDevice.from_bluetooth_address_async(addr)
    info = le.device_information
    print("address type:", le.bluetooth_address_type, "paired:", info.pairing.is_paired)
    if len(sys.argv) > 1 and sys.argv[1] == "unpair":
        r = await info.pairing.unpair_async()
        print("unpair:", r.status)
        return 0
    if info.pairing.is_paired:
        print("already paired")
        return 0
    custom = info.pairing.custom

    def on_req(_sender, args):
        print("pairing requested, kind:", args.pairing_kind, "pin:", getattr(args, "pin", ""))
        args.accept()

    custom.add_pairing_requested(on_req)
    kinds = (
        DevicePairingKinds.CONFIRM_ONLY
        | DevicePairingKinds.CONFIRM_PIN_MATCH
        | DevicePairingKinds.DISPLAY_PIN
    )
    for level in (DevicePairingProtectionLevel.NONE, DevicePairingProtectionLevel.ENCRYPTION):
        r = await custom.pair_async(kinds, level)
        print("pair level", level, "->", r.status, "protection", r.protection_level_used)
        if info.pairing.is_paired:
            break
    print("paired now:", info.pairing.is_paired)
    return 0


sys.exit(asyncio.run(main()))
