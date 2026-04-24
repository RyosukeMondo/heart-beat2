#!/bin/bash
# iOS Logs Script for Heart Beat
# Fetches and streams logs from the embedded debug server via iproxy tunnel
#
# Usage:
#   ./scripts/ios-logs.sh                    Fetch recent logs (JSON, pretty-printed)
#   ./scripts/ios-logs.sh --follow           Stream logs in real-time via WebSocket
#   ./scripts/ios-logs.sh --source=rust      Filter by source (rust|dart|native-ios|native-android|all)
#   ./scripts/ios-logs.sh --level=info       Filter by level (trace|debug|info|warn|error)
#   ./scripts/ios-logs.sh --limit=100        Limit number of logs (default: 100, max: 1000)
#
# Prerequisites:
#   brew install libimobiledevice jq websocat OR npm install -g wscat
#
# Note:
#   Run ./scripts/ios-debug-server.sh start first to establish the iproxy tunnel.

set -e

# Configuration
LOCAL_PORT=8888
BASE_URL="http://localhost:${LOCAL_PORT}"
WS_URL="ws://localhost:${LOCAL_PORT}"
LOCKFILE="/tmp/heart-beat-iproxy.lock"
CACHE_DIR="/tmp/heart-beat-logs-cache"

# Defaults
SOURCE="all"
LEVEL=""
LIMIT=100
FOLLOW=false
UDID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Level colors
declare -A LEVEL_COLORS=(
    ["TRACE"]="${CYAN}"
    ["DEBUG"]="${BLUE}"
    ["INFO"]="${GREEN}"
    ["WARN"]="${YELLOW}"
    ["ERROR"]="${RED}"
    ["WARNING"]="${YELLOW}"
)

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat iOS Logs${NC}"
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

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --source=rust|dart|native|all   Filter by log source (default: all)"
    echo "  --level=trace|debug|info|warn|error  Filter by minimum log level"
    echo "  --limit=N                       Limit number of logs (default: 100, max: 1000)"
    echo "  --follow                        Stream logs in real-time via WebSocket"
    echo "  --udid=UDID                     Target specific iOS device via USB"
    echo "  --help                          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Fetch recent logs"
    echo "  $0 --follow                           # Stream live logs"
    echo "  $0 --source=rust --level=error        # Stream only Rust errors"
    echo "  $0 --source=dart --limit=50           # Fetch 50 recent Dart logs"
    echo ""
    echo "Prerequisites:"
    echo "  brew install libimobiledevice jq websocat"
    echo "  # OR: npm install -g wscat"
    echo ""
    echo "Note: Run ./scripts/ios-debug-server.sh start first."
    exit 0
}

check_dependencies() {
    local missing=()

    if [ "$FOLLOW" = true ]; then
        # Prefer websocat, fall back to wscat
        if command -v websocat &> /dev/null; then
            WEBSOCKET_CMD="websocat"
        elif command -v wscat &> /dev/null; then
            WEBSOCKET_CMD="wscat"
        else
            missing+=("websocat or wscat (npm install -g wscat)")
        fi
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  brew install libimobiledevice jq websocat"
        echo "  # OR: npm install -g wscat"
        echo ""
        exit 1
    fi
}

