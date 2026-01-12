# Heart Beat Developer Guide

Complete guide for setting up your development environment and building the Heart Beat project.

## Environment Setup

This section covers all prerequisites and dependencies needed to build and run Heart Beat on Linux.

### System Requirements

- **OS:** Ubuntu 20.04+, Fedora 35+, or equivalent Linux distribution
- **Architecture:** x86_64 (ARM64 support experimental)
- **Disk space:** ~10GB for all tools and dependencies
- **RAM:** Minimum 8GB recommended for Android builds

### Core Dependencies

#### 1. Rust Toolchain

Heart Beat requires Rust 1.75 or later for the core library.

**Install Rust via rustup:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# Verify installation
rustc --version  # Should show 1.75+
cargo --version
```

**Add Android cross-compilation targets:**
```bash
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android
```

#### 2. Linux System Libraries

The BLE stack (btleplug) requires system libraries for Bluetooth and D-Bus communication.

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y \
  libudev-dev \
  libdbus-1-dev \
  libssl-dev \
  pkg-config \
  build-essential
```

**Fedora/RHEL:**
```bash
sudo dnf install -y \
  systemd-devel \
  dbus-devel \
  openssl-devel \
  pkg-config \
  gcc \
  gcc-c++
```

**Why these are needed:**
- `libudev-dev` - Device management for BLE adapters
- `libdbus-1-dev` - D-Bus IPC for BlueZ communication
- `libssl-dev` - TLS/SSL support for networking
- `pkg-config` - Build system dependency resolution
- `build-essential` - C/C++ compiler toolchain

#### 3. Flutter SDK

Heart Beat uses Flutter 3.16+ for the mobile UI.

**Install Flutter:**
```bash
# Download Flutter
cd ~/development
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz

# Add to PATH (add to ~/.bashrc or ~/.zshrc for persistence)
export PATH="$PATH:$HOME/development/flutter/bin"

# Verify installation
flutter --version  # Should show 3.16+
flutter doctor
```

**Install Flutter dependencies:**
```bash
# Navigate to project root
cd heart-beat2
flutter pub get
```

#### 4. Android SDK and NDK

Required for building Android APKs and cross-compiling Rust to ARM/x86 Android targets.

**Install Android Studio (includes SDK):**
```bash
# Download from https://developer.android.com/studio
# Or use snap:
sudo snap install android-studio --classic

# Launch Android Studio and complete the setup wizard
# This installs the base Android SDK
```

**Set Android SDK environment variables:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools"
```

**Install Android NDK r25c or later:**

The NDK provides the toolchain for compiling Rust to Android architectures.

```bash
# Via Android Studio:
# 1. Open Tools > SDK Manager
# 2. Select "SDK Tools" tab
# 3. Check "NDK (Side by side)" version 25.2.9519653 or later
# 4. Click "OK" to install

# Or via command line:
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install "ndk;25.2.9519653"
```

**Set NDK environment variable:**
```bash
# Add to ~/.bashrc or ~/.zshrc
# Replace <version> with your installed version (e.g., 25.2.9519653)
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/<version>"

# Example:
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"
```

**Install required Android platforms and build tools:**
```bash
# Heart Beat targets Android 8.0 (API 26) to Android 14 (API 34)
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  "platform-tools"
```

#### 5. Additional Tools

**Git:**
```bash
# Ubuntu/Debian
sudo apt install git

# Fedora
sudo dnf install git

# Verify
git --version
```

**LLVM tools (optional but recommended):**
```bash
# Ubuntu/Debian
sudo apt install llvm

# Fedora
sudo dnf install llvm

# These provide llvm-ar and llvm-strip for Android binary optimization
```

### Automated Setup

For convenience, use the provided setup script:

```bash
cd heart-beat2
./scripts/dev-setup.sh
```

This script will:
1. Check for Rust installation (install if missing)
2. Check for Flutter installation (guide you if missing)
3. Verify Android SDK/NDK configuration
4. Install Rust Android targets
5. Run `flutter pub get`
6. Verify all dependencies with `flutter doctor`

### Verify Installation

After setup, verify all dependencies are correctly installed:

```bash
./scripts/check-deps.sh
```

This checks:
- Rust version and Android targets
- Flutter version and Dart SDK
- Android SDK location and components
- Android NDK version (r25+)
- System libraries availability
- Project-specific dependencies

**Expected output:**
```
✓ rustc 1.75.0
✓ cargo 1.75.0
✓ Flutter 3.16.0
✓ ANDROID_HOME: /home/user/Android/Sdk
✓ adb version 34.0.5
✓ NDK version 25.2.9519653 (>= r25 required)
✓ aarch64-linux-android
✓ armv7-linux-androideabi
✓ x86_64-linux-android
✓ i686-linux-android

All required dependencies are installed!
```

### Troubleshooting

**"ANDROID_NDK_HOME not set" error:**
```bash
# Find your NDK installation
ls $ANDROID_HOME/ndk/

