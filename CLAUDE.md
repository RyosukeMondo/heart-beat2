# Heart Beat Development Guide

Quick reference for developers working on the Heart Beat project. For complete setup and workflow instructions, see [docs/DEVELOPER-GUIDE.md](docs/DEVELOPER-GUIDE.md).

## Development Quick Reference

### Common Commands

| Workflow | Command | Notes |
|----------|---------|-------|
| Linux CLI (fastest) | `cargo run --bin cli` | Rust CLI only, no UI |
| Linux Desktop | `./scripts/dev-linux.sh [release\|debug]` | Build Rust + Launch Flutter |
| Watch Mode | `./scripts/dev-watch.sh` | Auto-rebuild on changes |
| Android Deploy | `./scripts/adb-install.sh` | One-command build + install + launch |
| Android Logs | `./scripts/adb-logs.sh [OPTIONS]` | Filter Rust logs from device |
| Android Permissions | `./scripts/adb-permissions.sh` | Manage app permissions |
| BLE Debug | `./scripts/adb-ble-debug.sh enable\|disable\|status` | HCI snoop logging |
| Run Tests | `cargo test` | Run all Rust tests |
| Run Tests (CLI) | `cargo test --bin cli` | CLI-specific tests |
| iOS USB debug logs | `./scripts/ios-debug-server.sh start && ./scripts/ios-logs.sh --follow` | Requires libimobiledevice + iOS device |

### Debug Log Levels

Control Rust logging verbosity with `RUST_LOG` environment variable:

```bash
# All debug logs
RUST_LOG=debug cargo run --bin cli

# Only heart_beat module debug logs
RUST_LOG=heart_beat=debug cargo run --bin cli

# Specific module trace logs
RUST_LOG=heart_beat::ble=trace cargo run --bin cli

# Multiple modules
RUST_LOG=heart_beat::ble=debug,heart_beat::training=info cargo run --bin cli
```

Available log levels (lowest to highest): `trace`, `debug`, `info`, `warn`, `error`

### Quick Start

**First-time setup:**
```bash
./scripts/dev-setup.sh  # Install all dependencies
./scripts/check-deps.sh  # Verify installation
```

**Daily development:**
- Linux testing: `cargo run --bin cli --mock`
- UI testing: `./scripts/dev-linux.sh`
- Android testing: `./scripts/adb-install.sh`

For detailed workflows, debugging tips, and script reference, see [docs/DEVELOPER-GUIDE.md](docs/DEVELOPER-GUIDE.md).

### Health Monitoring — Manual Testing

The Health screen (`/health`) shows live BPM, 1h/24h/7d rolling averages, a 24h sparkline, and the low-HR rule status banner. The rule fires a local notification when sustained average HR drops below the configured threshold.

**Forcing a low-HR notification (manual test):**
- Open **Health Settings** and set **Low HR threshold** to `200` (or any value above realistic resting HR).
- Set **Sustained window** to `1 min` (minimum) to speed up the test.
- Ensure quiet hours are off (or set them to a time range that doesn't include now).
- Wait up to 30 seconds — the rule ticks every 30s while connected.
- A notification "Heart rate low — Average HR was N bpm over the last 1 min" should appear.
- Reset threshold back to `70` after the test.

**Files:**
- `lib/src/services/health_settings_service.dart` — threshold, sustained window, quiet hours, cadence, notifications toggle
- `lib/src/services/hr_history_service.dart` — `samplesInRange`, `rollingAvg`, `latestSample`
- `lib/src/services/coaching_cue_service.dart` — handles `sustained_low_hr` cue → local notification
- `rust/src/hr_store/` — Rust JSONL store + query functions (`samples_in_range`, `rolling_avg`, `latest_sample`)
- `rust/src/coaching/low_hr_rule.rs` — rule engine: rolling avg, hysteresis, quiet-hours suppression
