# Requirements Document

## Introduction

Implement a unified logging system that connects Rust tracing logs to Flutter, enables Android logcat output, and provides a centralized log management service. Currently, init_logging() and init_panic_handler() are defined but never called.

## Alignment with Product Vision

Debugging is essential for development velocity. A unified logging system enables rapid issue diagnosis across the Rust/Flutter boundary, reducing debugging time from hours to minutes.

## Requirements

### Requirement 1: Initialize Rust Logging

**User Story:** As a developer, I want Rust logs to be captured, so that I can debug BLE and core logic issues.

#### Acceptance Criteria

1. WHEN app starts THEN the system SHALL call init_panic_handler()
2. WHEN app starts THEN the system SHALL call init_logging() with a StreamSink
3. IF logging init fails THEN the system SHALL print error to console and continue

### Requirement 2: Flutter Log Service

**User Story:** As a developer, I want a centralized log service, so that I can access logs from anywhere in the app.

#### Acceptance Criteria

1. WHEN LogService receives a log THEN the system SHALL store it in memory
2. WHEN LogService receives a log THEN the system SHALL broadcast it to listeners
3. IF in debug mode THEN the system SHALL also print to debugPrint

### Requirement 3: Android Logcat Integration

**User Story:** As a developer, I want logs in Android logcat, so that I can use adb logcat for debugging.

#### Acceptance Criteria

1. WHEN running on Android THEN Rust logs SHALL appear in logcat
2. WHEN log is emitted THEN the system SHALL send to BOTH Flutter and logcat
3. IF logcat output fails THEN the system SHALL continue with Flutter-only logging

## Non-Functional Requirements

### Code Architecture and Modularity
- LogService as singleton for global access
- android_logger crate for native Android logging
- Dual output (Flutter + logcat) on Android

### Performance
- Log buffer limited to 1000 entries to prevent memory bloat
- Async log delivery to avoid blocking UI
