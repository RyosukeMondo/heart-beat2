# Tasks: Flutter Widget Tests

Fast unit tests for Flutter widgets - no device/emulator required.

- [x] 1. Set up widget test infrastructure
  - File: test/widget_test.dart, test/helpers/test_helpers.dart
  - Create test helpers for common widget testing patterns
  - Set up mock providers and test wrappers
  - Purpose: Establish foundation for fast, isolated widget testing
  - _Leverage: lib/src/bridge/api_generated.dart/api.dart, existing widget structure_
  - _Requirements: Enable `flutter test` to run without device_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Test Engineer specializing in widget testing | Task: Create widget test infrastructure with mock providers, test wrappers, and helper utilities that allow testing widgets in isolation without requiring Rust FFI or device | Restrictions: Do not test actual BLE functionality, mock all Rust bridge calls, keep tests fast (<100ms each) | Success: `flutter test test/` runs successfully without device, test helpers are reusable | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 2. Create HrDisplay widget tests
  - File: test/widgets/hr_display_test.dart
  - Test BPM rendering at various values (0, 60, 120, 200, 255)
  - Test color/styling changes based on heart rate zones
  - Purpose: Verify heart rate display widget renders correctly
  - _Leverage: lib/src/widgets/hr_display.dart, test/helpers/test_helpers.dart_
  - _Requirements: Cover edge cases, zone boundaries_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Widget Test Developer | Task: Create comprehensive tests for HrDisplay widget covering BPM values 0-255, zone color changes, and edge cases | Restrictions: Use mock data only, do not depend on actual HR stream | Success: All BPM display scenarios tested, zone colors verified | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 3. Create ZoneIndicator widget tests
  - File: test/widgets/zone_indicator_test.dart
  - Test all 5 HR zones render correctly
  - Test zone transitions and visual feedback
  - Purpose: Verify zone indicator displays correct zone information
  - _Leverage: lib/src/widgets/zone_indicator.dart, lib/src/bridge/api_generated.dart/domain/heart_rate.dart_
  - _Requirements: All zones covered, proper labeling_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Widget Test Developer | Task: Test ZoneIndicator widget for all 5 HR zones (Zone1-Zone5), verify correct colors, labels, and transitions | Restrictions: Mock zone data, test visual output only | Success: All 5 zones tested with correct colors and labels | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 4. Create PlanSelector widget tests
  - File: test/widgets/plan_selector_test.dart
  - Test plan list rendering
  - Test plan selection callback firing
  - Test empty state and error state
  - Purpose: Verify plan selector works correctly (the bug we just fixed!)
  - _Leverage: lib/src/widgets/plan_selector.dart_
  - _Requirements: Test onSelect callback, navigation_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Widget Test Developer | Task: Test PlanSelector widget including plan list display, tap callbacks, empty state, and error state | Restrictions: Mock listPlans API, verify callback is invoked with correct plan name | Success: Plan selection triggers callback correctly, all states render properly | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 5. Create SessionControls widget tests
  - File: test/widgets/session_controls_test.dart
  - Test pause/resume/stop button states
  - Test callback invocations
  - Purpose: Verify workout control buttons work correctly
  - _Leverage: lib/src/widgets/session_controls.dart_
  - _Requirements: Test all button states and callbacks_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Widget Test Developer | Task: Test SessionControls widget for pause/resume/stop buttons, verify correct visibility based on state, test callback invocations | Restrictions: Mock workout state, test UI behavior only | Success: All button states tested, callbacks verified | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 6. Create ConnectionBanner widget tests
  - File: test/widgets/connection_banner_test.dart
  - Test reconnecting state display
  - Test disconnected state display
  - Test connected state (hidden)
  - Purpose: Verify connection status banner shows correct states
  - _Leverage: lib/src/widgets/connection_banner.dart_
  - _Requirements: All connection states covered_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Widget Test Developer | Task: Test ConnectionBanner widget for reconnecting, disconnected, and connected states | Restrictions: Mock connection status stream | Success: All connection states display correctly | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 7. Add widget test CI script
  - File: scripts/test-widgets.sh
  - Create script to run widget tests with coverage
  - Add to CI pipeline documentation
  - Purpose: Enable automated widget testing in CI
  - _Leverage: Existing scripts/ patterns_
  - _Requirements: Exit code 0 on success, non-zero on failure_
  - _Prompt: Implement the task for spec flutter-widget-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer | Task: Create test-widgets.sh script that runs flutter test with coverage reporting | Restrictions: Follow existing scripts/ conventions, output coverage report | Success: Script runs tests and reports coverage percentage | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_