# Set the environment variable
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"

# Make permanent by adding to ~/.bashrc
echo 'export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"' >> ~/.bashrc
```

**"libudev.so not found" error:**
```bash
# Install missing system library
sudo apt install libudev-dev pkg-config
```

**Flutter doctor warnings:**
```bash
# Accept Android licenses
flutter doctor --android-licenses

# Install missing components as suggested
```

**Rust Android target installation fails:**
```bash
# Update rustup first
rustup update

# Try installing targets again
rustup target add aarch64-linux-android
```

---

## Development Workflows

This section covers different development approaches for building and testing Heart Beat. Choose the workflow that best fits your current task.

### Overview

Heart Beat supports three primary development workflows:

1. **Linux CLI** - Fastest iteration for Rust development
2. **Linux Desktop** - Full UI testing on Linux
3. **Android** - On-device testing with real BLE hardware

Each workflow has different build times and use cases.

### 1. Linux CLI Workflow (Fastest)

**Use when:**
- Developing or testing core Rust logic
- Writing unit tests
- Quick iteration without UI concerns
- No BLE hardware available (use mock mode)

**Basic usage:**
```bash
# Run the CLI binary
cargo run --bin cli

# Run with debug logging
RUST_LOG=debug cargo run --bin cli

# Run with mock BLE adapter (no real Bluetooth required)
cargo run --bin cli --mock
```

**Build time:** ~5-15 seconds for incremental builds

**Advantages:**
- Extremely fast compile times
- No Flutter/Android build overhead
- Direct access to Rust output and errors
- Easy to debug with print statements or debuggers

**Limitations:**
- No UI testing
- No real BLE on most Linux systems without adapter
- Mock mode required for BLE testing

**Example workflow:**
```bash
# 1. Make changes to Rust code in rust/src/
vim rust/src/training/mod.rs

# 2. Run tests
cargo test

# 3. Test in CLI with mock BLE
RUST_LOG=heart_beat::ble=debug cargo run --bin cli --mock

# 4. Iterate quickly
# (Repeat steps 1-3 as needed)
```

### 2. Linux Desktop Workflow

**Use when:**
- Testing Flutter UI components
- Verifying UI/Rust integration via FFI
- Developing UI features
- QA testing before Android deployment

**Basic usage:**
```bash
# One-command build and launch (release mode)
./scripts/dev-linux.sh

# Build in debug mode for faster compilation
./scripts/dev-linux.sh debug

# Manual build and run
cd rust && cargo build --release && cd ..
flutter run -d linux
```

**Build time:**
- Initial build: ~2-4 minutes (Rust + Flutter)
- Incremental Rust: ~10-30 seconds
- Incremental Flutter: ~5-15 seconds

**What the script does:**
1. Builds the Rust library (`libheart_beat.so`)
2. Launches Flutter Linux app
3. Hot reload works for Flutter code changes

**Advantages:**
- Full UI testing without deploying to Android
- Faster than Android builds
- Hot reload for Flutter changes
- Desktop debugging tools available

**Limitations:**
- Linux BLE stack differs from Android
- May not catch Android-specific issues
- Performance characteristics differ from mobile

**Example workflow:**
```bash
# 1. Start the app
./scripts/dev-linux.sh debug

# 2. Make Flutter UI changes
vim lib/pages/home_page.dart

# 3. Press 'r' in the terminal for hot reload (Flutter changes only)

# 4. For Rust changes:
#    - Stop the app (Ctrl+C)
#    - Rebuild: cd rust && cargo build && cd ..
#    - Restart: flutter run -d linux

# 5. Test UI flows manually
```

### 3. Android Workflow

**Use when:**
- Testing on real hardware
- Verifying BLE functionality with heart rate monitors
- Testing training scenarios end-to-end
- Final QA before release

**Basic usage:**
```bash
# One-command: build + install + launch
./scripts/adb-install.sh

# Build release APK
./scripts/adb-install.sh --release

# Manual steps
./build-android.sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.heart_beat/.MainActivity
```

**Build time:**
- Initial build: ~5-10 minutes (cross-compile Rust for 4 architectures + Flutter)
- Incremental: ~1-3 minutes
- Install + launch: ~10-30 seconds

**What the script does:**
1. Checks for connected Android device
2. Cross-compiles Rust for Android architectures (ARM64, ARMv7, x86_64, x86)
3. Builds Flutter APK
4. Installs APK on device
5. Launches the app

**Advantages:**
- Real BLE hardware testing
- Actual mobile performance characteristics
- Android-specific features (permissions, services)
- Production-like environment

**Limitations:**
- Slowest build times
- Requires USB connection or wireless ADB
- No hot reload (full rebuild required)

**Example workflow:**
```bash
# 1. Connect Android device via USB
adb devices

# 2. Deploy to device
./scripts/adb-install.sh

