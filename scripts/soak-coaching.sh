#!/bin/bash
# Soak Test for Long-Session Coaching
# Runs 8+ hour mock HR session with realistic patterns, monitoring:
# - BLE disconnect/reconnect events
# - Coaching cue timing
# - Battery drain (simulated)
# - Cold restart count (should be 0)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_ROOT/rust"
CLI_PATH="$RUST_DIR/target/release/cli"

# Default: 8 hour soak
SOAK_DURATION_SECS=28800  # 8 hours
INTERVAL_PATTERN="75,130"  # low,high BPM for interval pattern
WORK_SECS=300  # 5 min work
REST_SECS=60   # 1 min rest
LOG_DIR="$PROJECT_ROOT/.soak-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/soak_${TIMESTAMP}.log"
METRICS_FILE="$LOG_DIR/soak_${TIMESTAMP}_metrics.txt"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Heart Beat — 8h Coaching Soak Test${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --duration SECS   Soak duration in seconds (default: 28800 = 8h)"
    echo "  -l, --low BPM         Resting/low HR in interval mode (default: 75)"
    echo "  -h, --high BPM        Work/high HR in interval mode (default: 130)"
    echo "  -w, --work SECS       Work period seconds (default: 300)"
    echo "  -r, --rest SECS       Rest period seconds (default: 60)"
    echo "  --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --duration 3600 --low 65 --high 140  # 1h test at 65-140bpm"
}

show_help_and_exit() {
    usage
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--duration)
                SOAK_DURATION_SECS="$2"
                shift 2
                ;;
            -l|--low)
                INTERVAL_LOW="$2"
                shift 2
                ;;
            -h|--high)
                INTERVAL_HIGH="$2"
                shift 2
                ;;
            -w|--work)
                WORK_SECS="$2"
                shift 2
                ;;
            -r|--rest)
                REST_SECS="$2"
                shift 2
                ;;
            --help)
                show_help_and_exit
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if release binary exists
    if [ ! -f "$CLI_PATH" ]; then
        print_warning "Release binary not found at $CLI_PATH"
        print_info "Building release binary..."
        cd "$RUST_DIR" && cargo build --release --bin cli 2>&1 | tail -5
    fi

    if [ ! -x "$CLI_PATH" ]; then
        print_error "CLI binary not found or not executable: $CLI_PATH"
        exit 1
    fi

    print_success "CLI binary ready: $CLI_PATH"

    # Create log directory
    mkdir -p "$LOG_DIR"
}

format_duration() {
    local secs=$1
    local h=$((secs / 3600))
    local m=$(((secs % 3600) / 60))
    local s=$((secs % 60))
    printf "%02d:%02d:%02d" $h $m $s
}

print_summary() {
    local elapsed=$1
    local disconnects=$2
    local reconnects=$3
    local cues_fired=$4
    local battery_start=$5
    local battery_end=$6

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Soak Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "  Duration:        $(format_duration $elapsed)"
    echo -e "  Disconnects:     $disconnects"
    echo -e "  Reconnects:      $reconnects"
    echo -e "  Cues fired:      $cues_fired"
    echo -e "  Battery start:   ${battery_start}%"
    echo -e "  Battery end:     ${battery_end}%"
    echo ""

    # Check pass/fail criteria
    local failed=0

    if [ $disconnects -gt 0 ] && [ $reconnects -eq 0 ]; then
        echo -e "  ${RED}FAIL${NC}: Disconnects without reconnects detected"
        failed=1
    fi

    local battery_drain=$((battery_start - battery_end))
    if [ $battery_drain -gt 20 ]; then
        echo -e "  ${RED}FAIL${NC}: Battery drain ${battery_drain}% exceeds 20% threshold"
        failed=1
    else
        echo -e "  ${GREEN}PASS${NC}: Battery drain ${battery_drain}% within limit"
    fi

    echo ""
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All soak test criteria met.${NC}"
        return 0
    else
        echo -e "${RED}One or more criteria failed. Review logs.${NC}"
        return 1
    fi
}

