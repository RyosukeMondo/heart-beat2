#!/bin/bash
# Watch Rust files for changes and auto-rebuild with Flutter restart
#
# This script provides a continuous development workflow for Linux desktop:
# 1. Watches Rust source files for changes using cargo-watch
# 2. Auto-rebuilds the Rust library when changes are detected
# 3. Restarts the Flutter Linux app after successful rebuild
#
# Prerequisites:
#   cargo-watch must be installed: cargo install cargo-watch
#
# Usage:
#   ./scripts/dev-watch.sh [release|debug]
#
# Examples:
#   ./scripts/dev-watch.sh          # Watch and build in release mode (default)
#   ./scripts/dev-watch.sh release  # Watch and build in release mode
#   ./scripts/dev-watch.sh debug    # Watch and build in debug mode
#
# Note: Press Ctrl+C to stop watching. The Flutter app will be killed automatically.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if cargo-watch is installed
if ! command -v cargo-watch &> /dev/null; then
    echo -e "${RED}❌ Error: cargo-watch is not installed${NC}"
    echo ""
    echo -e "${YELLOW}Please install cargo-watch with:${NC}"
    echo "  cargo install cargo-watch"
    echo ""
    exit 1
fi

# Determine build mode (default: release)
BUILD_MODE="${1:-release}"
CARGO_FLAGS=""

if [ "$BUILD_MODE" = "debug" ]; then
    echo -e "${BLUE}🔍 Watch mode: DEBUG${NC}"
else
    CARGO_FLAGS="--release"
    echo -e "${BLUE}🔍 Watch mode: RELEASE${NC}"
fi

# File to track Flutter process PID
FLUTTER_PID_FILE="/tmp/heart-beat-flutter.pid"

# Cleanup function to kill Flutter process on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 Stopping watch mode...${NC}"
    if [ -f "$FLUTTER_PID_FILE" ]; then
        FLUTTER_PID=$(cat "$FLUTTER_PID_FILE")
        if kill -0 "$FLUTTER_PID" 2>/dev/null; then
            echo -e "${BLUE}Killing Flutter app (PID: $FLUTTER_PID)${NC}"
            kill "$FLUTTER_PID" 2>/dev/null || true
        fi
        rm -f "$FLUTTER_PID_FILE"
    fi
    echo -e "${GREEN}✅ Watch mode stopped${NC}"
    exit 0
}

# Register cleanup function
trap cleanup SIGINT SIGTERM EXIT

# Function to start Flutter app
start_flutter() {
    echo ""
    echo -e "${BLUE}🚀 Starting Flutter Linux app...${NC}"
    echo "======================================="

    # Kill existing Flutter process if running
    if [ -f "$FLUTTER_PID_FILE" ]; then
        OLD_PID=$(cat "$FLUTTER_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo -e "${YELLOW}Stopping previous Flutter instance (PID: $OLD_PID)${NC}"
            kill "$OLD_PID" 2>/dev/null || true
            sleep 1
        fi
    fi

    # Start Flutter app in background
    flutter run -d linux &
    FLUTTER_PID=$!
    echo "$FLUTTER_PID" > "$FLUTTER_PID_FILE"
    echo -e "${GREEN}Flutter app started (PID: $FLUTTER_PID)${NC}"
}

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}🔄 Starting continuous development mode${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Initial build and Flutter start
echo -e "${BLUE}Building Rust library initially...${NC}"
cd rust
if cargo build $CARGO_FLAGS; then
    echo -e "${GREEN}✅ Initial Rust build successful${NC}"
    cd ..
    start_flutter
    cd rust
else
    echo -e "${RED}❌ Error: Initial Rust build failed${NC}"
    exit 1
fi

# Watch for changes and rebuild
echo ""
echo -e "${BLUE}👀 Watching Rust files for changes...${NC}"
echo "======================================="
echo ""

cargo-watch \
    --watch src \
    --watch Cargo.toml \
    --ignore "target/*" \
    --shell "cargo build $CARGO_FLAGS && echo '\n✅ Rust rebuild successful - Flutter will hot reload automatically\n'" \
    --why

# Note: The script will stay running until Ctrl+C is pressed
# The cleanup function will handle stopping the Flutter app