check_iproxy_running() {
    if [ -f "$LOCKFILE" ]; then
        local pid
        pid=$(cat "$LOCKFILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi

    # Fallback: check if anything is listening on the local port
    if curl -sf "${BASE_URL}/debug/health" &> /dev/null; then
        return 0
    fi

    print_error "iproxy tunnel is not running."
    echo ""
    echo "Run the following first:"
    echo "  ./scripts/ios-debug-server.sh start"
    echo ""
    exit 1
}

build_query_params() {
    local params=""

    if [ "$SOURCE" != "all" ]; then
        params="${params}source=${SOURCE}&"
    fi

    if [ -n "$LEVEL" ]; then
        params="${params}level=${LEVEL}&"
    fi

    if [ "$LIMIT" -gt 0 ]; then
        params="${params}limit=${LIMIT}&"
    fi

    echo "$params"
}

fetch_logs() {
    local query_params="$1"
    local url="${BASE_URL}/debug/logs?${query_params}"

    if [ -z "$query_params" ]; then
        url="${BASE_URL}/debug/logs"
    fi

    local response
    response=$(curl -sf "$url")

    if [ $? -ne 0 ]; then
        print_error "Failed to fetch logs from ${url}"
        echo ""
        echo "Make sure the debug server is running on the device."
        exit 1
    fi

    echo "$response"
}

pretty_print_json() {
    local json="$1"
    local has_jq=false

    # Check if jq is available and works
    if command -v jq &> /dev/null && echo "$json" | jq . &> /dev/null 2>&1; then
        has_jq=true
    fi

    if [ "$has_jq" = true ]; then
        # Pretty print with jq, add color
        echo "$json" | jq -r '.data[] | "\(.timestamp) [\(.target)] [\(.level)] \(.message)"'
    else
        # Fallback: raw JSON
        echo "$json"
    fi
}

stream_logs_ws() {
    local query_params="$1"

    # Build WebSocket filter config from query params
    local ws_config="{}"
    if [ "$SOURCE" != "all" ] || [ -n "$LEVEL" ]; then
        local level_val="${LEVEL:-info}"
        local source_val="$SOURCE"
        ws_config="{\"level\":\"$level_val\",\"source\":\"$source_val\"}"
    fi

    if [ "$WEBSOCKET_CMD" = "websocat" ]; then
        echo "$ws_config" | websocat --ws-c-uri="$WS_URL/ws/logs" -u "$WS_URL/ws/logs" 2>&1
    else
        # wscat
        echo "$ws_config" | wscat -c "$WS_URL/ws/logs" 2>&1
    fi
}

colorize_line() {
    local line="$1"

    # Extract level from brackets like [INFO] [DEBUG] etc
    local level=$(echo "$line" | grep -oE '\[(TRACE|DEBUG|INFO|WARN|WARNING|ERROR)\]' | head -1 | tr -d '[]')
    local color="${LEVEL_COLORS[$level]:-${NC}}"

    if [ -n "$color" ] && [ "$color" != "${NC}" ]; then
        # Replace the level bracket with colored version
        echo "$line" | sed -E "s/\[($level)\]/\\${color}[$level]\\${NC}/g"
    else
        echo "$line"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source=*)
            SOURCE="${1#*=}"
            ;;
        --level=*)
            LEVEL="${1#*=}"
            ;;
        --limit=*)
            LIMIT="${1#*=}"
            ;;
        --follow)
            FOLLOW=true
            ;;
        --udid=*)
            UDID="${1#*=}"
            ;;
        --help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Validate
case "$SOURCE" in
    rust|dart|native-ios|native-android|all) ;;
    *)
        print_error "Invalid --source value: $SOURCE"
        echo "Use: rust, dart, native-ios, native-android, or all"
        exit 1
        ;;
esac

case "$LEVEL" in
    trace|debug|info|warn|error|"") ;;
    *)
        print_error "Invalid --level value: $LEVEL"
        echo "Use: trace, debug, info, warn, or error"
        exit 1
        ;;
esac

if [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 1000 ]; then
    print_error "Invalid --limit value: $LIMIT"
    echo "Use: 1 to 1000"
    exit 1
fi

main() {
    print_header

    check_dependencies

    if [ "$FOLLOW" = true ]; then
        check_iproxy_running
        print_info "Streaming live logs (Ctrl+C to stop)..."
        echo ""
        stream_logs_ws "$(build_query_params)"
    else
        check_iproxy_running
        print_info "Fetching logs..."
        echo ""

        local query_params
        query_params=$(build_query_params)
        local json
        json=$(fetch_logs "$query_params")

        if [ -z "$json" ]; then
            print_warn "No logs found"
            exit 0
        fi

        pretty_print_json "$json"
    fi
}

main