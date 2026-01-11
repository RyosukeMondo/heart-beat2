# Requirements Document

## Introduction

Complete Android build integration including FRB codegen, Rust library compilation for ARM64/x86_64, Flutter build configuration, and APK packaging.

## Alignment with Product Vision

Delivers production Android app, completing the cross-platform vision (Linux CLI + Android mobile).

## Requirements

### Requirement 1: FRB Code Generation

**User Story:** As a developer, I want FRB to generate Dart bindings, so that Flutter can call Rust functions.

#### Acceptance Criteria

1. WHEN flutter_rust_bridge_codegen runs THEN it SHALL generate lib/src/bridge/api_generated.dart from rust/src/api.rs
2. WHEN api.rs changes THEN codegen SHALL detect changes and regenerate
3. WHEN generated THEN Dart code SHALL include all #[frb] annotated functions
4. WHEN generated THEN types SHALL map correctly (Vec → List, Result → Exception, etc.)

### Requirement 2: Rust Library Compilation

**User Story:** As a developer, I want Rust compiled for Android, so that the native library links with Flutter.

#### Acceptance Criteria

1. WHEN building for Android THEN Rust SHALL compile for arm64-v8a, armeabi-v7a, x86_64
2. WHEN compiled THEN libraries SHALL be placed in jniLibs/[arch]/libheart_beat.so
3. WHEN linking THEN Flutter SHALL find native libraries automatically
4. WHEN running THEN app SHALL load native code without errors

### Requirement 3: Android Configuration

**User Story:** As a developer, I want Android properly configured, so that BLE and permissions work.

#### Acceptance Criteria

1. WHEN AndroidManifest.xml is configured THEN it SHALL request BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION
2. WHEN targeting Android 12+ THEN runtime permissions SHALL be requested
3. WHEN min SDK is set THEN it SHALL be API 26 (Android 8.0)
4. WHEN Rust panic occurs THEN app SHALL catch and display error message

### Requirement 4: Build Scripts

**User Story:** As a developer, I want build scripts, so that I can build with one command.

#### Acceptance Criteria

1. WHEN `./build-android.sh` runs THEN it SHALL: run FRB codegen, compile Rust for all Android targets, build APK
2. WHEN build fails THEN script SHALL show clear error message
3. WHEN `--release` flag used THEN it SHALL build optimized binaries
4. WHEN completed THEN script SHALL show APK location and size

### Requirement 5: Development Workflow

**User Story:** As a developer, I want hot reload during development, so that I can iterate quickly.

#### Acceptance Criteria

1. WHEN flutter run runs THEN hot reload SHALL work for Dart code changes
2. WHEN Rust changes THEN developer SHALL run flutter clean && flutter run
3. WHEN debugging THEN Rust logs SHALL appear in flutter logs output
4. WHEN errors occur THEN stack traces SHALL show Rust and Dart frames

## Non-Functional Requirements

### Build Performance
- Clean build: < 3 minutes on modern hardware
- Incremental Rust rebuild: < 30 seconds
- FRB codegen: < 10 seconds

### Binary Size
- Release APK: < 20MB
- Rust library per arch: < 5MB
- Strip debug symbols in release

### Compatibility
- Min SDK: API 26 (Android 8.0, 2017)
- Target SDK: API 34 (Android 14, latest)
- NDK: r25c or later
