# Requirements Document

## Introduction

Reconnection handling provides automatic BLE reconnection when connection is lost, with user feedback and session preservation. This ensures reliable operation during workouts as specified in the product success metrics.

## Alignment with Product Vision

From product.md Success Metrics: "Session Reliability: 99% of training sessions complete without BLE disconnection requiring user intervention". From tech.md: "Reconnection: Automatic retry on BLE disconnection".

## Requirements

### Requirement 1: Automatic Reconnection

**User Story:** As an athlete, I want the app to automatically reconnect if connection is lost, so my workout isn't interrupted.

#### Acceptance Criteria

1. WHEN BLE connection is lost THEN system SHALL attempt reconnection automatically
2. IF reconnection attempt THEN system SHALL try up to 5 times with exponential backoff
3. WHEN reconnection succeeds THEN system SHALL resume HR streaming immediately
4. IF all attempts fail THEN system SHALL notify user and offer manual reconnect

### Requirement 2: Session Preservation During Reconnect

**User Story:** As an athlete, I want my workout to pause during disconnection, so I don't lose progress.

#### Acceptance Criteria

1. WHEN connection is lost during workout THEN session SHALL pause automatically
2. IF reconnection succeeds THEN session SHALL resume from pause point
3. WHEN paused for reconnection THEN elapsed time SHALL not advance
4. IF user stops during reconnect THEN session SHALL save with interrupted status

### Requirement 3: User Feedback During Reconnection

**User Story:** As an athlete, I want to see reconnection status, so I know what's happening.

#### Acceptance Criteria

1. WHEN reconnecting THEN UI SHALL display "Reconnecting..." banner with attempt count
2. IF reconnection in progress THEN spinner indicator SHALL be visible
3. WHEN reconnection fails THEN UI SHALL show failure reason and retry option
4. WHEN reconnected THEN UI SHALL show brief success confirmation

### Requirement 4: Background Reconnection

**User Story:** As an athlete, I want reconnection to work even when app is backgrounded, so I can continue using my phone.

#### Acceptance Criteria

1. WHEN app is backgrounded during reconnect THEN attempts SHALL continue
2. IF reconnection succeeds in background THEN notification SHALL inform user
3. WHEN app is foregrounded THEN UI SHALL reflect current connection state

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Reconnection logic in state machine, separate from UI
- **Modular Design**: ReconnectionPolicy configurable
- **Clear Interfaces**: State machine emits events, UI observes

### Performance
- Reconnection attempt within 1 second of disconnect detection
- Exponential backoff: 1s, 2s, 4s, 8s, 16s between attempts

### Reliability
- Handle partial disconnections gracefully
- Preserve BLE adapter state across reconnection
