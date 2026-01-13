#!/bin/bash
# Golden Test Script for Heart Beat
# Runs Flutter golden tests for visual regression detection

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
UPDATE_GOLDENS=false
SHOW_DIFFS=true

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat Golden Tests${NC}"
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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --update        Update golden files (regenerate baseline images)"
    echo "  --no-diffs      Don't show image diffs on failure (faster)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "This script will:"
    echo "  1. Check for Flutter SDK"
    echo "  2. Run golden tests in test/golden/"
    echo "  3. Compare screenshots against baseline images"
    echo "  4. Show visual diffs if tests fail (unless --no-diffs)"
    echo ""
    echo "Golden tests detect visual regressions by comparing widget screenshots"
    echo "against baseline images stored in test/golden/goldens/"
    echo ""
    echo "Examples:"
    echo "  $0                # Run golden tests (compare against baselines)"
    echo "  $0 --update       # Regenerate baseline golden images"
    echo "  $0 --no-diffs     # Run tests without showing diffs on failure"
    exit 0
}

check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "flutter command not found. Please install Flutter SDK."
        exit 1
    fi
    print_success "Flutter SDK found"
}

check_golden_tests() {
    if [ ! -d "test/golden" ]; then
        print_error "test/golden directory not found"
        echo ""
        echo "Please run this script from the project root"
        echo "Expected directory structure:"
        echo "  project_root/"
        echo "    ├── test/"
        echo "    │   ├── golden/"
        echo "    │   │   ├── *_golden_test.dart"
        echo "    │   │   └── goldens/"
        echo "    │   │       └── *.png"
        exit 1
    fi

    # Count test files
    local test_count
    test_count=$(find test/golden -name "*_golden_test.dart" 2>/dev/null | wc -l)

    if [ "$test_count" -eq 0 ]; then
        print_warning "No golden test files found in test/golden/"
        exit 0
    fi

    print_success "Found $test_count golden test file(s)"
}

count_golden_files() {
    local golden_count=0
    if [ -d "test/golden/goldens" ]; then
        golden_count=$(find test/golden/goldens -name "*.png" 2>/dev/null | wc -l)
    fi
    echo "$golden_count"
}

show_diff_info() {
    print_info "Looking for failed test diffs..."
    echo ""

    # Check for Flutter's failure output directory
    local failures_dir="test/failures"
    if [ -d "$failures_dir" ]; then
        local diff_count
        diff_count=$(find "$failures_dir" -name "*.png" 2>/dev/null | wc -l)

        if [ "$diff_count" -gt 0 ]; then
            print_warning "Found $diff_count diff image(s) in $failures_dir/"
            echo ""
            echo "Diff files:"
            find "$failures_dir" -name "*.png" -exec echo "  {}" \;
            echo ""
            echo "To view diffs, open the images in an image viewer:"
            echo "  - Test image: test/golden/goldens/<name>.png"
            echo "  - Master image: $failures_dir/<name>_masterImage.png"
            echo "  - Diff image: $failures_dir/<name>_diff.png"
            echo ""
        else
            print_info "No diff images found (tests may have passed or no diffs generated)"
        fi
    else
        print_info "No failures directory found at $failures_dir/"
    fi
}

run_golden_tests() {
    print_step "Running golden tests..."
    echo ""

    # Build flutter test command
    local flutter_cmd="flutter test test/golden"

    # Add update flag if requested
    if [ "$UPDATE_GOLDENS" = true ]; then
        print_warning "UPDATE MODE: Regenerating golden baseline images"
        flutter_cmd="$flutter_cmd --update-goldens"
        echo ""
    fi

    print_info "Command: $flutter_cmd"
    echo ""

    # Run the tests and capture output
    local test_output
    local test_result

    if test_output=$($flutter_cmd 2>&1); then
        test_result=0
    else
        test_result=$?
    fi

    # Print the test output
    echo "$test_output"

    return $test_result
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update)
                UPDATE_GOLDENS=true
                shift
                ;;
            --no-diffs)
                SHOW_DIFFS=false
                shift
                ;;
            --help|-h)
                usage
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                print_error "Unexpected argument: $1"
                usage
                ;;
        esac
    done

    print_header

    # Record start time
    START_TIME=$(date +%s)

    # Execute test steps
    check_flutter
    echo ""

    check_golden_tests

    # Show golden file count before running tests
    local golden_count_before
    golden_count_before=$(count_golden_files)
    if [ "$golden_count_before" -gt 0 ]; then
        print_info "Current baseline: $golden_count_before golden image(s)"
    else
        print_warning "No baseline images found - run with --update to generate them"
    fi
    echo ""

    # Run tests and capture result
    if run_golden_tests; then
        # Calculate test time
        END_TIME=$(date +%s)
        TEST_TIME=$((END_TIME - START_TIME))
        MINUTES=$((TEST_TIME / 60))
        SECONDS=$((TEST_TIME % 60))

        echo ""

        if [ "$UPDATE_GOLDENS" = true ]; then
            local golden_count_after
            golden_count_after=$(count_golden_files)
            echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║   Golden Images Updated! ✓             ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
            echo ""
            print_success "Generated $golden_count_after golden baseline image(s)"
            echo ""
            echo "Baseline images saved to: test/golden/goldens/"
            echo ""
            echo "Next steps:"
            echo "  1. Review the generated images"
            echo "  2. Commit them to git if they look correct"
            echo "  3. Run '$0' without --update to verify tests pass"
        else
            echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║     All Golden Tests Passed! ✓         ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
            echo ""
            print_success "No visual regressions detected"
        fi

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
        echo -e "${RED}║     Golden Tests Failed ✗              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""

        if [ "$UPDATE_GOLDENS" = true ]; then
            print_error "Failed to generate golden images"
            echo ""
            echo "Review the error output above for details"
        else
            print_error "Visual regression detected!"
            echo ""

            if [ "$SHOW_DIFFS" = true ]; then
                show_diff_info
            fi

            echo "To fix:"
            echo "  1. Review the differences shown above"
            echo "  2. If changes are intentional, update baselines: $0 --update"
            echo "  3. If changes are bugs, fix the code and re-run tests"
        fi

        echo ""
        echo -e "Total time: ${BLUE}${MINUTES}m ${SECONDS}s${NC}"
        echo ""
        exit 1
    fi
}

main "$@"
