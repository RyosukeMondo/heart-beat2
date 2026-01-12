#!/bin/bash
# ADB Logs Script for Heart Beat Android Debugging
# Filters and displays colorized logcat output for heart rate monitoring app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Android Logs${NC}"
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

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --follow, -f    Follow log output (continuous mode)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Filters logs for: heart_beat, flutter, btleplug, BluetoothGatt"
    echo "Color codes: ERROR (red), WARN (yellow), INFO (green)"
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

    print_success "Device connected"
}

clear_logcat() {
    print_info "Clearing logcat buffer..."
    adb logcat -c
    print_success "Logcat cleared"
}

colorize_line() {
    local line="$1"

    # Color by log level
    if echo "$line" | grep -q " E "; then
        # ERROR - red
        echo -e "${RED}${line}${NC}"
    elif echo "$line" | grep -q " W "; then
        # WARN - yellow
        echo -e "${YELLOW}${line}${NC}"
    elif echo "$line" | grep -q " I "; then
        # INFO - green
        echo -e "${GREEN}${line}${NC}"
    else
        # Default
        echo "$line"
    fi
}

show_logs() {
    local follow_mode=$1

    if [ "$follow_mode" = "true" ]; then
        print_info "Starting continuous log output (Ctrl+C to stop)..."
        echo ""
        adb logcat | grep -E "heart_beat|flutter|btleplug|BluetoothGatt" | while IFS= read -r line; do
            colorize_line "$line"
        done
    else
        print_info "Showing filtered logs..."
        echo ""
        adb logcat -d | grep -E "heart_beat|flutter|btleplug|BluetoothGatt" | while IFS= read -r line; do
            colorize_line "$line"
        done
    fi
}

main() {
    local follow_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --follow|-f)
                follow_mode=true
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
    check_device
    clear_logcat
    show_logs "$follow_mode"
}

main "$@"
