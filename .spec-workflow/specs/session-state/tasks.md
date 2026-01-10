# Tasks Document

- [x] 1.1 Create session.rs with state machine scaffold
  - File: `rust/src/state/session.rs`
  - Define SessionState enum: Idle, InProgress(phase_idx, elapsed), Paused, Completed
  - Add statig state machine boilerplate
  - Purpose: Establish session state structure
  - _Leverage: state/connectivity.rs as reference, statig docs_
  - _Requirements: 1_
  - _Prompt: Role: Rust state machine specialist | Task: Create session.rs with SessionState enum (Idle, InProgress { current_phase: usize, elapsed_secs: u32 }, Paused { phase: usize, elapsed: u32 }, Completed). Define SessionEvent enum (Start(TrainingPlan), Tick, Pause, Resume, Stop). Add statig State trait impl scaffold | Restrictions: Follow statig patterns from connectivity.rs | Success: Compiles, state machine transitions defined_

- [x] 1.2 Implement session lifecycle transitions
  - File: `rust/src/state/session.rs`
  - Implement Start, Pause, Resume, Stop event handlers
  - Add phase progression logic on Tick events
  - Purpose: Handle session control flow
  - _Leverage: domain/training_plan.rs TrainingPlan_
  - _Requirements: 1, 2_
  - _Prompt: Role: Rust async developer | Task: Implement event handlers: Start loads TrainingPlan and transitions to InProgress(0, 0). Tick increments elapsed_secs, checks if phase duration exceeded, advances phase if needed. Pause saves state to Paused. Resume restores InProgress. Stop transitions to Completed | Restrictions: Must preserve elapsed time across Pause/Resume | Success: Session progresses through phases correctly_

- [x] 1.3 Add zone deviation detection
  - File: `rust/src/state/session.rs`
  - Create check_zone_deviation(bpm, target_zone) function
  - Track consecutive seconds outside zone
  - Purpose: Detect when user is outside target zone
  - _Leverage: domain/training_plan.rs calculate_zone_
  - _Requirements: 3_
  - _Prompt: Role: Rust developer with telemetry experience | Task: Add check_zone_deviation maintaining state for consecutive_low_secs and consecutive_high_secs. If bpm below zone for 5+ secs emit TooLow. If above for 5+ secs emit TooHigh. Reset counters when in zone. Add ZoneDeviation enum (InZone, TooLow, TooHigh) | Restrictions: Must use moving window, not instant checks | Success: Detects deviations with 5s threshold, resets on return_

- [x] 1.4 Add progress query methods
  - File: `rust/src/state/session.rs`
  - Implement get_progress(), get_current_phase(), time_remaining()
  - Purpose: Provide session status to UI
  - _Leverage: SessionState fields_
  - _Requirements: 2_
  - _Prompt: Role: Rust API designer | Task: Implement get_progress returning (phase_idx, elapsed_secs, total_phase_duration). Implement get_current_phase returning Option<&TrainingPhase>. Implement time_remaining returning Option<u32> seconds left in phase. Add doc comments | Restrictions: Must return None when not InProgress | Success: UI can display accurate progress bars and timers_

- [x] 1.5 Export session in state/mod.rs
  - File: `rust/src/state/mod.rs`
  - Add pub mod session; and re-exports
  - Purpose: Make session state accessible
  - _Leverage: existing state/mod.rs_
  - _Requirements: All_
  - _Prompt: Role: Rust module expert | Task: Add pub mod session; to state/mod.rs. Export key types: SessionState, SessionEvent, ZoneDeviation. Verify module structure consistent | Restrictions: Follow existing patterns | Success: Session module importable_
