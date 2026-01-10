# Tasks Document

- [ ] 1.1 Create scheduler module structure
  - File: `rust/src/scheduler/mod.rs`, `rust/src/scheduler/executor.rs`
  - Create scheduler directory and module files
  - Add basic struct definitions
  - Purpose: Establish scheduler module foundation
  - _Leverage: state/mod.rs structure_
  - _Requirements: 1_
  - _Prompt: Role: Rust project organizer | Task: Create rust/src/scheduler/ directory. Create mod.rs with pub mod executor; pub use executor::*;. Create executor.rs with SessionExecutor struct. Add dependencies: tokio-cron-scheduler, tokio::time. Add use statements for state/session, domain/training_plan, ports/notification | Restrictions: Scaffold only, no implementation | Success: Module structure compiles_

- [ ] 1.2 Implement SessionExecutor::start
  - File: `rust/src/scheduler/executor.rs`
  - Create SessionExecutor with start_session(plan: TrainingPlan) method
  - Initialize session state machine and start tick loop
  - Purpose: Begin executing training session
  - _Leverage: state/session.rs SessionState_
  - _Requirements: 1_
  - _Prompt: Role: Rust async runtime expert | Task: Implement SessionExecutor struct with session_state: Arc<Mutex<SessionState>>, notification_port: Box<dyn NotificationPort>. Implement start_session sending SessionEvent::Start(plan), spawning tokio task with loop calling Tick every 1s using tokio::time::interval. Store task handle | Restrictions: Must use Arc<Mutex> for shared state, spawn task not block | Success: Session progresses through phases with 1s ticks_

- [ ] 1.3 Integrate HR data stream
  - File: `rust/src/scheduler/executor.rs`
  - Add hr_stream parameter to SessionExecutor::new
  - Pass incoming HR data to session state for zone checking
  - Purpose: Connect real-time HR to session execution
  - _Leverage: domain/filters.rs FilteredHeartRate stream_
  - _Requirements: 2_
  - _Prompt: Role: Rust streams expert | Task: Add hr_receiver: tokio::sync::broadcast::Receiver<FilteredHeartRate> to SessionExecutor. In tick loop, check for HR data via try_recv(). If received, call session_state.update_bpm(filtered_bpm). If zone deviation detected, emit notification via notification_port.notify() | Restrictions: Must not block on HR receiver, use try_recv not recv | Success: Zone deviations trigger notifications_

- [ ] 1.4 Add session persistence
  - File: `rust/src/scheduler/executor.rs`
  - Save session progress to JSON every 10 seconds
  - Load checkpoint on executor creation
  - Purpose: Survive process crashes without losing progress
  - _Leverage: serde_json for serialization_
  - _Requirements: 1, Reliability NFR_
  - _Prompt: Role: Rust persistence expert | Task: Add checkpoint_path field to SessionExecutor. Every 10 ticks, serialize current SessionState to JSON at checkpoint_path. On new(), check if checkpoint exists and load, resuming session if InProgress or Paused. Add clear_checkpoint() on Completed | Restrictions: Must handle file I/O errors gracefully, use tokio::fs for async | Success: Sessions resume after restart_

- [ ] 1.5 Implement cron scheduling
  - File: `rust/src/scheduler/executor.rs`
  - Add schedule_session(plan, cron_expr) using tokio-cron-scheduler
  - Emit notification when scheduled time arrives
  - Purpose: Enable pre-scheduled workouts
  - _Leverage: tokio-cron-scheduler crate_
  - _Requirements: 3_
  - _Prompt: Role: Rust scheduler specialist | Task: Add schedule_session(plan: TrainingPlan, cron: &str) creating tokio_cron_scheduler job. When job fires, emit NotificationEvent::WorkoutReady { plan_name }. Store job in pending_sessions HashMap. If user calls start_session matching plan within 10 min, begin. Else mark skipped | Restrictions: Must validate cron expression, return Err if invalid | Success: Scheduled sessions fire on time_

- [ ] 1.6 Export scheduler in lib.rs
  - File: `rust/src/lib.rs`
  - Add pub mod scheduler; and re-export SessionExecutor
  - Purpose: Make scheduler accessible to api.rs and CLI
  - _Leverage: existing lib.rs structure_
  - _Requirements: All_
  - _Prompt: Role: Rust module expert | Task: Add pub mod scheduler; to lib.rs. Re-export pub use scheduler::SessionExecutor. Verify API can import and use executor | Restrictions: Follow existing patterns | Success: api.rs and cli.rs can use SessionExecutor_
