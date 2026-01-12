# Requirements Document

## Introduction

Create an in-app debug console widget that displays real-time Rust logs with filtering capabilities. This enables developers to debug issues directly on the device without needing adb access.

## Alignment with Product Vision

The debug console accelerates development by providing immediate visibility into app behavior. Essential for field testing and diagnosing issues on real devices.

## Requirements

### Requirement 1: Log Display Widget

**User Story:** As a developer, I want to see logs in the app, so that I can debug without a computer connected.

#### Acceptance Criteria

1. WHEN debug console is visible THEN the system SHALL show recent logs in a scrollable list
2. WHEN new log arrives THEN the system SHALL auto-scroll to show it (if at bottom)
3. IF log level is ERROR THEN the system SHALL highlight it in red

### Requirement 2: Log Filtering

**User Story:** As a developer, I want to filter logs, so that I can focus on relevant information.

#### Acceptance Criteria

1. WHEN filter by level is set THEN the system SHALL only show logs at that level or higher
2. WHEN search text is entered THEN the system SHALL filter to logs containing that text
3. WHEN filter is cleared THEN the system SHALL show all logs

### Requirement 3: Debug Console Toggle

**User Story:** As a developer, I want to toggle the console, so that it doesn't interfere with normal app usage.

#### Acceptance Criteria

1. WHEN triple-tap on screen THEN the system SHALL toggle console visibility
2. IF console is visible THEN the system SHALL show as overlay on current screen
3. WHEN app is in release mode THEN the system SHALL hide the toggle gesture

## Non-Functional Requirements

### Code Architecture and Modularity
- Standalone widget, no dependencies on specific screens
- Uses LogService stream for data
- Gesture detection at app level

### Performance
- Limit displayed logs to 200 for smooth scrolling
- Lazy rendering for log list