# 3. Monitor logs
./scripts/adb-logs.sh --follow

# 4. Test with real heart rate monitor
# (Pair BLE device, start training session)

# 5. Make changes and redeploy
vim rust/src/ble/mod.rs
./scripts/adb-install.sh
```

### 4. Mock Mode

**Use when:**
- Developing without BLE hardware
- Testing training logic in isolation
- Automated testing
- CI/CD environments

**Usage:**
```bash
# CLI with mock BLE adapter
cargo run --bin cli --mock

# Mock adapter provides simulated heart rate data
# Useful for testing training calculations without real sensors
```

**Mock behavior:**
- Simulates BLE adapter discovery
- Generates fake heart rate data (60-180 bpm)
- Predictable data patterns for testing
- No real Bluetooth required

### Recommended Development Flow

For most feature development, use this progression:

1. **Start with Linux CLI** (`cargo run --bin cli --mock`)
   - Implement and test core Rust logic
   - Write unit tests
   - Fast iteration

2. **Move to Linux Desktop** (`./scripts/dev-linux.sh debug`)
   - Integrate with Flutter UI
   - Test UI components
   - Verify FFI bindings

3. **Deploy to Android** (`./scripts/adb-install.sh`)
   - Test on real hardware
   - Verify BLE functionality
   - Performance testing
   - Final QA

This approach minimizes build time while maintaining confidence in code quality.

### Watch Mode (Auto-rebuild)

For continuous development, use watch mode:

```bash
# Auto-rebuild Rust on file changes
./scripts/dev-watch.sh

# Watches rust/src/ and rebuilds automatically
# Useful when developing Rust code alongside Flutter
```

**How it works:**
- Monitors `rust/src/` for changes
- Triggers `cargo build` on modification
- Flutter hot reload still works for UI changes

**Use case:** Keep watch mode running while developing features that touch both Rust and Flutter.

---

## Debugging

This section covers debugging tools, log levels, and techniques for troubleshooting issues during development.

### Overview

Heart Beat provides multiple debugging mechanisms:

1. **Debug Console** - In-app UI for viewing logs and filters
2. **Log Levels** - Control Rust logging verbosity via `RUST_LOG`
3. **Android Logcat** - View logs from Android devices using `adb-logs.sh`
4. **BLE HCI Snoop** - Capture low-level Bluetooth packets using `adb-ble-debug.sh`

### 1. Debug Console (In-App)

The Flutter app includes a built-in debug console for viewing Rust logs in real-time.

**Activate the console:**
- Triple-tap anywhere on the screen to toggle the debug overlay

**Features:**
- Real-time log streaming from Rust layer
- Filter logs by level (ERROR, WARN, INFO, DEBUG, TRACE)
- Filter logs by module (ble, training, storage, etc.)
- Pause/resume log capture
- Clear log buffer

**Use cases:**
- Quick debugging on device without ADB
- Show logs to QA or non-technical users
- Demo logging during development
- On-device troubleshooting

**Limitations:**
- Only shows logs from current session
- Limited buffer size (~1000 lines)
- UI overhead may affect performance
- Not available in release builds (disabled by default)

### 2. Rust Log Levels

Control Rust logging verbosity using the `RUST_LOG` environment variable.

**Available log levels (lowest to highest):**
- `trace` - Very detailed, every function call
- `debug` - Detailed information for debugging
- `info` - General informational messages
- `warn` - Warning messages
- `error` - Error messages only

**Basic usage:**

```bash
# Enable all debug logs
RUST_LOG=debug cargo run --bin cli

# Enable only heart_beat module debug logs
RUST_LOG=heart_beat=debug cargo run --bin cli

# Enable trace logs for specific module
RUST_LOG=heart_beat::ble=trace cargo run --bin cli

# Multiple modules with different levels
RUST_LOG=heart_beat::ble=debug,heart_beat::training=info cargo run --bin cli

# Error level only (minimal logging)
RUST_LOG=error cargo run --bin cli
```

**Module hierarchy:**
```
heart_beat
├── ble          - Bluetooth Low Energy
├── training     - Training session management
├── storage      - Data persistence
├── hr_zone      - Heart rate zone calculations
└── cli          - CLI interface
```

**Examples for common debugging scenarios:**

```bash
# Debug BLE connection issues
RUST_LOG=heart_beat::ble=debug cargo run --bin cli

# Debug training calculations
RUST_LOG=heart_beat::training=debug,heart_beat::hr_zone=debug cargo run --bin cli

# Verbose output for all heart_beat code
RUST_LOG=heart_beat=trace cargo run --bin cli

# Production-like logging (errors and warnings only)
RUST_LOG=warn cargo run --bin cli
```

**Performance considerations:**
- `trace` and `debug` levels have significant overhead
- Use `info` or `warn` for production builds
- Excessive logging can affect BLE timing and responsiveness

### 3. Android Logcat (adb-logs.sh)

View logs from Android devices using the `adb-logs.sh` script.

**Basic usage:**

```bash
# Show filtered logs (one-time dump)
./scripts/adb-logs.sh

