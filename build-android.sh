#!/bin/bash
# Complete build script for Android APK
#
# This script orchestrates the entire Android build process:
# 1. Generate Flutter-Rust bridge bindings
# 2. Build Rust native libraries for all Android architectures
# 3. Build the Flutter APK
#
# Usage:
#   ./build-android.sh [OPTIONS]
#
# Options:
#   --release              Build in release mode (default)
#   --debug                Build in debug mode
#   --clean                Run flutter clean before building
#   --architectures ABIS   Build specific ABIs only (comma-separated: arm64-v8a,armeabi-v7a,x86_64,x86)
#   --help                 Show this help message
#
# Examples:
#   ./build-android.sh                                    # Build release APK
#   ./build-android.sh --debug                            # Build debug APK
#   ./build-android.sh --clean --release                  # Clean build release APK
#   ./build-android.sh --architectures arm64-v8a,x86_64   # Build only for specific architectures

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
BUILD_MODE="release"
CLEAN_BUILD=false
SPECIFIC_ARCHITECTURES=""

# Function to display help
show_help() {
    echo "Complete Android Build Script"
    echo ""
    echo "Usage: ./build-android.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --release              Build in release mode (default)"
    echo "  --debug                Build in debug mode"
    echo "  --clean                Run flutter clean before building"
    echo "  --architectures ABIS   Build specific ABIs only (comma-separated)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./build-android.sh                                    # Build release APK"
    echo "  ./build-android.sh --debug                            # Build debug APK"
    echo "  ./build-android.sh --clean --release                  # Clean build release APK"
    echo "  ./build-android.sh --architectures arm64-v8a,x86_64   # Build specific architectures"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --debug)
            BUILD_MODE="debug"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --architectures)
            SPECIFIC_ARCHITECTURES="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Run './build-android.sh --help' for usage information"
            exit 1
            ;;
    esac
done

# Record start time
START_TIME=$(date +%s)

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Android Build Script for Heart Beat  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Build mode: ${YELLOW}${BUILD_MODE}${NC}"
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "Clean build: ${YELLOW}enabled${NC}"
fi
if [ -n "$SPECIFIC_ARCHITECTURES" ]; then
    echo -e "Architectures: ${YELLOW}${SPECIFIC_ARCHITECTURES}${NC}"
fi
echo ""

# Step 0: Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${BLUE}[0/3]${NC} Cleaning previous build..."
    echo "======================================="
    flutter clean
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Step 1: Generate Flutter-Rust bridge bindings
echo -e "${BLUE}[1/3]${NC} Generating Flutter-Rust bridge bindings..."
echo "======================================="
if command -v flutter_rust_bridge_codegen &> /dev/null; then
    flutter_rust_bridge_codegen generate
    echo -e "${GREEN}✓ Bindings generated${NC}"
else
    echo -e "${RED}❌ flutter_rust_bridge_codegen not found${NC}"
    echo ""
    echo "Please install it with:"
    echo "  cargo install flutter_rust_bridge_codegen"
    exit 1
fi
echo ""

# Step 2: Build Rust native libraries
echo -e "${BLUE}[2/3]${NC} Building Rust native libraries..."
echo "======================================="
if [ -f "scripts/build-rust-android.sh" ]; then
    # If specific architectures are requested, we need to modify the build script
    # For now, we'll just call the script with the build mode
    # TODO: Add architecture filtering support to build-rust-android.sh
    if [ -n "$SPECIFIC_ARCHITECTURES" ]; then
        echo -e "${YELLOW}⚠ Note: Architecture filtering not yet implemented in build-rust-android.sh${NC}"
        echo -e "${YELLOW}  Building all architectures...${NC}"
        echo ""
    fi

    bash scripts/build-rust-android.sh "$BUILD_MODE"
    echo -e "${GREEN}✓ Rust libraries built${NC}"
else
    echo -e "${RED}❌ scripts/build-rust-android.sh not found${NC}"
    exit 1
fi
echo ""

# Step 3: Build Flutter APK
echo -e "${BLUE}[3/3]${NC} Building Flutter APK..."
echo "======================================="
FLUTTER_BUILD_FLAGS=""
if [ "$BUILD_MODE" = "release" ]; then
    FLUTTER_BUILD_FLAGS="--release"
else
    FLUTTER_BUILD_FLAGS="--debug"
fi

# Add architecture filtering if specified
if [ -n "$SPECIFIC_ARCHITECTURES" ]; then
    FLUTTER_BUILD_FLAGS="$FLUTTER_BUILD_FLAGS --target-platform android-arm64"
    # Note: Flutter's --target-platform is limited. For full control,
    # we'd need to modify build.gradle's abiFilters
    echo -e "${YELLOW}⚠ Note: Architecture filtering in Flutter build is limited${NC}"
    echo -e "${YELLOW}  Use build.gradle's abiFilters for precise control${NC}"
    echo ""
fi

flutter build apk $FLUTTER_BUILD_FLAGS
echo -e "${GREEN}✓ APK built${NC}"
echo ""

# Calculate build time
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
MINUTES=$((BUILD_TIME / 60))
SECONDS=$((BUILD_TIME % 60))

# Get APK information
if [ "$BUILD_MODE" = "release" ]; then
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
else
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Build Successful! 🎉           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo -e "APK location: ${BLUE}$APK_PATH${NC}"
    echo -e "APK size:     ${BLUE}$APK_SIZE${NC}"
else
    echo -e "${YELLOW}⚠ APK not found at expected location${NC}"
    echo -e "  Check build/app/outputs/flutter-apk/ directory"
fi

echo -e "Build time:   ${BLUE}${MINUTES}m ${SECONDS}s${NC}"
echo ""

# Show next steps
echo "Next steps:"
if [ "$BUILD_MODE" = "release" ]; then
    echo "  • Install: adb install $APK_PATH"
    echo "  • Test on device or emulator"
else
    echo "  • Install: adb install $APK_PATH"
    echo "  • Run: flutter run"
    echo "  • Debug: flutter logs"
fi
echo ""
