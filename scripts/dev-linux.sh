#!/bin/bash
# Build Rust library and launch Flutter Linux app
#
# This script provides a one-command development workflow for Linux desktop:
# 1. Builds the Rust library (libheart_beat.so)
# 2. Launches the Flutter Linux app
#
# Usage:
#   ./scripts/dev-linux.sh [release|debug]
#
# Examples:
#   ./scripts/dev-linux.sh          # Build release mode and run (default)
#   ./scripts/dev-linux.sh release  # Build release mode and run
#   ./scripts/dev-linux.sh debug    # Build debug mode and run

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine build mode (default: release)
BUILD_MODE="${1:-release}"
CARGO_FLAGS=""

if [ "$BUILD_MODE" = "debug" ]; then
    echo -e "${BLUE}🛠️  Building Rust library in DEBUG mode${NC}"
else
    CARGO_FLAGS="--release"
    echo -e "${BLUE}🚀 Building Rust library in RELEASE mode${NC}"
fi

# Build Rust library
echo ""
echo -e "${BLUE}Building Rust library...${NC}"
echo "======================================="

cd rust

if cargo build $CARGO_FLAGS; then
    echo -e "${GREEN}✅ Rust library built successfully!${NC}"
else
    echo -e "${RED}❌ Error: Rust build failed${NC}"
    exit 1
fi

cd ..

# Launch Flutter Linux app
echo ""
echo -e "${BLUE}Launching Flutter Linux app...${NC}"
echo "======================================="

if flutter run -d linux; then
    echo ""
    echo -e "${GREEN}✅ App closed successfully${NC}"
else
    echo ""
    echo -e "${RED}❌ Error: Flutter run failed${NC}"
    exit 1
fi
