# Architecture Documentation

## Table of Contents
- [Overview](#overview)
- [Hexagonal Architecture](#hexagonal-architecture)
- [Module Breakdown](#module-breakdown)
- [Dependency Graph](#dependency-graph)
- [Data Flow](#data-flow)
- [State Machines](#state-machines)
- [Key Design Decisions](#key-design-decisions)
- [Adding New Features](#adding-new-features)

## Overview

Heart Beat uses **hexagonal architecture** (ports and adapters pattern) to achieve:

- **Domain isolation** - Business logic independent of external dependencies
- **Platform independence** - Rust core runs on CLI, Android, iOS, desktop
- **Testability** - Mock implementations for all external interfaces
- **Flexibility** - Swap BLE libraries, notification systems, or platforms without touching domain code

### Architecture Principles

1. **Domain-centric** - Business rules in `domain/`, free of infrastructure concerns
2. **Dependency inversion** - Ports (traits) define contracts, adapters implement them
3. **State machines** - Explicit state modeling using `statig` for robustness
4. **CLI-first** - Rich terminal tool enables rapid development without mobile builds
5. **Type safety** - Compile-time guarantees via Rust's type system

## Hexagonal Architecture

```mermaid
graph TB
    subgraph "External World"
        UI[Flutter UI<br/>Mobile Interface]
        BLE[BLE Hardware<br/>Coospo HW9]
        CLI[CLI Tool<br/>Terminal]
    end

    subgraph "Adapters Layer - Infrastructure"
        FRB[FRB API Bridge<br/>api.rs]
        BtlePlug[BtleplugAdapter<br/>Real BLE Comms]
        MockBLE[MockAdapter<br/>Test Double]
        CLINotif[CliNotificationAdapter<br/>Terminal Output]
        MockNotif[MockNotificationAdapter<br/>Silent Test]
    end

    subgraph "Ports Layer - Contracts"
        BlePort[BleAdapter Trait<br/>scan, connect, stream]
        NotifPort[NotificationPort Trait<br/>zone alerts, feedback]
    end

    subgraph "Core Domain - Business Logic"
        Domain[domain/<br/>Pure Functions]
        HR[HeartRateMeasurement<br/>FilteredHeartRate]
        Filter[KalmanFilter<br/>Noise Reduction]
        HRV[HRV Analysis<br/>RMSSD, SDNN]
        Plan[TrainingPlan<br/>Phases, Zones]
    end

    subgraph "Orchestration Layer"
        State[State Machines<br/>statig FSM]
        ConnSM[Connection SM<br/>BLE Lifecycle]
        SessSM[Session SM<br/>Training Execution]
        Sched[SessionExecutor<br/>Plan Runner]
    end

    UI --> FRB
    CLI --> CLINotif
    CLI --> MockBLE
    BLE --> BtlePlug

    FRB --> BlePort
    FRB --> NotifPort
    BtlePlug -.implements.-> BlePort
    MockBLE -.implements.-> BlePort
    CLINotif -.implements.-> NotifPort
    MockNotif -.implements.-> NotifPort

    BlePort --> ConnSM
    NotifPort --> SessSM

    ConnSM --> State
    SessSM --> State
    State --> Sched

    Sched --> Domain
    Domain --> HR
    Domain --> Filter
    Domain --> HRV
    Domain --> Plan

    style Domain fill:#e1f5dd
    style BlePort fill:#fff4e6
    style NotifPort fill:#fff4e6
    style BtlePlug fill:#e3f2fd
    style MockBLE fill:#e3f2fd
```

**Flow:** External events → Adapters → Ports → Domain → State/Scheduler → Ports → Adapters → External actions

**Why Hexagonal?** The core domain (green) has **zero dependencies** on infrastructure. All external dependencies are injected via ports (traits), allowing the same domain logic to run on CLI, Android, iOS, or in tests without modification.

## Module Breakdown

### `domain/` - Business Logic

**Responsibility:** Pure domain types and algorithms, no dependencies on infrastructure.

**Files:**
- `heart_rate.rs` - HR data types, BLE parsing, zone calculations
- `filters.rs` - Kalman filter for noise reduction
- `hrv.rs` - Heart rate variability analysis (RMSSD, SDNN)
- `training_plan.rs` - Training plan data model, phases, zones

**Key Types:**
```rust
HeartRateMeasurement   // Raw BLE measurement
FilteredHeartRate      // Kalman-filtered HR with metadata
Zone                   // HR zones (Z1-Z5)
TrainingPlan           // Structured workout definition
Phase                  // Individual workout segment
```

**Constraints:**
- No `async` code (pure functions)
- No external I/O
- No platform-specific code
- 100% unit testable without mocks

### `ports/` - Trait Interfaces

**Responsibility:** Define contracts for external dependencies.

**Files:**
- `ble_adapter.rs` - BLE operations (scan, connect, stream)
- `notification.rs` - User notifications (audio, vibration, visual)

**Key Traits:**
```rust
pub trait BleAdapter {
    async fn scan_devices(&self) -> Result<Vec<DiscoveredDevice>>;
    async fn connect(&mut self, device_id: &str) -> Result<()>;
    async fn stream_heart_rate(&self) -> Result<Receiver<HeartRateMeasurement>>;
    async fn disconnect(&mut self) -> Result<()>;
}

pub trait NotificationPort {
    async fn notify_zone_deviation(&self, current: Zone, target: Zone);
    async fn notify_phase_change(&self, phase_name: &str);
}
```

**Why separate ports?**
- Enables testing with mocks
- Swappable implementations (btleplug → bluez, etc.)
- Platform-specific adapters (Android service, iOS, CLI)

### `adapters/` - Implementations

**Responsibility:** Concrete implementations of port traits.

**Files:**
- `btleplug_adapter.rs` - Real BLE via btleplug library
- `mock_adapter.rs` - Simulated HR data for testing
- `cli_notification_adapter.rs` - Terminal output notifications
- `mock_notification_adapter.rs` - Test notification capture

**Adapter Selection:**
```rust
// Production Android
let adapter = BtleplugAdapter::new();

// Development CLI
let adapter = MockAdapter::new();
```

**Testing Strategy:**
- Unit tests use `MockAdapter` for deterministic behavior
- Integration tests use `BtleplugAdapter` with real devices
- CLI uses mock by default, real adapter with `--device` flag

### `state/` - State Machines

**Responsibility:** Manage application lifecycle and session execution.

**Files:**
- `connectivity.rs` - BLE connection state machine
- `session.rs` - Training session execution state machine

**Connection States:**

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Scanning: StartScan
    Scanning --> Connecting: DeviceFound
    Scanning --> Idle: Timeout/Cancel
    Connecting --> Connected: GattReady
    Connecting --> Disconnected: Error
    Connected --> Streaming: StartStream
    Streaming --> Disconnected: Disconnect/Error
    Disconnected --> Idle: Reset
    Disconnected --> Scanning: Retry

    note right of Disconnected
        Auto-reconnect logic:
        3 attempts with
        exponential backoff
    end note
```

**Session States:**

```mermaid
stateDiagram-v2
    [*] --> Ready
    Ready --> Running: Start
    Running --> Paused: Pause
    Running --> Completed: AllPhasesComplete
    Paused --> Running: Resume
    Paused --> Completed: Stop
    Completed --> [*]

    state Running {
        [*] --> WarmUp
        WarmUp --> Work: IntervalComplete
        Work --> Recovery: IntervalComplete
        Recovery --> Work: MoreIntervals
        Recovery --> CoolDown: LastInterval
        CoolDown --> [*]
    }

    note right of Running
        Hierarchical states:
        WarmUp→Work→Recovery
        cycles, then CoolDown
    end note
```

**Why state machines?**
- Explicit, compile-checked state transitions prevent bugs
- Prevents invalid states (e.g., streaming while disconnected)
- Clear error handling and recovery paths
- Type-safe event handling with `statig`
- Hierarchical states (Running has substates) reduce complexity

### `scheduler/` - Orchestration

**Responsibility:** Execute training plans by coordinating state machines and adapters.

**Files:**
- `executor.rs` - Session orchestration logic
- `mod.rs` - Public API and types

**Key Type:**
```rust
pub struct SessionExecutor {
    plan: TrainingPlan,
    ble_adapter: Arc<dyn BleAdapter>,
    notifier: Arc<dyn NotificationPort>,
    filter: KalmanFilter,
}
```

**Workflow:**
1. Load `TrainingPlan` from JSON
2. Connect to BLE device via `BleAdapter`
3. Execute phases sequentially
4. Filter HR data with `KalmanFilter`
5. Detect zone deviations, trigger `NotificationPort`
6. Transition phases, handle session state
7. Persist session summary on completion

### `api.rs` - Flutter Bridge

**Responsibility:** Expose Rust functions to Dart via flutter_rust_bridge.

**Functions:**
```rust
#[frb(sync)]
pub fn scan_devices() -> Result<Vec<DiscoveredDevice>>;

pub fn connect_device(device_id: String) -> Result<()>;
pub fn start_mock_mode(config: MockConfig) -> Result<()>;
pub fn create_hr_stream() -> impl Stream<FilteredHeartRate>;
```

**Bridge Pattern:**
- `#[frb]` macros generate Dart bindings automatically
- Async Rust functions → Dart Futures
- Rust Streams → Dart Streams
- Serialization handled by FRB codegen

## Dependency Graph

```mermaid
graph TD
    subgraph "External Platforms"
        Flutter[Flutter App]
        CLI[CLI Tool]
    end

    subgraph "API Layer"
        API[api.rs<br/>FRB Bridge]
    end

    subgraph "Orchestration"
        Scheduler[scheduler/<br/>SessionExecutor]
        StateConn[state/connectivity.rs]
        StateSess[state/session.rs]
    end

    subgraph "Domain"
        HR[domain/heart_rate.rs]
        Filter[domain/filters.rs]
        HRV[domain/hrv.rs]
        Plan[domain/training_plan.rs]
    end

    subgraph "Ports"
        PortBLE[ports/ble_adapter.rs]
        PortNotif[ports/notification.rs]
    end

    subgraph "Adapters"
        BtleplugAdp[adapters/btleplug_adapter.rs]
        MockAdp[adapters/mock_adapter.rs]
        CliNotif[adapters/cli_notification_adapter.rs]
    end

    Flutter --> API
    CLI --> Scheduler
    CLI --> StateConn

    API --> Scheduler
    API --> StateConn
    API --> StateSess

    Scheduler --> StateConn
    Scheduler --> StateSess
    Scheduler --> PortBLE
    Scheduler --> PortNotif
    Scheduler --> Plan
    Scheduler --> Filter

    StateSess --> Plan
    StateConn --> PortBLE

    Filter --> HR
    Scheduler --> HR
    Scheduler --> HRV

    BtleplugAdp -.implements.-> PortBLE
    MockAdp -.implements.-> PortBLE
    CliNotif -.implements.-> PortNotif
```

**Dependency Rules:**
1. Domain depends on nothing (pure logic)
2. Ports depend only on domain types
3. Adapters depend on ports (implement traits)
4. State machines depend on domain and ports
5. Scheduler orchestrates everything
6. API exposes scheduler and state to Flutter

## Data Flow

### BLE Packet → Filtered HR → UI

```mermaid
sequenceDiagram
    participant HRM as HR Monitor<br/>(Polar H10)
    participant BLE as BtleplugAdapter
    participant Filter as KalmanFilter
    participant Sched as SessionExecutor
    participant State as SessionStateMachine
    participant Notif as NotificationPort
    participant UI as Flutter UI

    HRM->>BLE: BLE packet (0x00 0x58)
    BLE->>BLE: Parse measurement
    BLE->>Filter: HeartRateMeasurement(88)
    Filter->>Filter: Apply Kalman filter
    Filter->>Sched: FilteredHeartRate(87.8)
    Sched->>State: Update current HR
    State->>State: Check zone deviation
    alt HR outside target zone
        State->>Notif: notify_zone_deviation(Z4, Z2)
        Notif->>UI: Vibration + "Slow down!"
    end
    Sched->>UI: Stream FilteredHeartRate
    UI->>UI: Update HR graph
```

### Training Session Execution

```mermaid
sequenceDiagram
    participant User
    participant Sched as SessionExecutor
    participant State as SessionStateMachine
    participant BLE as BleAdapter
    participant Notif as NotificationPort

    User->>Sched: start_session(plan)
    Sched->>State: Initialize(phases)
    Sched->>BLE: connect()
    BLE-->>Sched: Connected

    loop For each phase
        State->>State: Transition to Running
        Notif->>User: "Starting Warmup - Zone 2"

        loop While phase active
            BLE->>Sched: HR data stream
            Sched->>State: process_hr(filtered)
            State->>State: Check zone compliance
            opt Zone deviation
                State->>Notif: Zone alert
            end
        end

        State->>State: Phase timer expired
        State->>State: Transition to next phase
    end

    State->>State: All phases complete
    Sched->>Notif: "Session complete!"
    Sched->>Sched: Save summary
```

## State Machines

### Connection State Machine

**Implementation:** `rust/src/state/connectivity.rs`

**Purpose:** Manage BLE device lifecycle with automatic reconnection and error recovery.

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Scanning: StartScan
    note right of Scanning: Discovery phase<br/>filtering for HR<br/>service UUID

    Scanning --> Connecting: DeviceFound(id)
    Scanning --> Idle: Timeout(30s)

    Connecting --> Connected: GattReady
    Connecting --> Disconnected: ConnectError
    note right of Connecting: GATT handshake<br/>service discovery

    Connected --> Streaming: StartStream
    note right of Streaming: Subscribed to<br/>HR characteristic<br/>0x180D

    Streaming --> Disconnected: Disconnect
    Streaming --> Disconnected: ConnectionLost

    Disconnected --> Scanning: AutoRetry
    Disconnected --> Idle: MaxRetriesReached

    note left of Disconnected
        Retry Logic:
        - Attempt 1: 5s delay
        - Attempt 2: 10s delay
        - Attempt 3: 20s delay
        - Then: User action required
    end note
```

**States:**
```rust
pub enum ConnectionState {
    Idle,
    Scanning { devices: Vec<DiscoveredDevice> },
    Connecting { device_id: String },
    Connected { device_id: String },
    Streaming { device_id: String },
    Disconnected { retry_count: u8 },
}
```

**Events:**
```rust
pub enum ConnectionEvent {
    StartScan,
    DeviceFound(DiscoveredDevice),
    Connect(String),
    Connected,
    StartStream,
    Disconnect,
    ConnectionLost,
    Error(String),
}
```

**Key Design Points:**
- **Auto-reconnect:** On `ConnectionLost`, automatically retry up to 3 times with exponential backoff
- **Graceful degradation:** After max retries, transition to `Idle` requiring user intervention
- **Resource cleanup:** Each state transition properly cleans up BLE resources (unsubscribe, close)

### Session State Machine

**Implementation:** `rust/src/state/session.rs`

**Purpose:** Control training session execution with pause/resume and phase progression.

```mermaid
stateDiagram-v2
    [*] --> Ready

    Ready --> Running: Start(plan)
    note right of Ready: Plan loaded<br/>awaiting start

    Running --> Paused: Pause
    Paused --> Running: Resume
    Paused --> Completed: Stop

    Running --> Completed: AllPhasesComplete

    Completed --> [*]
    note right of Completed: Summary saved<br/>resources released

    state Running {
        [*] --> WarmUp

        WarmUp --> Work: IntervalComplete(10min)
        note right of WarmUp: Target: Zone 2<br/>Gradual HR increase

        Work --> Recovery: IntervalComplete
        note right of Work: Target: Plan zone<br/>Z3-Z5 intensity

        Recovery --> Work: MoreIntervals
        Recovery --> CoolDown: LastInterval
        note right of Recovery: Target: Zone 1-2<br/>Active recovery

        CoolDown --> [*]: IntervalComplete(10min)
        note right of CoolDown: Target: Zone 1<br/>Gradual HR decrease
    }
```

**Context Data:**
```rust
pub struct SessionContext {
    plan: TrainingPlan,
    current_phase: usize,
    phase_start: Instant,
    total_elapsed: Duration,
    paused_at: Option<Instant>,
    hr_history: Vec<FilteredHeartRate>,
}
```

**Events:**
```rust
pub enum SessionEvent {
    Start(TrainingPlan),
    Pause,
    Resume,
    Stop,
    PhaseComplete,
    HeartRateUpdate(FilteredHeartRate),
}
```

**Phase Progression Logic:**
```rust
impl SessionStateMachine {
    fn on_phase_complete(&mut self) -> SessionState {
        self.context.current_phase += 1;

        if self.context.current_phase >= self.context.plan.phases.len() {
            // All phases done
            SessionState::Completed
        } else {
            // Move to next phase
            self.context.phase_start = Instant::now();
            SessionState::Running
        }
    }
}
```

**Key Design Points:**
- **Hierarchical states:** `Running` contains sub-states (WarmUp/Work/Recovery/CoolDown) managed by statig
- **Pause preservation:** Pausing saves `Instant`, resuming adjusts timers to exclude pause duration
- **Zone compliance:** Each sub-state has target zone; `HeartRateUpdate` events trigger zone deviation checks
- **History tracking:** `hr_history` enables post-session HRV analysis and zone time-in-range statistics

## Key Design Decisions

### Why Hexagonal Architecture?

**Problem:** Tightly coupled BLE code makes testing impossible without physical devices.

**Solution:** Define `BleAdapter` trait, inject implementations.

**Benefit:**
- Unit tests use `MockAdapter` (instant, deterministic)
- Integration tests use `BtleplugAdapter` (real devices)
- CLI defaults to mock mode for rapid development

### Why `statig` for State Machines?

**Alternatives considered:**
- Hand-written enums (error-prone, no compile-time transition checks)
- `rust-fsm` (runtime state machine, less type-safe)

**Why `statig`:**
- Compile-time state transition validation
- Zero-cost abstractions (no runtime overhead)
- Clear, explicit state modeling
- Type-safe event handling

**Trade-off:** More verbose code, but eliminates entire classes of bugs.

### Why flutter_rust_bridge v2?

**Alternatives:**
- Dart FFI directly (manual serialization, error-prone)
- Platform channels (Dart ↔ Kotlin/Swift ↔ Rust, 3-layer overhead)

**Why FRB v2:**
- Auto-generates Dart bindings from Rust code
- Supports async (Futures), streams, complex types
- Type-safe serialization
- Hot-reload compatible

**Performance:** ~10-50μs overhead per call (negligible for HR monitoring)

### Why CLI-First Development?

**Traditional:** Flutter app → build APK → deploy → test (5+ min cycle)

**CLI-First:** Rust changes → `cargo run` → test (<10s cycle)

**Benefits:**
- 30x faster iteration
- No emulator/device needed
- Easy debugging with println/logs
- Rich terminal UI with colors, tables, progress bars

**CLI Features:**
- `devices scan` - List BLE devices
- `session start` - Execute training plan
- `mock steady --bpm 140` - Simulate HR patterns
- `plan create` - Interactive plan builder

### Why Kalman Filtering?

**Problem:** BLE HR sensors have ±3-5 BPM jitter, causing false zone alerts.

**Solution:** Kalman filter smooths data while preserving responsiveness.

**Tuning:**
- Process noise (`q`): 0.1 (low, assumes HR changes slowly)
- Measurement noise (`r`): 2.0 (moderate, BLE data has some noise)

**Result:** Smooth output, ~1s lag, eliminates spurious alerts.

## Adding New Features

### Example: Add Cadence Monitoring

**1. Domain (Pure Logic)**
```rust
// domain/cadence.rs
pub struct CadenceData {
    pub steps_per_minute: u16,
    pub timestamp: SystemTime,
}

pub fn parse_cadence(ble_data: &[u8]) -> Result<CadenceData> {
    // Parse BLE Running Speed and Cadence service
}
```

**2. Port (Interface)**
```rust
// ports/cadence_adapter.rs
#[async_trait]
pub trait CadenceAdapter {
    async fn stream_cadence(&self) -> Result<Receiver<CadenceData>>;
}
```

**3. Adapter (Implementation)**
```rust
// adapters/btleplug_cadence_adapter.rs
pub struct BtleplugCadenceAdapter { /* ... */ }

impl CadenceAdapter for BtleplugCadenceAdapter {
    async fn stream_cadence(&self) -> Result<Receiver<CadenceData>> {
        // Subscribe to 0x1816 Running Speed and Cadence service
    }
}
```

**4. State/Scheduler (Orchestration)**
```rust
// scheduler/executor.rs
pub struct SessionExecutor {
    cadence_adapter: Option<Arc<dyn CadenceAdapter>>, // Add field
}

impl SessionExecutor {
    pub async fn start_session(&mut self) {
        // Stream cadence alongside HR
        if let Some(cadence) = &self.cadence_adapter {
            let cadence_rx = cadence.stream_cadence().await?;
            // Process cadence data
        }
    }
}
```

**5. API (Expose to Flutter)**
```rust
// api.rs
#[frb]
pub fn create_cadence_stream() -> impl Stream<CadenceData> {
    // Expose cadence stream to Dart
}
```

**6. Tests**
```rust
// tests/cadence_integration.rs
#[tokio::test]
async fn test_cadence_stream() {
    let adapter = MockCadenceAdapter::new();
    // Test cadence parsing and streaming
}
```

### Where to Add Code

| Feature Type | Module | Example |
|--------------|--------|---------|
| New domain logic | `domain/` | HRV metrics, power zones |
| External dependency | `ports/` + `adapters/` | GPS, cadence, power meter |
| State management | `state/` | Race mode, interval timer |
| Orchestration | `scheduler/` | Multi-sensor fusion |
| Flutter API | `api.rs` | New data streams, commands |
| CLI command | `bin/cli.rs` | `cadence monitor` |

### Testing Strategy

1. **Unit tests** - Pure domain logic (no mocks needed)
2. **Integration tests** - With `MockAdapter` (fast, deterministic)
3. **CLI tests** - Manual testing via rich terminal UI
4. **E2E tests** - Real BLE devices (slow, run in CI only)

---

**Next:** See [development.md](development.md) for setup and contribution workflow.
