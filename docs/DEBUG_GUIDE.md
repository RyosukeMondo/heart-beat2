# Debugging Guide

Practical debugging techniques for the Heart Beat app, learned from real debugging sessions.

## Golden Rule

**Read error messages before writing code.** Logs tell you exactly what's wrong - look at them first.

## Quick Reference

### Start Debugging Session

```bash
# Terminal 1: Clear logs and watch in real-time
adb logcat -c && adb logcat | grep -E "heart_beat|flutter|ERROR|Exception|BluetoothGatt"

# Terminal 2: Deploy and test
./scripts/adb-install.sh
```

### Common Log Filters

```bash
# All app logs (verbose)
adb logcat | grep -E "heart_beat|flutter"

# Errors only
adb logcat | grep -iE "ERROR|Exception|FATAL|panic"

# BLE-specific
adb logcat | grep -iE "BluetoothGatt|btleplug|BLE"

# Connection issues
adb logcat | grep -iE "connect|GATT|status="

# Using project script
./scripts/adb-logs.sh --follow
```

## Common Issues & Solutions

### 1. GATT Error 133 (Connection Failed)

**Symptom:**
```
BluetoothGatt: onClientConnectionState() - status=133 connected=false
```

**Cause:** Android BLE flakiness - stale connection state, device busy, or range issues.

**Solutions:**
- Toggle Bluetooth off/on on the phone
- Wait a few seconds and retry
- Move closer to the HR monitor
- The app has built-in retry logic (3 attempts with backoff)

### 2. Foreground Service Timeout

**Symptom:**
```
ForegroundServiceDidNotStartInTimeException: Context.startForegroundService()
did not then call Service.startForeground()
```

**Cause:** `setAsForegroundService()` not called within 10 seconds of service start.

**Solution:** Ensure `onStart` callback immediately calls:
```dart
if (service is AndroidServiceInstance) {
  await service.setAsForegroundService();
}
```

### 3. Tokio Runtime Panic

**Symptom:**
```
panic: there is no reactor running, must be called from the context of a Tokio 1.x runtime
```

**Cause:** Calling `tokio::spawn()` from a sync function in FRB.

**Solution:** Make the function `async`:
```rust
// Before (wrong)
pub fn create_hr_stream(...) -> Result<()> {
    tokio::spawn(async move { ... });  // PANIC!
}

// After (correct)
pub async fn create_hr_stream(...) -> Result<()> {
    tokio::spawn(async move { ... });  // OK
}
```

### 4. AOT Entry Point Error

**Symptom:**
```
ERROR: To access 'BackgroundService' from native code, it must be annotated
```

**Cause:** Dart AOT compilation requires entry point annotations for native callbacks.

**Solution:** Add pragma to class and callbacks:
```dart
@pragma('vm:entry-point')
class BackgroundService {
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async { ... }
}
```

### 5. No Heart Rate Data

**Symptom:** App connects but shows "Waiting for heart rate data..." forever.

**Cause:** Connected to device but not subscribed to HR notifications.

**Checklist:**
1. Is `subscribe_hr()` called after connect?
2. Is the notification stream being read?
3. Is `emit_hr_data()` being called with parsed data?
4. Check logs for "Subscribed to HR notifications"

### 6. Permission Denied for Foreground Service

**Symptom:**
```
SecurityException: requires permissions: FOREGROUND_SERVICE_HEALTH
any of [ACTIVITY_RECOGNITION, health.READ_HEART_RATE, ...]
```

**Cause:** Android 14+ requires health permission for health foreground services.

**Solution:** Add to AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
```

## Debugging Strategy

### 1. Isolate the Problem

If multiple things might be broken, disable non-essential features:

```dart
// Temporarily disable background service to test core BLE
// await _startBackgroundService();
```

### 2. Test Incrementally

- **Linux CLI first** (fastest iteration): `cargo run --bin cli`
- **Then Android**: `./scripts/adb-install.sh`

### 3. Add Strategic Logging

```rust
tracing::info!("connect_device: step X completed");
tracing::debug!("Received {} bytes", data.len());
tracing::error!("Failed at step Y: {}", e);
```

### 4. Check Logs Before and After

```bash
# Before action
adb logcat -c

# Perform action in app

# Check what happened
adb logcat -d | grep heart_beat
```

## Rust Log Levels

```bash
# All debug logs
RUST_LOG=debug cargo run --bin cli

# Specific module
RUST_LOG=heart_beat::adapters=debug cargo run --bin cli

# Multiple modules
RUST_LOG=heart_beat::adapters=debug,heart_beat::api=trace cargo run --bin cli
```

## BLE Debugging

### Enable HCI Snoop Log (Bluetooth packet capture)

```bash
./scripts/adb-ble-debug.sh enable
# Reproduce issue
./scripts/adb-ble-debug.sh disable
# Pull log from /data/misc/bluetooth/logs/
```

### Check Bluetooth State

```bash
adb shell dumpsys bluetooth_manager | grep -E "state|enabled|scanning"
```

### List Paired/Connected Devices

```bash
adb shell dumpsys bluetooth_manager | grep -A5 "Bonded devices"
```

## Time-Saving Tips

1. **Use two terminals** - one for logs, one for commands
2. **Clear logs before testing** - `adb logcat -c`
3. **Filter aggressively** - don't scroll through thousands of unrelated logs
4. **Read the actual error** - Android/Rust errors are usually descriptive
5. **Check permissions first** - many Android issues are permission-related
