# Requirements Document

## Introduction

Enhanced CLI with comprehensive commands for development, debugging, and training session execution. Improves developer experience and enables full feature testing without Android deployment.

## Alignment with Product Vision

Supports "Linux-First Development" principle: CLI enables rapid iteration with 5-second cycles, full feature parity with Flutter app for testing.

## Requirements

### Requirement 1: Enhanced Device Commands

**User Story:** As a developer, I want rich device management commands, so that I can test all BLE scenarios.

#### Acceptance Criteria

1. WHEN `cli devices scan` runs THEN it SHALL display devices in table format with name, ID, RSSI, services
2. WHEN `cli devices connect <id>` runs THEN it SHALL connect and display connection status with retries
3. WHEN `cli devices info` runs THEN it SHALL show connected device details, battery, signal strength
4. WHEN `cli devices disconnect` runs THEN it SHALL cleanly disconnect and return to idle

### Requirement 2: Training Session Commands

**User Story:** As a developer, I want to run training sessions from CLI, so that I can test workout execution.

#### Acceptance Criteria

1. WHEN `cli session start <plan.json>` runs THEN it SHALL load plan, validate, and begin execution
2. WHEN session is active THEN CLI SHALL display phase name, elapsed time, target zone, current BPM in real-time
3. WHEN zone deviation occurs THEN CLI SHALL show colored alerts (blue=low, red=high, green=in-zone)
4. WHEN `cli session pause` runs THEN session SHALL pause preserving state
5. WHEN `cli session resume` runs THEN session SHALL continue from saved state
6. WHEN `cli session stop` runs THEN it SHALL display summary with avg HR, time in zones, phases completed

### Requirement 3: Mock Mode Enhancements

**User Story:** As a developer, I want realistic mock HR scenarios, so that I can test edge cases without hardware.

#### Acceptance Criteria

1. WHEN `cli mock steady --bpm 140` runs THEN it SHALL emit constant 140 BPM with ±2 BPM noise
2. WHEN `cli mock ramp --start 120 --end 180 --duration 60` runs THEN it SHALL linearly increase BPM over 60 seconds
3. WHEN `cli mock interval --low 130 --high 170 --work 30 --rest 30` runs THEN it SHALL alternate between work/rest BPM
4. WHEN `cli mock dropout --probability 0.1` runs THEN it SHALL simulate 10% packet loss

### Requirement 4: Plan Management Commands

**User Story:** As a developer, I want to manage training plans, so that I can quickly test different workouts.

#### Acceptance Criteria

1. WHEN `cli plan list` runs THEN it SHALL show all saved plans in ~/.heart-beat/plans/
2. WHEN `cli plan show <name>` runs THEN it SHALL display plan phases in table format
3. WHEN `cli plan validate <file>` runs THEN it SHALL check plan validity and show errors
4. WHEN `cli plan create` runs THEN it SHALL launch interactive wizard to build plan

## Non-Functional Requirements

### Code Architecture
- cli.rs uses clap v4 with subcommands
- All logic delegates to existing api.rs functions
- Colored output with `colored` crate
- Tables with `comfy-table` crate

### Performance
- Command response: < 100ms (except scan/connect)
- Real-time updates: 60fps refresh rate for session display

### Usability
- Help text for all commands with examples
- Progress indicators for long operations
- Graceful error messages with suggestions
