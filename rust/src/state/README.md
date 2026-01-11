# State Module

## Purpose

Type-safe **state machines** for managing connection lifecycle and training session execution. Uses `statig` for compile-time state transition validation.

## State Machines

### ConnectionStateMachine (`connectivity.rs`)

Manages BLE device connection lifecycle.

**States:**
```rust
pub enum ConnectionState {
    Idle,
    Scanning { devices: Vec<DiscoveredDevice> },
    Connecting { device_id: String },
    Connected { device_id: String },
    Streaming { device_id: String },
    Disconnected,
}
```

**Events:**
```rust
pub enum ConnectionEvent {
    StartScan,
    DeviceFound(DiscoveredDevice),
    ScanComplete,
    Connect(String),
    Connected,
    StartStream,
    StreamStarted,
    Disconnect,
    Error(String),
}
```

**State Diagram:**
```
┌──────┐  StartScan   ┌──────────┐  Connect(id)  ┌────────────┐
│ Idle │─────────────>│ Scanning │──────────────>│ Connecting │
└──────┘              └──────────┘               └────────────┘
                           │                            │
                      DeviceFound                   Connected
                           │                            │
                           ▼                            ▼
                      (accumulate)                ┌───────────┐
                                                  │ Connected │
                                                  └───────────┘
                                                        │
                                                   StartStream
                                                        │
                                                        ▼
                                                  ┌────────────┐
                                                  │ Streaming  │
                                                  └────────────┘
                                                        │
                          ┌─────────────────────────────┘
                          │ Disconnect/Error
                          ▼
                    ┌──────────────┐
                    │ Disconnected │────┐
                    └──────────────┘    │
                          ▲             │ Error
                          └─────────────┘
```

**Usage:**
```rust
use heart_beat::state::{ConnectionStateMachine, ConnectionEvent};

let mut machine = ConnectionStateMachine::default();

// Start scan
machine.handle(&ConnectionEvent::StartScan);
assert!(matches!(machine.state(), ConnectionState::Scanning { .. }));

// Connect to device
machine.handle(&ConnectionEvent::Connect("device-123".into()));
machine.handle(&ConnectionEvent::Connected);
assert!(matches!(machine.state(), ConnectionState::Connected { .. }));

// Start streaming
machine.handle(&ConnectionEvent::StartStream);
machine.handle(&ConnectionEvent::StreamStarted);
assert!(matches!(machine.state(), ConnectionState::Streaming { .. }));
```

### SessionStateMachine (`session.rs`)

Manages training session execution with phase tracking.

**States:**
```rust
pub enum SessionState {
    Ready { plan: TrainingPlan },
    Running {
        plan: TrainingPlan,
        current_phase: usize,
        phase_start: SystemTime,
        hr_samples: Vec<FilteredHeartRate>,
    },
    Paused {
        plan: TrainingPlan,
        current_phase: usize,
        elapsed: Duration,
        hr_samples: Vec<FilteredHeartRate>,
    },
    Completed {
        summary: SessionSummary,
    },
}
```

**Events:**
```rust
pub enum SessionEvent {
    Start,
    Pause,
    Resume,
    Stop,
    PhaseComplete,
    HeartRateUpdate(FilteredHeartRate),
}
```

**State Diagram:**
```
┌───────────────┐  Start   ┌──────────────────┐
│ Ready         │─────────>│ Running          │
│ {plan}        │          │ {phase 0, hr[]}  │
└───────────────┘          └──────────────────┘
      ▲                           │  │  │
      │ Stop                      │  │  │ PhaseComplete
      │                           │  │  └──────────────┐
      │                           │  │                 │
      │                      Pause│  │HeartRateUpdate  │(next phase)
      │                           │  │(accumulate)     │
      │                           ▼  ▼                 ▼
      │                    ┌──────────────┐     ┌────────────┐
      │                    │ Paused       │     │ Running    │
      │                    │ {elapsed}    │     │ {phase N}  │
      └────────────────────└──────────────┘     └────────────┘
                                  │ Resume             │
                                  └────────────────────┘
                                                       │
                                             All phases done
                                                       │
                                                       ▼
                                              ┌────────────────┐
                                              │ Completed      │
                                              │ {summary}      │
                                              └────────────────┘
```

