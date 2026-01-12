#!/bin/bash
# BLE Real-time Heart Rate Monitor for Heart Beat
# Connects to a paired device and displays real-time heart rate data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
CONFIG_DIR="$HOME/.heart-beat"
DEVICE_CONFIG="$CONFIG_DIR/device.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Device info (loaded from config or args)
DEVICE_MAC=""
DEVICE_NAME=""

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Real-time Monitor${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

load_device_config() {
    if [ -n "$1" ]; then
        # MAC address provided as argument
        DEVICE_MAC="$1"
        DEVICE_NAME="Unknown"
        return 0
    fi

    if [ -f "$DEVICE_CONFIG" ]; then
        source "$DEVICE_CONFIG"
        if [ -n "$DEVICE_MAC" ]; then
            print_info "Using saved device: $DEVICE_NAME ($DEVICE_MAC)"
            return 0
        fi
    fi

    print_error "No device configured"
    echo ""
    echo "Either:"
    echo "  1. Run ./scripts/ble-pair.sh first"
    echo "  2. Provide MAC address: $0 XX:XX:XX:XX:XX:XX"
    exit 1
}

check_device_wearing() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}  Ready to Monitor${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
    echo "Device: $DEVICE_NAME"
    echo "MAC:    $DEVICE_MAC"
    echo ""
    echo "Make sure you are wearing the heart rate monitor!"
    echo ""
    read -p "Press ENTER to start monitoring (Ctrl+C to stop)..."
    echo ""
}

connect_device() {
    print_info "Connecting to $DEVICE_NAME..."

    # Ensure device is connected
    local result
    result=$(
        (
            echo "power on"
            sleep 1
            echo "connect $DEVICE_MAC"
            sleep 3
            echo "quit"
        ) | bluetoothctl 2>&1
    )

    if echo "$result" | grep -q "Connection successful\|Connected: yes"; then
        print_success "Connected"
        return 0
    else
        print_warning "Connection may have issues, trying to continue..."
        return 0
    fi
}

check_rust_cli() {
    # Check if the Rust CLI is built
    local cli_path="$PROJECT_ROOT/rust/target/release/cli"
    local cli_debug_path="$PROJECT_ROOT/rust/target/debug/cli"

    if [ -x "$cli_path" ]; then
        echo "$cli_path"
        return 0
    elif [ -x "$cli_debug_path" ]; then
        echo "$cli_debug_path"
        return 0
    fi

    return 1
}

