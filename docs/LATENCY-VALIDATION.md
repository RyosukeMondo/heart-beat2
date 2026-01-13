# Latency Validation Guide

## Overview

This guide provides step-by-step instructions for validating the P95 < 100ms latency requirement for the Heart Beat application. The validation measures end-to-end latency from BLE notification receipt to UI update.

## Requirements

- Physical Android device with BLE support
- Heart rate monitor with BLE (e.g., Polar H10, Garmin HRM-Dual)
- Android Debug Bridge (adb) installed
- At least 30 minutes for data collection
- Physical activity capability (exercise bike, treadmill, or actual workout)

## Measurement Architecture

The latency measurement captures the following pipeline:

```
BLE Notification → Rust Parser → Kalman Filter → FRB Bridge → Flutter UI
     (t0)                                                        (t1)

Latency = t1 - t0
```

Timestamps:
- `t0`: Captured in `btleplug_adapter.rs` when BLE notification received
- `t1`: Captured in `session_screen.dart` when StreamBuilder receives data
- Both use monotonic clocks (Rust: `Instant`, Flutter: `DateTime.microsecondsSinceEpoch`)

## Validation Procedure

### 1. Build Instrumented Version

Build the app in release mode to measure production-like performance:

```bash
# Build and install on device
./scripts/adb-install.sh

# Verify installation
adb shell pm list packages | grep com.example.heart_beat
```

**Note**: Debug builds have significantly higher latency due to additional overhead. Always use release builds for validation.

### 2. Prepare the Device

```bash
# Ensure Bluetooth is enabled
adb shell settings get global bluetooth_on

# Clear app data for clean state
adb shell pm clear com.example.heart_beat

# Verify sufficient storage
adb shell df -h

# Ensure device is charged or connected to power
adb shell dumpsys battery
```

### 3. Start Log Collection

Open a terminal and start collecting logs:

```bash
# Collect all logs to a file with timestamp
./scripts/adb-logs.sh --save "latency_validation_$(date +%Y%m%d_%H%M%S).txt"

# Alternative: Filter only latency logs
./scripts/adb-logs.sh --tag LatencyService --save "latency_$(date +%Y%m%d_%H%M%S).txt"
```

Keep this terminal open during the entire validation session.

### 4. Connect to Heart Rate Monitor

1. Launch the Heart Beat app on the device
2. Tap "Scan for Devices"
3. Select your heart rate monitor from the list
4. Wait for connection to establish
5. Verify you see live heart rate data on screen

### 5. Perform Extended Workout Session

**Duration**: Minimum 30 minutes (recommended: 45-60 minutes for robust statistics)

**Activity Options**:
- Indoor cycling (easiest to maintain)
- Treadmill running
- Elliptical trainer
- Actual outdoor workout (if device mounting is available)

**Target Variety**: Vary your heart rate throughout the session:
- 5 min warmup (low HR)
- 10 min moderate intensity (zone 2-3)
- 5 min high intensity intervals (zone 4-5)
- 5 min recovery (zone 1-2)
- 5 min moderate (zone 2-3)
- 5 min cooldown (zone 1)

**Monitoring**:
- Keep the device screen active or check periodically
- Latency statistics are logged every 30 seconds
- Ensure the app doesn't crash or disconnect
- Note any unusual events (signal loss, device overheating, etc.)

### 6. Complete the Session

After at least 30 minutes:
1. Stop the workout (or simply disconnect)
2. Wait for final latency statistics to be logged
3. Stop the log collection (Ctrl+C in the log terminal)
4. Note the log file location

### 7. Disconnect and Retrieve Logs

```bash
# Stop logging (Ctrl+C)
# Logs are already saved if using --save flag

# Optional: Pull additional device logs
adb logcat -d > full_logcat_$(date +%Y%m%d_%H%M%S).txt
```

## Data Analysis

### Automated Analysis Script

Use the provided Python script to analyze collected logs:

```bash
# Basic analysis
python3 scripts/analyze_latency.py latency_validation_20260113_143000.txt

# Generate detailed report
python3 scripts/analyze_latency.py latency_validation_20260113_143000.txt --detailed

# Export to CSV for further analysis
python3 scripts/analyze_latency.py latency_validation_20260113_143000.txt --csv latency_data.csv
```

### Manual Analysis

If you prefer manual analysis, search for latency log entries:

```bash
# Extract all latency statistics
grep "Latency Statistics" latency_validation_20260113_143000.txt -A 6

# Count total log entries
grep "Latency Statistics" latency_validation_20260113_143000.txt | wc -l

# Extract P95 values
grep "P95:" latency_validation_20260113_143000.txt | awk '{print $3}' | sed 's/ms//'
```