# Follow logs continuously (like tail -f)
./scripts/adb-logs.sh --follow

# Show help
./scripts/adb-logs.sh --help
```

**What it does:**
1. Checks for connected Android device
2. Clears logcat buffer for clean output
3. Filters logs for relevant tags: `heart_beat`, `flutter`, `btleplug`, `BluetoothGatt`
4. Colorizes output by log level (red=ERROR, yellow=WARN, green=INFO)

**Use cases:**
- Real-time debugging during Android development
- Capture logs from device testing
- Monitor app behavior during BLE sessions
- Debug native Android issues

**Advanced filtering:**

The script filters for these tags by default:
- `heart_beat` - Rust FFI logs
- `flutter` - Flutter framework logs
- `btleplug` - BLE library logs
- `BluetoothGatt` - Android BLE stack logs

For custom filtering, use `adb logcat` directly:

```bash
# Show only ERROR logs
adb logcat | grep " E " | grep heart_beat

# Show logs with specific keyword
adb logcat | grep "heart rate"

# Show logs from specific PID
adb logcat --pid=$(adb shell pidof -s com.example.heart_beat)

# Save logs to file
./scripts/adb-logs.sh > debug.log
```

**Common issues:**

**No device connected:**
```bash
# Check device connection
adb devices

# If no devices shown:
# 1. Check USB cable
# 2. Enable USB debugging in Developer Options
# 3. Authorize computer on device
```

**Too many logs:**
```bash
# Use grep to narrow down
./scripts/adb-logs.sh --follow | grep "BLE"

# Reduce log level in Rust code
# Edit rust/src/lib.rs or module files
```

**Logs delayed or missing:**
```bash
# Restart ADB server
adb kill-server
adb start-server

# Clear and restart logging
adb logcat -c
./scripts/adb-logs.sh --follow
```

### 4. BLE HCI Snoop Logging (adb-ble-debug.sh)

Capture low-level Bluetooth HCI (Host Controller Interface) packets for deep BLE debugging.

**What is HCI snoop logging?**
- Records all Bluetooth packets between the host and controller
- Captures connection establishment, service discovery, characteristic reads/writes
- Output format compatible with Wireshark for analysis
- Critical for debugging BLE protocol issues

**Basic usage:**

```bash
# Enable HCI snoop logging
./scripts/adb-ble-debug.sh enable

# Check logging status
./scripts/adb-ble-debug.sh status

# Disable HCI snoop logging
./scripts/adb-ble-debug.sh disable
```

**What `enable` does:**
1. Enables `bluetooth_hci_log` setting on device
2. Restarts Bluetooth service to activate logging
3. Creates log file at `/data/misc/bluetooth/logs/btsnoop_hci.log`

**Retrieving the log file:**

```bash
# Enable root access (may not work on all devices)
adb root

# Pull the log file
adb pull /data/misc/bluetooth/logs/btsnoop_hci.log .

# If adb root fails, try:
adb shell "su -c 'cp /data/misc/bluetooth/logs/btsnoop_hci.log /sdcard/'"
adb pull /sdcard/btsnoop_hci.log .
```

**Analyzing with Wireshark:**

1. Install Wireshark: `sudo apt install wireshark`
2. Open `btsnoop_hci.log` in Wireshark
3. Use filters:
   - `bluetooth` - All Bluetooth traffic
   - `bthci_acl` - ACL data packets
   - `btatt` - ATT protocol (GATT operations)
   - `btle` - Bluetooth Low Energy

**Common BLE debugging scenarios:**

**Connection failures:**
```bash
# Enable logging
./scripts/adb-ble-debug.sh enable

# Reproduce the connection issue in the app

# Retrieve and analyze log
adb root
adb pull /data/misc/bluetooth/logs/btsnoop_hci.log .

# Look for:
# - Connection request packets
# - Connection complete events
# - Disconnection events with reason codes
```

**Service discovery issues:**
```bash
# Enable logging, reproduce issue, retrieve log

