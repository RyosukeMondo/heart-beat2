#!/bin/bash
set -e

echo "=== Heart-Beat BLE Setup for Linux ==="
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run with sudo"
    echo "Usage: sudo ./setup-ble.sh"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
echo "Setting up BLE for user: $ACTUAL_USER"
echo ""

# Update package list
echo "1. Updating package list..."
apt-get update

# Install BlueZ (Bluetooth stack) and development libraries
echo ""
echo "2. Installing Bluetooth packages..."
apt-get install -y \
    bluez \
    bluetooth \
    libbluetooth-dev \
    libudev-dev \
    libdbus-1-dev

# Enable and start Bluetooth service
echo ""
echo "3. Enabling Bluetooth service..."
systemctl enable bluetooth
systemctl start bluetooth

# Add user to bluetooth group if it exists
echo ""
echo "4. Adding user to bluetooth group..."
if getent group bluetooth > /dev/null 2>&1; then
    usermod -a -G bluetooth "$ACTUAL_USER"
    echo "   User $ACTUAL_USER added to 'bluetooth' group"
else
    echo "   'bluetooth' group doesn't exist (this is normal on some distros)"
fi

# Create udev rule for BLE access without sudo
echo ""
echo "5. Creating udev rule for BLE access..."
cat > /etc/udev/rules.d/99-bluetooth-hci.rules << 'EOF'
# Allow users in plugdev/bluetooth group to access Bluetooth adapters
KERNEL=="hci*", GROUP="bluetooth", MODE="0660"
SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", MODE="0660", GROUP="plugdev"
EOF

# Add user to plugdev group (common on Ubuntu/Debian)
if getent group plugdev > /dev/null 2>&1; then
    usermod -a -G plugdev "$ACTUAL_USER"
    echo "   User $ACTUAL_USER added to 'plugdev' group"
fi

# Reload udev rules
echo ""
echo "6. Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# Check Bluetooth status
echo ""
echo "7. Checking Bluetooth status..."
systemctl status bluetooth --no-pager | head -n 5

# Check for Bluetooth adapters
echo ""
echo "8. Detecting Bluetooth adapters..."
hciconfig -a || echo "   No hciconfig found, trying bluetoothctl..."
bluetoothctl list || echo "   Error listing adapters"

# Power on Bluetooth adapter
echo ""
echo "9. Powering on Bluetooth adapter..."
bluetoothctl power on || echo "   Warning: Could not power on adapter automatically"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "IMPORTANT: You need to log out and log back in for group changes to take effect."
echo ""
echo "After logging back in, test with:"
echo "  cd rust"
echo "  cargo run --bin cli -- scan"
echo ""
echo "If you see permission errors, try:"
echo "  sudo setcap cap_net_raw,cap_net_admin+eip \$(which cargo-clippy)"
echo "  Or run once with: sudo \$(which cargo) run --bin cli -- scan"
echo ""
