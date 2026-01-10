# Design Document

## Architecture Overview

Ports and adapters pattern for biofeedback notifications. Trait in ports/, implementations in adapters/.

```
domain/session.rs
     ↓ emits
NotificationPort (trait)
     ↑ implements
  ┌──────┼──────────┐
  ↓      ↓          ↓
Mock   CLI      Flutter
```

## Interface Design

### NotificationPort Trait
```rust
#[async_trait]
pub trait NotificationPort: Send + Sync {
    async fn notify(&self, event: NotificationEvent) -> Result<()>;
}
```

### NotificationEvent Enum
```rust
#[derive(Debug, Clone, Serialize)]
pub enum NotificationEvent {
    ZoneDeviation {
        deviation: ZoneDeviation,
        current_bpm: u16,
        target_zone: Zone,
    },
    PhaseTransition {
        from_phase: usize,
        to_phase: usize,
        phase_name: String,
    },
    BatteryLow {
        percentage: u8,
    },
    ConnectionLost,
    WorkoutReady {
        plan_name: String,
    },
}
```

## Adapter Implementations

### MockNotificationAdapter
```rust
pub struct MockNotificationAdapter {
    events: Arc<Mutex<Vec<NotificationEvent>>>,
}

impl NotificationPort for MockNotificationAdapter {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        self.events.lock().unwrap().push(event);
        Ok(())
    }
}

impl MockNotificationAdapter {
    pub fn get_events(&self) -> Vec<NotificationEvent> {
        self.events.lock().unwrap().clone()
    }

    pub fn clear_events(&self) {
        self.events.lock().unwrap().clear();
    }
}
```

### CliNotificationAdapter
```rust
pub struct CliNotificationAdapter;

impl NotificationPort for CliNotificationAdapter {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        match event {
            NotificationEvent::ZoneDeviation { deviation, current_bpm, target_zone } => {
                match deviation {
                    ZoneDeviation::TooLow => {
                        println!("{} BPM: {} (Target: {:?})",
                            "⬇️  TOO LOW".blue(), current_bpm, target_zone);
                    },
                    ZoneDeviation::TooHigh => {
                        println!("{} BPM: {} (Target: {:?})",
                            "⬆️  TOO HIGH".red(), current_bpm, target_zone);
                    },
                    ZoneDeviation::InZone => {
                        println!("{} BPM: {} (Target: {:?})",
                            "✓ IN ZONE".green(), current_bpm, target_zone);
                    },
                }
            },
            NotificationEvent::PhaseTransition { from_phase, to_phase, phase_name } => {
                println!("\n{} {} → {} ({})\n",
                    "🔄 PHASE CHANGE".yellow(), from_phase, to_phase, phase_name);
            },
            NotificationEvent::BatteryLow { percentage } => {
                println!("{} {}%", "🔋 LOW BATTERY".yellow(), percentage);
            },
            NotificationEvent::ConnectionLost => {
                println!("{}", "❌ CONNECTION LOST".red().bold());
            },
            NotificationEvent::WorkoutReady { plan_name } => {
                println!("{} {}", "🏃 WORKOUT READY:".green(), plan_name);
            },
        }
        Ok(())
    }
}
```

### FlutterNotificationAdapter (Future)
Will use FRB StreamSink to emit events to Dart, where Flutter will:
- ZoneDeviation → Haptic feedback + color change
- PhaseTransition → Text-to-speech announcement
- BatteryLow → persistent banner
- ConnectionLost → dialog

## Testing Strategy

### Unit Tests
- Mock adapter records events correctly
- CLI adapter formats output (captured stdout)
- Event serialization for logging

### Integration Tests
- Session state machine emits to mock adapter
- Verify event ordering and content
- Test multiple concurrent subscribers