# In Wireshark, filter for:
# btatt.opcode == 0x10  (Read By Group Type - primary service discovery)
# btatt.opcode == 0x08  (Read By Type - characteristic discovery)
```

**Characteristic read/write failures:**
```bash
# Filter in Wireshark:
# btatt.opcode == 0x0a  (Read Request)
# btatt.opcode == 0x0b  (Read Response)
# btatt.opcode == 0x12  (Write Request)
# btatt.opcode == 0x13  (Write Response)
# btatt.opcode == 0x01  (Error Response)
```

**Performance considerations:**
- HCI logging adds overhead (~5-10% CPU)
- May affect BLE connection timing
- Log file can grow large (several MB for long sessions)
- Disable logging after capturing issue

**Disable when done:**
```bash
./scripts/adb-ble-debug.sh disable
```

### 5. Common Debugging Workflows

**BLE connection not working:**

1. Check device Bluetooth is enabled
2. Enable debug logging:
   ```bash
   RUST_LOG=heart_beat::ble=debug cargo run --bin cli
   ```
3. Check for error messages in logs
4. If issue persists, enable HCI snoop:
   ```bash
   ./scripts/adb-ble-debug.sh enable
   # Reproduce issue
   # Analyze with Wireshark
   ```

**Training calculations incorrect:**

1. Enable training module logging:
   ```bash
   RUST_LOG=heart_beat::training=debug cargo run --bin cli
   ```
2. Check heart rate zone calculations
3. Verify input data (heart rate values, zone thresholds)
4. Test with mock data:
   ```bash
   cargo run --bin cli --mock
   ```

**App crashes on Android:**

1. Capture crash logs:
   ```bash
   ./scripts/adb-logs.sh --follow > crash.log
   ```
2. Look for stack traces or panic messages
3. Check for null pointer dereferences or FFI issues
4. Reproduce with Linux Desktop build for easier debugging

**Performance issues:**

1. Profile with reduced logging:
   ```bash
   RUST_LOG=warn cargo run --bin cli
   ```
2. Monitor BLE event timing:
   ```bash
   RUST_LOG=heart_beat::ble=info cargo run --bin cli
   ```
3. Check for blocking operations in Rust code
4. Analyze HCI timing with Wireshark

### 6. Debugging Tips

**Use the right tool for the job:**
- **Quick checks:** Debug console (triple-tap)
- **Development:** `RUST_LOG` with `cargo run`
- **Android testing:** `adb-logs.sh --follow`
- **BLE protocol issues:** `adb-ble-debug.sh` + Wireshark

**Isolate the problem:**
- Test with mock mode first (`--mock` flag)
- Test on Linux Desktop before Android
- Reduce log noise by filtering specific modules

**Save logs for later:**
```bash
# Save to file with timestamps
./scripts/adb-logs.sh > "debug-$(date +%Y%m%d-%H%M%S).log"

# Or for continuous logging
./scripts/adb-logs.sh --follow | tee debug.log
```

**Don't debug blind:**
- Always enable appropriate log level
- Use `debug` or `trace` when investigating issues
- Reduce to `info` or `warn` after fixing

**Performance debugging:**
- Use `info` level to minimize overhead
- Profile with release builds (`cargo build --release`)
- Compare timings with and without logging

---

## Scripts Reference

This section documents all helper scripts in the `scripts/` directory. Each script automates common development tasks.

### Setup and Verification Scripts

#### dev-setup.sh

Automated development environment setup for first-time installation.

**Purpose:** Install and configure all dependencies needed for Heart Beat development.

**Usage:**
```bash
./scripts/dev-setup.sh
```

**What it does:**
1. Checks for Rust installation (installs via rustup if missing)
2. Checks for Flutter installation (provides instructions if missing)
3. Verifies Android SDK/NDK configuration
4. Installs Rust Android cross-compilation targets
5. Runs `flutter pub get` to install Flutter dependencies
6. Runs `flutter doctor` for comprehensive verification

**When to use:**
- First-time project setup
- Setting up a new development machine
- After major system updates
- When dependencies become outdated

**Exit codes:**
- `0` - Setup completed successfully
- `1` - Setup failed (check error messages)

#### check-deps.sh

Verifies all development dependencies are correctly installed and configured.

**Purpose:** Quick health check of your development environment.

**Usage:**
```bash
./scripts/check-deps.sh
```

**What it checks:**
- Rust toolchain (rustc, cargo, rustup)
- Flutter SDK and Dart version
- Android SDK location and components
- Android NDK version (ensures r25+)
- Rust Android targets
- System libraries (git, llvm tools)
- Project dependencies (flutter_rust_bridge, ffigen)

**Output:**
```
✓ rustc 1.75.0
✓ cargo 1.75.0
✓ Flutter 3.16.0
✓ ANDROID_HOME: /home/user/Android/Sdk
✓ NDK version 25.2.9519653 (>= r25 required)
✓ aarch64-linux-android
✓ All required dependencies are installed!
```

**When to use:**
- Before starting development work
- After running dev-setup.sh
- When troubleshooting build issues
- To verify environment after system updates

**Exit codes:**
- `0` - All dependencies OK
- `1` - Missing or misconfigured dependencies

### Build Scripts

#### dev-linux.sh

One-command build and launch for Linux desktop development.

**Purpose:** Build Rust library and launch Flutter Linux app in a single command.

**Usage:**
```bash
./scripts/dev-linux.sh [release|debug]
```

**Examples:**
```bash
./scripts/dev-linux.sh          # Build release mode (default)
./scripts/dev-linux.sh release  # Build release mode (faster runtime)
./scripts/dev-linux.sh debug    # Build debug mode (faster compilation)
```

**What it does:**
1. Builds Rust library (`libheart_beat.so`) in specified mode
2. Launches Flutter Linux app with `flutter run -d linux`
3. Provides colorized output showing build progress

**Build times:**
- Initial: ~2-4 minutes
- Incremental: ~10-30 seconds

**When to use:**
- Testing UI features on Linux
- Developing Flutter/Rust integration
- Quick testing without Android device
- Before deploying to Android

#### dev-watch.sh

Continuous development mode with auto-rebuild on file changes.

**Purpose:** Watch Rust source files and automatically rebuild when changes are detected.

**Prerequisites:**
```bash
cargo install cargo-watch
```

**Usage:**
```bash
./scripts/dev-watch.sh [release|debug]
```

**Examples:**
```bash
./scripts/dev-watch.sh          # Watch in release mode
./scripts/dev-watch.sh debug    # Watch in debug mode (faster builds)
```

**What it does:**
1. Performs initial Rust build
2. Launches Flutter Linux app in background
3. Watches `rust/src/` for file changes
4. Auto-rebuilds Rust library on changes
5. Restarts Flutter app after successful rebuild

**How to stop:**
- Press Ctrl+C (automatically kills Flutter app)

**When to use:**
- Active Rust development alongside Flutter
- Frequent Rust code changes
- Rapid iteration on core logic

**Note:** Flutter hot reload still works for Flutter-only changes.

#### build-rust-android.sh

Cross-compiles Rust library for all Android architectures.

**Purpose:** Build native Android libraries (.so files) for ARM and x86 targets.

**Usage:**
```bash
./scripts/build-rust-android.sh [release|debug]
```

**Examples:**
```bash
./scripts/build-rust-android.sh          # Build release (default)
./scripts/build-rust-android.sh release  # Build release with optimizations
./scripts/build-rust-android.sh debug    # Build debug (faster, larger)
```

**What it does:**
1. Verifies `ANDROID_NDK_HOME` is set
2. Configures NDK toolchain for each architecture
3. Builds for: `aarch64` (ARM64), `armv7` (ARM32), `x86_64`, `i686`
4. Copies .so files to `android/app/src/main/jniLibs/`
5. Strips symbols in release mode to reduce size

**Build times:**
- Initial: ~5-10 minutes
- Incremental: ~1-3 minutes

**Output:**
```
📦 Building for aarch64-linux-android (arm64-v8a)...
   ✓ Built and stripped (2.1M)
