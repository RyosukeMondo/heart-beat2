#!/bin/bash
# Integration Test Script for Heart Beat
# Runs Flutter integration tests on connected Android device or emulator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default options
TEST_FILE=""
DEVICE=""

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Integration Tests${NC}"
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

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS] [TEST_FILE]"
    echo ""
    echo "Arguments:"
    echo "  TEST_FILE       Specific test file to run (optional)"
    echo "                  Example: integration_test/connection_flow_test.dart"
    echo ""
    echo "Options:"
    echo "  -d, --device ID Use specific device (optional, auto-detects if not provided)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "This script will:"
    echo "  1. Check for Flutter and connected Android device/emulator"
    echo "  2. Run integration tests on the device"
    echo "  3. Report test results"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all integration tests"
    echo "  $0 integration_test/connection_flow_test.dart  # Run specific test"
    echo "  $0 -d emulator-5554                  # Run on specific device"
    exit 0
}

check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "flutter command not found. Please install Flutter SDK."
        exit 1
    fi
    print_success "Flutter SDK found"
}

check_device() {
    if ! command -v adb &> /dev/null; then
        print_error "adb command not found. Please install Android SDK Platform Tools."
        exit 1
    fi

    local device_count
    device_count=$(adb devices | grep -E "device$|emulator" | wc -l)

    if [ "$device_count" -eq 0 ]; then
        print_error "No Android device or emulator connected"
        echo ""
        echo "Please connect a device or start an emulator:"
        echo ""
        echo "Physical device:"
        echo "  1. Connect device via USB"
        echo "  2. Enable Developer Options"
        echo "  3. Enable USB Debugging"
        echo "  4. Authorize this computer on the device"
        echo ""
        echo "Emulator:"
        echo "  flutter emulators --launch <emulator_id>"
        echo ""
        echo "Run 'adb devices' to verify connection"
        echo "Run 'flutter devices' to see available devices"
        exit 1
    fi

    # If device not specified, use the first available device
    if [ -z "$DEVICE" ]; then
        DEVICE=$(adb devices | grep -E "device$|emulator" | head -1 | awk '{print $1}')
    fi

    # Verify the device exists
    if ! adb devices | grep -q "$DEVICE"; then
        print_error "Device $DEVICE not found"
        echo ""
        echo "Available devices:"
        adb devices
        exit 1
    fi

    print_success "Device connected: $DEVICE"
}

check_integration_tests() {
    if [ ! -d "integration_test" ]; then
        print_error "integration_test directory not found"
        echo ""
        echo "Please run this script from the project root"
        echo "Expected directory structure:"
        echo "  project_root/"
        echo "    ├── integration_test/"
        echo "    │   ├── connection_flow_test.dart"
        echo "    │   ├── workout_flow_test.dart"
        echo "    │   └── ..."
        exit 1
    fi

    # Count test files
    local test_count
    test_count=$(find integration_test -name "*_test.dart" | wc -l)

    if [ "$test_count" -eq 0 ]; then
        print_warning "No integration test files found in integration_test/"
        exit 0
    fi

    print_success "Found $test_count integration test file(s)"
}

run_tests() {
    local test_file=$1
    print_step "Running integration tests..."
    echo ""

    # Build flutter test command
    local flutter_cmd="flutter test"

    # Add device flag
    if [ -n "$DEVICE" ]; then
        flutter_cmd="$flutter_cmd -d $DEVICE"
    fi

    # Add specific test file if provided
    if [ -n "$test_file" ]; then
        if [ ! -f "$test_file" ]; then
            print_error "Test file not found: $test_file"
            exit 1
        fi
        print_info "Running test file: $test_file"
        flutter_cmd="$flutter_cmd $test_file"
    else
        print_info "Running all integration tests"
        flutter_cmd="$flutter_cmd integration_test"
    fi

    echo ""
    print_info "Command: $flutter_cmd"
    echo ""

    # Run the tests
    if $flutter_cmd; then
        return 0
    else
        return 1
    fi
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--device)
                DEVICE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                # Treat as test file
                TEST_FILE="$1"
                shift
                ;;
        esac
    done

    print_header

    # Record start time
    START_TIME=$(date +%s)

    # Execute test steps
    check_flutter
    check_device
    echo ""

    check_integration_tests
    echo ""

    # Run tests and capture result
    if run_tests "$TEST_FILE"; then
        # Calculate test time
        END_TIME=$(date +%s)
        TEST_TIME=$((END_TIME - START_TIME))
        MINUTES=$((TEST_TIME / 60))
        SECONDS=$((TEST_TIME % 60))

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     All Tests Passed! ✓                ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "Total time: ${BLUE}${MINUTES}m ${SECONDS}s${NC}"
        echo ""
        exit 0
    else
        # Calculate test time
        END_TIME=$(date +%s)
        TEST_TIME=$((END_TIME - START_TIME))
        MINUTES=$((TEST_TIME / 60))
        SECONDS=$((TEST_TIME % 60))

        echo ""
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║     Tests Failed ✗                     ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "Total time: ${BLUE}${MINUTES}m ${SECONDS}s${NC}"
        echo ""
        echo "Review the test output above for details"
        exit 1
    fi
}

main "$@"
