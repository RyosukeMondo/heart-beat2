#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Dependency Version Check${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Track overall status
ALL_DEPS_OK=true

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
    ALL_DEPS_OK=false
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}→${NC} $1"
}

# Function to compare versions (returns 0 if v1 >= v2)
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

echo -e "${BLUE}Checking core dependencies...${NC}"
echo ""

# Check Rust
echo "Rust:"
if command_exists rustc; then
    RUST_VERSION=$(rustc --version | cut -d' ' -f2)
    print_success "rustc $RUST_VERSION"

    if command_exists cargo; then
        CARGO_VERSION=$(cargo --version | cut -d' ' -f2)
        print_success "cargo $CARGO_VERSION"
    else
        print_error "cargo not found"
    fi

    if command_exists rustup; then
        RUSTUP_VERSION=$(rustup --version | cut -d' ' -f2)
        print_success "rustup $RUSTUP_VERSION"
    else
        print_warning "rustup not found (recommended for managing Rust versions)"
    fi
else
    print_error "Rust is not installed"
    echo "  Install from: https://rustup.rs/"
fi
echo ""

# Check Flutter
echo "Flutter:"
if command_exists flutter; then
    FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n1 | awk '{print $2}')
    print_success "Flutter $FLUTTER_VERSION"

    # Check Dart (comes with Flutter)
    if command_exists dart; then
        DART_VERSION=$(dart --version 2>&1 | grep -oP 'Dart SDK version: \K[0-9.]+')
        print_success "Dart $DART_VERSION"
    fi
else
    print_error "Flutter is not installed"
    echo "  Install from: https://docs.flutter.dev/get-started/install"
fi
echo ""

# Check Android SDK
echo "Android SDK:"
if [ -n "$ANDROID_HOME" ] || [ -n "$ANDROID_SDK_ROOT" ]; then
    ANDROID_PATH="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
    print_success "ANDROID_HOME: $ANDROID_PATH"

    # Check for specific SDK components
    if [ -d "$ANDROID_PATH/platform-tools" ]; then
        if command_exists adb; then
            ADB_VERSION=$(adb --version | head -n1 | awk '{print $5}')
            print_success "adb version $ADB_VERSION"
        fi
    else
        print_warning "platform-tools not found in Android SDK"
    fi

    if [ -d "$ANDROID_PATH/build-tools" ]; then
        BUILD_TOOLS_VERSION=$(ls -1 "$ANDROID_PATH/build-tools" | sort -V | tail -n1)
        print_success "build-tools $BUILD_TOOLS_VERSION"
    else
        print_warning "build-tools not found in Android SDK"
    fi
else
    print_error "ANDROID_HOME is not set"
    echo "  Set it to your Android SDK location"
fi
echo ""

# Check Android NDK
echo "Android NDK:"
if [ -n "$ANDROID_NDK_HOME" ]; then
    if [ -d "$ANDROID_NDK_HOME" ]; then
        print_success "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"

        if [ -f "$ANDROID_NDK_HOME/source.properties" ]; then
            NDK_VERSION=$(grep 'Pkg.Revision' "$ANDROID_NDK_HOME/source.properties" | cut -d'=' -f2 | tr -d ' ')

            # Extract major version
            NDK_MAJOR=$(echo "$NDK_VERSION" | cut -d'.' -f1)

            if [ "$NDK_MAJOR" -ge 25 ]; then
                print_success "NDK version $NDK_VERSION (>= r25 required)"
            else
                print_warning "NDK version $NDK_VERSION (r25 or later recommended)"
            fi
        else
            print_warning "Could not determine NDK version"
        fi
    else
        print_error "ANDROID_NDK_HOME is set but directory does not exist: $ANDROID_NDK_HOME"
    fi
else
    print_error "ANDROID_NDK_HOME is not set"
    echo "  Set it to your Android NDK location (e.g., \$ANDROID_HOME/ndk/<version>)"
fi
echo ""

# Check Rust Android targets
echo "Rust Android targets:"
if command_exists rustup; then
    REQUIRED_TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android" "i686-linux-android")

    for target in "${REQUIRED_TARGETS[@]}"; do
        if rustup target list | grep -q "$target (installed)"; then
            print_success "$target"
        else
            print_error "$target not installed"
            echo "  Run: rustup target add $target"
        fi
    done
else
    print_error "rustup not found - cannot check Android targets"
fi
echo ""

# Check additional tools
echo "Additional tools:"
if command_exists git; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_success "git $GIT_VERSION"
else
    print_error "git is not installed"
fi

if command_exists llvm-ar; then
    print_success "llvm-ar available"
else
    print_warning "llvm-ar not found (may be needed for cross-compilation)"
fi

if command_exists llvm-strip; then
    print_success "llvm-strip available"
else
    print_warning "llvm-strip not found (used for binary optimization)"
fi
echo ""

# Check project-specific dependencies
echo -e "${BLUE}Checking project dependencies...${NC}"
echo ""

# Check if flutter_rust_bridge is in pubspec.yaml
if [ -f "pubspec.yaml" ]; then
    if grep -q "flutter_rust_bridge:" pubspec.yaml; then
        FRB_VERSION=$(grep "flutter_rust_bridge:" pubspec.yaml | awk '{print $2}' | tr -d "'^~")
        print_success "flutter_rust_bridge: $FRB_VERSION (in pubspec.yaml)"
    else
        print_warning "flutter_rust_bridge not found in pubspec.yaml"
    fi

    if grep -q "ffigen:" pubspec.yaml; then
        FFIGEN_VERSION=$(grep "ffigen:" pubspec.yaml | awk '{print $2}' | tr -d "'^~")
        print_success "ffigen: $FFIGEN_VERSION (in pubspec.yaml)"
    else
        print_warning "ffigen not found in pubspec.yaml"
    fi
else
    print_warning "pubspec.yaml not found in current directory"
fi

# Check for Cargo.toml
if [ -f "rust/Cargo.toml" ]; then
    print_success "rust/Cargo.toml exists"

    # Check for flutter_rust_bridge dependency
    if grep -q "flutter_rust_bridge" rust/Cargo.toml; then
        print_success "flutter_rust_bridge in Cargo.toml"
    else
        print_warning "flutter_rust_bridge not found in rust/Cargo.toml"
    fi
else
    print_error "rust/Cargo.toml not found"
fi

# Check for Cargo config
if [ -f "rust/.cargo/config.toml" ]; then
    print_success "rust/.cargo/config.toml exists (Android linker config)"
else
    print_warning "rust/.cargo/config.toml not found (needed for Android builds)"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
if [ "$ALL_DEPS_OK" = true ]; then
    echo -e "${GREEN}All required dependencies are installed!${NC}"
    echo ""
    echo "You're ready to build. Try:"
    echo "  ./build-android.sh"
else
    echo -e "${YELLOW}Some dependencies are missing or misconfigured${NC}"
    echo ""
    echo "Run the setup script to fix issues:"
    echo "  ./scripts/dev-setup.sh"
fi
echo -e "${BLUE}======================================${NC}"

# Exit with error code if dependencies are missing
if [ "$ALL_DEPS_OK" = true ]; then
    exit 0
else
    exit 1
fi
