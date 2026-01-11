#!/usr/bin/env bash
set -e

HOOK_DIR=".git/hooks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing pre-commit hooks..."

# Ensure .git/hooks directory exists
if [ ! -d "$HOOK_DIR" ]; then
    echo "Error: .git/hooks directory not found. Are you in the git repository root?"
    exit 1
fi

# Create pre-commit hook
cat > "$HOOK_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash

# Pre-commit hook for HeartBeat2
# Runs formatting checks, linting, and fast tests
# Skip with: git commit --no-verify

set -e

echo "Running pre-commit checks..."
START_TIME=$(date +%s)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found. Please install Rust.${NC}"
    exit 1
fi

# Change to rust directory
cd rust

echo -e "${YELLOW}1/3 Checking code formatting...${NC}"
if ! cargo fmt --all --check; then
    echo -e "${RED}Error: Code is not formatted. Run 'cargo fmt --all' to fix.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Formatting check passed${NC}"

echo -e "${YELLOW}2/3 Running clippy...${NC}"
if ! cargo clippy --all-targets --all-features -- -D warnings; then
    echo -e "${RED}Error: Clippy found warnings. Fix them before committing.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Clippy passed${NC}"

echo -e "${YELLOW}3/3 Running fast tests...${NC}"
if ! cargo test --lib --all-features; then
    echo -e "${RED}Error: Tests failed. Fix them before committing.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Tests passed${NC}"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "${GREEN}All pre-commit checks passed! (${ELAPSED}s)${NC}"
echo "Tip: Use 'git commit --no-verify' to skip these checks if needed."
EOF

# Make the hook executable
chmod +x "$HOOK_DIR/pre-commit"

echo "Pre-commit hook installed successfully!"
echo "The hook will run formatting checks, clippy, and fast tests before each commit."
echo "To skip the hook, use: git commit --no-verify"
