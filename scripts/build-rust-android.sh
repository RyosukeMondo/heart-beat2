#!/bin/bash
# Build Rust libraries for all Android architectures
#
# This script compiles the Rust library for all Android target architectures
# and copies the resulting .so files to the appropriate jniLibs directories
# for inclusion in the APK.
#
# Usage:
#   ./scripts/build-rust-android.sh [release|debug]
#
# Examples:
#   ./scripts/build-rust-android.sh          # Build release mode (default)
#   ./scripts/build-rust-android.sh release  # Build release mode
#   ./scripts/build-rust-android.sh debug    # Build debug mode

set -e

# Check ANDROID_NDK_HOME is set
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "❌ Error: ANDROID_NDK_HOME environment variable is not set"
    echo ""
    echo "Please set ANDROID_NDK_HOME to your NDK installation path:"
    echo "  export ANDROID_NDK_HOME=/path/to/android/sdk/ndk/25.2.9519653"
    echo ""
    echo "Or add it to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "  echo 'export ANDROID_NDK_HOME=\$HOME/Android/Sdk/ndk/25.2.9519653' >> ~/.bashrc"
    exit 1
fi

# Determine build mode (default: release)
BUILD_MODE="${1:-release}"
CARGO_FLAGS=""
BUILD_DIR="release"

if [ "$BUILD_MODE" = "debug" ]; then
    BUILD_DIR="debug"
    echo "🛠️  Building in DEBUG mode"
else
    CARGO_FLAGS="--release"
    echo "🚀 Building in RELEASE mode"
fi

# Target configurations: rust_target:android_abi
TARGETS=(
    "aarch64-linux-android:arm64-v8a"
    "armv7-linux-androideabi:armeabi-v7a"
    "x86_64-linux-android:x86_64"
    "i686-linux-android:x86"
)

# Change to rust directory
cd rust

echo ""
echo "Building Rust libraries for Android..."
echo "======================================="

# Build for each target
for target_pair in "${TARGETS[@]}"; do
    IFS=':' read -r rust_target android_abi <<< "$target_pair"

    echo ""
    echo "📦 Building for $rust_target ($android_abi)..."

    # Build with cargo
    cargo build $CARGO_FLAGS --target "$rust_target"

    # Create jniLibs directory
    mkdir -p "../android/app/src/main/jniLibs/$android_abi"

    # Copy library to jniLibs
    cp "target/$rust_target/$BUILD_DIR/libheart_beat.so" \
       "../android/app/src/main/jniLibs/$android_abi/"

    # Strip symbols in release mode
    if [ "$BUILD_MODE" = "release" ]; then
        "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" \
            "../android/app/src/main/jniLibs/$android_abi/libheart_beat.so"

        # Get file size after stripping
        SIZE=$(du -h "../android/app/src/main/jniLibs/$android_abi/libheart_beat.so" | cut -f1)
        echo "   ✓ Built and stripped ($SIZE)"
    else
        # Get file size (debug build)
        SIZE=$(du -h "../android/app/src/main/jniLibs/$android_abi/libheart_beat.so" | cut -f1)
        echo "   ✓ Built ($SIZE)"
    fi
done

cd ..

echo ""
echo "✅ All architectures built successfully!"
echo ""
echo "Libraries copied to:"
for target_pair in "${TARGETS[@]}"; do
    IFS=':' read -r rust_target android_abi <<< "$target_pair"
    echo "  - android/app/src/main/jniLibs/$android_abi/libheart_beat.so"
done