### Expected Log Format

Latency statistics are logged every 30 seconds:

```
[LatencyService] Latency Statistics:
  Samples: 456 (Total: 1234)
  P50: 45.23 ms
  P95: 78.91 ms
  P99: 92.45 ms
  ✓ P95 latency meets <100ms requirement
```

## Validation Criteria

### Primary Requirement

**P95 < 100ms**: At least 95% of samples must have latency less than 100ms.

### Success Criteria

- ✅ P95 latency < 100ms throughout entire session
- ✅ No P95 values exceed 100ms in any 30-second window
- ✅ Minimum 3600 samples collected (30 min × 2 samples/sec)
- ✅ No data gaps longer than 5 seconds

### Warning Conditions

- ⚠️ P95 between 100-120ms: Close to threshold, investigate bottlenecks
- ⚠️ P99 > 150ms: Occasional outliers, may indicate GC pauses or CPU throttling
- ⚠️ Increasing trend: P95 grows over time, may indicate memory leak

### Failure Conditions

- ❌ P95 > 100ms in multiple measurement windows
- ❌ P50 > 80ms: Median latency too high, systemic issue
- ❌ Frequent disconnections or app crashes

## Troubleshooting

### High Latency Issues

If P95 exceeds 100ms, investigate:

1. **Device Performance**
   - Check CPU/GPU usage: `adb shell top -m 10 -n 1`
   - Check memory: `adb shell dumpsys meminfo com.example.heart_beat`
   - Check thermal throttling: `adb shell cat /sys/class/thermal/thermal_zone*/temp`

2. **Build Configuration**
   - Verify release build: Check `--release` flag was used
   - Check Rust optimizations: `rust/Cargo.toml` should have `opt-level = 3`
   - Verify Flutter release build: Look for `flutter build` not `flutter run`

3. **BLE Connection Quality**
   - Check RSSI: Strong signal should be > -70 dBm
   - Minimize interference: Turn off WiFi, move away from other devices
   - Use quality HR monitor: Cheap devices may have inconsistent timing

4. **Background Apps**
   - Close other apps: `adb shell am force-stop <package>`
   - Disable battery optimization: System Settings → Apps → Heart Beat → Battery

### Missing Latency Logs

If latency logs are not appearing:

```bash
# Check if app is running
adb shell ps | grep heart_beat

# Verify log level
adb logcat -v time | grep "LatencyService"

# Check if service started
adb logcat -d | grep "Started latency tracking"
```

### Data Collection Issues

If unable to collect sufficient samples:

- **Connection Drops**: Check HR monitor battery, ensure proper chest strap positioning
- **App Backgrounded**: Keep screen on or check background service is running
- **Device Sleep**: Disable sleep during charging in Developer Options

## Example Validation Report

```
=== Latency Validation Report ===
Date: 2026-01-13
Device: Samsung Galaxy S21
Android Version: 13
HR Monitor: Polar H10
Session Duration: 45 minutes

Results:
  Total Samples: 5,400
  Sample Rate: 2.0 Hz
  Data Gaps: None

Latency Statistics:
  P50: 42.5 ms ✓
  P95: 76.3 ms ✓
  P99: 89.7 ms ✓
  Max: 112.3 ms (single outlier)

Validation: PASS ✓
  - P95 well below 100ms target
  - Consistent performance throughout session
  - No systemic issues detected

Recommendations:
  - Performance exceeds requirements
  - Consider P95 < 80ms as new target for future optimizations
```

## Acceptance Criteria Checklist

Before marking task 9 as complete, verify:

- [ ] Validation performed on physical Android device (not emulator)
- [ ] Real BLE heart rate monitor used (not mock data)
- [ ] Session duration ≥ 30 minutes
- [ ] Minimum 3,600 samples collected
- [ ] P95 < 100ms verified across entire session
- [ ] Data analysis script executed successfully
- [ ] Validation report generated and documented
- [ ] Results logged in implementation log
- [ ] Any issues or anomalies documented

## References

- Latency Budget: `docs/LATENCY.md`
- Developer Guide: `docs/DEVELOPER-GUIDE.md`
- Benchmark CI: `.github/workflows/benchmark.yml`
- Latency Service Implementation: `lib/src/services/latency_service.dart:58`
- Timestamp Capture: `rust/src/adapters/btleplug_adapter.rs:*`
- Data Structures: `rust/src/domain/heart_rate.rs:63-72,159-171`
