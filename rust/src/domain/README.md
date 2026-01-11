# Domain Module

## Purpose

Pure business logic and domain types with zero dependencies on infrastructure. All types here are platform-agnostic and fully unit testable without mocks.

## Key Types

### Heart Rate (`heart_rate.rs`)

**HeartRateMeasurement**
```rust
pub struct HeartRateMeasurement {
    pub bpm: u8,
    pub contact_detected: bool,
    pub energy_expended: Option<u16>,
    pub rr_intervals: Vec<u16>,
    pub timestamp: SystemTime,
}
```
Raw BLE heart rate data parsed from standard HR service (0x180D).

**FilteredHeartRate**
```rust
pub struct FilteredHeartRate {
    pub bpm: f64,
    pub raw_bpm: u8,
    pub zone: Zone,
    pub timestamp: SystemTime,
}
```
Kalman-filtered HR with zone classification.

**Zone**
```rust
pub enum Zone {
    Z1, // 50-60% max HR - Recovery
    Z2, // 60-70% - Base building
    Z3, // 70-80% - Aerobic endurance
    Z4, // 80-90% - Lactate threshold
    Z5, // 90-100% - VO2 max
}
```

**Functions:**
- `parse_heart_rate(data: &[u8]) -> Result<HeartRateMeasurement>` - Parse BLE packet
- `is_valid_bpm(bpm: u8) -> bool` - Validate HR (30-220 range)
- `calculate_zone(bpm: u8, max_hr: u8) -> Zone` - Classify HR into zone

### Filters (`filters.rs`)

**KalmanFilter**
```rust
pub struct KalmanFilter {
    process_noise: f64,  // q
    measurement_noise: f64,  // r
    estimate: f64,
    error_covariance: f64,
}
```

Smooths noisy HR measurements while preserving responsiveness.

**Usage:**
```rust
let mut filter = KalmanFilter::new(0.1, 2.0);
let filtered = filter.update(raw_bpm as f64);
```

**Tuning:**
- Low `q` (0.1) - Assumes HR changes slowly
- Moderate `r` (2.0) - BLE data has some noise
- Result: ~1s lag, eliminates spurious zone alerts

### HRV (`hrv.rs`)

**HRVMetrics**
```rust
pub struct HRVMetrics {
    pub rmssd: f64,  // Root mean square of successive differences
    pub sdnn: f64,   // Standard deviation of NN intervals
    pub pnn50: f64,  // % of intervals differing by >50ms
    pub timestamp: SystemTime,
}
```

Heart rate variability analysis for recovery and training load assessment.

**Functions:**
- `calculate_hrv(rr_intervals: &[u16]) -> Result<HRVMetrics>`
- `requires ≥5 minutes` of RR interval data for accurate metrics

### Training Plan (`training_plan.rs`)

**TrainingPlan**
```rust
pub struct TrainingPlan {
    pub name: String,
    pub phases: Vec<Phase>,
    pub max_hr: u8,
}
```

**Phase**
```rust
pub struct Phase {
    pub name: String,
    pub duration_min: u32,
    pub target_zone: Zone,
    pub description: Option<String>,
}
```

**Example:**
```rust
let plan = TrainingPlan {
    name: "5K Intervals".to_string(),
    max_hr: 185,
    phases: vec![
        Phase::new("Warmup", 10, Zone::Z2),
        Phase::new("Intervals", 5, Zone::Z4),
        Phase::new("Recovery", 3, Zone::Z2),
        Phase::new("Cooldown", 7, Zone::Z1),
    ],
};
```

**JSON Format:**
```json
{
  "name": "5K Intervals",
  "max_hr": 185,
  "phases": [
    {"name": "Warmup", "duration_min": 10, "zone": 2},
    {"name": "Intervals", "duration_min": 5, "zone": 4}
  ]
}
```

## Main Functions

### Heart Rate Processing
- `parse_heart_rate(data: &[u8])` - BLE packet → `HeartRateMeasurement`
- `is_valid_bpm(bpm: u8)` - Validate HR range
- `calculate_zone(bpm: u8, max_hr: u8)` - HR → Zone

### Filtering
- `KalmanFilter::new(q, r)` - Create filter with noise parameters
- `filter.update(measurement)` - Apply filter to raw HR

### HRV Analysis
- `calculate_hrv(rr_intervals)` - Compute HRV metrics from RR data

### Training Plans
- `TrainingPlan::from_json(json_str)` - Parse plan from JSON
- `plan.validate()` - Check plan validity (duration, zones)
- `phase.get_hr_range(max_hr)` - Zone → (lower_bpm, upper_bpm)

## Usage Examples

### Parse BLE Heart Rate
```rust
use heart_beat::domain::{parse_heart_rate, is_valid_bpm};

let ble_data = vec![0x00, 0x58]; // HR = 88 BPM
let measurement = parse_heart_rate(&ble_data)?;

if is_valid_bpm(measurement.bpm) {
    println!("HR: {} BPM", measurement.bpm);
}
```

### Filter HR Stream
```rust
use heart_beat::domain::KalmanFilter;

let mut filter = KalmanFilter::new(0.1, 2.0);

for raw_bpm in hr_stream {
    let filtered = filter.update(raw_bpm as f64);
    println!("Raw: {}, Filtered: {:.1}", raw_bpm, filtered);
}
```

### Load Training Plan
```rust
use heart_beat::domain::TrainingPlan;

let json = std::fs::read_to_string("plan.json")?;
let plan = TrainingPlan::from_json(&json)?;

for phase in &plan.phases {
    let (low, high) = phase.get_hr_range(plan.max_hr);
    println!("{}: {}-{} BPM", phase.name, low, high);
}
```

## Testing Approach

**100% unit testable** - All functions are pure or deterministic:

```rust
#[test]
fn test_parse_hr_basic() {
    let data = vec![0x00, 0x58];
    let hr = parse_heart_rate(&data).unwrap();
    assert_eq!(hr.bpm, 88);
}

#[test]
fn test_kalman_filter_smooths_noise() {
    let mut filter = KalmanFilter::new(0.1, 2.0);
    let noisy = vec![120, 123, 119, 125, 121];
    let filtered: Vec<f64> = noisy.iter()
        .map(|&x| filter.update(x as f64))
        .collect();
    // Verify filtered values are smoother
}
```

**Property-based tests** with `proptest`:
```rust
proptest! {
    #[test]
    fn test_valid_bpm_range(bpm in 30u8..220u8) {
        assert!(is_valid_bpm(bpm));
    }
}
```

## Design Constraints

1. **No `async`** - All functions are synchronous
2. **No I/O** - No file, network, or device access
3. **No platform deps** - Pure Rust, works everywhere
4. **Serde serialization** - All types derive `Serialize`/`Deserialize`
5. **Clear ownership** - No `Arc`, `Mutex`, or shared state

## Adding Domain Logic

When adding new domain types or algorithms:

1. Keep functions **pure** (deterministic, no side effects)
2. Use **value types** (structs, enums) not references
3. Write **unit tests** for all branches
4. Document with **rustdoc comments** and examples
5. Consider **property-based tests** for complex logic

**Good domain code:**
```rust
pub fn calculate_pace(distance_km: f64, time_min: f64) -> f64 {
    time_min / distance_km
}
```

**Bad domain code:**
```rust
pub async fn calculate_pace(db: &Database) -> Result<f64> {
    let distance = db.get_distance().await?;  // I/O in domain!
    // ...
}
```

---

See [../ports/README.md](../ports/README.md) for how domain types flow through the system.
