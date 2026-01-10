# Design Document

## Architecture Overview

Pure domain module defining training plan data structures and zone calculation logic. No I/O dependencies, 100% testable with unit tests.

```
training_plan.rs (Pure Domain)
     ↓ Used by
session_state.rs (Executes plan)
     ↓ Used by
scheduler/executor.rs (Runtime)
```

## Data Models

### TrainingPlan
```rust
pub struct TrainingPlan {
    pub name: String,
    pub phases: Vec<TrainingPhase>,
    pub created_at: chrono::DateTime<Utc>,
    pub max_hr: u16,
}
```

### TrainingPhase
```rust
pub struct TrainingPhase {
    pub name: String,
    pub target_zone: Zone,
    pub duration_secs: u32,
    pub transition: TransitionCondition,
}
```

### TransitionCondition
```rust
pub enum TransitionCondition {
    TimeElapsed,
    HeartRateReached { target_bpm: u16, hold_secs: u32 },
}
```

## Zone Calculation Algorithm

### Zone Percentages (Karvonen Method)
- Zone 1: 50-60% max HR (Recovery)
- Zone 2: 60-70% max HR (Endurance)
- Zone 3: 70-80% max HR (Tempo)
- Zone 4: 80-90% max HR (Threshold)
- Zone 5: 90-100% max HR (VO2 Max)

### Implementation
```rust
pub fn calculate_zone(bpm: u16, max_hr: u16) -> Result<Option<Zone>> {
    if max_hr < 100 || max_hr > 220 {
        return Err(anyhow!("Invalid max_hr"));
    }

    let pct = (bpm as f32 / max_hr as f32) * 100.0;

    match pct {
        p if p < 50.0 => Ok(None),
        p if p < 60.0 => Ok(Some(Zone::Zone1)),
        p if p < 70.0 => Ok(Some(Zone::Zone2)),
        p if p < 80.0 => Ok(Some(Zone::Zone3)),
        p if p < 90.0 => Ok(Some(Zone::Zone4)),
        _ => Ok(Some(Zone::Zone5)),
    }
}
```

## Plan Validation

### Validation Rules
1. At least 1 phase
2. All phase durations > 0
3. Total duration < 4 hours (14400s)
4. Target zones valid (Zone1-Zone5)
5. HeartRateReached targets physiologically possible (30-220 BPM)

```rust
impl TrainingPlan {
    pub fn validate(&self) -> Result<()> {
        if self.phases.is_empty() {
            bail!("Plan must have at least 1 phase");
        }

        let total_secs: u32 = self.phases.iter().map(|p| p.duration_secs).sum();
        if total_secs > 14400 {
            bail!("Plan exceeds 4 hours");
        }

        for phase in &self.phases {
            if phase.duration_secs == 0 {
                bail!("Phase duration must be > 0");
            }
        }

        Ok(())
    }
}
```

## Example Plans

### 5K Tempo Run
- 10min Zone2 (warmup)
- 20min Zone3 (tempo)
- 10min Zone1 (cooldown)

### VO2 Max Intervals
- 5min Zone2 (warmup)
- 5x [3min Zone5, 2min Zone2]
- 5min Zone1 (cooldown)

### Base Endurance
- 45min Zone2 (steady state)

## Serialization Format

JSON with ISO8601 timestamps:
```json
{
  "name": "5K Tempo Run",
  "max_hr": 180,
  "created_at": "2026-01-11T12:00:00Z",
  "phases": [
    {
      "name": "Warmup",
      "target_zone": "Zone2",
      "duration_secs": 600,
      "transition": "TimeElapsed"
    },
    {
      "name": "Tempo",
      "target_zone": "Zone3",
      "duration_secs": 1200,
      "transition": "TimeElapsed"
    }
  ]
}
```

## Testing Strategy

### Property-Based Tests
- Random plan generation with proptest
- Verify validation catches all invalid plans
- Verify zone calculation is monotonic

### Unit Tests
- Zone calculation edge cases (49%, 50%, 100%)
- Validation rules
- Example plan fixtures
