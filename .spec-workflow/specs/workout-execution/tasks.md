# Tasks Document

- [x] 1.1 Add SessionProgress type for UI updates
  - File: `rust/src/domain/session_progress.rs`
  - Define SessionProgress and PhaseProgress structs
  - Add ZoneStatus enum (InZone, TooLow, TooHigh)
  - Purpose: Streamable session state for Flutter
  - _Leverage: existing session state types_
  - _Requirements: 2, 3_
  - _Prompt: Role: Rust domain developer | Task: Create rust/src/domain/session_progress.rs with SessionProgress struct (state, current_phase, total_elapsed_secs, total_remaining_secs, zone_status, current_bpm). Add PhaseProgress (phase_index, phase_name, target_zone, elapsed_secs, remaining_secs). Add ZoneStatus enum. Derive Serialize. | Restrictions: FRB-compatible types | Success: Types compile with serde_

- [x] 1.2 Add progress emission to SessionExecutor
  - File: `rust/src/scheduler/executor.rs`
  - Add SessionProgress channel output
  - Emit progress on tick (1Hz)
  - Purpose: Stream session state to Flutter
  - _Leverage: existing tick loop in executor_
  - _Requirements: 2_
  - _Prompt: Role: Rust async developer | Task: Modify SessionExecutor to accept Sender<SessionProgress>. In tick loop, build SessionProgress from current state and emit. Include zone_status from ZoneTracker. Emit on every tick (1/second). | Restrictions: Don't break existing tick logic | Success: Progress emitted every second_

- [x] 2.1 Add session control API functions
  - File: `rust/src/api.rs`
  - Add start_workout(plan_name), pause_workout(), resume_workout(), stop_workout()
  - Add create_session_progress_stream()
  - Purpose: Flutter control of workouts
  - _Leverage: existing SessionExecutor methods_
  - _Requirements: 1, 4_
  - _Prompt: Role: Rust FFI developer | Task: Add pub async fn start_workout(plan_name: String) -> Result<()> that loads plan, creates SessionExecutor, starts session. Add pause_workout(), resume_workout(), stop_workout() delegating to executor. Add create_session_progress_stream() returning StreamSink. | Restrictions: Handle executor not initialized | Success: Flutter can control workouts_

- [x] 2.2 Create plan selection bottom sheet
  - File: `lib/src/widgets/plan_selector.dart`
  - List available plans from ~/.heart-beat/plans/
  - Allow selection and start
  - Purpose: Plan selection UI
  - _Leverage: existing plans directory, Material BottomSheet_
  - _Requirements: 1_
  - _Prompt: Role: Flutter developer | Task: Create PlanSelector widget as ModalBottomSheet. Call listPlans() API to get available plans. Display as ListView with plan name and duration. On tap, call onSelect callback with plan name. Add "No plans found" empty state. | Restrictions: Match Material 3 styling | Success: User can select plans_

- [x] 3.1 Create WorkoutScreen
  - File: `lib/src/screens/workout_screen.dart`
  - Display active workout with phase progress
  - Subscribe to SessionProgress stream
  - Show HR, zone, phase info
  - Purpose: Main workout execution UI
  - _Leverage: existing session_screen.dart patterns_
  - _Requirements: 2, 3_
  - _Prompt: Role: Flutter developer | Task: Create WorkoutScreen receiving plan_name parameter. Call startWorkout() on init. Subscribe to createSessionProgressStream(). Display: large HR, zone indicator, phase name, time remaining, progress bar. Update on stream events. | Restrictions: Landscape-friendly layout | Success: Workout progress displays in real-time_

- [x] 3.2 Create PhaseProgressWidget
  - File: `lib/src/widgets/phase_progress.dart`
  - Show current phase with progress bar
  - Display upcoming phases
  - Purpose: Phase visualization
  - _Leverage: LinearProgressIndicator, Material widgets_
  - _Requirements: 2_
  - _Prompt: Role: Flutter developer | Task: Create PhaseProgressWidget taking PhaseProgress. Display: phase name prominently, LinearProgressIndicator for phase completion, time remaining text, next phase preview. Use zone color for progress bar. | Restrictions: Clear at arm's length | Success: Phase progress intuitive_

- [x] 3.3 Create ZoneFeedbackWidget
  - File: `lib/src/widgets/zone_feedback.dart`
  - Display "Speed Up" or "Slow Down" overlay
  - Animate when zone deviation occurs
  - Purpose: Zone deviation feedback
  - _Leverage: AnimatedContainer, ZoneStatus_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Create ZoneFeedbackWidget taking ZoneStatus. When TooLow, show blue "SPEED UP" overlay with up arrow. When TooHigh, show red "SLOW DOWN" overlay with down arrow. Animate opacity for attention. InZone shows nothing. | Restrictions: High visibility, non-intrusive | Success: Zone feedback immediately visible_

- [x] 4.1 Add session controls
  - File: `lib/src/widgets/session_controls.dart`
  - Pause/Resume and Stop buttons
  - Confirmation dialog for stop
  - Purpose: User control during workout
  - _Leverage: IconButton, AlertDialog_
  - _Requirements: 4_
  - _Prompt: Role: Flutter developer | Task: Create SessionControls widget with Row of buttons: Pause/Resume toggle (calls pauseWorkout/resumeWorkout), Stop (shows confirmation AlertDialog, calls stopWorkout on confirm). Large touch targets (48dp minimum). | Restrictions: Glove-friendly sizing | Success: Controls work reliably_

- [x] 4.2 Add workout route and navigation
  - File: `lib/src/app.dart`
  - Add /workout/:planName route
  - Navigate from session screen
  - Purpose: Enable workout access
  - _Leverage: existing routing_
  - _Requirements: 1_
  - _Prompt: Role: Flutter developer | Task: Add '/workout/:planName' route to app.dart. Replace "Coming Soon" button in session_screen.dart with "Start Workout" that shows PlanSelector, then navigates to workout route. | Restrictions: Pass plan name as route parameter | Success: User can navigate to workout_

- [ ] 5.1 Test workout flow end-to-end
  - File: N/A (manual testing)
  - Test complete workout cycle on device
  - Verify phase transitions and zone feedback
  - Purpose: Validate workout execution
  - _Leverage: existing training plans_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: QA Engineer | Task: Build and install APK. Start workout with tempo_run plan. Verify: phases transition correctly, zone feedback appears when HR deviates, pause/resume works, stop saves session. Test with real HR monitor. | Restrictions: Test on real device | Success: Complete workout flow works_
