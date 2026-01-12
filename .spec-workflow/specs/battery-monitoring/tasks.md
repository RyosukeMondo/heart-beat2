# Tasks Document

- [x] 1.1 Create BatteryLevel domain type
  - File: `rust/src/domain/battery.rs`
  - Define BatteryLevel struct with level, is_charging, timestamp
  - Add is_low() method with 15% threshold
  - Purpose: Domain type for battery state
  - _Leverage: existing domain types pattern in heart_rate.rs_
  - _Requirements: 1, 2_
  - _Prompt: Role: Rust domain developer | Task: Create rust/src/domain/battery.rs with BatteryLevel struct. Fields: level (Option<u8>), is_charging (bool), timestamp (SystemTime). Add is_low() returning true if level < 15. Derive Debug, Clone, Serialize. | Restrictions: Pure domain type, no I/O dependencies | Success: Type compiles, is_low() works correctly_

- [x] 1.2 Add battery module to domain mod.rs
  - File: `rust/src/domain/mod.rs`
  - Export battery module
  - Purpose: Make BatteryLevel available
  - _Leverage: existing mod.rs exports_
  - _Requirements: 1_
  - _Prompt: Role: Rust developer | Task: Add pub mod battery; to rust/src/domain/mod.rs. Re-export BatteryLevel for convenience. | Restrictions: Follow existing export pattern | Success: crate::domain::BatteryLevel accessible_

- [x] 2.1 Add battery read method to BtleplugAdapter
  - File: `rust/src/adapters/btleplug_adapter.rs`
  - Implement read_battery_level() async method
  - Read from Battery Service UUID 0x180F, characteristic 0x2A19
  - Purpose: Read battery from connected device
  - _Leverage: existing characteristic read pattern in subscribe_heart_rate_
  - _Requirements: 1_
  - _Prompt: Role: Rust BLE developer | Task: Add async fn read_battery_level(&self) -> Result<Option<u8>> to BtleplugAdapter. Find Battery Service (0x180F), read Battery Level characteristic (0x2A19). Parse single byte as percentage. Return None if service not found. | Restrictions: Do not block HR streaming, handle missing service gracefully | Success: Returns battery percentage when available_

- [x] 2.2 Add battery polling loop to BtleplugAdapter
  - File: `rust/src/adapters/btleplug_adapter.rs`
  - Implement start_battery_polling() with 60s interval
  - Emit BatteryLevel via channel
  - Check threshold and emit BatteryLow notification
  - Purpose: Periodic battery monitoring
  - _Leverage: tokio::time::interval pattern_
  - _Requirements: 1, 2_
  - _Prompt: Role: Rust async developer | Task: Add start_battery_polling(tx: Sender<BatteryLevel>, notification_port: Arc<dyn NotificationPort>) method. Use tokio::interval(Duration::from_secs(60)). On each tick call read_battery_level(), emit to tx, check is_low() and emit NotificationEvent::BatteryLow if true. | Restrictions: Must be cancellable, don't spam notifications | Success: Battery level emitted every 60s, low battery triggers notification once_

- [ ] 3.1 Add battery stream to api.rs
  - File: `rust/src/api.rs`
  - Add create_battery_stream() function
  - Wire to battery polling in connect flow
  - Purpose: Expose battery to Flutter
  - _Leverage: existing create_hr_stream() pattern_
  - _Requirements: 1, 3_
  - _Prompt: Role: Rust FFI developer | Task: Add pub async fn create_battery_stream() -> StreamSink<BatteryLevel> to api.rs. Create broadcast channel, start polling when device connected. Follow create_hr_stream() pattern exactly. | Restrictions: Must work with FRB codegen | Success: Flutter can subscribe to battery updates_

- [ ] 3.2 Update Flutter session_screen.dart battery display
  - File: `lib/src/screens/session_screen.dart`
  - Subscribe to battery stream from Rust
  - Pass battery level to BatteryIndicator widget
  - Purpose: Display real battery level
  - _Leverage: existing HR stream subscription pattern_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Update session_screen.dart to call createBatteryStream() after connection. Use StreamBuilder to receive BatteryLevel updates. Pass level to existing BatteryIndicator widget. Handle null case with "?" display. | Restrictions: Don't break existing HR streaming | Success: Battery indicator shows real percentage_

- [ ] 4.1 Add battery unit tests
  - File: `rust/src/domain/battery.rs` (tests module)
  - Test BatteryLevel::is_low() at boundary values
  - Test serialization
  - Purpose: Validate battery logic
  - _Leverage: existing domain test patterns_
  - _Requirements: 2_
  - _Prompt: Role: Rust test developer | Task: Add #[cfg(test)] mod tests to battery.rs. Test is_low() returns true at 14%, false at 15%, false at 16%. Test None level handling. Test serialization round-trip. | Restrictions: No external dependencies in tests | Success: cargo test battery passes_

- [ ] 4.2 Test battery monitoring on device
  - File: N/A (manual testing)
  - Build and install APK on Pixel 9a
  - Connect to Coospo HW9
  - Verify battery level displays correctly
  - Purpose: Validate end-to-end battery monitoring
  - _Leverage: adb-install.sh script_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: QA Engineer | Task: Rebuild APK with adb-install.sh. Connect to Coospo HW9. Verify: battery indicator shows percentage (not ?), level updates periodically, adb logcat shows battery read logs. | Restrictions: Test on real device | Success: Battery level displays and updates_