run_with_rust_cli() {
    local cli_path="$1"

    print_info "Using Heart Beat CLI for monitoring"
    print_info "Scanning for device first..."

    # The CLI needs to scan first to discover the btleplug device ID
    # Run scan, find the device, then connect
    local scan_output
    scan_output=$("$cli_path" devices scan 2>&1) || true

    # Extract device ID from scan output (look for our device name)
    local device_id
    device_id=$(echo "$scan_output" | grep -i "HW9\|$DEVICE_NAME" | grep -oE '[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}' | head -1)

    if [ -z "$device_id" ]; then
        # Try using the MAC address directly (some btleplug versions support this)
        device_id="$DEVICE_MAC"
    fi

    echo ""
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  Real-time Heart Rate Data${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    echo ""

    "$cli_path" devices connect "$device_id"
}

# Parse heart rate measurement from raw BLE data
# Heart Rate Measurement format (simplified):
# Byte 0: Flags
#   Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
# Byte 1 (or 1-2): Heart Rate Value
parse_hr_value() {
    local hex_data="$1"

    # Remove spaces and convert to array
    local bytes=($hex_data)

    if [ ${#bytes[@]} -lt 2 ]; then
        echo "?"
        return
    fi

    local flags=$((16#${bytes[0]}))
    local hr_format=$((flags & 0x01))

    if [ $hr_format -eq 0 ]; then
        # UINT8 format
        echo $((16#${bytes[1]}))
    else
        # UINT16 format (little endian)
        echo $(( (16#${bytes[2]} << 8) | 16#${bytes[1]} ))
    fi
}

discover_hr_handle() {
    # Discover the Heart Rate Measurement characteristic handle
    # HR Measurement UUID: 2a37
    print_info "Discovering Heart Rate characteristic..."

    # Use gatttool interactive mode with random address type
    local chars
    chars=$(timeout 15 bash -c '
        (sleep 1; echo "connect"; sleep 4; echo "char-desc"; sleep 2; echo "quit") | \
        gatttool -t random -b '"$DEVICE_MAC"' -I 2>&1
    ' || true)

    # Look for the HR measurement characteristic (uuid 00002a37)
    local hr_handle
    hr_handle=$(echo "$chars" | grep -i "2a37" | grep -oP 'handle: 0x\K[0-9a-fA-F]+' | head -1)

    if [ -n "$hr_handle" ]; then
        echo "0x$hr_handle"
        return 0
    fi

    # Fallback: common handle for Coospo HW9
    echo "0x0029"
    return 0
}

run_with_gatttool() {
    print_info "Using gatttool for monitoring"
    echo ""

    # For Coospo HW9: HR handle = 0x0029, CCCD = 0x002a
    # Discover dynamically or use known values
    local hr_handle="0x0029"
    local cccd_handle="0x002a"

    print_info "HR handle: $hr_handle, CCCD: $cccd_handle"

    echo ""
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  Real-time Heart Rate Data${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    echo ""

    printf "%-20s %10s %15s\n" "Timestamp" "BPM" "Status"
    echo "-----------------------------------------------"

    # Use gatttool interactive mode with random address type
    # Enable notifications and listen
    (
        sleep 1
        echo "connect"
        sleep 5
        echo "char-write-req $cccd_handle 0100"
        # Keep running to receive notifications
        sleep 300
    ) | gatttool -t random -b "$DEVICE_MAC" -I --listen 2>&1 | while read -r line; do
        # Strip ANSI escape codes
        clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\[K//g')

        if [[ "$clean_line" =~ "Notification handle".*"value:"[[:space:]]*(.*) ]]; then
            local hex_data="${BASH_REMATCH[1]}"
            local hr
            hr=$(parse_hr_value "$hex_data")
            local timestamp
            timestamp=$(date +"%H:%M:%S")

            if [ "$hr" != "?" ] && [ "$hr" -gt 30 ] && [ "$hr" -lt 220 ]; then
                printf "%-20s %10s %15s\n" "$timestamp" "$hr BPM" "OK"
            else
                printf "%-20s %10s %15s\n" "$timestamp" "$hr" "invalid"
            fi
        elif [[ "$clean_line" =~ "Connection successful" ]]; then
            print_success "Connected to device"
        elif [[ "$clean_line" =~ "Characteristic value was written" ]]; then
            print_success "Notifications enabled"
        fi
    done
}

run_with_python() {
    # Python script handles all prompts and connection
    "$SCRIPT_DIR/.venv/bin/python" -u "$SCRIPT_DIR/ble_hr_monitor.py" "$DEVICE_MAC"
}

run_with_simple_monitor() {
    print_info "Using bluetoothctl for basic monitoring"
    echo ""

    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  Device Status Monitor${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""
    echo "Press Ctrl+C to stop"
    echo ""

    # Poll device info periodically
    while true; do
        local info
        info=$(bluetoothctl info "$DEVICE_MAC" 2>&1)

        local connected="No"
        local battery="N/A"

        if echo "$info" | grep -q "Connected: yes"; then
            connected="Yes"
        fi

        local bat_hex
        bat_hex=$(echo "$info" | grep "Battery Percentage" | grep -oP '0x[0-9a-fA-F]+' | head -1)
        if [ -n "$bat_hex" ]; then
            battery="$((bat_hex))%"
        fi

        clear
        echo -e "${CYAN}======================================${NC}"
        echo -e "${CYAN}  Device Status${NC}"
        echo -e "${CYAN}======================================${NC}"
        echo ""
        echo "Device:    $DEVICE_NAME"
        echo "MAC:       $DEVICE_MAC"
        echo "Connected: $connected"
        echo "Battery:   $battery"
        echo ""
        echo "Time:      $(date +"%H:%M:%S")"
        echo ""
        echo -e "${YELLOW}Note: For real-time HR data, build the Rust CLI:${NC}"
        echo "  cd rust && cargo build --release"
        echo "  ./scripts/ble-realtime.sh"
        echo ""
        echo "Press Ctrl+C to stop"

        sleep 2
    done
}

disconnect_on_exit() {
    echo ""
    print_info "Disconnecting..."
    bluetoothctl disconnect "$DEVICE_MAC" &>/dev/null || true
    print_success "Disconnected"
}

show_usage() {
    echo "Usage: $0 [OPTIONS] [DEVICE_MAC]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -s, --simple   Use simple status monitor (no HR data)"
    echo ""
    echo "Arguments:"
    echo "  DEVICE_MAC     Optional MAC address (uses saved config if omitted)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use saved device"
    echo "  $0 F4:8C:C9:1B:E6:1B        # Specify device MAC"
    echo "  $0 --simple                  # Simple status monitor"
}

main() {
    local simple_mode=false
    local device_arg=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--simple)
                simple_mode=true
                shift
                ;;
            *)
                if [[ "$1" =~ ^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$ ]]; then
                    device_arg="$1"
                else
                    print_error "Invalid MAC address format: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    print_header
    load_device_config "$device_arg"

    if [ "$simple_mode" = true ]; then
        check_device_wearing
        connect_device
        trap disconnect_on_exit EXIT
        run_with_simple_monitor
    else
        # Prefer Python bleak-based monitor (most reliable)
        if [ -x "$SCRIPT_DIR/.venv/bin/python" ]; then
            # Python script handles connection/disconnection itself
            run_with_python
        elif command -v gatttool &>/dev/null; then
            check_device_wearing
            connect_device
            trap disconnect_on_exit EXIT
            run_with_gatttool
        else
            print_warning "No BLE tools available, using simple monitor"
            check_device_wearing
            connect_device
            trap disconnect_on_exit EXIT
            run_with_simple_monitor
        fi
    fi
}

main "$@"
