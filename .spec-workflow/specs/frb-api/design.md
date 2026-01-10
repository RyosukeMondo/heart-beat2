# Design Document

## Architecture Overview

FRB API layer orchestrates Rust core components and exposes them to Flutter via type-safe FFI. Acts as thin coordination layer with no business logic.

```
Flutter (Dart)
     ↓ FFI
  api.rs (Orchestration)
     ↓
  ┌──────┼──────┐
  ↓      ↓      ↓
domain  state  adapters
```

## Data Models

### Exposed Types
- `DiscoveredDevice` - from domain/heart_rate.rs
- `FilteredHeartRate` - from domain/heart_rate.rs
- `TrainingPlan` - from domain/training_plan.rs (future)

All types derive Serialize for FRB auto-conversion.

## API Surface

### Async Functions
```rust
#[frb]
pub async fn scan_devices() -> Result<Vec<DiscoveredDevice>>

#[frb]
pub async fn connect_device(device_id: String) -> Result<()>

#[frb]
pub async fn disconnect() -> Result<()>

#[frb]
pub async fn start_mock_mode() -> Result<()>
```

### Streaming API
```rust
#[frb]
pub fn create_hr_stream() -> StreamSink<FilteredHeartRate>
```

Uses tokio::sync::broadcast for fan-out to multiple StreamSink consumers.

## Component Integration

### BLE Operations
- Instantiate BtleplugAdapter on-demand
- Drive connectivity state machine
- Handle adapter errors and convert to Dart exceptions

### State Management
- Maintain single ConnectivityState instance
- Coordinate between BLE events and state transitions
- Expose state queries to Flutter

### HR Streaming
- Subscribe to filter output channel
- Emit to all active StreamSink instances
- Handle backpressure with bounded buffer (100 items)

## Error Handling

All errors use anyhow::Result, converted by FRB to Flutter exceptions with messages.

### Error Categories
- `BleScanFailed` - adapter initialization or scan timeout
- `ConnectionFailed` - connection timeout or device not found
- `NotConnected` - operation requires active connection
- `InternalError` - unexpected state or logic error

## Testing Strategy

### Unit Tests
- Mock BleAdapter for API function tests
- Verify state transitions triggered correctly
- Test error propagation

### Integration Tests
- Use mock adapter with simulated devices
- Verify full scan → connect → stream flow
- Test StreamSink fan-out with multiple subscribers

### CLI Verification
- CLI uses same api.rs functions
- Manual testing: `cli scan`, `cli connect <id>`, `cli mock`