📦 Building for armv7-linux-androideabi (armeabi-v7a)...
   ✓ Built and stripped (1.8M)
```

**When to use:**
- Before building Android APK
- After Rust code changes
- When testing on Android devices

**Requirements:**
- `ANDROID_NDK_HOME` environment variable set
- Rust Android targets installed

### Android Deployment Scripts

#### adb-install.sh

One-command Android deployment: build, install, and launch.

**Purpose:** Streamlined Android deployment workflow.

**Usage:**
```bash
./scripts/adb-install.sh [--release|--debug]
```

**Examples:**
```bash
./scripts/adb-install.sh          # Deploy debug APK (default)
./scripts/adb-install.sh --debug  # Deploy debug APK
./scripts/adb-install.sh --release # Deploy release APK
```

**What it does:**
1. Checks for connected Android device
2. Builds APK using `build-android.sh`
3. Installs APK on device (replaces existing)
4. Launches Heart Beat app
5. Reports total deployment time

**Build + deploy time:**
- Initial: ~5-10 minutes
- Incremental: ~1-3 minutes
- Install + launch: ~10-30 seconds

**Output:**
```
[OK] Device connected: AB12CD34EF56
[STEP] Building debug APK...
[STEP] Installing APK on device...
[STEP] Launching Heart Beat app...

╔════════════════════════════════════════╗
║     Deployment Successful! 🎉          ║
╚════════════════════════════════════════╝

Total time: 3m 24s

Next steps:
  • Check logs: ./scripts/adb-logs.sh --follow
  • Debug mode: flutter run
```

**When to use:**
- Testing on real Android device
- Deploying after code changes
- QA testing before release
- BLE hardware testing

**Requirements:**
- Android device connected via USB
- USB debugging enabled
- Device authorized

#### adb-logs.sh

View filtered and colorized Android logcat output.

**Purpose:** Monitor app logs from Android device with automatic filtering.

**Usage:**
```bash
./scripts/adb-logs.sh [OPTIONS]
```

**Options:**
- `--follow, -f` - Continuous log output (like `tail -f`)
- `--help, -h` - Show help message

**Examples:**
```bash
./scripts/adb-logs.sh              # Show logs once
./scripts/adb-logs.sh --follow     # Follow logs continuously
./scripts/adb-logs.sh -f           # Short form
```

**What it does:**
1. Checks for connected device
2. Clears logcat buffer
3. Filters logs for: `heart_beat`, `flutter`, `btleplug`, `BluetoothGatt`
4. Colorizes by level: ERROR (red), WARN (yellow), INFO (green)

**Output:**
```
[OK] Device connected
[INFO] Clearing logcat buffer...
[INFO] Showing filtered logs...

