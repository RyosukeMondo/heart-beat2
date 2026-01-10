# Technology Stack

## Project Type
Cross-platform mobile application with native Rust core logic, targeting Android for production and Linux CLI for development/debugging. Hybrid architecture using Flutter for UI and Rust for deterministic signal processing and BLE communication.

## Core Technologies

### Primary Language(s)
- **Rust**: Core logic, BLE communication, signal processing (Edition 2024)
- **Dart/Flutter**: UI layer, permission handling, user interaction
- **Runtime**: Tokio async runtime (Rust), Flutter engine (Dart)

### Key Dependencies/Libraries

**Rust Core:**
| Library | Version | Purpose |
|---------|---------|---------|
| `tokio` | 1.x | Async runtime with full features |
| `flutter_rust_bridge` | 2.x | Type-safe FFI bindings to Flutter |
| `btleplug` | 0.11 | Cross-platform BLE communication |
| `cardio-rs` | 0.1 | HRV analysis (RMSSD, SDNN) |
| `kalman_filters` | 0.1 | Signal smoothing and noise reduction |
| `statig` | 0.3 | Hierarchical state machine |
| `tokio-cron-scheduler` | 0.13 | Training plan execution |
| `tracing` | 0.1 | Structured logging |
| `anyhow` | 1.x | Error handling |
| `serde` | 1.x | Serialization |
| `uuid` | 1.x | BLE UUID handling |

**Rust Dev Dependencies:**
| Library | Version | Purpose |
|---------|---------|---------|
| `mockall` | 0.13 | Trait mocking for unit tests |
| `proptest` | 1.5 | Property-based testing |

**Flutter:**
| Package | Purpose |
|---------|---------|
| `flutter_rust_bridge` | FFI bridge to Rust |
| `flutter_background_service` | Android foreground service |
| `patrol` | Native UI testing (permission dialogs) |

### Application Architecture
Hexagonal Architecture (Ports and Adapters):

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter (Dart)                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │     UI      │  │   Widgets   │  │  Permissions    │ │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘ │
└─────────┼────────────────┼──────────────────┼──────────┘
          │                │                  │
          └────────────────┼──────────────────┘
                           │ FRB v2 (StreamSink)
┌──────────────────────────┼──────────────────────────────┐
│                     Rust Core                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  BLE Comm   │  │   Signal    │  │  State Machine  │ │
│  │  (btleplug) │  │  Processing │  │    (statig)     │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │   Kalman    │  │  HRV Calc   │  │   Scheduler     │ │
│  │   Filter    │  │ (cardio-rs) │  │  (tokio-cron)   │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Layers:**
- **Domain (Rust)**: HR zone calculation, training plan management, signal filtering
- **Ports (Rust Traits)**: `BleAdapter`, `NotificationPort` interfaces
- **Adapters**: btleplug (BLE), FRB (Flutter UI), CLI (debug output)

### Data Storage (if applicable)
- **Primary storage**: Local file system (JSON training plans, session logs)
- **Caching**: In-memory state within Rust core
- **Data formats**: JSON for configuration, binary BLE packets

### External Integrations (if applicable)
- **Hardware**: Coospo HW9 via Bluetooth Low Energy
- **Protocols**: BLE GATT (Heart Rate Service 0x180D, Battery Service 0x180F)
- **Authentication**: N/A (direct BLE pairing)

### Monitoring & Dashboard Technologies (if applicable)
- **Dashboard Framework**: Flutter widgets with StreamBuilder
- **Real-time Communication**: FRB v2 StreamSink (Rust → Dart)
- **Visualization Libraries**: Flutter built-in charts
- **State Management**: Rust statig HSM as source of truth

## Development Environment

### Build & Development Tools
- **Build System**: Cargo (Rust), Flutter CLI, FRB codegen
- **Package Management**: Cargo (Rust), pub (Dart)
- **Development workflow**: CLI-first development (see below)

### CLI-First Development Strategy
The project adopts a **CLI-first implementation** approach to drastically reduce development cycle time and minimize UAT burden:

