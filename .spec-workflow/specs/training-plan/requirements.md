# Requirements Document

## Introduction

Training plan definitions and zone-based workout scheduling. Enables users to define structured workouts (WarmUp → Work → Recovery) with automatic transitions based on time or heart rate thresholds.

## Alignment with Product Vision

Implements "Planned Training Execution" feature from product.md: scheduler-driven training sessions with automatic zone transitions, transforming passive monitoring into active training tool.

## Requirements

### Requirement 1: Training Plan Data Model

**User Story:** As a user, I want to define a training plan with multiple phases, so that my workout progresses automatically.

#### Acceptance Criteria

1. WHEN a TrainingPlan is created THEN it SHALL contain Vec<TrainingPhase> and metadata (name, created_at)
2. WHEN a TrainingPhase is defined THEN it SHALL specify target Zone, duration_secs, and transition_condition
3. IF transition_condition is TimeElapsed THEN phase SHALL end after duration_secs
4. IF transition_condition is HeartRateReached(bpm) THEN phase SHALL end when filtered BPM >= target for 10 consecutive seconds

### Requirement 2: Zone Calculation

**User Story:** As a user, I want zones calculated from my max HR, so that training is personalized.

#### Acceptance Criteria

1. WHEN calculate_zone(bpm, max_hr) is called THEN it SHALL return Zone1 (50-60%), Zone2 (60-70%), Zone3 (70-80%), Zone4 (80-90%), Zone5 (90-100%)
2. WHEN bpm < 50% max_hr THEN it SHALL return None (below training threshold)
3. WHEN max_hr is invalid (<100 or >220) THEN it SHALL return Err

### Requirement 3: Plan Serialization

**User Story:** As a user, I want to save/load training plans, so that I can reuse workouts.

#### Acceptance Criteria

1. WHEN TrainingPlan implements Serialize/Deserialize THEN it SHALL persist to JSON
2. WHEN loading a plan THEN it SHALL validate phase durations (> 0s) and zone ranges
3. IF plan is invalid THEN it SHALL return Err with validation message

## Non-Functional Requirements

### Code Architecture
- training_plan.rs in domain/ (no I/O dependencies)
- Pure functions for zone calculation and validation
- Serde for JSON serialization

### Performance
- Zone calculation: O(1) lookup, < 1μs
- Plan validation: < 1ms for 20-phase plan

### Usability
- Example plans: "5k Tempo Run", "Base Endurance", "VO2 Max Intervals" in tests
