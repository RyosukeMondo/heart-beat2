# Requirements Document

## Introduction

NotificationPort trait defining interface for biofeedback notifications (audio/visual). Enables domain logic to trigger alerts without coupling to specific notification implementations (Flutter audio, CLI stdout, etc.).

## Alignment with Product Vision

Implements "Biofeedback Loop" feature: audio/visual notifications when HR deviates from target zone. Uses ports/adapters pattern to keep domain logic pure.

## Requirements

### Requirement 1: NotificationPort Trait

**User Story:** As a domain developer, I want a clean interface to trigger notifications, so that I don't couple to UI frameworks.

#### Acceptance Criteria

1. WHEN NotificationPort is defined THEN it SHALL have async fn notify(event: NotificationEvent)
2. WHEN NotificationEvent is emitted THEN implementations SHALL handle: ZoneDeviation, PhaseTransition, BatteryLow, ConnectionLost
3. WHEN notify is called THEN implementations MAY choose how to alert user (audio, visual, log)

### Requirement 2: NotificationEvent Types

**User Story:** As an adapter developer, I want clear event types, so that I can provide appropriate feedback.

#### Acceptance Criteria

1. WHEN ZoneDeviation event contains TooLow/TooHigh THEN adapter SHALL emit distinct audio tones or visual colors
2. WHEN PhaseTransition event contains next_phase name THEN adapter SHALL announce phase name
3. WHEN BatteryLow event contains percentage THEN adapter SHALL display persistent warning
4. WHEN ConnectionLost event occurs THEN adapter SHALL alert user immediately

### Requirement 3: Mock Notification Adapter

**User Story:** As a test developer, I want a mock adapter, so that I can verify notification logic without UI.

#### Acceptance Criteria

1. WHEN MockNotificationAdapter is used THEN it SHALL record all notify() calls
2. WHEN test asserts notifications THEN it SHALL query recorded events
3. WHEN multiple events fire THEN mock SHALL preserve order

## Non-Functional Requirements

### Code Architecture
- notification.rs in ports/ (trait only)
- No implementation in ports, only interface definition
- Adapters in adapters/ (mock, flutter, cli)

### Performance
- notify() call overhead: < 5ms
- Non-blocking: implementations must not block domain logic