**Rationale:**
- Android emulator startup is slow and BLE passthrough is unreliable
- Real device deployment adds 30-60 seconds per iteration
- CLI enables code → compile → test in seconds

**Implementation:**
```
src/
├── lib.rs          # Core library (shared by CLI and Flutter)
├── bin/
│   └── cli.rs      # Standalone CLI binary
└── api.rs          # FRB-exposed API for Flutter
```

**CLI Capabilities (`bin/cli.rs`):**
1. **BLE Scanning**: Discover Coospo HW9 using Linux BlueZ backend
2. **Connection & Subscription**: Stream HR data to terminal in real-time
3. **Logic Verification**: Apply Kalman filter and state machine, log transitions
4. **Mock Mode**: Simulate HR data patterns for testing without hardware

**Development Flow:**
```
[Code Change] → cargo build → ./target/debug/cli scan → Connect → Verify
     └── Entire cycle: ~5 seconds
```

**Benefits:**
- Unit tests run on CI Linux runners with mocked BLE
- Integration tests verify full packet → filter → state machine pipeline
- Only final E2E/UAT requires real Android device
- Same domain logic runs on both CLI and mobile (hexagonal architecture)

### Code Quality Tools
- **Static Analysis**: `cargo clippy` (Rust), `dart analyze` (Flutter)
- **Formatting**: `cargo fmt` (Rust), `dart format` (Flutter)
- **Testing Framework**: `cargo test` + proptest (Rust), `patrol` (Flutter E2E)
- **Coverage**: `cargo-tarpaulin` (threshold: 80%)
- **Documentation**: `cargo doc`, Dart doc comments

### Version Control & Collaboration
- **VCS**: Git
- **Branching Strategy**: Feature branches with PR review
- **Code Review Process**: PR-based review with CI checks

### Dashboard Development (if applicable)
- **Live Reload**: Flutter hot reload for UI, cargo watch for Rust CLI
- **Port Management**: N/A (mobile app)
- **Multi-Instance Support**: N/A

## Deployment & Distribution (if applicable)
- **Target Platform(s)**: Android (production), Linux (development)
- **Distribution Method**: APK/Play Store (Android), cargo build (CLI)
- **Installation Requirements**: Android 8.0+, Bluetooth 5.0 device
- **Update Mechanism**: Play Store updates

## Technical Requirements & Constraints

### Performance Requirements
- Response time: < 100ms from BLE event to UI update
- Memory usage: Minimal heap allocation in hot path
- Startup time: < 2s to ready state

### Compatibility Requirements
- **Platform Support**: Android 8.0+ (API 26), Linux x86_64 (development)
- **Hardware**: Bluetooth 5.0, Coospo HW9 heart rate monitor
- **Standards Compliance**: Bluetooth SIG Heart Rate Profile

### Security & Compliance
- **Security Requirements**: Local-only data storage, no cloud transmission
- **Threat Model**: Physical device access only, no remote attack surface

### Scalability & Reliability
- **Session Duration**: 60+ minutes continuous operation
- **Reconnection**: Automatic retry on BLE disconnection
- **Battery Monitoring**: Warning at 15% device battery

## Technical Decisions & Rationale

### Decision Log
1. **Rust for core logic**: No GC pauses, memory safety, deterministic timing for real-time signal processing
2. **FRB v2 over MethodChannel**: Type-safe auto-generated bindings, native async support, StreamSink for continuous data
3. **statig over smlang**: Hierarchical state machine support, better async integration, typestate-like safety
4. **btleplug as primary BLE**: Open source, multi-platform; abstracted for swappability to simplersble if stability issues arise
5. **Kalman filter over moving average**: Better balance of tracking responsiveness and noise rejection
6. **HW9 as input-only device**: Avoid reverse-engineering LED control; use phone for all feedback

## Known Limitations

- **btleplug Android stability**: JNI threading issues reported; mitigated by BleAdapter abstraction allowing swap to simplersble
- **Background execution**: Android aggressive process killing; requires Foreground Service implementation
- **Motion artifacts**: Optical HR inherently noisy during movement; Kalman filter provides mitigation but not elimination
