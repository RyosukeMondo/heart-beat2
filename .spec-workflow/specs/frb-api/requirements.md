# Requirements Document

## Introduction

FRB API layer exposing Rust core functionality to Flutter via flutter_rust_bridge v2. Provides StreamSink-based real-time heart rate streaming and async methods for BLE operations.

## Alignment with Product Vision

Enables Flutter UI to consume deterministic Rust core logic with type-safe FFI bindings, supporting the cross-platform development goal (Linux CLI + Android app).

## Requirements

### Requirement 1: API Surface

**User Story:** As a Flutter developer, I want a simple API to control BLE and receive HR data, so that I can build the UI without understanding Rust internals.

#### Acceptance Criteria

1. WHEN api.rs is exposed via FRB THEN it SHALL provide async functions: scan_devices(), connect_device(device_id), disconnect(), start_mock_mode()
2. WHEN scan completes THEN it SHALL return Vec<DiscoveredDevice>
3. WHEN HR data is available THEN it SHALL stream via StreamSink<FilteredHeartRate> to Flutter
4. WHEN errors occur THEN they SHALL be propagated as Flutter exceptions with error messages

### Requirement 2: StreamSink Integration

**User Story:** As a Flutter developer, I want reactive HR data updates, so that the UI automatically refreshes.

#### Acceptance Criteria

1. WHEN create_hr_stream() is called THEN it SHALL return StreamSink handle
2. WHEN HR data is filtered THEN it SHALL emit to all active StreamSink subscribers
3. WHEN app is backgrounded THEN stream SHALL continue emitting
4. WHEN disconnect is called THEN stream SHALL emit null/disconnected event

### Requirement 3: CLI Parity

**User Story:** As a developer, I want CLI to use same core logic as Flutter, so that CLI testing reflects production behavior.

#### Acceptance Criteria

1. WHEN api.rs is implemented THEN CLI SHALL NOT duplicate logic from api.rs
2. WHEN domain/state changes THEN both CLI and Flutter SHALL automatically benefit
3. WHEN testing CLI THEN verified behavior SHALL match Flutter app behavior

## Non-Functional Requirements

### Code Architecture
- api.rs depends on domain, ports, adapters, state modules
- api.rs orchestrates components, contains no business logic itself
- FRB codegen runs on api.rs only, lib.rs re-exports

### Performance
- StreamSink emissions: < 10ms overhead from domain to Dart isolate
- Startup: < 500ms from Flutter init to API ready

### Reliability
- Handle Flutter isolate shutdown gracefully
- No Rust panics across FFI boundary
