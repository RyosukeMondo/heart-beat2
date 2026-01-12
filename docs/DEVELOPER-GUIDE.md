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

For development workflows and debugging guides, continue reading the sections below.