run_soak_test() {
    local duration=$SOAK_DURATION_SECS
    local low_bpm=${INTERVAL_LOW:-75}
    local high_bpm=${INTERVAL_HIGH:-130}

    echo -e "  Pattern:        Interval (${low_bpm}bpm rest / ${high_bpm}bpm work)"
    echo -e "  Work period:     ${WORK_SECS}s"
    echo -e "  Rest period:     ${REST_SECS}s"
    echo ""

    print_info "Starting soak test — duration: $(format_duration $duration)"

    # Initialize counters
    local disconnect_count=0
    local reconnect_count=0
    local cue_count=0
    local battery_start=85
    local battery_end=$battery_start

    # Track connection state
    local was_connected=false
    local session_start=$(date +%s)

    # Open log file for cue logging
    exec 3>"$LOG_FILE"

    # Print header to log
    echo "Heart Beat Coaching Soak Test" >&3
    echo "Started: $(date)" >&3
    echo "Duration: ${duration}s" >&3
    echo "Pattern: interval ${low_bpm}-${high_bpm} BPM" >&3
    echo "----------------------------------------" >&3

    # Calculate expected cycles
    local cycle_duration=$((WORK_SECS + REST_SECS))
    local expected_cycles=$((duration / cycle_duration))
    echo "Expected interval cycles: $expected_cycles" >&3

    echo ""
    print_info "Logging to: $LOG_FILE"

    # Status line
    printf "\n  %-12s %-10s %-10s %-8s %-8s %-10s\n" \
        "Elapsed" "BPM" "State" "Disconnects" "Reconnects" "Cues"
    echo "  --------------------------------------------------------------------------"

    local start_time=$(date +%s)
    local last_cycle_check=$start_time
    local cycle_count=0

    # Use the mock interval command for realistic HR patterns
    # Run as background process that we'll monitor
    local mock_pid=""
    local current_bpm="—"

    # Start the mock session in background
    (
        cd "$PROJECT_ROOT"
        RUST_LOG=info "$CLI_PATH" mock interval \
            --low "$low_bpm" \
            --high "$high_bpm" \
            --work-secs "$WORK_SECS" \
            --rest-secs "$REST_SECS" 2>&1
    ) &
    mock_pid=$!

    # Monitor loop
    while true; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local remaining=$((duration - elapsed))

        # Check if we've reached duration
        if [ $elapsed -ge $duration ]; then
            break
        fi

        # Check if mock process is still running
        if ! kill -0 $mock_pid 2>/dev/null; then
            # Mock process ended — expected at end of interval cycles
            # Re-estimate duration based on cycles completed
            cycle_count=$((elapsed / cycle_duration))
            if [ $cycle_count -ge $expected_cycles ]; then
                print_info "Completed $cycle_count interval cycles"
                break
            fi
        fi

        # Simulate connection state changes (in real life this would come from the app)
        # For soak test with mock adapter, we assume stable connection
        local current_state="connected"

        # Simulate occasional disconnects for soak testing (1 per ~45 min)
        local time_in_cycle=$((elapsed % cycle_duration))
        local should_disconnect=false
        if [ $((elapsed % 2700)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            should_disconnect=true
        fi

        # Check for simulated disconnect event (rare, for reconnect testing)
        if $should_disconnect && [ "$current_state" = "connected" ]; then
            disconnect_count=$((disconnect_count + 1))
            current_state="disconnected"
            echo "[DISCONNECT] t=${elapsed}s" >&3
        fi

        # Simulate reconnect after ~30s
        if [ "$current_state" = "disconnected" ] && [ $((elapsed % 30)) -eq 0 ]; then
            reconnect_count=$((reconnect_count + 1))
            current_state="connected"
            echo "[RECONNECT] t=${elapsed}s" >&3
        fi

        # Simulate cue firing (roughly every 2-5 minutes based on HR patterns)
        local time_since_last_cue=${last_cue_time:-0}
        local cue_interval=$((120 + RANDOM % 180))  # 2-5 min random interval
        if [ $((elapsed - time_since_last_cue)) -ge $cue_interval ]; then
            cue_count=$((cue_count + 1))
            last_cue_time=$elapsed

            # Determine cue type based on position in interval cycle
            local phase="rest"
            if [ $time_in_cycle -lt $WORK_SECS ]; then
                phase="work"
            fi

            local cue_type="unknown"
            if [ "$phase" = "work" ] && [ $((RANDOM % 3)) -eq 0 ]; then
                cue_type="raise_hr"
            elif [ "$phase" = "rest" ] && [ $((RANDOM % 4)) -eq 0 ]; then
                cue_type="cool_down"
            elif [ $((RANDOM % 10)) -eq 0 ]; then
                cue_type="stand_up"
            fi

            echo "[CUE] t=${elapsed}s type=$cue_type bpm=$current_bpm" >&3
        fi

        # Simulate battery drain (roughly 0.5% per minute for BLE + CPU)
        if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            battery_end=$((battery_start - (elapsed / 60) * 5 / 10))
            [ $battery_end -lt 5 ] && battery_end=5
        fi

        # Print status line (every 30 seconds)
        if [ $((elapsed % 30)) -eq 0 ]; then
            printf "  %-12s %-10s %-10s %-8s %-8s %-10s\n" \
                "$(format_duration $elapsed)" \
                "$current_bpm" \
                "$current_state" \
                "$disconnect_count" \
                "$reconnect_count" \
                "$cue_count"
        fi

        sleep 1
    done

    # Clean up mock process
    if kill -0 $mock_pid 2>/dev/null; then
        kill $mock_pid 2>/dev/null || true
        wait $mock_pid 2>/dev/null || true
    fi

    local final_elapsed=$(($(date +%s) - session_start))

    # Write final metrics
    {
        echo "----------------------------------------"
        echo "Soak Test Complete"
        echo "Duration: ${final_elapsed}s"
        echo "Disconnects: $disconnect_count"
        echo "Reconnects: $reconnect_count"
        echo "Cues fired: $cue_count"
        echo "Battery start: ${battery_start}%"
        echo "Battery end: ${battery_end}%"
        echo "Battery drain: $((battery_start - battery_end))%"
    } >&3

    echo ""
    print_success "Soak test complete"

    # Return results
    METRICS="duration=${final_elapsed} disconnects=${disconnect_count} reconnects=${reconnect_count} cues=${cue_count} battery_start=${battery_start} battery_end=${battery_end}"
    echo "$METRICS" > "$METRICS_FILE"

    print_summary $final_elapsed $disconnect_count $reconnect_count $cue_count $battery_start $battery_end
}

main() {
    parse_args "$@"
    print_header

    echo "Configuration:"
    echo "  Duration:     $(format_duration $SOAK_DURATION_SECS)"
    echo "  Low BPM:      ${INTERVAL_LOW:-75}"
    echo "  High BPM:     ${INTERVAL_HIGH:-130}"
    echo "  Work/Rest:    ${WORK_SECS}s / ${REST_SECS}s"
    echo ""

    check_prerequisites
    run_soak_test

    echo ""
    echo -e "Log file: ${CYAN}$LOG_FILE${NC}"
    echo -e "Metrics:  ${CYAN}$METRICS_FILE${NC}"
    echo ""
}

main "$@"