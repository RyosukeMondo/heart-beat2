# Android Debugging Guide

This guide provides comprehensive instructions for debugging the Heart Beat Android application, including both Flutter/Dart and Rust native code.

## Table of Contents

- [Quick Start](#quick-start)
- [Viewing Logs](#viewing-logs)
- [Debugging Dart/Flutter](#debugging-dartflutter)
- [Debugging Rust Code](#debugging-rust-code)
- [Common Issues](#common-issues)
- [Performance Profiling](#performance-profiling)
- [Troubleshooting Flowchart](#troubleshooting-flowchart)

## Quick Start

### Essential Commands

```bash
# View all logs
flutter logs

# View only app logs (with grep)
flutter logs | grep "HeartBeat"

# View Android system logs
adb logcat

# View Rust logs specifically
adb logcat | grep "RUST"

# Clear log buffer
adb logcat -c

# Run app in debug mode
flutter run --debug

# Run with verbose logging
RUST_LOG=debug flutter run
```

## Viewing Logs

### Flutter Logs

The `flutter logs` command shows output from both Dart and native code:

```bash
# Basic logs
flutter logs

# Filter by severity
flutter logs --grep error

# Continuous logs with timestamp
flutter logs -t
```

**Log Levels:**
- `D` - Debug
- `I` - Info
- `W` - Warning
- `E` - Error

### ADB Logcat

For more detailed system and native logs:

```bash
# All logs
adb logcat

# Filter by tag
adb logcat -s "HeartBeat:*"

# Filter by priority (V=verbose, D=debug, I=info, W=warn, E=error, F=fatal)
adb logcat *:E  # Only errors

# Clear and monitor
adb logcat -c && adb logcat

# Save to file
adb logcat > debug.log
```

### Rust Logs

Rust logs are forwarded to Flutter through the logging bridge (Task 5.1):

```bash
# Set log level via environment variable
export RUST_LOG=debug
flutter run

# Or inline
RUST_LOG=trace flutter run

# View only Rust logs
flutter logs | grep "rust::"
```

**Rust Log Levels:**
- `trace` - Very detailed
- `debug` - Debug information
- `info` - General information
- `warn` - Warnings
- `error` - Errors

### Example Log Output

```
I/flutter (12345): [2026-01-11 10:30:45.123] rust::heart_beat::ble - Scanning for BLE devices
D/flutter (12345): [2026-01-11 10:30:45.456] rust::heart_beat::ble - Found device: Polar H10 (AA:BB:CC:DD:EE:FF)
E/flutter (12345): [2026-01-11 10:30:46.789] rust::heart_beat::ble - Connection failed: Device not in range
```

## Debugging Dart/Flutter

### Using DevTools

Flutter DevTools provides a powerful debugging interface:

```bash
# Start app in debug mode
flutter run --debug

# DevTools will show a URL like:
# http://127.0.0.1:9100?uri=http://127.0.0.1:12345/xxx/
# Open this URL in your browser
```

**DevTools Features:**
- **Inspector**: View widget tree and properties
- **Timeline**: Analyze UI performance
- **Memory**: Track memory usage and leaks
- **Debugger**: Set breakpoints, step through code
- **Logging**: View all logs in one place
- **Network**: Monitor HTTP requests

### Breakpoints in VS Code

1. Open the Dart file
2. Click left of line number to add breakpoint (red dot)
3. Press `F5` or Run → Start Debugging
4. App will pause at breakpoint
5. Use debugger controls:
   - `F10` - Step over
   - `F11` - Step into
   - `Shift+F11` - Step out
   - `F5` - Continue

### Print Debugging

```dart
import 'package:flutter/foundation.dart';

// Use debugPrint for production-safe logging
debugPrint('BLE scan started');

// Conditional logging
if (kDebugMode) {
  print('Debug info: $deviceId');
}
```

### Hot Reload vs Hot Restart

- **Hot Reload** (`r` in terminal or `Ctrl+S`): Preserves app state
- **Hot Restart** (`R` in terminal): Resets app state
- **Full Restart** (`q` then `flutter run`): Rebuilds everything including Rust

**When to use each:**
- Hot Reload: UI changes, most Dart code changes
- Hot Restart: State management changes, new dependencies
- Full Restart: Rust code changes, native library updates

## Debugging Rust Code

### Setup for Rust Debugging

1. **Install LLDB**:
```bash
sudo apt-get install lldb
```

2. **Build with debug symbols**:
```bash
# In rust/ directory
cargo build --target aarch64-linux-android
```

3. **Connect debugger**:
```bash
# Find the app process
adb shell ps | grep heart_beat

# Attach LLDB
adb forward tcp:5039 tcp:5039
lldb-server platform --listen "*:5039" --server
```

### Rust Debug Techniques

#### 1. Log-based Debugging

Add logging to Rust code:

```rust
use tracing::{debug, info, warn, error};

#[flutter_rust_bridge::frb(sync)]
pub fn scan_devices() -> Result<Vec<DiscoveredDevice>> {
    info!("Starting BLE device scan");

    match scanner.scan() {
        Ok(devices) => {
            debug!("Found {} devices", devices.len());
            Ok(devices)
        }
        Err(e) => {
            error!("Scan failed: {}", e);
            Err(e)
        }
    }
}
```

#### 2. Panic Backtrace

Enable panic backtraces:

```bash
RUST_BACKTRACE=1 flutter run
```

Example panic output:
```
thread 'main' panicked at 'Device not found', rust/src/ble.rs:42:5
stack backtrace:
   0: rust_begin_unwind
   1: core::panicking::panic_fmt
   2: heart_beat::ble::connect_device
   3: heart_beat::api::connect_device
```

#### 3. Assertions

Use assertions for development:

```rust
debug_assert!(device_id.len() == 17, "Invalid MAC address length");
assert!(heart_rate > 0 && heart_rate < 300, "Invalid heart rate");
```

### Inspecting Native Libraries

```bash
# List libraries in APK
unzip -l app.apk | grep libheart_beat.so

# Check architecture
file android/app/src/main/jniLibs/arm64-v8a/libheart_beat.so

# Verify symbols
nm -D libheart_beat.so | grep init_logging

# Check library dependencies
adb shell "ls -l /data/app/*/lib/arm64/"
```

## Common Issues

### Issue 1: Library Not Found

**Error:**
```
java.lang.UnsatisfiedLinkError: dlopen failed: library "libheart_beat.so" not found
```

**Diagnosis:**
```bash
# Check if library exists in APK
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libheart_beat.so

# Check installed app
adb shell run-as com.example.heart_beat ls -R lib/
```

**Solutions:**
1. Rebuild Rust libraries: `./scripts/build-rust-android.sh`
2. Clean and rebuild: `flutter clean && ./build-android.sh`
3. Verify Gradle configuration in `android/app/build.gradle`
4. Check `jniLibs` directory structure matches ABI names

### Issue 2: Permission Denied

**Error:**
```
SecurityException: Need BLUETOOTH_CONNECT permission
```

**Diagnosis:**
```bash
# Check granted permissions
adb shell dumpsys package com.example.heart_beat | grep permission

# View runtime permissions
adb shell pm list permissions -d -g
```

**Solutions:**
1. Update `AndroidManifest.xml` with required permissions
2. Request runtime permissions in Flutter:
```dart
await Permission.bluetoothScan.request();
await Permission.bluetoothConnect.request();
await Permission.location.request();
```
3. For Android 12+, ensure both manifest and runtime permissions
4. Check targetSdkVersion compatibility

### Issue 3: Rust Panics

**Error:**
```
flutter: [ERROR] rust::heart_beat - thread panicked at 'index out of bounds'
```

**Diagnosis:**
1. Check `flutter logs` for panic location
2. Enable backtrace: `RUST_BACKTRACE=full flutter run`
3. Review recent Rust code changes

**Solutions:**
1. Panic handler converts to Dart exception (configured in Task 3.3)
2. Add bounds checking or use `.get()` instead of indexing
3. Wrap with `catch_unwind` for graceful handling:
```rust
std::panic::catch_unwind(|| {
    // potentially panicking code
}).unwrap_or_else(|_| {
    error!("Panic caught");
    Err(MyError::PanicOccurred)
})
```

### Issue 4: Bluetooth Not Working

**Error:**
```
BluetoothAdapter not found or Bluetooth is off
```

**Diagnosis:**
```bash
# Check Bluetooth hardware
adb shell service call bluetooth_manager 6

# Check Bluetooth status
adb shell settings get global bluetooth_on
```

**Solutions:**
1. Enable Bluetooth: `adb shell svc bluetooth enable`
2. Verify device has BLE hardware
3. Check manifest: `<uses-feature android:name="android.hardware.bluetooth_le" />`
4. Test on physical device (emulator BLE support is limited)

### Issue 5: Build Failures

**Error:**
```
Execution failed for task ':app:mergeDebugNativeLibs'
```

**Diagnosis:**
```bash
# Check dependency versions
./scripts/check-deps.sh

# Verify NDK installation
echo $ANDROID_NDK_HOME
ls $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/
```

**Solutions:**
1. Clean build: `flutter clean && rm -rf android/.gradle`
2. Verify NDK path in `rust/.cargo/config.toml`
3. Rebuild Rust: `./scripts/build-rust-android.sh --clean`
4. Update Gradle: `cd android && ./gradlew --version`
5. Check `build.gradle` for conflicting dependencies

### Issue 6: FRB Binding Errors

**Error:**
```
MissingPluginException: No implementation found for method init_logging
```

**Diagnosis:**
```bash
# Check generated bindings
cat lib/src/bridge/api_generated.dart | grep init_logging

# Verify codegen ran
ls -la lib/src/bridge/*.frb.dart
```

**Solutions:**
1. Regenerate bindings: `flutter_rust_bridge_codegen`
2. Run hot restart (not just hot reload)
3. Verify `api.rs` exports the function
4. Check function signature matches between Rust and Dart

## Performance Profiling

### Flutter Performance

#### 1. Using DevTools Timeline

```bash
flutter run --profile  # Note: --profile mode, not --release
```

Open DevTools → Timeline tab:
- Record UI performance
- Identify janky frames (>16ms for 60fps)
- Find expensive widget builds
- Check for unnecessary rebuilds

#### 2. Flutter Inspector

Look for:
- Deep widget trees (optimization opportunity)
- Unnecessary `setState()` calls
- Widgets rebuilding too frequently

### Android Studio Profiler

1. Run app: `flutter run --profile`
2. Open Android Studio → View → Tool Windows → Profiler
3. Attach to running app

**CPU Profiler:**
- Shows time spent in each method
- Identifies hot paths
- Traces native (Rust) calls

**Memory Profiler:**
- Track allocations
- Find memory leaks
- View heap dumps

**Network Profiler:**
- Monitor HTTP requests
- View request/response times

### Rust Performance

#### 1. Benchmarking

Add to `rust/Cargo.toml`:
```toml
[dev-dependencies]
criterion = "0.5"
```

Create benchmark:
```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn benchmark_scan(c: &mut Criterion) {
    c.bench_function("scan_devices", |b| {
        b.iter(|| scan_devices(black_box(&adapter)))
    });
}

criterion_group!(benches, benchmark_scan);
criterion_main!(benches);
```

Run: `cargo bench`

#### 2. Profiling with perf

```bash
# Record profile
adb shell simpleperf record -p $(adb shell pidof com.example.heart_beat)

# Pull and analyze
adb pull /data/local/tmp/perf.data
simpleperf report
```

### Performance Checklist

- [ ] No frames >16ms in Timeline
- [ ] No excessive widget rebuilds
- [ ] Memory usage stable (no leaks)
- [ ] CPU usage reasonable (<30% idle)
- [ ] BLE scan completes <5s
- [ ] HR data streams at 1Hz consistently
- [ ] No allocation spikes

## Troubleshooting Flowchart

```
App crashes on launch?
├─ Check flutter logs for stack trace
├─ Native library issue?
│  ├─ Verify .so files in APK
│  ├─ Check NDK configuration
│  └─ Rebuild Rust: ./scripts/build-rust-android.sh
├─ Permission issue?
│  ├─ Check AndroidManifest.xml
│  └─ Request runtime permissions
└─ Dart exception?
   ├─ Check DevTools debugger
   └─ Add try-catch and log

BLE not working?
├─ Permissions granted?
│  ├─ BLUETOOTH_SCAN
│  ├─ BLUETOOTH_CONNECT
│  └─ LOCATION (required for BLE on Android)
├─ Bluetooth enabled?
│  └─ Check system settings
├─ Device compatible?
│  └─ Test on physical device
└─ Check Rust logs for adapter errors

Rust function not found?
├─ Regenerate bindings: flutter_rust_bridge_codegen
├─ Hot restart app
├─ Verify function in api.rs
└─ Check FRB version compatibility

Build fails?
├─ Clean build: flutter clean
├─ Check dependencies: ./scripts/check-deps.sh
├─ Verify NDK: echo $ANDROID_NDK_HOME
├─ Update Gradle wrapper
└─ Clear Gradle cache: rm -rf android/.gradle

Performance issues?
├─ Profile with DevTools
├─ Check for unnecessary rebuilds
├─ Review BLE scanning frequency
├─ Check for memory leaks
└─ Optimize Rust hot paths
```

## Best Practices

### Development

1. **Always check logs first**: `flutter logs` reveals most issues
2. **Use debug builds**: Release builds omit symbols and logs
3. **Hot reload for Dart, full restart for Rust**: Saves time
4. **Enable verbose Rust logs**: `RUST_LOG=debug` during development
5. **Test on real devices**: Emulator BLE support is limited

### Debugging

1. **Start simple**: Use print statements before complex debugging
2. **Isolate the problem**: Binary search through recent changes
3. **Check permissions early**: Many Android issues are permissions
4. **Verify environment**: Run `./scripts/check-deps.sh`
5. **Read the full error**: Don't stop at the first line

### Performance

1. **Profile before optimizing**: Measure, don't guess
2. **Focus on user-visible issues**: Dropped frames, slow responses
3. **Optimize hot paths**: Use profiler to find them
4. **Test on low-end devices**: Ensures broad compatibility

## Additional Resources

### Documentation
- [Flutter Debugging Guide](https://docs.flutter.dev/testing/debugging)
- [Android Debugging Docs](https://developer.android.com/studio/debug)
- [Rust Error Handling](https://doc.rust-lang.org/book/ch09-00-error-handling.html)
- [FRB Documentation](https://cjycode.com/flutter_rust_bridge/)

### Tools
- [Flutter DevTools](https://docs.flutter.dev/tools/devtools/overview)
- [Android Studio Profiler](https://developer.android.com/studio/profile)
- [LLDB Debugger](https://lldb.llvm.org/)
- [ADB Reference](https://developer.android.com/tools/adb)

### Community
- [Flutter Discord](https://discord.gg/flutter)
- [Rust Users Forum](https://users.rust-lang.org/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter+android)

## Quick Reference Card

### Most Used Commands

```bash
# Logs
flutter logs                          # All logs
adb logcat -c && adb logcat          # Clear and view system logs
RUST_LOG=debug flutter run           # Debug with Rust logs

# Building
./build-android.sh                    # Build release APK
./build-android.sh --debug           # Build debug APK
./scripts/build-rust-android.sh      # Rebuild Rust only

# Debugging
flutter run --debug                   # Debug mode with DevTools
flutter analyze                       # Static analysis
flutter doctor -v                     # Check environment

# Device Management
adb devices                          # List devices
adb logcat -c                        # Clear logs
adb install -r app.apk              # Reinstall app
adb uninstall com.example.heart_beat # Uninstall app

# Profiling
flutter run --profile                # Profile mode
adb shell am dumpheap <pid> /data/local/tmp/heap.dump  # Heap dump
```

---

**Last Updated**: 2026-01-11
**Related Docs**: [Development Guide](development.md), [User Guide](user-guide.md)
