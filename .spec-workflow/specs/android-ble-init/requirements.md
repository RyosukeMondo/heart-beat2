# Requirements Document

## Introduction

Fix the btleplug Android initialization issue that causes BLE scanning to fail with "droidplug has not been initialized" error. This is a critical bug blocking all BLE functionality on Android.

## Alignment with Product Vision

This directly supports the core product goal of real-time HR streaming from BLE heart rate monitors on Android devices. Without this fix, the Android app cannot scan for or connect to any BLE devices.

## Requirements

### Requirement 1: Android Platform Initialization

**User Story:** As an Android user, I want BLE scanning to work, so that I can connect to my heart rate monitor.

#### Acceptance Criteria

1. WHEN the app starts on Android THEN the system SHALL initialize btleplug with the JNI environment
2. IF btleplug initialization fails THEN the system SHALL log a descriptive error message
3. WHEN BLE operations are attempted before initialization THEN the system SHALL return a clear error

### Requirement 2: Platform-Agnostic API

**User Story:** As a developer, I want a single initialization API, so that the Flutter code works on all platforms.

#### Acceptance Criteria

1. WHEN init is called on Android THEN the system SHALL perform Android-specific initialization
2. WHEN init is called on Linux/desktop THEN the system SHALL skip Android-specific code
3. IF initialization succeeds THEN the system SHALL return Ok(())

## Non-Functional Requirements

### Code Architecture and Modularity
- Single Responsibility: Initialization logic isolated in api.rs
- Platform detection via cfg attributes
- No changes to existing BLE adapter code

### Reliability
- Initialization must complete before any BLE operations
- Clear error messages on failure
- Graceful degradation if BLE unavailable
