#!/bin/bash
# ADB Install Script for Heart Beat Android Deployment
# One-command build, install, and launch for Android devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
BUILD_MODE="debug"
APP_PACKAGE="com.example.heart_beat"
MAIN_ACTIVITY="MainActivity"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Android Deploy${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --release       Build and install release APK"
    echo "  --debug         Build and install debug APK (default)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "This script will:"
    echo "  1. Check for connected Android device"
    echo "  2. Build the APK using build-android.sh"
    echo "  3. Install the APK on the device"
    echo "  4. Launch the Heart Beat app"
    exit 0
}

check_device() {
    if ! command -v adb &> /dev/null; then
        print_error "adb command not found. Please install Android SDK Platform Tools."
        exit 1
    fi

    local device_count
    device_count=$(adb devices | grep -c "device$" || true)

    if [ "$device_count" -eq 0 ]; then
        print_error "No Android device connected"
        echo ""
        echo "Please connect a device and ensure USB debugging is enabled:"
        echo "  1. Connect device via USB"
        echo "  2. Enable Developer Options"
        echo "  3. Enable USB Debugging"
        echo "  4. Authorize this computer on the device"
        echo ""
        echo "Run 'adb devices' to verify connection"
        exit 1
    fi

    local device_name
    device_name=$(adb devices | grep "device$" | head -1 | awk '{print $1}')
    print_success "Device connected: $device_name"
}

build_apk() {
    local mode=$1
    print_step "Building $mode APK..."
    echo ""

    # Check if build-android.sh exists
    if [ ! -f "./build-android.sh" ]; then
        print_error "build-android.sh not found in current directory"
        echo "Please run this script from the project root"
        exit 1
    fi

    # Set ANDROID_NDK_HOME if not already set
    if [ -z "$ANDROID_NDK_HOME" ]; then
        # Try to find NDK in common locations
        if [ -d "$HOME/Android/Sdk/ndk" ]; then
            # Find the latest NDK version
            LATEST_NDK=$(ls -1 "$HOME/Android/Sdk/ndk" | sort -V | tail -1)
            if [ -n "$LATEST_NDK" ]; then
                export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$LATEST_NDK"
                print_info "Set ANDROID_NDK_HOME to $ANDROID_NDK_HOME"
            fi
        fi
    fi

    # Build the APK
    if [ "$mode" = "release" ]; then
        ./build-android.sh --release
    else
        ./build-android.sh --debug
    fi

    print_success "Build completed"
}

install_apk() {
    local mode=$1
    print_step "Installing APK on device..."
    echo ""

    # Determine APK path based on build mode
    if [ "$mode" = "release" ]; then
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    else
        APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    fi

    # Verify APK exists
    if [ ! -f "$APK_PATH" ]; then
        print_error "APK not found at $APK_PATH"
        exit 1
    fi

    # Install with -r flag to replace existing app
    print_info "Installing from $APK_PATH"
    if adb install -r "$APK_PATH"; then
        print_success "Installation successful"
    else
        print_error "Installation failed"
        exit 1
    fi
}

launch_app() {
    print_step "Launching Heart Beat app..."
    echo ""

    # Launch the app
    if adb shell am start -n "$APP_PACKAGE/.$MAIN_ACTIVITY"; then
        print_success "App launched successfully"
    else
        print_error "Failed to launch app"
        echo ""
        echo "You can manually launch the app from the device"
        exit 1
    fi
}

main() {
    # Parse arguments
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
            --help|-h)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    print_header
    print_info "Build mode: $BUILD_MODE"
    echo ""

    # Record start time
    START_TIME=$(date +%s)

    # Execute deployment steps
    check_device
    echo ""

    build_apk "$BUILD_MODE"
    echo ""

    install_apk "$BUILD_MODE"
    echo ""

    launch_app
    echo ""

    # Calculate deployment time
    END_TIME=$(date +%s)
    DEPLOY_TIME=$((END_TIME - START_TIME))
    MINUTES=$((DEPLOY_TIME / 60))
    SECONDS=$((DEPLOY_TIME % 60))

    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Deployment Successful! 🎉          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Total time: ${BLUE}${MINUTES}m ${SECONDS}s${NC}"
    echo ""
    echo "Next steps:"
    echo "  • Check logs: ./scripts/adb-logs.sh --follow"
    echo "  • Debug mode: flutter run"
    echo ""
}

main "$@"
