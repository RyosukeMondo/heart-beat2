# Tasks Document

- [ ] 1.1 Create training_plan.rs with data structures
  - File: `rust/src/domain/training_plan.rs`
  - Define TrainingPlan, TrainingPhase, TransitionCondition enums/structs
  - Add serde derives for JSON serialization
  - Purpose: Establish training plan data model
  - _Leverage: domain/heart_rate.rs Zone enum_
  - _Requirements: 1, 3_
  - _Prompt: Role: Rust data modeling expert | Task: Create training_plan.rs with TrainingPlan struct (name: String, phases: Vec<TrainingPhase>, created_at: chrono::DateTime). TrainingPhase struct (target_zone: Zone, duration_secs: u32, transition: TransitionCondition). TransitionCondition enum (TimeElapsed, HeartRateReached(u16)). Derive Serialize, Deserialize, Debug | Restrictions: No I/O code, pure data structures | Success: Compiles, serde JSON serialization works_

- [ ] 1.2 Implement zone calculation function
  - File: `rust/src/domain/training_plan.rs`
  - Implement calculate_zone(bpm: u16, max_hr: u16) -> Result<Option<Zone>>
  - Return Zone based on percentage thresholds
  - Purpose: Provide pure zone calculation logic
  - _Leverage: domain/heart_rate.rs Zone enum_
  - _Requirements: 2_
  - _Prompt: Role: Rust developer with sports science knowledge | Task: Implement calculate_zone returning Zone1 (50-60% max_hr), Zone2 (60-70%), Zone3 (70-80%), Zone4 (80-90%), Zone5 (90-100%). Return None if <50%. Return Err if max_hr invalid (<100 or >220). Add doc comments with examples | Restrictions: Pure function, no side effects | Success: Unit tests pass for all zones and edge cases_

- [ ] 1.3 Add plan validation
  - File: `rust/src/domain/training_plan.rs`
  - Implement TrainingPlan::validate() -> Result<()>
  - Check phase durations > 0, total duration < 4 hours
  - Purpose: Prevent invalid plans from executing
  - _Leverage: anyhow for errors_
  - _Requirements: 3_
  - _Prompt: Role: Rust validation expert | Task: Implement validate method checking: all phase durations > 0, total duration < 14400s (4 hours), at least 1 phase exists. Return Err with descriptive message if invalid. Add unit tests for valid and invalid plans | Restrictions: No I/O, pure validation logic | Success: Catches all invalid cases, allows valid plans_

- [ ] 1.4 Create example training plans
  - File: `rust/src/domain/training_plan.rs` (tests module)
  - Add fixture functions: tempo_run(), base_endurance(), vo2_intervals()
  - Purpose: Provide realistic test data and usage examples
  - _Leverage: training_plan structs_
  - _Requirements: 1_
  - _Prompt: Role: Rust test engineer with running experience | Task: Create tempo_run (10min Z2 warmup, 20min Z3 work, 10min Z1 cooldown), base_endurance (45min Z2), vo2_intervals (5min Z2, 5x [3min Z5, 2min Z2], 5min Z1). Use TimeElapsed transitions. Add doc comments explaining each plan | Restrictions: Tests only, not production code | Success: Plans validate and serialize correctly_

- [ ] 1.5 Export training_plan in domain/mod.rs
  - File: `rust/src/domain/mod.rs`
  - Add pub mod training_plan; and re-exports
  - Purpose: Make training_plan accessible to other modules
  - _Leverage: existing domain/mod.rs pattern_
  - _Requirements: All_
  - _Prompt: Role: Rust module organization expert | Task: Add pub mod training_plan; to domain/mod.rs. Add pub use training_plan::{TrainingPlan, TrainingPhase, TransitionCondition, calculate_zone}. Verify module structure follows project conventions | Restrictions: Follow existing mod.rs pattern | Success: Other modules can import training_plan types_