**Usage:**
```rust
use heart_beat::state::{SessionStateMachine, SessionEvent};
use heart_beat::domain::{TrainingPlan, FilteredHeartRate};

let plan = TrainingPlan::from_json(&json_str)?;
let mut machine = SessionStateMachine::new(plan);

// Start session
machine.handle(&SessionEvent::Start);

// Feed HR data
let hr = FilteredHeartRate { bpm: 145.0, zone: Zone::Z3, /* ... */ };
machine.handle(&SessionEvent::HeartRateUpdate(hr));

// Pause
machine.handle(&SessionEvent::Pause);

// Resume
machine.handle(&SessionEvent::Resume);

// Complete phase
machine.handle(&SessionEvent::PhaseComplete);

// Stop early
machine.handle(&SessionEvent::Stop);
```

## Main Functions

### ConnectionStateMachine

**Creation:**
```rust
let machine = ConnectionStateMachine::default();
```

**State Queries:**
```rust
machine.state()  // Get current state
machine.is_connected()  // Check if connected
machine.get_device_id()  // Get connected device ID (if connected)
```

**Event Handling:**
```rust
machine.handle(&event)  // Process event, transition state
```

### SessionStateMachine

**Creation:**
```rust
let machine = SessionStateMachine::new(training_plan);
```

**State Queries:**
```rust
machine.state()  // Get current state
machine.is_running()  // Check if session active
machine.get_current_phase()  // Get phase details
machine.get_elapsed_time()  // Get session duration
machine.get_hr_samples()  // Get accumulated HR data
```

**Event Handling:**
```rust
machine.handle(&event)  // Process event, transition state
```

**Zone Checking:**
```rust
let hr = FilteredHeartRate { bpm: 165.0, zone: Zone::Z4, /* ... */ };
let target_zone = Zone::Z2;

if hr.zone != target_zone {
    // Trigger notification
    notifier.notify_zone_deviation(hr.zone, target_zone).await;
}
```

## Usage Examples

### Full Session Flow

```rust
use heart_beat::state::{SessionStateMachine, SessionEvent};
use heart_beat::domain::{TrainingPlan, FilteredHeartRate, Zone};
use std::time::Duration;
use tokio::time::interval;

#[tokio::main]
async fn main() -> Result<()> {
    // Load training plan
    let plan = TrainingPlan::from_json(r#"
    {
        "name": "Easy Run",
        "max_hr": 180,
        "phases": [
            {"name": "Warmup", "duration_min": 5, "zone": 2},
            {"name": "Steady", "duration_min": 20, "zone": 2},
            {"name": "Cooldown", "duration_min": 5, "zone": 1}
        ]
    }
    "#)?;

    let mut session = SessionStateMachine::new(plan);

    // Start session
    session.handle(&SessionEvent::Start);

    // Simulate HR updates every second
    let mut ticker = interval(Duration::from_secs(1));
    let mut elapsed = 0;

    loop {
        ticker.tick().await;
        elapsed += 1;

        // Simulate HR data
        let hr = FilteredHeartRate {
            bpm: 130.0,
            raw_bpm: 131,
            zone: Zone::Z2,
            timestamp: SystemTime::now(),
        };

        session.handle(&SessionEvent::HeartRateUpdate(hr));

        // Check phase completion (5 min = 300 sec)
        let current_phase = session.get_current_phase().unwrap();
        let phase_duration_sec = current_phase.duration_min * 60;

        if elapsed >= phase_duration_sec {
            session.handle(&SessionEvent::PhaseComplete);
            elapsed = 0;

            // Check if all phases done
            if session.is_completed() {
                let summary = session.get_summary();
                println!("Session complete! Avg HR: {:.1}", summary.avg_hr);
                break;
            }
        }
    }

    Ok(())
}
```

### Connection Management

```rust
use heart_beat::state::{ConnectionStateMachine, ConnectionEvent};
use heart_beat::adapters::BtleplugAdapter;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<()> {
    let mut conn = ConnectionStateMachine::default();
    let adapter = BtleplugAdapter::new();

    // Start scan
    conn.handle(&ConnectionEvent::StartScan);
    let devices = adapter.scan_devices(Duration::from_secs(5)).await?;

    for device in devices {
        conn.handle(&ConnectionEvent::DeviceFound(device.clone()));
    }

    conn.handle(&ConnectionEvent::ScanComplete);

    // Connect to first device
    if let Some(device) = conn.get_devices().first() {
        conn.handle(&ConnectionEvent::Connect(device.id.clone()));

        match adapter.connect(&device.id).await {
            Ok(_) => {
                conn.handle(&ConnectionEvent::Connected);
                println!("Connected to {}", device.name);
            }
            Err(e) => {
                conn.handle(&ConnectionEvent::Error(e.to_string()));
                println!("Connection failed");
            }
        }
    }

    // Start streaming
    if conn.is_connected() {
        conn.handle(&ConnectionEvent::StartStream);
        let rx = adapter.stream_heart_rate().await?;
        conn.handle(&ConnectionEvent::StreamStarted);

        // Process HR stream...
    }

    Ok(())
}
```

