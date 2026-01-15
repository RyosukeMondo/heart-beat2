# Tasks Document

- [x] 1.1 Create api.rs skeleton with FRB annotations
  - File: `rust/src/api.rs`
  - Add FRB codegen comments and module structure
  - Export DiscoveredDevice and FilteredHeartRate types
  - Purpose: Establish FRB API foundation
  - _Leverage: domain/heart_rate.rs types_
  - _Requirements: 1_
  - _Prompt: Role: Rust FFI specialist | Task: Create api.rs with flutter_rust_bridge annotations. Add pub use crate::domain::heart_rate::{DiscoveredDevice, FilteredHeartRate}. Add stub functions scan_devices(), connect_device(device_id: String), disconnect() returning Result<()>. Add #[frb] attributes | Restrictions: No implementation yet, just signatures | Success: cargo build succeeds, FRB codegen runs_

- [x] 1.2 Implement scan_devices with BleAdapter
  - File: `rust/src/api.rs`
  - Create scan_devices() -> Result<Vec<DiscoveredDevice>>
  - Instantiate btleplug adapter, call scan with 10s timeout
  - Purpose: Expose BLE scanning to Flutter
  - _Leverage: ports/ble_adapter.rs, adapters/btleplug_adapter.rs_
  - _Requirements: 1_
  - _Prompt: Role: Rust async developer | Task: Implement scan_devices using BtleplugAdapter. Call adapter.scan(Duration::from_secs(10)).await, map results to Vec<DiscoveredDevice>. Use anyhow for error handling | Restrictions: Must be async, handle adapter creation failure | Success: Returns devices when BLE available, Err on failure_

- [x] 1.3 Implement connect_device with state machine
  - File: `rust/src/api.rs`
  - Create connect_device(device_id: String) -> Result<()>
  - Transition connectivity state machine from Idle to Connecting
  - Purpose: Connect to selected device
  - _Leverage: state/connectivity.rs, adapters/btleplug_adapter.rs_
  - _Requirements: 1, 3_
  - _Prompt: Role: Rust state machine expert | Task: Implement connect_device that creates BtleplugAdapter, sends Connect event to connectivity state machine, awaits Connected state or timeout. Return Ok if connected, Err with message if failed | Restrictions: Must respect state machine transitions, max 15s timeout | Success: Connects successfully, returns Err on timeout_

- [x] 1.4 Create StreamSink for HR data
  - File: `rust/src/api.rs`
  - Implement get_hr_stream_receiver() for broadcast subscription
  - Implement emit_hr_data() for pipeline integration
  - Purpose: Stream HR data to Flutter reactively
  - _Leverage: domain/filters.rs, tokio::sync::broadcast_
  - _Requirements: 2_
  - _Prompt: Role: Rust async streaming expert | Task: Create HR data streaming using OnceLock for thread-safe global state, broadcast channel with 100-item buffer, support multiple subscribers with fan-out, handle backpressure by allowing lagging | Restrictions: Must be thread-safe, handle subscriber lag gracefully | Success: HR data streams to multiple subscribers, no data loss under normal load_

- [x] 1.5 Re-export API in lib.rs
  - File: `rust/src/lib.rs`
  - Add pub mod api; pub use api::*;
  - Verify FRB codegen sees exported items
  - Purpose: Make API visible to Flutter
  - _Leverage: existing lib.rs structure_
  - _Requirements: 1_
  - _Prompt: Role: Rust module organization expert | Task: Add pub mod api and pub use api::* to lib.rs, verify FRB codegen sees exported items | Restrictions: Don't break existing module structure | Success: FRB codegen runs successfully, API functions visible to Flutter_
