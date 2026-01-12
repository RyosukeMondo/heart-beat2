#!/bin/bash
# BLE Setup Script for Heart Beat
# Installs required packages and configures permissions for BLE heart rate monitoring

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
    echo -e "${BLUE}  Heart Beat BLE Setup${NC}"
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

print_step() {
    echo -e "\n${BLUE}[$1/$TOTAL_STEPS]${NC} $2"
}

TOTAL_STEPS=6

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script requires root privileges"
        echo ""
        echo "Usage: sudo ./scripts/ble-setup.sh"
        exit 1
    fi
}

get_actual_user() {
    ACTUAL_USER="${SUDO_USER:-$USER}"
    print_info "Setting up BLE for user: $ACTUAL_USER"
}

check_bluetooth_packages() {
    print_step 1 "Checking Bluetooth packages..."

    local packages_to_install=()

    if ! dpkg -l bluez &>/dev/null; then
        packages_to_install+=("bluez")
    else
        print_success "bluez is installed"
    fi

    if ! dpkg -l bluez-tools &>/dev/null; then
        packages_to_install+=("bluez-tools")
    else
        print_success "bluez-tools is installed"
    fi

    if ! dpkg -l bluetooth &>/dev/null; then
        packages_to_install+=("bluetooth")
    else
        print_success "bluetooth is installed"
    fi

    if ! dpkg -l libbluetooth-dev &>/dev/null; then
        packages_to_install+=("libbluetooth-dev")
    else
        print_success "libbluetooth-dev is installed"
    fi

    if ! dpkg -l libdbus-1-dev &>/dev/null; then
        packages_to_install+=("libdbus-1-dev")
    else
        print_success "libdbus-1-dev is installed"
    fi

    if [ ${#packages_to_install[@]} -gt 0 ]; then
        print_info "Installing missing packages: ${packages_to_install[*]}"
        apt-get update -qq
        apt-get install -y "${packages_to_install[@]}"
        print_success "Packages installed"
    fi
}

enable_bluetooth_service() {
    print_step 2 "Enabling Bluetooth service..."

    if systemctl is-active --quiet bluetooth; then
        print_success "Bluetooth service is running"
    else
        systemctl enable bluetooth
        systemctl start bluetooth
        print_success "Bluetooth service started"
    fi
}

check_bluetooth_adapter() {
    print_step 3 "Checking Bluetooth adapter..."

    if hciconfig hci0 &>/dev/null; then
        local status
        status=$(hciconfig hci0 | grep -o "UP RUNNING" || true)
        if [ -n "$status" ]; then
            print_success "Bluetooth adapter is UP and RUNNING"
        else
            print_info "Bringing up Bluetooth adapter..."
            hciconfig hci0 up
            print_success "Bluetooth adapter is now UP"
        fi

        # Check for BLE support
        if hciconfig hci0 -a | grep -q "LE"; then
            print_success "Bluetooth adapter supports BLE"
        else
            print_warning "Bluetooth adapter may not support BLE"
        fi
    else
        print_error "No Bluetooth adapter found (hci0)"
        print_info "Please ensure you have a Bluetooth adapter connected"
        exit 1
    fi
}

configure_user_permissions() {
    print_step 4 "Configuring user permissions..."

    # Add user to bluetooth group
    if getent group bluetooth > /dev/null 2>&1; then
        if groups "$ACTUAL_USER" | grep -q bluetooth; then
            print_success "User $ACTUAL_USER is already in 'bluetooth' group"
        else
            usermod -a -G bluetooth "$ACTUAL_USER"
            print_success "Added $ACTUAL_USER to 'bluetooth' group"
        fi
    else
        print_warning "'bluetooth' group doesn't exist (normal on some distros)"
    fi

    # Add user to plugdev group
    if getent group plugdev > /dev/null 2>&1; then
        if groups "$ACTUAL_USER" | grep -q plugdev; then
            print_success "User $ACTUAL_USER is already in 'plugdev' group"
        else
            usermod -a -G plugdev "$ACTUAL_USER"
            print_success "Added $ACTUAL_USER to 'plugdev' group"
        fi
    fi
}

create_udev_rules() {
    print_step 5 "Creating udev rules for BLE access..."

    local rules_file="/etc/udev/rules.d/99-heart-beat-ble.rules"

    cat > "$rules_file" << 'EOF'
# Heart Beat BLE Rules
# Allow users in bluetooth/plugdev group to access Bluetooth adapters
KERNEL=="hci*", GROUP="bluetooth", MODE="0660"
SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", MODE="0660", GROUP="plugdev"
EOF

    udevadm control --reload-rules
    udevadm trigger

    print_success "udev rules created and reloaded"
}

power_on_bluetooth() {
    print_step 6 "Powering on Bluetooth adapter..."

    bluetoothctl power on &>/dev/null || true
    print_success "Bluetooth adapter powered on"
}

print_summary() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}  BLE Setup Complete!${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    print_warning "You may need to log out and log back in for group changes to take effect."
    echo ""
    echo "Next steps:"
    echo "  1. Log out and log back in (if first time setup)"
    echo "  2. Put on your heart rate monitor chest strap"
    echo "  3. Run: ./scripts/ble-pair.sh"
    echo ""
}

main() {
    print_header
    check_root
    get_actual_user
    check_bluetooth_packages
    enable_bluetooth_service
    check_bluetooth_adapter
    configure_user_permissions
    create_udev_rules
    power_on_bluetooth
    print_summary
}

main "$@"