## Testing Approach

### Unit Tests - Pure State Logic

```rust
#[test]
fn test_session_start() {
    let plan = create_test_plan();
    let mut machine = SessionStateMachine::new(plan);

    machine.handle(&SessionEvent::Start);

    assert!(machine.is_running());
    assert_eq!(machine.get_current_phase().unwrap().name, "Warmup");
}

#[test]
fn test_pause_resume() {
    let mut machine = create_running_session();

    machine.handle(&SessionEvent::Pause);
    assert!(matches!(machine.state(), SessionState::Paused { .. }));

    machine.handle(&SessionEvent::Resume);
    assert!(machine.is_running());
}

#[test]
fn test_phase_transitions() {
    let plan = TrainingPlan {
        phases: vec![
            Phase::new("Phase1", 1, Zone::Z2),
            Phase::new("Phase2", 1, Zone::Z3),
        ],
        ..Default::default()
    };

    let mut machine = SessionStateMachine::new(plan);
    machine.handle(&SessionEvent::Start);

    assert_eq!(machine.get_current_phase().unwrap().name, "Phase1");

    machine.handle(&SessionEvent::PhaseComplete);

    assert_eq!(machine.get_current_phase().unwrap().name, "Phase2");

    machine.handle(&SessionEvent::PhaseComplete);

    assert!(machine.is_completed());
}
```

### Integration Tests - With Adapters

```rust
#[tokio::test]
async fn test_full_session_with_mock() {
    let plan = create_test_plan();
    let mut session = SessionStateMachine::new(plan);
    let adapter = MockAdapter::new();
    adapter.set_mock_hr(140);

    session.handle(&SessionEvent::Start);

    let mut rx = adapter.stream_heart_rate().await.unwrap();

    for _ in 0..10 {
        let hr_raw = rx.recv().await.unwrap();
        let hr_filtered = filter.update(hr_raw.bpm as f64);
        let hr = FilteredHeartRate { /* ... */ };

        session.handle(&SessionEvent::HeartRateUpdate(hr));
    }

    assert_eq!(session.get_hr_samples().len(), 10);
}
```

## Why statig?

### Alternatives Considered

**Hand-written enums:**
```rust
// Manual state management - error-prone!
match (current_state, event) {
    (State::Idle, Event::Start) => State::Running,
    (State::Running, Event::Pause) => State::Paused,
    // Easy to forget transitions, typos, etc.
}
```

**Why statig:**
- ✅ Compile-time state transition validation
- ✅ Zero-cost abstractions (no runtime overhead)
- ✅ Type-safe event handling
- ✅ Clear, declarative state definitions
- ✅ Prevents invalid transitions at compile time

### Example Error Caught at Compile Time

```rust
// This won't compile - can't pause from Idle!
let mut machine = SessionStateMachine::new(plan);
machine.handle(&SessionEvent::Pause);  // ❌ Compile error!
```

## Design Guidelines

### ✅ Good State Machine Design

```rust
pub enum State {
    Idle,
    Active { data: Vec<u8> },  // State-specific data
    Error { message: String },
}

pub enum Event {
    Start,
    DataReceived(u8),  // Event-specific data
    Fail(String),
}
```
- Clear, distinct states
- State-specific data in variants
- Events carry necessary payload
- Explicit error states

### ❌ Bad State Machine Design

```rust
pub enum State {
    Idle,
    Running,  // What phase? What data?
}

pub enum Event {
    Update,  // Update what?
    Change,  // Change to what?
}
```
- Vague states and events
- Missing necessary data
- Ambiguous transitions

## Adding New State Machines

When adding a new state machine:

1. **Define states** - What lifecycle states exist?
2. **Define events** - What triggers transitions?
3. **Draw state diagram** - Visualize valid transitions
4. **Implement with statig** - Compile-time validation
5. **Write tests** - Cover all transitions

**Example: Workout Timer State Machine**

```rust
pub enum TimerState {
    Idle,
    Running { start: SystemTime },
    Paused { elapsed: Duration },
}

pub enum TimerEvent {
    Start,
    Pause,
    Resume,
    Reset,
}
```

---

See [../scheduler/README.md](../scheduler/README.md) for how state machines orchestrate sessions.
