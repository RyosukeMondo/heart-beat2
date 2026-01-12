#!/bin/bash
# ADB Permissions Script for Heart Beat Android Debugging
# Shows app permissions and highlights Bluetooth-related permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# App configuration
APP_PACKAGE="com.example.heart_beat"

# Key permissions to highlight
BLE_PERMISSIONS=(
    "android.permission.BLUETOOTH_SCAN"
    "android.permission.BLUETOOTH_CONNECT"
    "android.permission.BLUETOOTH_ADVERTISE"
    "android.permission.ACCESS_FINE_LOCATION"
    "android.permission.ACCESS_COARSE_LOCATION"
)

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Permissions Check${NC}"
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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all           Show all permissions (not just Bluetooth-related)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Highlights key permissions:"
    echo "  • BLUETOOTH_SCAN"
    echo "  • BLUETOOTH_CONNECT"
    echo "  • BLUETOOTH_ADVERTISE"
    echo "  • ACCESS_FINE_LOCATION"
    echo "  • ACCESS_COARSE_LOCATION"
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

check_app_installed() {
    print_info "Checking if $APP_PACKAGE is installed..."

    if ! adb shell pm list packages | grep -q "^package:$APP_PACKAGE$"; then
        print_error "App $APP_PACKAGE is not installed on the device"
        echo ""
        echo "Install the app first:"
        echo "  ./scripts/adb-install.sh"
        exit 1
    fi

    print_success "App is installed"
}

is_ble_permission() {
    local permission=$1
    for ble_perm in "${BLE_PERMISSIONS[@]}"; do
        if [[ "$permission" == *"$ble_perm"* ]]; then
            return 0
        fi
    done
    return 1
}

format_permission_status() {
    local permission=$1
    local status=$2
    local is_ble=$3

    # Extract permission name (last part after .)
    local perm_name
    perm_name=$(echo "$permission" | awk -F. '{print $NF}')

    if [ "$status" = "granted" ]; then
        if [ "$is_ble" = "true" ]; then
            echo -e "  ${GREEN}✓${NC} ${MAGENTA}${perm_name}${NC}: ${GREEN}GRANTED${NC}"
        else
            echo -e "  ${GREEN}✓${NC} ${perm_name}: ${GREEN}granted${NC}"
        fi
    else
        if [ "$is_ble" = "true" ]; then
            echo -e "  ${RED}✗${NC} ${MAGENTA}${perm_name}${NC}: ${RED}DENIED${NC}"
        else
            echo -e "  ${RED}✗${NC} ${perm_name}: ${RED}denied${NC}"
        fi
    fi
}

show_permissions() {
    local show_all=$1

    print_info "Fetching app permissions..."
    echo ""

    # Get dumpsys output
    local dumpsys_output
    dumpsys_output=$(adb shell dumpsys package "$APP_PACKAGE" 2>/dev/null)

    if [ -z "$dumpsys_output" ]; then
        print_error "Failed to get package info"
        exit 1
    fi

    # Parse permissions
    echo -e "${BLUE}Declared Permissions:${NC}"
    echo ""

    local in_permissions=false
    local granted_count=0
    local denied_count=0
    local ble_granted=0
    local ble_denied=0

    while IFS= read -r line; do
        # Start of permissions section
        if [[ "$line" =~ "requested permissions:" ]]; then
            in_permissions=true
            continue
        fi

        # End of permissions section
        if [[ "$in_permissions" == true ]] && [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ "install permissions:" || "$line" =~ "User " || "$line" =~ "gids=" ]]; then
            if [[ "$line" =~ "install permissions:" ]]; then
                in_permissions=true
                continue
            else
                in_permissions=false
            fi
        fi

        # Parse permission lines
        if [ "$in_permissions" = true ]; then
            if [[ "$line" =~ android\.permission\. ]]; then
                # Extract permission name and status
                local permission
                local status

                permission=$(echo "$line" | grep -o "android\.permission\.[A-Z_]*" | head -1)

                if [[ "$line" =~ "granted=true" ]]; then
                    status="granted"
                    ((granted_count++))
                else
                    status="denied"
                    ((denied_count++))
                fi

                # Check if it's a BLE permission
                local is_ble="false"
                if is_ble_permission "$permission"; then
                    is_ble="true"
                    if [ "$status" = "granted" ]; then
                        ((ble_granted++))
                    else
                        ((ble_denied++))
                    fi
                fi

                # Show permission based on filter
                if [ "$show_all" = "true" ] || [ "$is_ble" = "true" ]; then
                    format_permission_status "$permission" "$status" "$is_ble"
                fi
            fi
        fi
    done <<< "$dumpsys_output"

    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo ""

    if [ "$show_all" = "true" ]; then
        echo -e "  Total granted: ${GREEN}$granted_count${NC}"
        echo -e "  Total denied:  ${RED}$denied_count${NC}"
        echo ""
    fi

    echo -e "  ${MAGENTA}Bluetooth/Location permissions:${NC}"
    echo -e "    Granted: ${GREEN}$ble_granted${NC}"
    echo -e "    Denied:  ${RED}$ble_denied${NC}"
    echo ""

    # Health check
    if [ $ble_denied -gt 0 ]; then
        print_warning "Some Bluetooth/Location permissions are denied"
        echo ""
        echo "For full BLE functionality, grant these permissions:"
        echo "  • Settings → Apps → Heart Beat → Permissions"
        echo "  • Enable all Bluetooth and Location permissions"
    else
        print_success "All Bluetooth/Location permissions are granted"
    fi
}

main() {
    local show_all=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                show_all=true
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
    check_app_installed
    echo ""

    show_permissions "$show_all"
    echo ""
}

main "$@"
