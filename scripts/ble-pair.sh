#!/bin/bash
# BLE Pairing Script for Heart Beat
# Scans for and pairs with BLE heart rate monitors

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCAN_DURATION=${SCAN_DURATION:-10}
CONFIG_DIR="$HOME/.heart-beat"
DEVICE_CONFIG="$CONFIG_DIR/device.conf"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat BLE Device Pairing${NC}"
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

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if bluetoothctl is available
    if ! command -v bluetoothctl &>/dev/null; then
        print_error "bluetoothctl not found. Run: sudo ./scripts/ble-setup.sh"
        exit 1
    fi

    # Check if bluetooth service is running
    if ! systemctl is-active --quiet bluetooth; then
        print_error "Bluetooth service is not running"
        print_info "Start it with: sudo systemctl start bluetooth"
        exit 1
    fi

    # Check if adapter is available
    if ! hciconfig hci0 &>/dev/null; then
        print_error "No Bluetooth adapter found"
        exit 1
    fi

    print_success "Prerequisites OK"
}

check_existing_device() {
    if [ -f "$DEVICE_CONFIG" ]; then
        source "$DEVICE_CONFIG"
        if [ -n "$DEVICE_MAC" ]; then
            echo ""
            print_info "Found previously paired device:"
            echo "  Name: ${DEVICE_NAME:-Unknown}"
            echo "  MAC:  $DEVICE_MAC"
            echo ""
            read -p "Use this device? [Y/n]: " use_existing
            if [[ "$use_existing" =~ ^[Yy]?$ ]]; then
                return 0  # Use existing device
            fi
        fi
    fi
    return 1  # Scan for new device
}

prompt_for_strap() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}  IMPORTANT: Prepare Your Device${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
    echo "Heart rate monitors only broadcast when worn:"
    echo "  1. Moisten the sensor pads on the chest strap"
    echo "  2. Put on the chest strap"
    echo "  3. Wait a few seconds for skin contact detection"
    echo ""
    read -p "Press ENTER when you're wearing the device..."
    echo ""
}

