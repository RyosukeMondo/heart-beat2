# Requirements Document

## Introduction

Flutter mobile application providing UI for heart rate monitoring and training session execution. Consumes Rust core via FRB, handles Android permissions, and provides reactive UI with StreamBuilder.

## Alignment with Product Vision

Delivers production mobile experience for Android, completing the CLI-to-mobile progression. Implements "Real-time Heart Rate Streaming" and "Planned Training Execution" features with mobile-optimized UI.

## Requirements

### Requirement 1: Project Setup

**User Story:** As a developer, I want Flutter project configured correctly, so that FRB bindings and dependencies work.

#### Acceptance Criteria

1. WHEN pubspec.yaml is created THEN it SHALL include flutter_rust_bridge, flutter_background_service, permission_handler
2. WHEN flutter pub get runs THEN all dependencies SHALL resolve
3. WHEN FRB codegen runs THEN bridge/api_generated.dart SHALL be created
4. WHEN app builds THEN Rust library SHALL link correctly

### Requirement 2: Home Screen

**User Story:** As a user, I want a home screen showing device status and scan button, so that I can connect to my HR monitor.

#### Acceptance Criteria

1. WHEN app launches THEN HomeScreen SHALL display "Scan for Devices" button
2. WHEN scan button pressed THEN app SHALL request Bluetooth permissions
3. IF permission granted THEN app SHALL call api.scan_devices() and show results
4. WHEN device in list tapped THEN app SHALL navigate to SessionScreen with device_id

### Requirement 3: Session Screen

**User Story:** As a user, I want a session screen showing live HR data, so that I can monitor my workout.

#### Acceptance Criteria

1. WHEN SessionScreen loads THEN it SHALL call api.connect_device(device_id)
2. WHEN connected THEN it SHALL create StreamBuilder listening to api.create_hr_stream()
3. WHEN HR data arrives THEN it SHALL display filtered_bpm in large text, current zone as colored indicator
4. WHEN user taps "Start Workout" THEN it SHALL load TrainingPlan and begin session
5. WHEN session active THEN it SHALL show phase name, elapsed time, and time remaining

### Requirement 4: Settings Screen

**User Story:** As a user, I want to configure my max HR, so that zones are personalized.

#### Acceptance Criteria

1. WHEN SettingsScreen loads THEN it SHALL display TextField for max_hr (default 180)
2. WHEN user saves THEN it SHALL persist to SharedPreferences
3. WHEN zone calculation occurs THEN it SHALL use saved max_hr value

### Requirement 5: Background Service

**User Story:** As a user, I want the app to continue streaming HR during workouts, so that I can lock my screen.

#### Acceptance Criteria

1. WHEN session starts THEN app SHALL start Android Foreground Service
2. WHEN service active THEN it SHALL display persistent notification with current BPM
3. WHEN user taps notification THEN it SHALL return to SessionScreen
4. WHEN session ends THEN service SHALL stop

## Non-Functional Requirements

### Code Architecture
- Screens in lib/src/screens/
- Widgets in lib/src/widgets/
- Services in lib/src/services/
- FRB bridge in lib/src/bridge/ (generated)

### Performance
- App launch to ready: < 3 seconds
- UI update latency: < 100ms from Rust emit to widget rebuild

### Usability
- Material Design 3
- Support Android 8.0+ (API 26)
- Handle permission denials gracefully
