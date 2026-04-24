#!/bin/bash
# iOS Debug Server Script for Heart Beat
# Wraps iproxy (libimobiledevice) to tunnel the embedded debug server from iOS device to Mac
#
# Usage:
#   ./scripts/ios-debug-server.sh start     Start iproxy tunnel (8888 -> device:8888)
#   ./scripts/ios-debug-server.sh stop      Stop iproxy tunnel
#   ./scripts/ios-debug-server.sh status    Check if iproxy is running
#   ./scripts/ios-debug-server.sh restart  Restart iproxy tunnel
#
# Prerequisites:
#   brew install libimobiledevice

set -e

# Configuration
LOCAL_PORT=8888
DEVICE_PORT=8888
LOCKFILE="/tmp/heart-beat-iproxy.lock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Heart Beat iOS Debug Server${NC}"
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
    echo "Usage: $0 <start|stop|status|restart>"
    echo ""
    echo "Commands:"
    echo "  start   Start iproxy tunnel (${LOCAL_PORT} -> device:${DEVICE_PORT})"
    echo "  stop    Stop iproxy tunnel"
    echo "  status  Check if iproxy tunnel is running"
    echo "  restart Restart iproxy tunnel"
    echo ""
    echo "Prerequisites:"
    echo "  brew install libimobiledevice"
    exit 0
}

check_iproxy() {
    if ! command -v iproxy &> /dev/null; then
        print_error "iproxy not found."
        echo ""
        echo "Install libimobiledevice:"
        echo "  brew install libimobiledevice"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
}

check_device() {
    if ! command -v idevice_id &> /dev/null; then
        print_warn "idevice_id not found. Device check skipped."
        return 0
    fi

    local device_count
    device_count=$(idevice_id -l 2>/dev/null | grep -c "." || true)

    if [ "$device_count" -eq 0 ]; then
        print_warn "No iOS device connected via USB."
        echo "Connect a device and ensure it's trusted."
        echo ""
    else
        print_success "iOS device connected"
    fi
}

save_pid() {
    echo "$1" > "$LOCKFILE"
}

load_pid() {
    if [ -f "$LOCKFILE" ]; then
        cat "$LOCKFILE"
    else
        echo ""
    fi
}

is_running() {
    local pid
    pid=$(load_pid)

    if [ -z "$pid" ]; then
        return 1
    fi

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        # Stale lockfile
        rm -f "$LOCKFILE"
        return 1
    fi
}

do_start() {
    if is_running; then
        local pid
        pid=$(load_pid)
        print_warn "iproxy already running (PID: $pid)"
        print_info "Tunnel: localhost:${LOCAL_PORT} -> device:${DEVICE_PORT}"
        return 0
    fi

    check_iproxy
    check_device

    print_info "Starting iproxy tunnel..."
    print_info "Tunnel: localhost:${LOCAL_PORT} -> device:${DEVICE_PORT}"
    echo ""

    # Start iproxy in background
    # -l enables USB mode (requires device connected)
    iproxy "${LOCAL_PORT}:${DEVICE_PORT}" -l &
    local pid=$!

    save_pid "$pid"

    # Give it a moment to start
    sleep 1

    if is_running; then
        print_success "iproxy started (PID: $pid)"
        echo ""
        echo "Debug server accessible at: http://localhost:${LOCAL_PORT}"
        echo ""
        echo "Stop with: $0 stop"
    else
        print_error "Failed to start iproxy"
        rm -f "$LOCKFILE"
        exit 1
    fi
}

do_stop() {
    if ! is_running; then
        print_info "iproxy is not running"
        return 0
    fi

    local pid
    pid=$(load_pid)

    print_info "Stopping iproxy (PID: $pid)..."

    if kill "$pid" 2>/dev/null; then
        # Give it time to clean up
        sleep 1
        rm -f "$LOCKFILE"
        print_success "iproxy stopped"
    else
        print_warn "Process already gone"
        rm -f "$LOCKFILE"
    fi
}

do_status() {
    if is_running; then
        local pid
        pid=$(load_pid)
        print_success "iproxy is running (PID: $pid)"
        print_info "Tunnel: localhost:${LOCAL_PORT} -> device:${DEVICE_PORT}"
        echo ""
        echo "Debug server accessible at: http://localhost:${LOCAL_PORT}"
    else
        print_info "iproxy is not running"
        echo ""
        echo "Start with: $0 start"
    fi
}

do_restart() {
    print_info "Restarting iproxy tunnel..."
    do_stop
    sleep 1
    do_start
}

main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    print_header

    local command="$1"

    case "$command" in
        start)
            do_start
            ;;
        stop)
            do_stop
            ;;
        status)
            do_status
            ;;
        restart)
            do_restart
            ;;
        *)
            print_error "Unknown command: $command"
            usage
            ;;
    esac
}

main "$@"
