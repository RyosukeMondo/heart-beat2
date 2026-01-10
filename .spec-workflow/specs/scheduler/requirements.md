# Requirements Document

## Introduction

Training plan scheduler using tokio-cron-scheduler to execute scheduled workouts, manage session lifecycle, and integrate session state machine with real-time HR data.

## Alignment with Product Vision

Implements "Planned Training Execution" feature: scheduler-driven training sessions with automatic phase transitions, connecting training plans to real-time biofeedback.

## Requirements

### Requirement 1: Session Executor

**User Story:** As a user, I want to start a training session, so that the system guides me through phases automatically.

#### Acceptance Criteria

1. WHEN start_session(plan) is called THEN executor SHALL initialize session state machine with TrainingPlan
2. WHEN session is active THEN executor SHALL tick session state every 1 second
3. WHEN phase transition occurs THEN executor SHALL emit NotificationEvent::PhaseTransition
4. WHEN session completes THEN executor SHALL persist session log to JSON

### Requirement 2: HR Data Integration

**User Story:** As a user, I want my HR data to influence session execution, so that phase transitions respect my physiology.

#### Acceptance Criteria

1. WHEN HR data arrives THEN executor SHALL pass current_bpm to session state machine
2. WHEN TransitionCondition::HeartRateReached(target) is met THEN executor SHALL advance phase
3. WHEN zone deviation detected THEN executor SHALL emit NotificationEvent::ZoneDeviation
4. WHEN HR signal lost for > 30s THEN executor SHALL pause session and notify user

### Requirement 3: Scheduled Sessions

**User Story:** As a user, I want to schedule workouts in advance, so that I'm reminded to train.

#### Acceptance Criteria

1. WHEN schedule_session(plan, cron_expr) is called THEN it SHALL register cron job
2. WHEN cron time arrives THEN it SHALL emit notification "Workout Ready" and wait for user start
3. WHEN user starts within 10 minutes THEN it SHALL begin session
4. IF user ignores THEN it SHALL mark session as skipped

## Non-Functional Requirements

### Code Architecture
- scheduler/executor.rs orchestrates session state + HR stream + notifications
- Uses tokio-cron-scheduler for scheduling
- No business logic in executor, delegates to domain and state

### Performance
- Tick overhead: < 10ms per second
- Session start latency: < 100ms

### Reliability
- Persist session progress every 10 seconds to survive crashes
- Auto-recover from last checkpoint on restart
