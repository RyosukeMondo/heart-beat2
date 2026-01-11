# Scheduler Module

## Purpose

**Orchestrate training sessions** by coordinating BLE adapters, state machines, filters, and notifications. The scheduler is the "conductor" that brings all components together.

## Key Types

### SessionExecutor (`executor.rs`)

Central orchestrator for training session execution.

```rust
pub struct SessionExecutor {
    plan: TrainingPlan,
    ble_adapter: Arc<dyn BleAdapter>,
    notifier: Arc<dyn NotificationPort>,
    filter: KalmanFilter,
    state_machine: SessionStateMachine,
}
```

**Responsibilities:**
- Execute training plan phases sequentially
- Stream and filter HR data
- Detect zone deviations, trigger notifications
- Manage session state transitions
- Persist session summaries

## Main Functions

### Creation

```rust
impl SessionExecutor {
    pub fn new(
        plan: TrainingPlan,
        ble_adapter: Arc<dyn BleAdapter>,
        notifier: Arc<dyn NotificationPort>,
    ) -> Self {
        let filter = KalmanFilter::new(0.1, 2.0);
        let state_machine = SessionStateMachine::new(plan.clone());

        Self {
            plan,
            ble_adapter,
            notifier,
            filter,
            state_machine,
        }
    }
}
```

### Session Execution

```rust
pub async fn start_session(&mut self) -> Result<SessionSummary>
```
Executes the entire training plan:
1. Connect to BLE device
2. Initialize state machine
3. For each phase:
   - Notify phase start
   - Stream HR data
   - Filter and check zone compliance
   - Detect phase completion
   - Transition to next phase
4. Generate session summary
5. Disconnect and cleanup

**Usage:**
```rust
let executor = SessionExecutor::new(plan, ble_adapter, notifier);
let summary = executor.start_session().await?;

println!("Session complete!");
println!("Avg HR: {:.1} BPM", summary.avg_hr);
println!("Time in zone: {}%", summary.time_in_zone_pct);
```

### Phase Management

```rust
pub async fn execute_phase(&mut self, phase: &Phase) -> Result<PhaseResult>
```
Executes a single training phase:
- Announce phase start
- Stream HR for phase duration
- Collect HR samples
- Calculate phase statistics
- Return phase summary

### HR Processing

```rust
pub fn process_heart_rate(&mut self, raw: HeartRateMeasurement) -> FilteredHeartRate
```
Processes raw BLE measurement:
1. Validate BPM range
2. Apply Kalman filter
3. Calculate zone
4. Create `FilteredHeartRate`

### Zone Monitoring

```rust
pub async fn check_zone_compliance(&self, hr: &FilteredHeartRate, target: Zone)
```
Monitors zone compliance:
- Compare current zone with target
- Trigger notification on deviation
- Track time in/out of zone

## Usage Examples

### Basic Session Execution

```rust
use heart_beat::scheduler::SessionExecutor;
use heart_beat::domain::TrainingPlan;
use heart_beat::adapters::{BtleplugAdapter, CliNotificationAdapter};
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<()> {
    // Load training plan
    let json = std::fs::read_to_string("workout.json")?;
    let plan = TrainingPlan::from_json(&json)?;

    // Create dependencies
    let ble = Arc::new(BtleplugAdapter::new());
    let notifier = Arc::new(CliNotificationAdapter::new());

    // Create executor
    let mut executor = SessionExecutor::new(plan, ble, notifier);

    // Run session
    let summary = executor.start_session().await?;

    println!("Session Summary:");
    println!("  Duration: {} min", summary.duration_min);
    println!("  Avg HR: {:.1} BPM", summary.avg_hr);
    println!("  Max HR: {} BPM", summary.max_hr);
    println!("  Calories: {}", summary.calories);
    println!("  Time in zone: {}%", summary.time_in_zone_pct);

    Ok(())
}
```

### Mock Session for Testing

```rust
use heart_beat::scheduler::SessionExecutor;
use heart_beat::adapters::{MockAdapter, MockNotificationAdapter};

#[tokio::test]
async fn test_session_execution() {
    let plan = create_test_plan(); // Helper to create simple plan

    // Mock dependencies
    let mut mock_ble = MockAdapter::new();
    mock_ble.set_mock_hr(140); // Simulate steady 140 BPM

    let ble = Arc::new(mock_ble);
    let notifier = Arc::new(MockNotificationAdapter::new());

    let mut executor = SessionExecutor::new(plan, ble, notifier.clone());

    let summary = executor.start_session().await.unwrap();

    // Verify execution
    assert!(summary.avg_hr > 130.0 && summary.avg_hr < 150.0);
    assert_eq!(notifier.get_notification_count(), 3); // 3 phase changes
}
```