I/heart_beat: BLE adapter initialized
D/btleplug: Starting device scan...
I/flutter: UI initialized
```

**When to use:**
- Real-time debugging during development
- Monitoring app behavior
- Capturing error messages
- BLE debugging

**Tip:** Save logs to file:
```bash
./scripts/adb-logs.sh > debug.log
./scripts/adb-logs.sh --follow | tee debug.log
```

#### adb-permissions.sh

Check and display app permissions, highlighting BLE/Location permissions.

**Purpose:** Verify Bluetooth and Location permissions are granted.

**Usage:**
```bash
./scripts/adb-permissions.sh [--all]
```

**Options:**
- `--all` - Show all permissions (not just BLE-related)

**Examples:**
```bash
./scripts/adb-permissions.sh        # Show BLE permissions only
./scripts/adb-permissions.sh --all  # Show all permissions
```

**What it shows:**
- `BLUETOOTH_SCAN` - Required for BLE device discovery
- `BLUETOOTH_CONNECT` - Required for BLE connections
- `BLUETOOTH_ADVERTISE` - Required for advertising
- `ACCESS_FINE_LOCATION` - Required for BLE on Android
- `ACCESS_COARSE_LOCATION` - Alternative location permission

**Output:**
```
Declared Permissions:

  ✓ BLUETOOTH_SCAN: GRANTED
  ✓ BLUETOOTH_CONNECT: GRANTED
  ✗ ACCESS_FINE_LOCATION: DENIED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:

  Bluetooth/Location permissions:
    Granted: 2
    Denied:  1

[WARN] Some Bluetooth/Location permissions are denied

For full BLE functionality, grant these permissions:
  • Settings → Apps → Heart Beat → Permissions
  • Enable all Bluetooth and Location permissions
```

**When to use:**
- Debugging BLE connection issues
- Verifying app setup
- After fresh installation
- Troubleshooting permission errors

#### adb-ble-debug.sh

Enable/disable Bluetooth HCI snoop logging for low-level BLE debugging.

**Purpose:** Capture raw Bluetooth packets for Wireshark analysis.

**Usage:**
```bash
./scripts/adb-ble-debug.sh <command>
```

**Commands:**
- `enable` - Enable HCI logging and restart Bluetooth
- `disable` - Disable HCI logging and restart Bluetooth
- `status` - Show current logging status
- `help` - Show help message

**Examples:**
```bash
./scripts/adb-ble-debug.sh enable   # Enable logging
./scripts/adb-ble-debug.sh status   # Check if enabled
./scripts/adb-ble-debug.sh disable  # Disable logging
```

**What it does:**
1. Enables `bluetooth_hci_log` setting on device
2. Restarts Bluetooth service
3. Logs HCI packets to `/data/misc/bluetooth/logs/btsnoop_hci.log`

**Retrieving logs:**
```bash
adb root
adb pull /data/misc/bluetooth/logs/btsnoop_hci.log .
```

**Analyzing with Wireshark:**
1. Open `btsnoop_hci.log` in Wireshark
2. Filter: `bluetooth`, `btatt`, `bthci_acl`, `btle`
3. Analyze connection events, GATT operations, errors

**When to use:**
- Deep BLE protocol debugging
- Connection failure analysis
- Service discovery issues
- Characteristic read/write failures
- Performance analysis

**Warning:** HCI logging adds overhead (~5-10% CPU). Disable after capturing issue.

### BLE Setup Scripts (Linux Only)

#### ble-setup.sh

Configure Linux system for BLE heart rate monitor access.

**Purpose:** Set up Bluetooth permissions, services, and udev rules for BLE development.

**Usage:**
```bash
sudo ./scripts/ble-setup.sh
```

**What it does:**
1. Installs Bluetooth packages: `bluez`, `bluez-tools`, `bluetooth`, `libbluetooth-dev`
2. Enables and starts Bluetooth service
3. Checks Bluetooth adapter (hci0) and brings it UP
4. Adds user to `bluetooth` and `plugdev` groups
5. Creates udev rules for BLE device access
6. Powers on Bluetooth adapter

**Output:**
```
[1/6] Checking Bluetooth packages...
[OK] bluez is installed
[2/6] Enabling Bluetooth service...
[OK] Bluetooth service is running
[3/6] Checking Bluetooth adapter...
[OK] Bluetooth adapter is UP and RUNNING
[OK] Bluetooth adapter supports BLE
...
[OK] BLE Setup Complete!
```

**When to use:**
- First-time Linux setup for BLE
- After system reinstallation
- When BLE permission errors occur

**Important:** Log out and log back in after running for group changes to take effect.

#### ble-pair.sh

Scan for and pair with BLE heart rate monitors.

**Purpose:** Interactive pairing workflow for heart rate chest straps.

**Usage:**
```bash
./scripts/ble-pair.sh [OPTIONS]
```

**Options:**
- `-h, --help` - Show help message
- `-s, --scan` - Force new scan (ignore saved device)
- `-d, --duration <seconds>` - Scan duration (default: 10)

**Examples:**
```bash
./scripts/ble-pair.sh              # Normal pairing
./scripts/ble-pair.sh --scan       # Force scan for new device
SCAN_DURATION=20 ./scripts/ble-pair.sh  # Longer scan
```

**Interactive workflow:**
1. Checks prerequisites (bluetoothctl, Bluetooth service)
2. Checks for previously paired device
3. Prompts to wear heart rate strap
4. Scans for HR monitors (looks for: HW9, CooSpo, Polar, Garmin, Wahoo)
5. Displays discovered devices
6. Pairs, trusts, and verifies connection
7. Saves device config to `~/.heart-beat/device.conf`

**Output:**
```
======================================
  IMPORTANT: Prepare Your Device
