# Tasks Document

- [x] 1.1 Create DebugConsole widget
  - File: `lib/src/widgets/debug_console.dart`
  - Implement log display with StreamBuilder
  - Add level and search filtering
  - Style with Material Design 3
  - Purpose: Core debug console UI
  - _Leverage: LogService.stream, Material widgets_
  - _Requirements: 1, 2_
  - _Prompt: Implement the task for spec debug-console, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI developer | Task: Create DebugConsole widget that displays logs from LogService.stream. Include: level filter dropdown (debug/info/warn/error), search TextField, ListView.builder for logs with colored level badges, auto-scroll to bottom on new logs. Limit to 200 displayed logs. | Restrictions: Use Material 3 components, no external packages | Success: Widget displays logs with working filters | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.2 Create DebugConsoleOverlay wrapper
  - File: `lib/src/widgets/debug_console_overlay.dart`
  - Implement triple-tap gesture detection
  - Manage Overlay for floating console
  - Hide in release mode
  - Purpose: Toggle console visibility
  - _Leverage: GestureDetector, Overlay, kDebugMode_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec debug-console, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer | Task: Create DebugConsoleOverlay StatefulWidget that wraps child and detects triple-tap anywhere. On triple-tap, show/hide DebugConsole as Overlay. Use kDebugMode to disable in release builds. Position overlay at bottom half of screen with drag handle. | Restrictions: Must not interfere with child widget interactions | Success: Triple-tap toggles console, release builds have no console | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.3 Integrate overlay in app.dart
  - File: `lib/src/app.dart`
  - Wrap MaterialApp.router with DebugConsoleOverlay
  - Purpose: Enable console toggle throughout app
  - _Leverage: existing app.dart structure_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec debug-console, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer | Task: Update app.dart to wrap the MaterialApp.router with DebugConsoleOverlay widget. Ensure the overlay covers all routes and screens. | Restrictions: Minimal changes to existing structure | Success: Triple-tap works on any screen | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.4 Test debug console functionality
  - File: N/A (manual testing)
  - Test on Linux desktop and Android
  - Verify filtering and auto-scroll
  - Purpose: Validate console works correctly
  - _Leverage: flutter run commands_
  - _Requirements: 1, 2, 3_
  - _Prompt: Implement the task for spec debug-console, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Test debug console on both Linux desktop (flutter run -d linux) and Android device. Verify: triple-tap shows/hides console, logs appear in real-time, level filter works, search filter works, auto-scroll works, console doesn't appear in release build. | Restrictions: Test both platforms | Success: All features work on both platforms | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_
