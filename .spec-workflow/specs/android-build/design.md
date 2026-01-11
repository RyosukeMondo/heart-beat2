# Design Document

## Build Process Overview

```
┌─────────────────────────────────────────────────────────┐
│                   build-android.sh                      │
└───────────────────┬─────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
    ┌────────┐ ┌────────┐ ┌──────────┐
    │  FRB   │ │  Rust  │ │ Flutter  │
    │ Codegen│ │ Build  │ │  Build   │
    └────────┘ └────────┘ └──────────┘
        │           │           │
        ↓           ↓           ↓
   api_gen.dart  libheart_    APK
                 beat.so
```

## FRB Code Generation

### Configuration File
```yaml
# flutter_rust_bridge.yaml
rust_input:
  - rust/src/api.rs
dart_output:
  - lib/src/bridge/
llvm_path:
  - /usr/lib/llvm-15
dart_format_line_length: 80
```

### Generated Dart Code Structure
```dart
// lib/src/bridge/api_generated.dart (generated)

class RustLib {
  static Future<void> init() async { ... }
}

Future<List<DiscoveredDevice>> scanDevices() async { ... }

Future<void> connectDevice({required String deviceId}) async { ... }

Stream<FilteredHeartRate> createHrStream() { ... }

class DiscoveredDevice {
  final String id;
  final String? name;
  final int rssi;
}

class FilteredHeartRate {
  final int rawBpm;
  final int filteredBpm;
  final double? rmssd;
  final int? batteryLevel;
}
```

### Integration in Flutter
```dart
// lib/main.dart
import 'src/bridge/api_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(); // Initialize FFI
  runApp(MyApp());
}
```

## Rust Cross-Compilation

### Cargo Config for Android
```toml
# rust/.cargo/config.toml

[target.aarch64-linux-android]
ar = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang"

[target.armv7-linux-androideabi]
ar = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi30-clang"

[target.x86_64-linux-android]
ar = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android30-clang"

[target.i686-linux-android]
ar = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/i686-linux-android30-clang"
```

### Build Script
```bash
#!/bin/bash
# scripts/build-rust-android.sh

set -e

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME not set"
    exit 1
fi

BUILD_MODE="${1:-release}"
CARGO_FLAGS="--release"
if [ "$BUILD_MODE" = "debug" ]; then
    CARGO_FLAGS=""
fi

TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "armv7-linux-androideabi:armeabi-v7a"
    "x86_64-linux-android:x86_64"
    "i686-linux-android:x86"
)

cd rust

for target_pair in "${TARGETS[@]}"; do
    IFS=':' read -r rust_target android_abi <<< "$target_pair"

    echo "Building for $rust_target ($android_abi)..."
    cargo build $CARGO_FLAGS --target "$rust_target"

    # Copy to jniLibs
    mkdir -p "../android/app/src/main/jniLibs/$android_abi"
    cp "target/$rust_target/${BUILD_MODE:-release}/libheart_beat.so" \
       "../android/app/src/main/jniLibs/$android_abi/"

    # Strip symbols in release mode
    if [ "$BUILD_MODE" = "release" ]; then
        "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" \
            "../android/app/src/main/jniLibs/$android_abi/libheart_beat.so"
    fi

    echo "✓ $android_abi built"
done

echo "All architectures built successfully"
```

## Android Configuration

### AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Bluetooth Permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />

    <!-- Android 12+ Bluetooth Permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- Location (required for BLE on Android < 12) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Foreground Service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <uses-feature
        android:name="android.hardware.bluetooth_le"
        android:required="true" />

    <application
        android:label="Heart Beat"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".HeartRateService"
            android:foregroundServiceType="location"
            android:exported="false" />
    </application>
</manifest>
```

### build.gradle
```gradle
// android/app/build.gradle

