# Tasks: Flutter Golden Tests

Screenshot comparison tests for UI regression detection.

- [x] 1. Set up golden test infrastructure
  - File: test/golden/golden_test_helpers.dart
  - Configure golden file location and naming convention
  - Create test wrapper with consistent theming and sizing
  - Purpose: Establish consistent golden test environment
  - _Leverage: Flutter's matchesGoldenFile, lib/src/app.dart theme_
  - _Requirements: Reproducible screenshots across CI runs_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Engineer | Task: Set up golden test infrastructure with consistent sizing, theming, and file organization | Restrictions: Use Material 3 theme from app.dart, fix device pixel ratio for reproducibility | Success: Golden tests produce identical images across machines | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 2. Create HrDisplay golden tests
  - File: test/golden/hr_display_golden_test.dart
  - Golden: test/golden/goldens/hr_display_60bpm.png
  - Golden: test/golden/goldens/hr_display_150bpm.png
  - Golden: test/golden/goldens/hr_display_200bpm.png
  - Purpose: Catch visual regressions in HR display
  - _Leverage: lib/src/widgets/hr_display.dart, test/golden/golden_test_helpers.dart_
  - _Requirements: Test different BPM values_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Developer | Task: Create golden tests for HrDisplay widget at various BPM values (60, 150, 200) | Restrictions: Use consistent widget size, generate baseline goldens | Success: Golden files generated and tests pass | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 3. Create ZoneIndicator golden tests
  - File: test/golden/zone_indicator_golden_test.dart
  - Golden: test/golden/goldens/zone_indicator_zone1.png through zone5.png
  - Purpose: Catch visual regressions in zone display
  - _Leverage: lib/src/widgets/zone_indicator.dart_
  - _Requirements: All 5 zones captured_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Developer | Task: Create golden tests for ZoneIndicator widget for all 5 HR zones | Restrictions: Consistent sizing, verify zone colors are distinct | Success: 5 golden files generated, visual differences detectable | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 4. Create PhaseProgress golden tests
  - File: test/golden/phase_progress_golden_test.dart
  - Golden: test/golden/goldens/phase_progress_warmup.png
  - Golden: test/golden/goldens/phase_progress_active.png
  - Golden: test/golden/goldens/phase_progress_cooldown.png
  - Purpose: Catch visual regressions in workout phase display
  - _Leverage: lib/src/widgets/phase_progress.dart_
  - _Requirements: Different phase types captured_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Developer | Task: Create golden tests for PhaseProgressWidget showing different workout phases | Restrictions: Use representative phase data | Success: Phase visuals captured and verified | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 5. Create ConnectionBanner golden tests
  - File: test/golden/connection_banner_golden_test.dart
  - Golden: test/golden/goldens/connection_banner_reconnecting.png
  - Golden: test/golden/goldens/connection_banner_failed.png
  - Purpose: Catch visual regressions in connection status
  - _Leverage: lib/src/widgets/connection_banner.dart_
  - _Requirements: Reconnecting and failed states_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Developer | Task: Create golden tests for ConnectionBanner widget states | Restrictions: Mock connection status data | Success: Banner states visually captured | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [x] 6. Create full screen golden tests
  - File: test/golden/screens_golden_test.dart
  - Golden: test/golden/goldens/home_screen.png
  - Golden: test/golden/goldens/session_screen.png
  - Golden: test/golden/goldens/workout_screen.png
  - Purpose: Catch layout regressions in full screens
  - _Leverage: lib/src/screens/*.dart_
  - _Requirements: Mock all data dependencies_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter Golden Test Developer | Task: Create golden tests for full screen layouts (home, session, workout) | Restrictions: Mock all API calls and streams, use consistent screen size | Success: Full screen layouts captured for regression testing | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 7. Add golden test CI script
  - File: scripts/test-golden.sh
  - Create script to run golden tests
  - Support --update flag to regenerate goldens
  - Purpose: Enable automated visual regression testing
  - _Leverage: flutter test --update-goldens_
  - _Requirements: Clear pass/fail output, diff on failure_
  - _Prompt: Implement the task for spec flutter-golden-tests, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer | Task: Create test-golden.sh script for running golden tests with optional regeneration | Restrictions: Follow existing scripts/ conventions | Success: Script detects visual regressions and reports clearly | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_
