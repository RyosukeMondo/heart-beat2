# Design Document

## Architecture Overview

Orchestration layer coordinating session state machine, HR data stream, and notification port. Uses tokio-cron-scheduler for scheduled workouts.

```
SessionExecutor
     ↓ drives
SessionState (statig)
     ↑ consumes
  ┌─────┼─────┐
  ↓     ↓     ↓
 HR  Timer  User
Stream  (Tick) Events
```

## Component Design

### SessionExecutor
```rust
pub struct SessionExecutor {
    session_state: Arc<Mutex<SessionStateMachine>>,
    hr_receiver: broadcast::Receiver<FilteredHeartRate>,
    notification_port: Arc<dyn NotificationPort>,
    tick_task: Option<JoinHandle<()>>,
    checkpoint_path: PathBuf,
    scheduler: JobScheduler,
}
```

### Lifecycle Methods
```rust
impl SessionExecutor {
    pub fn new(
        hr_receiver: broadcast::Receiver<FilteredHeartRate>,
        notification_port: Arc<dyn NotificationPort>,
    ) -> Self;

    pub async fn start_session(&mut self, plan: TrainingPlan) -> Result<()>;

    pub async fn pause_session(&mut self) -> Result<()>;

    pub async fn resume_session(&mut self) -> Result<()>;

    pub async fn stop_session(&mut self) -> Result<SessionSummary>;

    pub async fn schedule_session(&mut self, plan: TrainingPlan, cron: &str) -> Result<JobId>;
}
```

## Tick Loop Design

```rust
async fn tick_loop(
    state: Arc<Mutex<SessionStateMachine>>,
    mut hr_receiver: broadcast::Receiver<FilteredHeartRate>,
    notification_port: Arc<dyn NotificationPort>,
) {
    let mut interval = tokio::time::interval(Duration::from_secs(1));

    loop {
        tokio::select! {
            _ = interval.tick() => {
                let mut state = state.lock().unwrap();
                state.handle(SessionEvent::Tick);

                if let Some(deviation) = state.get_zone_deviation() {
                    notification_port.notify(NotificationEvent::ZoneDeviation {
                        deviation,
                        current_bpm: state.get_current_bpm(),
                        target_zone: state.get_target_zone(),
                    }).await.ok();
                }

                if state.is_completed() {
                    break;
                }
            }

            hr_data = hr_receiver.recv() => {
                if let Ok(data) = hr_data {
                    let mut state = state.lock().unwrap();
                    state.handle(SessionEvent::UpdateBpm(data.filtered_bpm));
                }
            }
        }
    }
}
```

## Checkpoint/Restore

### Checkpoint Format
```json
{
  "plan": { /* TrainingPlan */ },
  "state": "InProgress",
  "phase_index": 2,
  "elapsed_secs": 145,
  "last_checkpoint": "2026-01-11T12:15:30Z"
}
```

### Implementation
```rust
impl SessionExecutor {
    async fn save_checkpoint(&self) -> Result<()> {
        let state = self.session_state.lock().unwrap();
        let checkpoint = Checkpoint {
            plan: state.get_plan().clone(),
            state: state.get_state_name(),
            phase_index: state.get_phase_index(),
            elapsed_secs: state.get_elapsed(),
            last_checkpoint: Utc::now(),
        };

        tokio::fs::write(
            &self.checkpoint_path,
            serde_json::to_string_pretty(&checkpoint)?
        ).await?;

        Ok(())
    }

    pub async fn restore_checkpoint(&mut self) -> Result<bool> {
        if !self.checkpoint_path.exists() {
            return Ok(false);
        }

        let data = tokio::fs::read_to_string(&self.checkpoint_path).await?;
        let checkpoint: Checkpoint = serde_json::from_str(&data)?;

        // Only restore if checkpoint < 1 hour old
        if (Utc::now() - checkpoint.last_checkpoint).num_hours() < 1 {
            self.session_state.lock().unwrap().restore(checkpoint);
            self.start_tick_loop();
            Ok(true)
        } else {
            Ok(false)
        }
    }
}
```

## Cron Scheduling

### Schedule Storage
```rust
struct PendingSession {
    plan: TrainingPlan,
    scheduled_at: DateTime<Utc>,
    job_id: Uuid,
}

impl SessionExecutor {
    pending_sessions: HashMap<Uuid, PendingSession>,
}
```

### Scheduling Flow
```rust
pub async fn schedule_session(&mut self, plan: TrainingPlan, cron: &str) -> Result<JobId> {
    let job_id = Uuid::new_v4();
    let plan_name = plan.name.clone();
    let notification_port = self.notification_port.clone();

    let job = Job::new_async(cron, move |_uuid, _lock| {
        let notification_port = notification_port.clone();
        let plan_name = plan_name.clone();

        Box::pin(async move {
            notification_port.notify(NotificationEvent::WorkoutReady {
                plan_name
            }).await.ok();
        })
    })?;

    self.scheduler.add(job).await?;

    self.pending_sessions.insert(job_id, PendingSession {
        plan,
        scheduled_at: Utc::now(),
        job_id,
    });

    Ok(job_id)
}
```

## Testing Strategy

### Unit Tests
- Tick loop with mock HR stream
- Checkpoint save/restore
- Cron schedule parsing

### Integration Tests
- Full session execution with real state machine
- HR updates trigger zone checks
- Phase transitions emit notifications
- Checkpoint survives process restart (file-based test)
