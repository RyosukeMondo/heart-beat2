# Requirements Document

## Introduction

Workout execution provides the active workout tracking UI with phase progression, zone guidance, and biofeedback alerts. This transforms the passive HR monitoring into an active training tool as described in the product vision.

## Alignment with Product Vision

From product.md: "Planned Training Execution: Scheduler-driven training sessions with automatic zone transitions (WarmUp -> Work -> Recovery)" and "Biofeedback Loop: Audio/visual notifications when heart rate deviates from target zone".

## Requirements

### Requirement 1: Start Workout from Plan

**User Story:** As an athlete, I want to start a workout from a training plan, so that I can follow a structured session.

#### Acceptance Criteria

1. WHEN user selects "Start Workout" THEN system SHALL display plan selection
2. IF plan is selected THEN system SHALL start session with first phase
3. WHEN session starts THEN system SHALL display current phase, target zone, elapsed time

### Requirement 2: Phase Progression Display

**User Story:** As an athlete, I want to see my progress through workout phases, so that I know what's coming next.

#### Acceptance Criteria

1. WHEN phase transitions THEN UI SHALL update current phase indicator
2. IF transition is time-based THEN system SHALL auto-advance at phase duration
3. IF transition is HR-based THEN system SHALL advance when HR target sustained 10 seconds
4. WHEN in phase THEN display SHALL show: phase name, time remaining, target zone

### Requirement 3: Zone Deviation Feedback

**User Story:** As an athlete, I want feedback when I'm outside my target zone, so that I can adjust my effort.

#### Acceptance Criteria

1. WHEN HR is below target zone for 5+ seconds THEN system SHALL show "Speed Up" indicator
2. WHEN HR is above target zone for 5+ seconds THEN system SHALL show "Slow Down" indicator
3. IF deviation persists 10+ seconds THEN system SHALL emit audio notification
4. WHEN HR returns to zone THEN indicator SHALL clear immediately

### Requirement 4: Session Controls

**User Story:** As an athlete, I want to pause, resume, and stop my workout, so that I have control during training.

#### Acceptance Criteria

1. WHEN user taps pause THEN system SHALL pause timer and phase progression
2. WHEN user taps resume THEN system SHALL continue from pause point
3. WHEN user taps stop THEN system SHALL show confirmation and save session
4. IF app is backgrounded THEN session SHALL continue running

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Workout UI separate from session state machine
- **Modular Design**: Phase progress widget, zone indicator widget, controls widget
- **Clear Interfaces**: SessionExecutor drives state, UI observes

### Performance
- UI update within 100ms of state change
- Phase transition animation smooth (60fps)

### Usability
- Large touch targets for glove-friendly operation
- High contrast zone colors visible in sunlight
