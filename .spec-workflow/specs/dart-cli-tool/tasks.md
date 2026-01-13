# Tasks: Dart CLI Tool

Dart CLI that exercises the same code paths as Flutter UI for rapid testing without device deployment.

- [x] 1. Create Dart CLI entry point
  - File: bin/dart_cli.dart
  - Set up CLI argument parsing with args package
  - Initialize Rust bridge in CLI mode
  - Purpose: Enable testing Flutter/Rust integration from command line
  - _Leverage: lib/src/bridge/api_generated.dart/api.dart, package:args_
  - _Requirements: Must initialize RustLib without Flutter UI_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Create CLI entry point that initializes Rust bridge and parses commands | Restrictions: Do not import Flutter UI packages, only use dart:io and bridge code | Success: `dart run bin/dart_cli.dart --help` shows available commands | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 2. Add scan command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart scan`
  - List discovered BLE devices
  - Purpose: Test BLE scanning from CLI
  - _Leverage: lib/src/bridge/api_generated.dart/api.dart scanDevices_
  - _Requirements: Match Rust CLI scan behavior_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add scan command that calls scanDevices and displays results | Restrictions: Format output similar to Rust CLI | Success: `dart run bin/dart_cli.dart scan` shows discovered devices | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 3. Add connect command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart connect <device_id>`
  - Connect to device and show HR stream
  - Purpose: Test device connection from CLI
  - _Leverage: connectDevice, createHrStream APIs_
  - _Requirements: Stream HR data to stdout_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add connect command that connects to device and streams HR data | Restrictions: Handle connection errors gracefully, support Ctrl+C to disconnect | Success: `dart run bin/dart_cli.dart connect <id>` streams HR values | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 4. Add list-plans command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart list-plans`
  - List available training plans
  - Purpose: Test plan listing from CLI
  - _Leverage: listPlans API_
  - _Requirements: Show plan names_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add list-plans command that displays available training plans | Restrictions: Format output clearly | Success: `dart run bin/dart_cli.dart list-plans` shows plans | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 5. Add start-workout command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart start-workout <plan_name>`
  - Start workout and show progress stream
  - Purpose: Test workout execution from CLI (same code path as UI!)
  - _Leverage: startWorkout, createSessionProgressStream APIs_
  - _Requirements: Display phase, time, zone status_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add start-workout command that starts workout and streams progress | Restrictions: Support pause/resume via keyboard input, format output clearly | Success: `dart run bin/dart_cli.dart start-workout "Easy Run"` runs workout | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 6. Add history command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart history`
  - List past workout sessions
  - Purpose: Test session history from CLI
  - _Leverage: listSessions API_
  - _Requirements: Show session summary_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add history command that lists past workout sessions | Restrictions: Format dates nicely, show key metrics | Success: `dart run bin/dart_cli.dart history` shows past sessions | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 7. Add profile command
  - File: bin/dart_cli.dart (extend)
  - Command: `dart run bin/dart_cli.dart profile [--age N] [--max-hr N]`
  - View and modify user profile
  - Purpose: Test profile management from CLI
  - _Leverage: Profile APIs_
  - _Requirements: Show current profile, allow updates_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart CLI Developer | Task: Add profile command for viewing and modifying user profile | Restrictions: Validate inputs, show current values | Success: `dart run bin/dart_cli.dart profile` shows profile | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 8. Create Dart CLI test script
  - File: scripts/test-dart-cli.sh
  - Run Dart CLI commands in sequence to verify functionality
  - Test: list-plans, profile, history
  - Purpose: Automated smoke test for Dart/Rust integration
  - _Leverage: bin/dart_cli.dart_
  - _Requirements: Fast feedback on bridge issues_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer | Task: Create test script that runs Dart CLI commands and verifies output | Restrictions: Don't require BLE device, test offline commands | Success: Script catches Dart/Rust bridge issues before device deploy | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_

- [ ] 9. Add to pubspec.yaml executables
  - File: pubspec.yaml (modify)
  - Register dart_cli as executable
  - Purpose: Enable `dart pub global activate` installation
  - _Leverage: pubspec.yaml executables section_
  - _Requirements: Executable named heart_beat_cli_
  - _Prompt: Implement the task for spec dart-cli-tool, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Dart Developer | Task: Add executables section to pubspec.yaml for dart_cli | Restrictions: Follow Dart package conventions | Success: `dart pub global activate --source path .` installs CLI | After implementation: 1) Mark task as [-] in-progress before starting, 2) Use log-implementation tool to record what was created, 3) Mark task as [x] complete_