### Custom HR Processing

```rust
use heart_beat::scheduler::SessionExecutor;
use heart_beat::domain::{HeartRateMeasurement, FilteredHeartRate};

let mut executor = create_executor();

let raw = HeartRateMeasurement {
    bpm: 142,
    contact_detected: true,
    energy_expended: None,
    rr_intervals: vec![],
    timestamp: SystemTime::now(),
};

let filtered = executor.process_heart_rate(raw);

println!("Raw: {} BPM", raw.bpm);
println!("Filtered: {:.1} BPM", filtered.bpm);
println!("Zone: {:?}", filtered.zone);
```

### Phase-by-Phase Execution

```rust
use heart_beat::scheduler::SessionExecutor;

let plan = TrainingPlan::from_json(&json)?;
let mut executor = SessionExecutor::new(plan.clone(), ble, notifier);

for (i, phase) in plan.phases.iter().enumerate() {
    println!("Starting phase {}: {}", i + 1, phase.name);

    let result = executor.execute_phase(phase).await?;

    println!("Phase complete:");
    println!("  Avg HR: {:.1} BPM", result.avg_hr);
    println!("  Time in zone: {}%", result.time_in_zone_pct);
}
```

## Data Flow

### Session Execution Flow

```
User
  │
  └─> SessionExecutor::start_session()
         │
         ├─> BleAdapter::connect()
         │
         ├─> SessionStateMachine::handle(Start)
         │
         └─> For each Phase:
               │
               ├─> NotificationPort::notify_phase_change()
               │
               ├─> BleAdapter::stream_heart_rate()
               │     │
               │     ├─> HeartRateMeasurement (raw BLE)
               │     │
               │     ├─> KalmanFilter::update()
               │     │
               │     ├─> FilteredHeartRate
               │     │
               │     ├─> check_zone_compliance()
               │     │     │
               │     │     └─> NotificationPort::notify_zone_deviation()
               │     │
               │     └─> SessionStateMachine::handle(HeartRateUpdate)
               │
               ├─> Phase timer expires
               │
               └─> SessionStateMachine::handle(PhaseComplete)
         │
         ├─> All phases complete
         │
         ├─> SessionStateMachine::handle(Stop)
         │
         ├─> Generate SessionSummary
         │
         └─> BleAdapter::disconnect()
```

## Session Summary

After session completion, a summary is generated:

```rust
pub struct SessionSummary {
    pub plan_name: String,
    pub duration_min: u32,
    pub avg_hr: f64,
    pub max_hr: u8,
    pub min_hr: u8,
    pub calories: u32,
    pub time_in_zone_pct: f64,
    pub phases: Vec<PhaseResult>,
    pub timestamp: SystemTime,
}

pub struct PhaseResult {
    pub name: String,
    pub avg_hr: f64,
    pub time_in_zone_pct: f64,
    pub duration_min: u32,
}
```

**Usage:**
```rust
let summary = executor.start_session().await?;

// Save to JSON
let json = serde_json::to_string_pretty(&summary)?;
std::fs::write("session_summary.json", json)?;

// Display to user
println!("Workout: {}", summary.plan_name);
println!("Total time: {} min", summary.duration_min);
println!("Average HR: {:.1} BPM", summary.avg_hr);
println!("Peak HR: {} BPM", summary.max_hr);
println!("Calories burned: {}", summary.calories);

for (i, phase) in summary.phases.iter().enumerate() {
    println!("\nPhase {}: {}", i + 1, phase.name);
    println!("  Avg HR: {:.1} BPM", phase.avg_hr);
    println!("  Zone compliance: {}%", phase.time_in_zone_pct);
}
```

## Error Handling

The scheduler handles various error scenarios:

### Connection Errors

```rust
match executor.start_session().await {
    Ok(summary) => println!("Success: {}", summary.plan_name),
    Err(e) if e.to_string().contains("connection") => {
        println!("Connection failed - check BLE device is on");
    }
    Err(e) => println!("Error: {}", e),
}
```

### Phase Failures

```rust
pub enum SessionError {
    ConnectionLost,
    InvalidHeartRate,
    PhaseTimeout,
    UserStopped,
}
```

**Recovery strategies:**
- Connection lost → Retry with exponential backoff
- Invalid HR → Skip sample, continue
- Phase timeout → Prompt user to continue or stop
- User stopped → Save partial summary

## Testing Approach

### Unit Tests - Core Logic