scan_for_devices() {
    print_info "Scanning for BLE heart rate monitors (${SCAN_DURATION}s)..."
    echo ""

    # Create temp file for scan results
    local scan_file
    scan_file=$(mktemp)

    # Run scan and capture output
    (
        echo "power on"
        echo "scan on"
        sleep "$SCAN_DURATION"
        echo "scan off"
        sleep 1
        echo "quit"
    ) | bluetoothctl 2>&1 | tee "$scan_file"

    echo ""

    # Parse discovered devices - look for HR monitors
    # Common HR monitor names: HW9, CooSpo, Polar, Garmin, Wahoo
    local devices=()
    local device_names=()

    while IFS= read -r line; do
        if [[ "$line" =~ \[NEW\].*Device.*([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})(.*)$ ]]; then
            local mac="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            name=$(echo "$name" | sed 's/^[[:space:]]*//')

            # Filter for likely HR monitors
            if [[ "$name" =~ (HW[0-9]|CooSpo|Polar|Garmin|Wahoo|HR|Heart|TICKR|Coospo) ]]; then
                devices+=("$mac")
                device_names+=("$name")
            fi
        fi
    done < "$scan_file"

    rm -f "$scan_file"

    if [ ${#devices[@]} -eq 0 ]; then
        print_warning "No heart rate monitors found"
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Make sure the chest strap is wet and worn"
        echo "  - Try moving closer to the computer"
        echo "  - Check that the device battery is charged"
        echo "  - Try increasing scan duration: SCAN_DURATION=20 $0"
        echo ""
        exit 1
    fi

    echo ""
    print_success "Found ${#devices[@]} heart rate monitor(s):"
    echo ""

    for i in "${!devices[@]}"; do
        echo "  [$((i+1))] ${device_names[$i]} (${devices[$i]})"
    done

    echo ""

    # Select device
    local selection
    if [ ${#devices[@]} -eq 1 ]; then
        selection=1
        print_info "Auto-selecting the only device found"
    else
        read -p "Select device [1-${#devices[@]}]: " selection
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#devices[@]} ]; then
            print_error "Invalid selection"
            exit 1
        fi
    fi

    DEVICE_MAC="${devices[$((selection-1))]}"
    DEVICE_NAME="${device_names[$((selection-1))]}"

    print_success "Selected: $DEVICE_NAME ($DEVICE_MAC)"
}

pair_device() {
    print_info "Pairing with $DEVICE_NAME..."
    echo ""

    # Pair, trust, and connect
    local result
    result=$(
        (
            echo "power on"
            echo "scan on"
            sleep 3
            echo "pair $DEVICE_MAC"
            sleep 5
            echo "trust $DEVICE_MAC"
            sleep 2
            echo "connect $DEVICE_MAC"
            sleep 3
            echo "quit"
        ) | bluetoothctl 2>&1
    )

    # Check results
    if echo "$result" | grep -q "Pairing successful\|Paired: yes"; then
        print_success "Pairing successful"
    else
        print_warning "Pairing may have failed, but continuing..."
    fi

    if echo "$result" | grep -q "Trusted: yes"; then
        print_success "Device trusted"
    fi

    if echo "$result" | grep -q "Connection successful\|Connected: yes"; then
        print_success "Connected to device"
    fi
}

verify_device() {
    print_info "Verifying device connection..."

    local info
    info=$(bluetoothctl info "$DEVICE_MAC" 2>&1)

    if echo "$info" | grep -q "Connected: yes"; then
        print_success "Device is connected"

        # Check for Heart Rate service
        if echo "$info" | grep -q "Heart Rate"; then
            print_success "Heart Rate service available"
        fi

        # Check battery if available
        local battery
        battery=$(echo "$info" | grep "Battery Percentage" | grep -oP '0x[0-9a-fA-F]+' | head -1)
        if [ -n "$battery" ]; then
            local battery_pct=$((battery))
            print_success "Battery level: ${battery_pct}%"
        fi

        return 0
    else
        print_warning "Device is not connected"
        return 1
    fi
}

save_device_config() {
    mkdir -p "$CONFIG_DIR"

    cat > "$DEVICE_CONFIG" << EOF
# Heart Beat Device Configuration
# Generated: $(date)
DEVICE_MAC="$DEVICE_MAC"
DEVICE_NAME="$DEVICE_NAME"
EOF

    print_success "Device configuration saved to $DEVICE_CONFIG"
}

disconnect_device() {
    print_info "Disconnecting device (it will auto-reconnect when needed)..."
    bluetoothctl disconnect "$DEVICE_MAC" &>/dev/null || true
}

print_summary() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}  Pairing Complete!${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo "Device: $DEVICE_NAME"
    echo "MAC:    $DEVICE_MAC"
    echo ""
    echo "Next steps:"
    echo "  1. Test real-time HR: ./scripts/ble-realtime.sh"
    echo "  2. Or use the CLI:    cd rust && cargo run --bin cli -- devices connect $DEVICE_MAC"
    echo ""
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -s, --scan     Force new scan (ignore saved device)"
    echo "  -d, --duration Scan duration in seconds (default: 10)"
    echo ""
    echo "Environment variables:"
    echo "  SCAN_DURATION  Scan duration in seconds (default: 10)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Normal pairing flow"
    echo "  $0 --scan             # Force scan for new device"
    echo "  SCAN_DURATION=20 $0   # Longer scan time"
}

main() {
    local force_scan=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--scan)
                force_scan=true
                shift
                ;;
            -d|--duration)
                SCAN_DURATION="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_header
    check_prerequisites

    # Check for existing device or scan for new one
    if [ "$force_scan" = false ] && check_existing_device; then
        source "$DEVICE_CONFIG"
    else
        prompt_for_strap
        scan_for_devices
        pair_device
        save_device_config
    fi

    verify_device || true
    disconnect_device
    print_summary
}

main "$@"
