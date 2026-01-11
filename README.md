# Heart Beat - Smart Heart Rate Training Assistant

[![CI](https://github.com/heart-beat/heart-beat/actions/workflows/ci.yml/badge.svg)](https://github.com/heart-beat/heart-beat/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/heart-beat/heart-beat/branch/main/graph/badge.svg)](https://codecov.io/gh/heart-beat/heart-beat)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A real-time heart rate monitoring and training execution system with biofeedback alerts. Built with Rust core and Flutter UI for cross-platform mobile deployment.

## Overview

Heart Beat helps athletes train effectively by:

- **Real-time HR monitoring** via Bluetooth Low Energy heart rate sensors
- **Zone-based training plans** with structured workouts across 5 heart rate zones
- **Live biofeedback alerts** when heart rate deviates from target zone
- **Session execution** with automatic phase transitions and workout tracking
- **HRV analysis** for recovery and training load assessment

**Why this exists:** Manual HR zone tracking during workouts is distracting and error-prone. Heart Beat automates zone monitoring and provides instant audio/visual feedback, letting athletes focus on their training.

## Features

### Core Capabilities
- **BLE Heart Rate Streaming** - Real-time data from Polar, Garmin, Wahoo sensors
- **Kalman Filtering** - Smooth, accurate HR readings with noise reduction
- **Training Plan Execution** - Define multi-phase workouts with warmup, intervals, cooldown
- **Biofeedback Loop** - Instant notifications when HR exits target zone
- **State Machine Orchestration** - Robust connection and session management
- **CLI Development Tool** - Rich terminal interface for testing and simulation

### Platform Support
- **Android** - Native mobile app with background service
- **Linux CLI** - Full-featured command-line interface for development
- **Cross-platform Rust core** - Portable business logic and domain models

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Mobile UI | Flutter 3.16+ | Cross-platform native interface |
| Business Logic | Rust 2021 | Performance-critical core library |
| FFI Bridge | flutter_rust_bridge v2 | Seamless Rust ↔ Dart integration |
| BLE Stack | btleplug | Cross-platform Bluetooth Low Energy |
| State Management | statig | Type-safe state machines |
| Filtering | cardio-rs, kalman_filters | HR signal processing |
| Scheduling | tokio-cron-scheduler | Workout automation |

**Architecture:** Hexagonal (ports/adapters) with strict domain isolation, enabling easy testing and platform independence.

## Prerequisites

### Development Environment

| Tool | Version | Purpose |
|------|---------|---------|
| Rust | 1.75+ | Core library compilation |
| Flutter | 3.16+ | Mobile app framework |
| Android SDK | API 26-34 | Android build target |
| Android NDK | r25c+ | Rust cross-compilation |

### Install Dependencies

**Rust:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-linux-android armv7-linux-androideabi
```

**Flutter:**
```bash
# Follow official guide: https://docs.flutter.dev/get-started/install
flutter --version  # Verify 3.16+
```

**Android NDK:**
```bash
# Via Android Studio SDK Manager, or:
sdkmanager --install "ndk;25.2.9519653"
```

## Quick Start

### 1. Clone and Build

```bash
git clone https://github.com/heart-beat/heart-beat.git
cd heart-beat

# Build Rust core
cd rust
cargo build --release
cargo test

# Build Flutter app
cd ..
flutter pub get
flutter build apk
```

### 2. CLI Usage (Development)

The CLI tool provides rich features for testing and development:

**Scan for BLE devices:**
```bash
cargo run --bin cli devices scan
```

**Run mock training session:**
```bash
cargo run --bin cli session start --plan test_plan.json --mock
```

**Watch real-time HR stream:**
```bash
cargo run --bin cli session monitor --device "Polar H10"
```

**Create interactive training plan:**
```bash
cargo run --bin cli plan create
```

**Mock HR patterns for testing:**
```bash
# Steady state at 140 BPM
cargo run --bin cli mock steady --bpm 140

# Interval workout simulation
cargo run --bin cli mock interval --low 120 --high 165 --duration 60
```

### 3. Flutter App Usage

**Run on connected device:**
```bash
flutter run --release
```

**Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Features:**
- Scan and connect to heart rate monitors
- Execute training plans with phase tracking
- Real-time HR graph with zone overlay
- Audio/vibration alerts for zone deviations
- Session history and statistics

## Project Structure

```
heart-beat/
├── rust/                    # Rust core library
│   ├── src/
│   │   ├── domain/         # Business logic (HR, HRV, training plans)
│   │   ├── ports/          # Trait interfaces (BLE, notifications)
│   │   ├── adapters/       # Implementations (btleplug, mock)
│   │   ├── state/          # State machines (connectivity, session)
│   │   ├── scheduler/      # Workout orchestration
│   │   ├── api.rs          # Flutter bridge (FRB exports)
│   │   └── bin/cli.rs      # CLI development tool
│   └── tests/              # Integration tests
│
├── lib/                    # Flutter application
│   ├── screens/           # UI pages
│   ├── widgets/           # Reusable components
│   └── services/          # FFI bridge to Rust
│
├── android/               # Android-specific configuration
├── docs/                  # Documentation (architecture, guides)
└── .spec-workflow/       # Implementation specifications
```

## Development

### Testing

```bash
# Rust unit + integration tests
cd rust
cargo test

# Flutter widget tests
flutter test

# Integration tests (requires device)
flutter test integration_test/
```

### Code Quality

```bash
# Rust linting
cargo clippy -- -D warnings
cargo fmt --check

# Flutter analysis
flutter analyze
```

### Coverage

```bash
# Install coverage tool
cargo install cargo-llvm-cov

# Generate report
cargo llvm-cov --html
# Open target/llvm-cov/html/index.html
```

**Target:** 80% minimum coverage (90% for critical paths)

### Mock Testing

For development without physical HR monitors:

```bash
# Mock adapter provides simulated HR streams
cargo run --bin cli session start --plan test_plan.json --mock

# Simulate dropout scenarios
cargo run --bin cli mock dropout --frequency 0.1
```

## Documentation

- **[Architecture Guide](docs/architecture.md)** - System design and module boundaries
- **[User Manual](docs/user-guide.md)** - Training zones, plan creation, app usage
- **[Development Guide](docs/development.md)** - Setup, workflow, contribution process
- **[API Examples](docs/api-examples.md)** - Code examples for common tasks
- **[Contributing](CONTRIBUTING.md)** - How to contribute to the project

## Training Plans

Plans are JSON files defining structured workouts:

```json
{
  "name": "5K Interval Workout",
  "phases": [
    {"name": "Warmup", "duration_min": 10, "zone": 2},
    {"name": "Intervals", "duration_min": 5, "zone": 4},
    {"name": "Recovery", "duration_min": 3, "zone": 2},
    {"name": "Intervals", "duration_min": 5, "zone": 4},
    {"name": "Cooldown", "duration_min": 7, "zone": 1}
  ]
}
```

**Heart Rate Zones:**
| Zone | % Max HR | Intensity | Purpose |
|------|----------|-----------|---------|
| 1 | 50-60% | Very Light | Recovery |
| 2 | 60-70% | Light | Base building |
| 3 | 70-80% | Moderate | Aerobic endurance |
| 4 | 80-90% | Hard | Lactate threshold |
| 5 | 90-100% | Maximum | VO2 max |

See `docs/plans/` for example training plans.

## Performance

**Latency targets:**
- BLE packet → filtered HR: < 50ms
- Zone violation → notification: < 100ms
- Session state transition: < 10ms

**Resource usage:**
- Memory: < 50MB runtime
- Battery: < 5% drain per hour (screen off)
- CPU: < 10% average

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Code of conduct
- Development setup
- Pull request process
- Style guidelines

## Acknowledgments

- **cardio-rs** - Heart rate analysis algorithms
- **btleplug** - Cross-platform BLE library
- **flutter_rust_bridge** - Seamless Rust-Dart FFI
- Training zone formulas based on Karvonen method

---

**Status:** Active development | Core implementation complete | Android build in progress

For questions or issues, please [open an issue](https://github.com/heart-beat/heart-beat/issues).
