# Requirements Document

## Introduction

Training session state machine managing workout execution, phase transitions, and real-time biofeedback. Works in conjunction with scheduler to execute TrainingPlan and emit zone deviation events.

## Alignment with Product Vision

Implements "Planned Training Execution" and "Biofeedback Loop" features: automatic phase transitions and audio/visual notifications when HR deviates from target zone.

## Requirements

### Requirement 1: Session State Machine

**User Story:** As a user, I want my workout to progress through phases automatically, so that I can focus on training.

#### Acceptance Criteria

1. WHEN session starts THEN state SHALL be Idle
2. WHEN start_session(plan) is called THEN state SHALL transition to WarmUp with first phase
3. WHEN phase duration elapsed OR HR threshold met THEN state SHALL transition to next phase
4. WHEN all phases complete THEN state SHALL transition to Completed
5. WHEN pause_session() is called THEN state SHALL transition to Paused, preserving elapsed time

### Requirement 2: Phase Progress Tracking

**User Story:** As a user, I want to see how much time remains in the current phase, so that I can pace myself.

#### Acceptance Criteria

1. WHEN in active phase THEN system SHALL track elapsed_secs and remaining_secs
2. WHEN get_progress() is called THEN it SHALL return (current_phase_index, elapsed_secs, total_phase_duration)
3. WHEN phase transitions THEN elapsed_secs SHALL reset to 0 for new phase

### Requirement 3: Zone Deviation Detection

**User Story:** As a user, I want to know when I'm outside my target zone, so that I can adjust intensity.

#### Acceptance Criteria

1. WHEN current_bpm is received THEN system SHALL compare against current phase target_zone
2. IF bpm is below zone for > 5 seconds THEN emit ZoneDeviation::TooLow event
3. IF bpm is above zone for > 5 seconds THEN emit ZoneDeviation::TooHigh event
4. IF bpm returns to zone THEN emit ZoneDeviation::InZone event

## Non-Functional Requirements

### Code Architecture
- session.rs in state/ using statig state machine
- Depends on domain/training_plan and domain/heart_rate types
- Emits events to NotificationPort trait

### Performance
- State transition: < 5ms
- Zone check: < 100μs per HR update

### Reliability
- Preserve session progress if process is killed
- Auto-resume from Paused after 30 minutes of inactivity
