#!/bin/bash
# Automated smoke test for Dart CLI - tests Flutter/Rust bridge integration
# Tests commands that don't require BLE devices for fast feedback

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print header
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Heart Beat - Dart CLI Smoke Tests                            ║${NC}"
    echo -e "${BLUE}║  Testing Flutter/Rust Bridge Integration                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print test section
print_section() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo "─────────────────────────────────────────────────────────────────"
}

# Print test step
print_test() {
    echo -e "${BLUE}  Testing: $1${NC}"
    ((TESTS_RUN++)) || true
}

# Print success
print_success() {
    echo -e "${GREEN}  ✓ PASS${NC}"
    ((TESTS_PASSED++)) || true
}

# Print failure
print_failure() {
    echo -e "${RED}  ✗ FAIL: $1${NC}"
    ((TESTS_FAILED++)) || true
}

# Print summary
print_summary() {
    echo ""
    echo "═════════════════════════════════════════════════════════════════"
    echo ""
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed! ($TESTS_PASSED/$TESTS_RUN)${NC}"
    else
        echo -e "${RED}✗ Some tests failed. ($TESTS_PASSED passed, $TESTS_FAILED failed out of $TESTS_RUN)${NC}"
    fi
    echo ""
    echo "═════════════════════════════════════════════════════════════════"
}

# Check if dart is available
check_dart() {
    if ! command -v dart &> /dev/null; then
        print_failure "Dart command not found. Please install Dart SDK."
        exit 1
    fi
    print_success
}

# Test command execution
test_command() {
    local description=$1
    local command=$2
    local expected_pattern=$3

    print_test "$description"

    # Run command and capture output
    if output=$(eval "$command" 2>&1); then
        # Check if output contains expected pattern
        if echo "$output" | grep -q "$expected_pattern"; then
            print_success
            return 0
        else
            print_failure "Output doesn't contain expected pattern: '$expected_pattern'"
            echo "  Output: $output"
            return 1
        fi
    else
        print_failure "Command failed with exit code $?"
        echo "  Output: $output"
        return 1
    fi
}

# Test command fails appropriately
test_command_fails() {
    local description=$1
    local command=$2

    print_test "$description"

    # Run command and expect it to fail
    if output=$(eval "$command" 2>&1); then
        print_failure "Command should have failed but succeeded"
        return 1
    else
        print_success
        return 0
    fi
}

# Main test execution
main() {
    print_header

    # Check prerequisites
    print_section "Prerequisites"
    print_test "Dart SDK installed"
    check_dart

    # Test help and version commands
    print_section "Basic Commands"
    test_command \
        "Help message" \
        "dart run bin/dart_cli.dart --help" \
        "Heart Beat CLI"

    test_command \
        "Version information" \
        "dart run bin/dart_cli.dart --version" \
        "Heart Beat CLI v"

    test_command \
        "No command shows usage" \
        "dart run bin/dart_cli.dart" \
        "Available commands"

    # Test command-specific help
    print_section "Command Help"
    test_command \
        "List-plans help" \
        "dart run bin/dart_cli.dart list-plans --help" \
        "List available training plans"

    test_command \
        "Profile help" \
        "dart run bin/dart_cli.dart profile --help" \
        "View and modify user profile"

    test_command \
        "History help" \
        "dart run bin/dart_cli.dart history --help" \
        "View workout history"

    # Test list-plans command
    print_section "Training Plans"
    test_command \
        "List training plans" \
        "dart run bin/dart_cli.dart list-plans" \
        "Available training plans"

    # Note: The actual plans may vary, but command should succeed
    # Check for either "Available training plans" or "No training plans found"

    # Test profile command
    print_section "User Profile"
    test_command \
        "View profile (default)" \
        "dart run bin/dart_cli.dart profile" \
        "User Profile"

    test_command \
        "Profile shows training zones" \
        "dart run bin/dart_cli.dart profile" \
        "Training Zones"

    test_command \
        "Update age to 30" \
        "dart run bin/dart_cli.dart profile --age 30" \
        "Profile updated successfully"

    test_command \
        "Update max HR to 190" \
        "dart run bin/dart_cli.dart profile --max-hr 190" \
        "Profile updated successfully"

    test_command \
        "Update both age and max HR" \
        "dart run bin/dart_cli.dart profile --age 35 --max-hr 185" \
        "Profile updated successfully"

    # Test profile validation
    print_section "Profile Validation"
    test_command_fails \
        "Reject invalid age (too young)" \
        "dart run bin/dart_cli.dart profile --age 5"

    test_command_fails \
        "Reject invalid age (too old)" \
        "dart run bin/dart_cli.dart profile --age 150"

    test_command_fails \
        "Reject invalid max HR (too low)" \
        "dart run bin/dart_cli.dart profile --max-hr 50"

    test_command_fails \
        "Reject invalid max HR (too high)" \
        "dart run bin/dart_cli.dart profile --max-hr 250"

    test_command_fails \
        "Reject non-numeric age" \
        "dart run bin/dart_cli.dart profile --age abc"

    # Test history command
    print_section "Workout History"
    test_command \
        "View workout history" \
        "dart run bin/dart_cli.dart history" \
        "Loading workout history"

    # Note: History may be empty, but command should succeed
    # Check for "Loading workout history" which appears in both cases

    # Test error handling
    print_section "Error Handling"
    test_command_fails \
        "Reject invalid flag" \
        "dart run bin/dart_cli.dart --invalid-flag"

    # Print summary
    print_summary

    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run tests
main
