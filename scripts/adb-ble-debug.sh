#!/bin/bash
# ADB BLE Debug Script for Heart Beat Android Debugging
# Enables/disables HCI snoop logging and manages Bluetooth service

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
    echo -e "${BLUE}  Heart Beat BLE Debug Manager${NC}"
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

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  enable     Enable HCI snoop logging and restart Bluetooth"
    echo "  disable    Disable HCI snoop logging and restart Bluetooth"
    echo "  status     Show current HCI snoop logging status"
    echo "  help       Show this help message"
    echo ""
    echo "Description:"
    echo "  HCI snoop logging captures low-level Bluetooth packets for debugging."
    echo "  Logs are saved to: /data/misc/bluetooth/logs/btsnoop_hci.log"
    echo ""
    echo "Requirements:"
    echo "  - USB debugging enabled"
    echo "  - Device connected via adb"
    echo ""
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

get_hci_status() {
    local status
    status=$(adb shell settings get secure bluetooth_hci_log 2>/dev/null || echo "unknown")
    echo "$status"
}

show_status() {
    print_info "Checking HCI snoop logging status..."

    local status
    status=$(get_hci_status)

    echo ""
    case "$status" in
        1)
            print_success "HCI snoop logging is ENABLED"
            echo ""
            echo -e "${CYAN}Log location:${NC} /data/misc/bluetooth/logs/btsnoop_hci.log"
            echo ""
            echo "To retrieve the log file:"
            echo "  adb root"
            echo "  adb pull /data/misc/bluetooth/logs/btsnoop_hci.log ."
            echo ""
            echo "To analyze with Wireshark:"
            echo "  1. Open btsnoop_hci.log in Wireshark"
            echo "  2. Filter for 'bluetooth' or 'bthci' packets"
            ;;
        0)
            print_warning "HCI snoop logging is DISABLED"
            echo ""
            echo "To enable, run: $0 enable"
            ;;
        *)
            print_error "Could not determine HCI snoop logging status"
            echo ""
            echo "Status value: $status"
            ;;
    esac
}

enable_hci_logging() {
    print_info "Enabling HCI snoop logging..."

    # Enable HCI snoop logging
    adb shell settings put secure bluetooth_hci_log 1

    print_success "HCI snoop logging enabled"

    # Restart Bluetooth service
    print_info "Restarting Bluetooth service..."
    adb shell svc bluetooth disable
    sleep 2
    adb shell svc bluetooth enable
    sleep 2

    print_success "Bluetooth service restarted"
    echo ""
    print_success "HCI snoop logging is now active"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Use your BLE app to reproduce the issue"
    echo "  2. Retrieve the log: adb root && adb pull /data/misc/bluetooth/logs/btsnoop_hci.log ."
    echo "  3. Analyze with Wireshark or btsnoop tool"
    echo ""
    print_warning "Note: Logging adds overhead and may affect BLE performance"
}

disable_hci_logging() {
    print_info "Disabling HCI snoop logging..."

    # Disable HCI snoop logging
    adb shell settings put secure bluetooth_hci_log 0

    print_success "HCI snoop logging disabled"

    # Restart Bluetooth service
    print_info "Restarting Bluetooth service..."
    adb shell svc bluetooth disable
    sleep 2
    adb shell svc bluetooth enable
    sleep 2

    print_success "Bluetooth service restarted"
    echo ""
    print_success "HCI snoop logging is now inactive"
}

main() {
    if [ $# -eq 0 ]; then
        print_error "No command specified"
        usage
    fi

    local command=$1

    case "$command" in
        enable)
            print_header
            check_device
            enable_hci_logging
            ;;
        disable)
            print_header
            check_device
            disable_hci_logging
            ;;
        status)
            print_header
            check_device
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $command"
            usage
            ;;
    esac
}

main "$@"
