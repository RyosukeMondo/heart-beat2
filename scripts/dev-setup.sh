#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Heart Beat Development Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Track if setup is complete
SETUP_COMPLETE=true

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}→${NC} $1"
}

echo -e "${BLUE}[1/6] Checking Rust installation...${NC}"
if command_exists rustc; then
    RUST_VERSION=$(rustc --version | cut -d' ' -f2)
    print_success "Rust is installed (version: $RUST_VERSION)"
else
    print_warning "Rust is not installed"
    echo ""
    echo "Installing Rust via rustup..."
    if command_exists curl; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        print_success "Rust installed successfully"
    else
        print_error "curl is not installed. Please install curl first."
        echo "  Ubuntu/Debian: sudo apt install curl"
        echo "  Fedora: sudo dnf install curl"
        echo "  macOS: curl is pre-installed"
        SETUP_COMPLETE=false
    fi
fi

echo ""
echo -e "${BLUE}[2/6] Checking Flutter installation...${NC}"
if command_exists flutter; then
    FLUTTER_VERSION=$(flutter --version | head -n1 | cut -d' ' -f2)
    print_success "Flutter is installed (version: $FLUTTER_VERSION)"
else
    print_error "Flutter is not installed"
    echo ""
    echo "Please install Flutter from: https://docs.flutter.dev/get-started/install"
    echo ""
    echo "Quick installation steps:"
    echo "  1. Download Flutter SDK from the link above"
    echo "  2. Extract it to a suitable location (e.g., ~/development/)"
    echo "  3. Add Flutter to your PATH:"
    echo "     export PATH=\"\$PATH:\`pwd\`/flutter/bin\""
    echo "  4. Run 'flutter doctor' to verify installation"
    echo ""
    SETUP_COMPLETE=false
fi

echo ""
echo -e "${BLUE}[3/6] Checking Android SDK/NDK installation...${NC}"
if [ -n "$ANDROID_HOME" ] || [ -n "$ANDROID_SDK_ROOT" ]; then
    ANDROID_PATH="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
    print_success "Android SDK found at: $ANDROID_PATH"

    if [ -n "$ANDROID_NDK_HOME" ]; then
        print_success "Android NDK found at: $ANDROID_NDK_HOME"

        # Check NDK version
        if [ -f "$ANDROID_NDK_HOME/source.properties" ]; then
            NDK_VERSION=$(grep 'Pkg.Revision' "$ANDROID_NDK_HOME/source.properties" | cut -d'=' -f2 | tr -d ' ')
            print_info "NDK version: $NDK_VERSION"
        fi
    else
        print_error "Android NDK not found"
        echo ""
        echo "Please install Android NDK r25c or later via Android Studio:"
        echo "  1. Open Android Studio"
        echo "  2. Go to Tools > SDK Manager"
        echo "  3. Select SDK Tools tab"
        echo "  4. Check 'NDK (Side by side)' and click OK"
        echo "  5. Set ANDROID_NDK_HOME environment variable:"
        echo "     export ANDROID_NDK_HOME=\$ANDROID_HOME/ndk/<version>"
        echo ""
        SETUP_COMPLETE=false
    fi
else
    print_error "Android SDK not found"
    echo ""
    echo "Please install Android Studio and the Android SDK:"
    echo "  Download from: https://developer.android.com/studio"
    echo ""
    echo "After installation, set environment variables:"
    echo "  export ANDROID_HOME=\$HOME/Android/Sdk  # Linux"
    echo "  export ANDROID_HOME=\$HOME/Library/Android/sdk  # macOS"
    echo "  export PATH=\$PATH:\$ANDROID_HOME/tools:\$ANDROID_HOME/platform-tools"
    echo ""
    SETUP_COMPLETE=false
fi

echo ""
echo -e "${BLUE}[4/6] Installing Rust Android targets...${NC}"
if command_exists rustup; then
    TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android" "i686-linux-android")

    for target in "${TARGETS[@]}"; do
        if rustup target list | grep -q "$target (installed)"; then
            print_success "$target already installed"
        else
            print_info "Installing $target..."
            if rustup target add "$target"; then
                print_success "$target installed"
            else
                print_error "Failed to install $target"
                SETUP_COMPLETE=false
            fi
        fi
    done
else
    print_error "rustup not found. Please install Rust first."
    SETUP_COMPLETE=false
fi

echo ""
echo -e "${BLUE}[5/6] Installing Flutter dependencies...${NC}"
if command_exists flutter; then
    print_info "Running flutter pub get..."
    if flutter pub get; then
        print_success "Flutter dependencies installed"
    else
        print_error "Failed to install Flutter dependencies"
        SETUP_COMPLETE=false
    fi
else
    print_warning "Skipping Flutter dependencies (Flutter not installed)"
fi

echo ""
echo -e "${BLUE}[6/6] Checking additional tools...${NC}"
if command_exists git; then
    print_success "git is installed"
else
    print_error "git is not installed. Please install git."
    SETUP_COMPLETE=false
fi

if command_exists flutter && flutter doctor --version >/dev/null 2>&1; then
    print_info "Running flutter doctor for additional checks..."
    echo ""
    flutter doctor
fi

echo ""
echo -e "${BLUE}======================================${NC}"
if [ "$SETUP_COMPLETE" = true ]; then
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run './scripts/check-deps.sh' to verify all dependencies"
    echo "  2. Run './build-android.sh' to build the Android APK"
    echo "  3. Check 'docs/development.md' for development guidelines"
else
    echo -e "${YELLOW}Setup completed with warnings${NC}"
    echo ""
    echo "Please address the issues above and run this script again."
    echo "For help, check 'docs/development.md'"
fi
echo -e "${BLUE}======================================${NC}"