======================================

Heart rate monitors only broadcast when worn:
  1. Moisten the sensor pads on the chest strap
  2. Put on the chest strap
  3. Wait a few seconds for skin contact detection

Press ENTER when you're wearing the device...

[INFO] Scanning for BLE heart rate monitors (10s)...

[OK] Found 1 heart rate monitor(s):

  [1] HW9 (F4:8C:C9:1B:E6:1B)

[OK] Selected: HW9 (F4:8C:C9:1B:E6:1B)
[OK] Pairing successful
[OK] Device trusted
[OK] Connected to device
```

**Saved configuration:**
```
~/.heart-beat/device.conf
```

**When to use:**
- First-time device setup
- Pairing new heart rate monitor
- Switching between devices

#### ble-realtime.sh

Connect to paired device and display real-time heart rate data.

**Purpose:** Monitor heart rate data in terminal for testing.

**Usage:**
```bash
./scripts/ble-realtime.sh [OPTIONS] [DEVICE_MAC]
```

**Options:**
- `-h, --help` - Show help message
- `-s, --simple` - Simple status monitor (no HR data)

**Examples:**
```bash
./scripts/ble-realtime.sh                    # Use saved device
./scripts/ble-realtime.sh F4:8C:C9:1B:E6:1B # Specify MAC
./scripts/ble-realtime.sh --simple           # Status only
```

**What it does:**
1. Loads device config from `~/.heart-beat/device.conf`
2. Connects to device via bluetoothctl
3. Monitors heart rate characteristic
4. Displays BPM values in real-time

**Output:**
```
======================================
  Real-time Heart Rate Data
======================================

Press Ctrl+C to stop monitoring

Timestamp            BPM           Status
-----------------------------------------------
14:32:15             72 BPM        OK
14:32:16             74 BPM        OK
14:32:17             75 BPM        OK
```

**When to use:**
- Testing BLE connectivity
- Verifying heart rate monitor works
- Debugging before app development
- Quick HR monitor check

**Requirements:**
- Device paired via `ble-pair.sh`
- Python with `bleak` library (optional but recommended)
- Or `gatttool` for fallback

### Script Dependencies

**All scripts:**
- Bash 4.0+
- Core utilities (grep, sed, awk)

**Android scripts:**
- Android SDK with `adb` in PATH
- USB debugging enabled on device

**Linux desktop scripts:**
- Rust toolchain
- Flutter SDK
- Linux development libraries

**BLE scripts (Linux):**
- BlueZ stack (`bluez`, `bluez-tools`)
- Bluetooth adapter (hci0)
- Python 3.8+ with `bleak` (optional)

### Common Script Workflows

**First-time setup:**
```bash
./scripts/dev-setup.sh
./scripts/check-deps.sh
```

**Linux desktop development:**
```bash
./scripts/dev-linux.sh debug
# Make changes, hot reload Flutter
# For Rust changes, Ctrl+C and re-run
```

**Watch mode development:**
```bash
./scripts/dev-watch.sh debug
# Edit Rust files, auto-rebuilds
# Edit Flutter files, hot reload
```

**Android deployment:**
```bash
./scripts/adb-install.sh
./scripts/adb-logs.sh --follow
# Test app, monitor logs
```

**BLE debugging (Linux):**
```bash
sudo ./scripts/ble-setup.sh
./scripts/ble-pair.sh
./scripts/ble-realtime.sh
```

**BLE debugging (Android):**
```bash
./scripts/adb-permissions.sh
./scripts/adb-ble-debug.sh enable
# Reproduce issue
adb pull /data/misc/bluetooth/logs/btsnoop_hci.log .
./scripts/adb-ble-debug.sh disable
```

---
