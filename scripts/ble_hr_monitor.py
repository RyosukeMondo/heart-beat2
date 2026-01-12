#!/usr/bin/env python3
"""
BLE Heart Rate Monitor for Heart Beat
Reliable real-time heart rate monitoring using bleak library.
"""

import asyncio
import sys
from datetime import datetime

try:
    from bleak import BleakClient, BleakScanner
except ImportError:
    print("Error: bleak not installed. Run: pip install bleak")
    sys.exit(1)

# Heart Rate Service and Characteristic UUIDs
HR_SERVICE_UUID = "0000180d-0000-1000-8000-00805f9b34fb"
HR_MEASUREMENT_UUID = "00002a37-0000-1000-8000-00805f9b34fb"
BATTERY_SERVICE_UUID = "0000180f-0000-1000-8000-00805f9b34fb"
BATTERY_LEVEL_UUID = "00002a19-0000-1000-8000-00805f9b34fb"


def parse_heart_rate(data: bytearray) -> dict:
    """Parse heart rate measurement data according to BLE HR spec."""
    if len(data) < 2:
        return {"bpm": 0, "rr_intervals": []}

    flags = data[0]
    hr_format = flags & 0x01  # 0 = UINT8, 1 = UINT16
    rr_present = (flags >> 4) & 0x01

    if hr_format == 0:
        bpm = data[1]
        offset = 2
    else:
        bpm = data[1] | (data[2] << 8)
        offset = 3

    rr_intervals = []
    if rr_present:
        while offset + 1 < len(data):
            rr = (data[offset] | (data[offset + 1] << 8)) / 1024.0 * 1000  # Convert to ms
            rr_intervals.append(rr)
            offset += 2

    return {"bpm": bpm, "rr_intervals": rr_intervals}


def hr_callback(sender, data):
    """Callback for heart rate notifications."""
    result = parse_heart_rate(data)
    timestamp = datetime.now().strftime("%H:%M:%S")
    bpm = result["bpm"]

    if 30 < bpm < 220:
        rr_str = ""
        if result["rr_intervals"]:
            rr_str = f"  RR: {result['rr_intervals'][0]:.0f}ms"
        print(f"{timestamp}    {bpm:3d} BPM{rr_str}")
    else:
        print(f"{timestamp}    --- (invalid: {bpm})")


async def scan_for_device(name_filter: str = None, mac_filter: str = None, timeout: float = 10.0):
    """Scan for BLE devices and return matching device."""
    print(f"Scanning for devices ({timeout}s)...")

    devices = await BleakScanner.discover(timeout=timeout)

    for device in devices:
        device_name = device.name or ""
        device_addr = device.address.upper()

        if mac_filter and device_addr == mac_filter.upper():
            return device
        if name_filter and name_filter.lower() in device_name.lower():
            return device

    return None


async def monitor_heart_rate(address: str):
    """Connect to device and monitor heart rate."""
    print(f"\nConnecting to {address}...")

    async with BleakClient(address) as client:
        if not client.is_connected:
            print("Failed to connect!")
            return

        print("Connected!")

        # Try to read battery level
        try:
            battery_data = await client.read_gatt_char(BATTERY_LEVEL_UUID)
            battery = battery_data[0]
            print(f"Battery: {battery}%")
        except Exception:
            print("Battery: N/A")

        print("\n" + "=" * 40)
        print("  Real-time Heart Rate")
        print("=" * 40)
        print("\nTimestamp      BPM")
        print("-" * 40)

        # Subscribe to heart rate notifications
        await client.start_notify(HR_MEASUREMENT_UUID, hr_callback)

        # Keep running until Ctrl+C
        try:
            while client.is_connected:
                await asyncio.sleep(1)
        except asyncio.CancelledError:
            pass

        await client.stop_notify(HR_MEASUREMENT_UUID)
        print("\nDisconnected.")


async def main():
    """Main entry point."""
    # Default device MAC (Coospo HW9)
    device_mac = "F4:8C:C9:1B:E6:1B"
    device_name = "HW9"

    # Parse command line args
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if ":" in arg:
            device_mac = arg
        else:
            device_name = arg

    print("=" * 40)
    print("  Heart Beat BLE Monitor")
    print("=" * 40)
    print(f"\nTarget: {device_name} ({device_mac})")
    print("\nMake sure:")
    print("  1. Heart rate strap is wet and worn")
    print("  2. Device LED is blinking")
    print("\nPress Ctrl+C to stop\n")

    # Scan for device first
    device = await scan_for_device(name_filter=device_name, mac_filter=device_mac)

    if not device:
        print(f"\nDevice not found!")
        print("Make sure the strap is worn and the device is advertising.")
        return 1

    print(f"Found: {device.name} ({device.address})")

    # Monitor heart rate
    await monitor_heart_rate(device.address)
    return 0


if __name__ == "__main__":
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\nStopped by user.")
        sys.exit(0)
