# Tasks Document

- [x] 1.1 Create notification.rs with trait definition
  - File: `rust/src/ports/notification.rs`
  - Define NotificationPort trait with async fn notify(event: NotificationEvent)
  - Add async_trait annotation
  - Purpose: Establish notification interface
  - _Leverage: ports/ble_adapter.rs as reference_
  - _Requirements: 1_
  - _Prompt: Role: Rust trait design expert | Task: Create notification.rs with #[async_trait] pub trait NotificationPort. Add async fn notify(&self, event: NotificationEvent) -> Result<()>. Use anyhow for errors. Add doc comments explaining purpose and usage | Restrictions: Trait only, no implementations | Success: Compiles, trait is async-compatible_

- [x] 1.2 Define NotificationEvent enum
  - File: `rust/src/ports/notification.rs`
  - Create NotificationEvent enum with variants for each event type
  - Add serde derives for potential logging
  - Purpose: Enumerate all notification types
  - _Leverage: state/session.rs ZoneDeviation_
  - _Requirements: 2_
  - _Prompt: Role: Rust enum expert | Task: Create NotificationEvent enum: ZoneDeviation { deviation: ZoneDeviation, current_bpm: u16, target_zone: Zone }, PhaseTransition { from_phase: usize, to_phase: usize, phase_name: String }, BatteryLow { percentage: u8 }, ConnectionLost. Derive Debug, Clone, Serialize | Restrictions: Must be self-contained, no external state | Success: Enum covers all event types from requirements_

- [x] 1.3 Create MockNotificationAdapter
  - File: `rust/src/adapters/mock_notification_adapter.rs`
  - Implement NotificationPort trait storing events in Vec
  - Add query methods: get_events(), clear_events()
  - Purpose: Enable testing without UI
  - _Leverage: adapters/mock_adapter.rs pattern_
  - _Requirements: 3_
  - _Prompt: Role: Rust testing specialist | Task: Create MockNotificationAdapter struct with events: Arc<Mutex<Vec<NotificationEvent>>>. Implement NotificationPort by pushing events to vec. Add get_events(&self) -> Vec<NotificationEvent> cloning vec. Add clear_events(&self) | Restrictions: Must be thread-safe (Arc<Mutex>) | Success: Tests can assert on recorded notifications_

- [x] 1.4 Create CliNotificationAdapter
  - File: `rust/src/adapters/cli_notification_adapter.rs`
  - Implement NotificationPort printing to stdout with colors
  - Use colored crate for terminal output
  - Purpose: CLI biofeedback via terminal
  - _Leverage: tracing for structured logging_
  - _Requirements: 1, 2_
  - _Prompt: Role: Rust CLI developer | Task: Create CliNotificationAdapter implementing NotificationPort. On ZoneDeviation print colored message (red for TooHigh, blue for TooLow). On PhaseTransition print "Entering [phase]". On BatteryLow print yellow warning. On ConnectionLost print red alert. Use colored crate for ANSI colors | Restrictions: Must not block, use async println or tracing::info | Success: CLI shows colored notifications_

- [x] 1.5 Export notification in ports/mod.rs and adapters
  - File: `rust/src/ports/mod.rs`, `rust/src/adapters/mod.rs`
  - Add pub mod notification; and re-exports
  - Export MockNotificationAdapter and CliNotificationAdapter
  - Purpose: Make notification infrastructure accessible
  - _Leverage: existing mod.rs patterns_
  - _Requirements: All_
  - _Prompt: Role: Rust module expert | Task: In ports/mod.rs add pub mod notification; and pub use notification::*. In adapters/mod.rs add pub mod mock_notification_adapter; pub mod cli_notification_adapter; with re-exports. Verify module structure | Restrictions: Follow existing patterns | Success: All notification types importable_
