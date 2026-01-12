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
