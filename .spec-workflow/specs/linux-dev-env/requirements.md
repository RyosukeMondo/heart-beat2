# Requirements Document

## Introduction

Set up Flutter Linux desktop support and development scripts for rapid iteration. Linux development is 10-30x faster than Android builds, making it ideal for development workflow.

## Alignment with Product Vision

Fast iteration accelerates development. Linux desktop support enables testing UI and Rust logic without Android build overhead.

## Requirements

### Requirement 1: Flutter Linux Desktop Support

**User Story:** As a developer, I want to run the app on Linux, so that I can iterate quickly without Android builds.

#### Acceptance Criteria

1. WHEN `flutter run -d linux` is executed THEN the system SHALL launch the app
2. WHEN running on Linux THEN BLE operations SHALL use BlueZ (btleplug)
3. IF Linux dependencies are missing THEN the build SHALL show clear error messages

### Requirement 2: Development Scripts

**User Story:** As a developer, I want helper scripts, so that I can quickly build and run the app.

#### Acceptance Criteria

1. WHEN `./scripts/dev-linux.sh` is run THEN the system SHALL build Rust and launch Flutter
2. WHEN Rust files change THEN dev-watch script SHALL auto-rebuild
3. IF build fails THEN scripts SHALL show clear error messages

### Requirement 3: CLI Development Mode

**User Story:** As a developer, I want to test Rust logic via CLI, so that I can debug without any UI.

#### Acceptance Criteria

1. WHEN `cargo run --bin cli` is executed THEN the CLI SHALL start
2. WHEN `cli devices scan` is run THEN the system SHALL list nearby BLE devices
3. WHEN `cli --help` is run THEN the system SHALL show available commands

## Non-Functional Requirements

### Code Architecture and Modularity
- Scripts are standalone and documented
- Linux desktop shares same Rust core as Android
- No platform-specific UI code required

### Performance
- Linux builds should complete in < 10 seconds
- Hot reload should work for Flutter changes
