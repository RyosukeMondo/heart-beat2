# Design Document

## Architecture Overview

Hierarchical state machine using statig for training session execution. Consumes TrainingPlan and real-time HR data, emits zone deviation events.

```
SessionState (statig HSM)
     ↑ Events
SessionExecutor
     ↓ Notifications
NotificationPort
```

## State Machine Design

### State Hierarchy
```
SessionState
├─ Idle
├─ InProgress
│  ├─ phase_index: usize
│  ├─ elapsed_secs: u32
│  └─ zone_tracker: ZoneTracker
├─ Paused
│  ├─ saved_phase: usize
│  └─ saved_elapsed: u32
└─ Completed
   └─ summary: SessionSummary
```

### Events
```rust
pub enum SessionEvent {
    Start(TrainingPlan),
    Tick,  // Every 1 second
    UpdateBpm(u16),
    Pause,
    Resume,
    Stop,
}
```

### State Transitions
```
Idle --Start(plan)--> InProgress
InProgress --Tick--> InProgress (increment elapsed)
InProgress --Tick (phase done)--> InProgress (next phase)
InProgress --Tick (all done)--> Completed
InProgress --Pause--> Paused
Paused --Resume--> InProgress
InProgress --Stop--> Completed
```

## Zone Deviation Detection

### ZoneTracker State
```rust
struct ZoneTracker {
    consecutive_low_secs: u32,
    consecutive_high_secs: u32,
    last_deviation: ZoneDeviation,
}
```

### Detection Logic
```rust
impl ZoneTracker {
    fn check(&mut self, current_bpm: u16, target_zone: Zone, max_hr: u16) -> Option<ZoneDeviation> {
        let current_zone = calculate_zone(current_bpm, max_hr)?;

        match current_zone.cmp(&target_zone) {
            Ordering::Less => {
                self.consecutive_low_secs += 1;
                self.consecutive_high_secs = 0;

                if self.consecutive_low_secs >= 5 && self.last_deviation != TooLow {
                    self.last_deviation = TooLow;
                    return Some(TooLow);
                }
            },
            Ordering::Greater => {
                self.consecutive_high_secs += 1;
                self.consecutive_low_secs = 0;

                if self.consecutive_high_secs >= 5 && self.last_deviation != TooHigh {
                    self.last_deviation = TooHigh;
                    return Some(TooHigh);
                }
            },
            Ordering::Equal => {
                if self.last_deviation != InZone {
                    self.consecutive_low_secs = 0;
                    self.consecutive_high_secs = 0;
                    self.last_deviation = InZone;
                    return Some(InZone);
                }
            }
        }

        None
    }
}
```

## Phase Progression

### Time-Based Transition
```rust
fn handle_tick(&mut self, state: &mut InProgress) -> Option<Transition> {
    state.elapsed_secs += 1;

    let phase = &self.plan.phases[state.phase_index];

    if matches!(phase.transition, TransitionCondition::TimeElapsed)
        && state.elapsed_secs >= phase.duration_secs
    {
        return Some(Transition::NextPhase);
    }

    None
}
```

### HR-Based Transition
```rust
fn check_hr_transition(&mut self, state: &mut InProgress, bpm: u16) -> Option<Transition> {
    let phase = &self.plan.phases[state.phase_index];

    if let TransitionCondition::HeartRateReached { target_bpm, hold_secs } = phase.transition {
        if bpm >= target_bpm {
            state.hr_hold_secs += 1;

            if state.hr_hold_secs >= hold_secs {
                return Some(Transition::NextPhase);
            }
        } else {
            state.hr_hold_secs = 0;
        }
    }

    None
}
```

## Session Summary

Captured on Completed:
```rust
pub struct SessionSummary {
    pub plan_name: String,
    pub total_duration_secs: u32,
    pub avg_bpm: u16,
    pub max_bpm: u16,
    pub avg_hrv: Option<f32>,
    pub phases_completed: usize,
    pub zones_deviation_secs: HashMap<ZoneDeviation, u32>,
}
```

## Testing Strategy

### Unit Tests
- State transitions with mock events
- Zone tracking with synthetic BPM sequences
- Phase progression timing

### Integration Tests
- Full session execution with mock TrainingPlan
- Zone deviation event emission
- Pause/resume preserves state
