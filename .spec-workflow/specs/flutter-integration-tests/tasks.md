# Tasks: Flutter Integration Tests

Integration tests that run on device/emulator to test full app flows.

- [x] 1. Enhance integration test infrastructure
  - File: integration_test/test_helpers.dart
  - Create reusable test helpers for integration tests
  - Set up mock BLE device simulation
  - Purpose: Enable reliable integration testing on real devices
  - _Leverage: integration_test/app_test.dart (existing), lib/src/bridge/api_generated.dart/api.dart_
  - _Requirements: Tests must run on Android device/emulator_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Engineer | Task: Create integration test helpers including mock device simulation, app launch utilities, and common test patterns | Restrictions: Must work on real Android devices, use patrol or flutter_test driver | Success: Helper utilities enable reliable device testing | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 2. Create device connection flow test
  - File: integration_test/connection_flow_test.dart
  - Test: Launch app -> Scan devices -> Select device -> Verify connection
  - Test connection error handling
  - Purpose: Verify BLE connection flow works end-to-end
  - _Leverage: integration_test/test_helpers.dart, lib/src/screens/home_screen.dart_
  - _Requirements: Test with mock BLE or real device_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Developer | Task: Create integration test for full device connection flow from app launch to connected state | Restrictions: Handle both mock and real BLE scenarios, add proper timeouts | Success: Connection flow test passes on device | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 3. Create workout start flow test
  - File: integration_test/workout_flow_test.dart
  - Test: Session screen -> Start Workout -> Select Plan -> Workout screen
  - This tests the exact bug we just fixed!
  - Purpose: Regression test for workout navigation
  - _Leverage: lib/src/screens/session_screen.dart, lib/src/widgets/plan_selector.dart_
  - _Requirements: Verify navigation works correctly_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Developer | Task: Create integration test for workout start flow - specifically testing the PlanSelector navigation that was broken | Restrictions: Must verify actual navigation occurs, not just callback | Success: Test catches the navigation bug we fixed | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 4. Create workout execution flow test
  - File: integration_test/workout_execution_test.dart
  - Test: Start workout -> Verify HR display -> Pause -> Resume -> Stop
  - Test phase transitions during workout
  - Purpose: Verify workout execution works end-to-end
  - _Leverage: lib/src/screens/workout_screen.dart_
  - _Requirements: Test full workout lifecycle_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Developer | Task: Create integration test for workout execution including pause/resume/stop and phase transitions | Restrictions: Use mock HR data for predictable testing | Success: Full workout lifecycle tested | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 5. Create settings flow test
  - File: integration_test/settings_flow_test.dart
  - Test: Navigate to settings -> Modify profile -> Save -> Verify persistence
  - Purpose: Verify settings changes persist correctly
  - _Leverage: lib/src/screens/settings_screen.dart, lib/src/services/profile_service.dart_
  - _Requirements: Test profile persistence_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Developer | Task: Create integration test for settings modification and persistence | Restrictions: Clean up test data after test | Success: Settings changes persist across app restart | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 6. Create history flow test
  - File: integration_test/history_flow_test.dart
  - Test: Navigate to history -> View sessions -> Select session detail
  - Purpose: Verify session history navigation works
  - _Leverage: lib/src/screens/history_screen.dart, lib/src/screens/session_detail_screen.dart_
  - _Requirements: Test with seeded session data_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Integration Test Developer | Task: Create integration test for session history browsing and detail view | Restrictions: Seed test session data before test | Success: History navigation and detail view work correctly | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 7. Add integration test CI script
  - File: scripts/test-integration.sh
  - Create script to run integration tests on connected device
  - Support both real device and emulator
  - Purpose: Enable automated integration testing
  - _Leverage: scripts/adb-install.sh patterns_
  - _Requirements: Detect device, run tests, report results_
  - _Prompt: Implement the task for spec flutter-integration-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer | Task: Create test-integration.sh script that detects connected device and runs integration tests | Restrictions: Follow existing scripts/ conventions, handle no device case gracefully | Success: Script runs integration tests and reports pass/fail | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_
