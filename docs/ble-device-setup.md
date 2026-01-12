# BLE Heart Rate Monitor Setup Guide

This document covers BLE (Bluetooth Low Energy) heart rate monitor setup on Linux, including device pairing, troubleshooting, and technical specifications discovered during development.

## Supported Devices

### Coospo HW9

| Property | Value |
|----------|-------|
| Name | HW9 49268 |
| MAC Address | F4:8C:C9:1B:E6:1B |
| Address Type | Random |
| Protocol | Bluetooth Low Energy (BLE) |
| Services | Heart Rate, Battery, Device Info |

## Quick Start

```bash
# 1. One-time setup (install BLE packages)
sudo ./scripts/ble-setup.sh

# 2. Pair with your heart rate monitor
./scripts/ble-pair.sh

# 3. Monitor real-time heart rate
./scripts/ble-realtime.sh
```

## Scripts Overview

| Script | Purpose | Requires sudo |
|--------|---------|---------------|
| `scripts/ble-setup.sh` | Install BLE packages, configure permissions | Yes |
| `scripts/ble-pair.sh` | Scan and pair with HR monitors | No |
| `scripts/ble-realtime.sh` | Real-time heart rate monitoring | No |
| `scripts/ble_hr_monitor.py` | Python-based monitor (used internally) | No |

## Monitoring Options

### Option 1: Shell Script (Recommended)

```bash
./scripts/ble-realtime.sh
```

Automatically selects the best available method:
1. **Python/bleak** - Most reliable, includes RR intervals
2. **Bash/gatttool** - Fallback using BlueZ tools

### Option 2: Rust CLI (Most Features)

```bash
cd rust

# Scan for devices
./target/release/cli devices scan

# Connect (use device ID from scan output)
./target/release/cli devices connect hci0/dev_F4_8C_C9_1B_E6_1B
```

Features:
- Raw and filtered BPM
- RMSSD (Heart Rate Variability)
- Battery level
- Signal quality indicators

### Option 3: Python Script Directly

```bash
./scripts/.venv/bin/python ./scripts/ble_hr_monitor.py F4:8C:C9:1B:E6:1B
```

## Technical Specifications

### BLE Services and Characteristics

| Service | UUID | Description |
|---------|------|-------------|
| Heart Rate | `0000180d-0000-1000-8000-00805f9b34fb` | Heart rate measurements |
| Battery | `0000180f-0000-1000-8000-00805f9b34fb` | Battery level |
| Device Info | `0000180a-0000-1000-8000-00805f9b34fb` | Manufacturer, model, etc. |

### GATT Handles (Coospo HW9)

| Handle | UUID | Description |
|--------|------|-------------|
| 0x0029 | 2a37 | Heart Rate Measurement (notify) |
| 0x002a | 2902 | CCCD (enable notifications) |
| 0x0018 | 2a19 | Battery Level |

### Heart Rate Measurement Format

The Heart Rate Measurement characteristic (0x2A37) uses the following format:

```
Byte 0: Flags
  Bit 0: HR Value Format (0=UINT8, 1=UINT16)
  Bit 4: RR-Interval present

Byte 1 (or 1-2): Heart Rate Value (BPM)

Remaining bytes: RR-Intervals (if present)
  - Each RR interval is 2 bytes (UINT16)
  - Unit: 1/1024 seconds
  - Convert to ms: value * 1000 / 1024
```

Example parsing:
```
00 63          -> Flags=0x00, HR=99 BPM (0x63), no RR
10 52 de 02    -> Flags=0x10 (RR present), HR=82 BPM, RR=734ms
```

## Linux BLE Requirements

### Required Packages

```bash
sudo apt install bluez bluez-tools bluetooth libbluetooth-dev libdbus-1-dev
```

### Bluetooth Service

```bash
# Check status
systemctl status bluetooth

# Start if not running
sudo systemctl start bluetooth
sudo systemctl enable bluetooth
```

### User Permissions

Add user to bluetooth group:
```bash
sudo usermod -aG bluetooth $USER
# Log out and back in for changes to take effect
```

## Troubleshooting

### Device Not Found During Scan

**Cause**: Heart rate monitors only broadcast when worn (skin contact detection).

**Solution**:
1. Moisten the electrode pads on the chest strap
2. Put on the strap snugly
3. Wait 5-10 seconds for skin contact detection
4. LED should start blinking (blue on HW9)

### Connection Fails / Device Busy

**Cause**: Another application or process is connected to the device.

**Solution**:
```bash
# Disconnect via bluetoothctl
echo "disconnect F4:8C:C9:1B:E6:1B" | bluetoothctl

# Or restart bluetooth service
sudo systemctl restart bluetooth
```

### gatttool Timeout

**Cause**: HW9 uses random BLE address type.

**Solution**: Use `-t random` flag:
```bash
gatttool -t random -b F4:8C:C9:1B:E6:1B -I
```

### "Notify acquired" Error (Rust CLI)

**Cause**: Notifications already enabled by another process.

**Solution**: Disconnect existing connections first:
```bash
echo "disconnect F4:8C:C9:1B:E6:1B" | bluetoothctl
sleep 2
./target/release/cli devices connect hci0/dev_F4_8C_C9_1B_E6_1B
```

### Permission Denied

**Cause**: User not in bluetooth group or missing udev rules.

**Solution**:
```bash
sudo ./scripts/ble-setup.sh
# Log out and back in
```

## Device ID Formats

Different tools use different device ID formats:

| Tool | Format | Example |
|------|--------|---------|
| bluetoothctl | MAC address | `F4:8C:C9:1B:E6:1B` |
| gatttool | MAC address | `F4:8C:C9:1B:E6:1B` |
| btleplug (Rust) | hci path | `hci0/dev_F4_8C_C9_1B_E6_1B` |
| bleak (Python) | MAC address | `F4:8C:C9:1B:E6:1B` |

## Configuration Files

### Device Configuration

Location: `~/.heart-beat/device.conf`

```bash
# Heart Beat Device Configuration
DEVICE_MAC="F4:8C:C9:1B:E6:1B"
DEVICE_NAME="HW9 49268"
```

### udev Rules

Location: `/etc/udev/rules.d/99-heart-beat-ble.rules`

```
KERNEL=="hci*", GROUP="bluetooth", MODE="0660"
```

## Comparison of Monitoring Methods

| Feature | Bash/gatttool | Python/bleak | Rust/btleplug |
|---------|---------------|--------------|---------------|
| Raw BPM | Yes | Yes | Yes |
| RR Intervals | No | Yes | Yes |
| Filtered BPM | No | No | Yes |
| RMSSD (HRV) | No | No | Yes |
| Battery Level | No | Yes | Yes |
| Reliability | Good | Best | Best |
| Dependencies | BlueZ only | Python + bleak | Rust toolchain |

## References

- [Bluetooth Heart Rate Service Specification](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/)
- [BlueZ Documentation](http://www.bluez.org/documentation/)
- [btleplug (Rust BLE library)](https://github.com/deviceplug/btleplug)
- [bleak (Python BLE library)](https://github.com/hbldh/bleak)