```rust
#[test]
fn test_hr_filtering() {
    let mut executor = create_executor();

    let raw1 = create_measurement(140);
    let raw2 = create_measurement(145);
    let raw3 = create_measurement(138);

    let f1 = executor.process_heart_rate(raw1);
    let f2 = executor.process_heart_rate(raw2);
    let f3 = executor.process_heart_rate(raw3);

    // Verify filtering smooths values
    assert!(f2.bpm > f1.bpm && f2.bpm < 145.0);
}

#[test]
fn test_zone_calculation() {
    let executor = create_executor();
    let hr = create_filtered_hr(140, 180); // 140/180 = 77% = Zone 3

    assert_eq!(hr.zone, Zone::Z3);
}
```

### Integration Tests - Full Session

```rust
#[tokio::test]
async fn test_full_session() {
    let plan = TrainingPlan {
        name: "Test".into(),
        max_hr: 180,
        phases: vec![
            Phase::new("Warmup", 2, Zone::Z2),
            Phase::new("Work", 3, Zone::Z4),
        ],
    };

    let mock_ble = Arc::new(MockAdapter::new());
    mock_ble.set_mock_hr(140);

    let notifier = Arc::new(MockNotificationAdapter::new());

    let mut executor = SessionExecutor::new(plan, mock_ble, notifier.clone());

    let summary = executor.start_session().await.unwrap();

    assert_eq!(summary.phases.len(), 2);
    assert_eq!(summary.duration_min, 5);
    assert!(notifier.get_call_count() >= 2); // Phase changes
}
```

### Property-Based Tests

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_hr_always_filtered(raw_bpm in 60u8..180u8) {
        let mut executor = create_executor();
        let raw = create_measurement(raw_bpm);
        let filtered = executor.process_heart_rate(raw);

        // Filtered value should be in valid range
        assert!(filtered.bpm >= 30.0 && filtered.bpm <= 220.0);
    }
}
```

## Performance Considerations

### Latency Targets

- BLE packet → filtered HR: **< 50ms**
- Zone check + notification: **< 100ms**
- Phase transition: **< 10ms**

### Optimization Strategies

1. **Preallocate buffers** - Avoid allocations in hot loop
2. **Batch notifications** - Don't spam user with alerts
3. **Async streams** - Non-blocking HR processing
4. **Efficient filters** - Kalman is O(1) per sample

### Example: Optimized HR Processing

```rust
pub async fn process_hr_stream(&mut self) -> Result<()> {
    let mut rx = self.ble_adapter.stream_heart_rate().await?;
    let mut last_notification = SystemTime::now();

    // Preallocate buffer
    let mut hr_buffer = Vec::with_capacity(1000);

    while let Some(raw) = rx.recv().await {
        let filtered = self.filter.update(raw.bpm as f64);
        let hr = FilteredHeartRate { /* ... */ };

        hr_buffer.push(hr.clone());

        // Throttle notifications (max 1 per 5 seconds)
        let now = SystemTime::now();
        if now.duration_since(last_notification)? > Duration::from_secs(5) {
            self.check_zone_compliance(&hr, target_zone).await;
            last_notification = now;
        }
    }

    Ok(())
}
```

## Design Guidelines

### ✅ Good Orchestration

```rust
pub async fn start_session(&mut self) -> Result<Summary> {
    // Clear separation of concerns
    self.connect().await?;
    self.initialize_state();

    for phase in &self.plan.phases {
        self.execute_phase(phase).await?;
    }

    self.generate_summary()
}
```

### ❌ Bad Orchestration

```rust
pub async fn start_session(&mut self) -> Result<()> {
    // God method doing everything
    // 500 lines of connection + filtering + state + notifications
    // Impossible to test or reason about
}
```

## Adding Features

### Example: Add GPS Tracking

1. **Add dependency:**
```rust
pub struct SessionExecutor {
    gps_adapter: Option<Arc<dyn GpsAdapter>>,  // Add field
}
```

2. **Stream GPS data:**
```rust
pub async fn start_session(&mut self) -> Result<Summary> {
    // ... existing code ...

    if let Some(gps) = &self.gps_adapter {
        let gps_rx = gps.stream_location().await?;

        // Process GPS + HR concurrently
        tokio::select! {
            hr = hr_rx.recv() => { /* ... */ }
            loc = gps_rx.recv() => { /* ... */ }
        }
    }
}
```

3. **Include in summary:**
```rust
pub struct SessionSummary {
    pub total_distance_km: Option<f64>,  // Add field
}
```

---

See [../../docs/architecture.md](../../docs/architecture.md) for how scheduler fits into overall system.
