# Tasks Document

- [x] 1.1 Create CompletedSession domain types
  - File: `rust/src/domain/session_history.rs`
  - Define CompletedSession, SessionSummary, HrSample, PhaseResult
  - Add SessionStatus enum (Completed, Interrupted, Stopped)
  - Purpose: Domain types for session persistence
  - _Leverage: existing domain types, TrainingPlan types_
  - _Requirements: 1_
  - _Prompt: Role: Rust domain developer | Task: Create rust/src/domain/session_history.rs with CompletedSession struct (id, plan_name, start_time, end_time, status, hr_samples, phases_completed, summary). Add SessionSummary (duration_secs, avg_hr, max_hr, min_hr, time_in_zone). Add HrSample (timestamp, bpm). Derive Serialize, Deserialize. | Restrictions: Pure domain, no I/O | Success: Types compile with serde derives_

- [x] 1.2 Add SessionRepository port trait
  - File: `rust/src/ports/session_repository.rs`
  - Define async trait with CRUD methods
  - Purpose: Abstract session storage interface
  - _Leverage: existing port trait patterns (BleAdapter, NotificationPort)_
  - _Requirements: 1, 2, 4_
  - _Prompt: Role: Rust interface designer | Task: Create rust/src/ports/session_repository.rs with SessionRepository trait. Methods: async fn save(&self, session: &CompletedSession) -> Result<()>, async fn list(&self) -> Result<Vec<SessionSummaryPreview>>, async fn get(&self, id: &str) -> Result<Option<CompletedSession>>, async fn delete(&self, id: &str) -> Result<()>. | Restrictions: Async trait, use anyhow::Result | Success: Trait compiles, can be mocked_

- [x] 2.1 Implement FileSessionRepository adapter
  - File: `rust/src/adapters/file_session_repository.rs`
  - Implement SessionRepository using JSON files
  - Store in ~/.heart-beat/sessions/
  - Purpose: Concrete file-based storage
  - _Leverage: serde_json, std::fs patterns_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: Rust file I/O developer | Task: Create FileSessionRepository implementing SessionRepository. Use dirs::home_dir() + ".heart-beat/sessions/". Save as {date}_{plan}_{id}.json. List by reading directory, parse summary from filename and first few fields (lazy). | Restrictions: Create directory if missing, handle permissions | Success: Can save and list sessions_

- [x] 2.2 Add session recording to SessionExecutor
  - File: `rust/src/scheduler/executor.rs`
  - Inject SessionRepository into executor
  - Save session on complete/stop/interrupt
  - Collect HR samples during session
  - Purpose: Automatic session recording
  - _Leverage: existing SessionExecutor structure_
  - _Requirements: 1_
  - _Prompt: Role: Rust integration developer | Task: Modify SessionExecutor to accept Arc<dyn SessionRepository>. Collect HrSamples in Vec during session. On session_completed/stopped/interrupted, build CompletedSession with summary calculation, call repository.save(). | Restrictions: Don't break existing session flow | Success: Sessions saved automatically on completion_

- [x] 3.1 Add session history API to api.rs
  - File: `rust/src/api.rs`
  - Add list_sessions(), get_session(id), delete_session(id)
  - Initialize FileSessionRepository
  - Purpose: Expose session history to Flutter
  - _Leverage: existing api.rs patterns_
  - _Requirements: 2, 3, 4_
  - _Prompt: Role: Rust FFI developer | Task: Add pub async fn list_sessions() -> Vec<SessionSummaryPreview>, pub async fn get_session(id: String) -> Option<CompletedSession>, pub async fn delete_session(id: String) -> Result<()>. Create static FileSessionRepository instance. | Restrictions: FRB-compatible types | Success: Flutter can call session APIs_

- [x] 3.2 Create Flutter HistoryScreen
  - File: `lib/src/screens/history_screen.dart`
  - Display list of sessions with date, duration, avg HR
  - Tap to navigate to detail
  - Swipe to delete with confirmation
  - Purpose: Session list UI
  - _Leverage: existing screen patterns, Material 3_
  - _Requirements: 2, 4_
  - _Prompt: Role: Flutter developer | Task: Create HistoryScreen StatefulWidget. Call listSessions() on init. Use ListView.builder with Card per session showing date, plan name, duration, avg HR. Add Dismissible for swipe-to-delete with confirmation AlertDialog. Navigate to SessionDetailScreen on tap. | Restrictions: Handle empty state, loading state | Success: Sessions list displays correctly_

- [x] 3.3 Create Flutter SessionDetailScreen
  - File: `lib/src/screens/session_detail_screen.dart`
  - Show full session details
  - Display HR chart using fl_chart
  - Show phase-by-phase breakdown
  - Purpose: Session detail UI
  - _Leverage: fl_chart package_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Create SessionDetailScreen taking session id. Call getSession(id). Display: header with date/duration, summary card with min/max/avg HR, LineChart of HR over time using fl_chart, ListView of phases with duration and avg HR per phase. | Restrictions: Handle loading state, missing session | Success: Detail screen shows comprehensive data_

- [x] 4.1 Add history navigation to app
  - File: `lib/src/app.dart`
  - Add /history route
  - Add history button to home screen
  - Purpose: Make history accessible
  - _Leverage: existing routing setup_
  - _Requirements: 2_
  - _Prompt: Role: Flutter developer | Task: Add '/history' route to app.dart pointing to HistoryScreen. Add IconButton to HomeScreen AppBar navigating to history. | Restrictions: Consistent navigation pattern | Success: User can access history from home_

- [ ] 4.2 Add session history tests
  - File: `rust/tests/session_history_test.rs`
  - Test save/list/get/delete cycle
  - Test summary calculation
  - Purpose: Validate storage logic
  - _Leverage: tempdir for isolated testing_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: Rust test developer | Task: Create integration test using tempdir. Create FileSessionRepository with temp path. Test: save session, list shows it, get returns it, delete removes it. Test summary stats calculation (avg/min/max HR). | Restrictions: Clean up temp files | Success: All session history tests pass_