android {
    compileSdkVersion 34
    ndkVersion "25.2.9519653"

    defaultConfig {
        applicationId "com.example.heart_beat"
        minSdkVersion 26
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName

        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'
        }
    }

    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                         'proguard-rules.pro'
        }
        debug {
            applicationIdSuffix ".debug"
            debuggable true
        }
    }
}
```

## Panic Handling

```rust
// rust/src/lib.rs

use std::panic;

pub fn init_panic_hook() {
    panic::set_hook(Box::new(|panic_info| {
        let message = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
            s.clone()
        } else {
            "Unknown panic".to_string()
        };

        let location = panic_info
            .location()
            .map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()))
            .unwrap_or_else(|| "unknown".to_string());

        tracing::error!("Rust panic: {} at {}", message, location);

        // Convert to Dart exception via FRB
        // (FRB handles this automatically with Result types)
    }));
}

// In API functions
#[frb]
pub async fn connect_device(device_id: String) -> Result<()> {
    panic::catch_unwind(AssertUnwindSafe(|| async {
        // actual implementation
    }))
    .map_err(|_| anyhow!("Panic occurred in connect_device"))?
}
```

## Complete Build Script

```bash
#!/bin/bash
# build-android.sh

set -e

CLEAN=false
BUILD_MODE="release"
ARCHITECTURES="all"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) CLEAN=true ;;
        --debug) BUILD_MODE="debug" ;;
        --arch) ARCHITECTURES="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --clean      Run flutter clean before build"
            echo "  --debug      Build debug APK"
            echo "  --arch ARCH  Build specific architecture (arm64-v8a, x86_64, all)"
            exit 0
            ;;
    esac
    shift
done

echo "🔧 Building Heart Beat for Android ($BUILD_MODE mode)"

# Step 1: Clean if requested
if [ "$CLEAN" = true ]; then
    echo "→ Cleaning build artifacts..."
    flutter clean
fi

# Step 2: FRB Codegen
echo "→ Generating Dart bindings..."
flutter_rust_bridge_codegen \
    --rust-input rust/src/api.rs \
    --dart-output lib/src/bridge/

# Step 3: Build Rust libraries
echo "→ Building Rust libraries..."
./scripts/build-rust-android.sh "$BUILD_MODE"

# Step 4: Build Flutter APK
echo "→ Building Flutter APK..."
if [ "$BUILD_MODE" = "release" ]; then
    flutter build apk --release
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
else
    flutter build apk --debug
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

# Success
echo "✅ Build complete!"
echo "📦 APK: $APK_PATH"
echo "📏 Size: $(du -h "$APK_PATH" | cut -f1)"
```

## Development Workflow

### Initial Setup
```bash
# 1. Install dependencies
./scripts/dev-setup.sh

# 2. Generate FRB bindings
flutter_rust_bridge_codegen

# 3. Build for development
./build-android.sh --debug
```

### Iteration Cycle

**Dart-only changes (hot reload works):**
```bash
flutter run
# Make changes to Dart code
# Press 'r' for hot reload
```

**Rust changes (requires rebuild):**
```bash
# Make changes to Rust code
./scripts/build-rust-android.sh debug
flutter run
```

### Debugging

**View logs:**
```bash
flutter logs                    # All logs
adb logcat | grep heart_beat   # Android logs only
```

**Debug Rust with symbols:**
```bash
# Build with debug symbols
./build-android.sh --debug

# Attach lldb
adb forward tcp:1234 tcp:1234
lldb
(lldb) platform select remote-android
(lldb) platform connect connect://localhost:1234
(lldb) target create path/to/libheart_beat.so
```

## Testing Strategy

### FRB Integration Test
```dart
// integration_test/frb_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('scan devices returns list', (tester) async {
    final devices = await scanDevices();
    expect(devices, isA<List<DiscoveredDevice>>());
  });

  testWidgets('mock mode streams HR data', (tester) async {
    await startMockMode();
    final stream = createHrStream();

    final values = await stream.take(5).toList();
    expect(values.length, 5);
    expect(values.every((hr) => hr.filteredBpm > 0), true);
  });
}
```

Run with:
```bash
flutter test integration_test/frb_test.dart
```
