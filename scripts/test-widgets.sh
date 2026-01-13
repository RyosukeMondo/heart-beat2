#!/bin/bash
# Run Flutter widget tests with coverage reporting
#
# This script provides automated widget testing for CI/CD pipelines:
# 1. Runs all widget tests (test/widgets/)
# 2. Generates coverage report
# 3. Displays coverage percentage
# 4. Exits with non-zero code on test failure
#
# Usage:
#   ./scripts/test-widgets.sh [--coverage] [--verbose]
#
# Options:
#   --coverage    Generate and display coverage report (default: enabled)
#   --verbose     Show detailed test output
#   --no-coverage Skip coverage generation
#
# Examples:
#   ./scripts/test-widgets.sh                # Run tests with coverage
#   ./scripts/test-widgets.sh --verbose      # Run with detailed output
#   ./scripts/test-widgets.sh --no-coverage  # Run tests only, no coverage

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
COVERAGE_ENABLED=true
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --no-coverage)
            COVERAGE_ENABLED=false
            shift
            ;;
        --coverage)
            COVERAGE_ENABLED=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--coverage] [--verbose] [--no-coverage]"
            echo ""
            echo "Options:"
            echo "  --coverage     Generate and display coverage report (default)"
            echo "  --no-coverage  Skip coverage generation"
            echo "  --verbose      Show detailed test output"
            echo "  --help         Display this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Project root is the parent directory of scripts/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}🧪 Running Flutter Widget Tests${NC}"
echo "======================================="
echo ""

# Run widget tests
if [ "$COVERAGE_ENABLED" = true ]; then
    echo -e "${BLUE}Running tests with coverage...${NC}"

    # Run tests with coverage
    if [ "$VERBOSE" = true ]; then
        flutter test test/widgets/ --coverage --reporter expanded
    else
        flutter test test/widgets/ --coverage
    fi
    TEST_EXIT_CODE=$?
else
    echo -e "${BLUE}Running tests (coverage disabled)...${NC}"

    # Run tests without coverage
    if [ "$VERBOSE" = true ]; then
        flutter test test/widgets/ --reporter expanded
    else
        flutter test test/widgets/
    fi
    TEST_EXIT_CODE=$?
fi

echo ""

# Check test results
if [ $TEST_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ Widget tests failed${NC}"
    exit $TEST_EXIT_CODE
fi

echo -e "${GREEN}✅ All widget tests passed${NC}"

# Generate and display coverage report if enabled
if [ "$COVERAGE_ENABLED" = true ]; then
    echo ""
    echo -e "${BLUE}Coverage Report:${NC}"
    echo "======================================="

    # Check if coverage file exists
    if [ -f "coverage/lcov.info" ]; then
        # Check if lcov is installed
        if command -v lcov &> /dev/null; then
            # Generate human-readable summary
            echo ""
            lcov --summary coverage/lcov.info 2>&1 | grep -E "lines\.\.\.\.\.\.|functions\.\.\.\.\.\.|branches\.\.\.\.\.\." || true
            echo ""
            echo -e "${YELLOW}📊 Coverage report generated at: coverage/lcov.info${NC}"

            # Check if genhtml is available for HTML report
            if command -v genhtml &> /dev/null; then
                echo -e "${BLUE}Generating HTML coverage report...${NC}"
                genhtml coverage/lcov.info -o coverage/html --quiet
                echo -e "${GREEN}✅ HTML report generated at: coverage/html/index.html${NC}"
            else
                echo -e "${YELLOW}💡 Tip: Install lcov to generate HTML coverage reports${NC}"
                echo -e "${YELLOW}   sudo apt-get install lcov (Ubuntu/Debian)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  lcov not installed, showing basic coverage info${NC}"
            echo ""

            # Basic coverage calculation (count covered/total lines)
            if command -v grep &> /dev/null && command -v wc &> /dev/null; then
                TOTAL_LINES=$(grep -c "^DA:" coverage/lcov.info || echo "0")
                COVERED_LINES=$(grep "^DA:" coverage/lcov.info | grep -c ",0$" || echo "0")

                if [ "$TOTAL_LINES" -gt 0 ]; then
                    UNCOVERED=$COVERED_LINES
                    COVERED=$((TOTAL_LINES - UNCOVERED))
                    COVERAGE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($COVERED/$TOTAL_LINES)*100}")

                    echo -e "${GREEN}Lines covered: $COVERED / $TOTAL_LINES ($COVERAGE_PERCENT%)${NC}"
                fi
            fi

            echo ""
            echo -e "${YELLOW}💡 Tip: Install lcov for detailed coverage reports${NC}"
            echo -e "${YELLOW}   sudo apt-get install lcov (Ubuntu/Debian)${NC}"
        fi
    else
        echo -e "${RED}❌ Coverage file not found at coverage/lcov.info${NC}"
        echo -e "${YELLOW}💡 Make sure Flutter generated the coverage file${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Widget test suite completed successfully${NC}"
exit 0
