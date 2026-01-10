# Requirements Document

## Introduction

This specification defines the core heart rate telemetry feature for the Heart-Beat2 application. The feature enables real-time heart rate monitoring from the Coospo HW9 optical heart rate monitor via BLE, with signal processing, state management, and a CLI-first development approach for rapid iteration.

## Alignment with Product Vision

This feature directly implements the core product purpose: a deterministic healthcare telemetry system for planned heart rate training. It addresses:
- **Real-time Heart Rate Streaming**: Continuous BLE connection with Kalman-filtered signal processing
- **Determinism First**: Rust core logic with compile-time safety guarantees
- **Linux-First Development**: CLI debugging enabling 5-second iteration cycles

## Requirements

### Requirement 1: BLE Device Discovery

**User Story:** As a user, I want to scan for nearby Coospo HW9 devices, so that I can select and connect to my heart rate monitor.

#### Acceptance Criteria

1. WHEN the user initiates a scan THEN the system SHALL discover all BLE devices advertising Heart Rate Service (UUID 0x180D) within range
2. WHEN a device is discovered THEN the system SHALL display device name and signal strength (RSSI)
3. IF no devices are found within 10 seconds THEN the system SHALL notify the user with a timeout message
4. WHEN scanning is active THEN the system SHALL allow the user to cancel the scan

### Requirement 2: BLE Connection Management

**User Story:** As a user, I want to connect to my Coospo HW9 device, so that I can receive heart rate data.

#### Acceptance Criteria

1. WHEN the user selects a device THEN the system SHALL establish a BLE connection within 5 seconds
2. IF connection fails THEN the system SHALL retry up to 3 times with exponential backoff
3. WHEN connected THEN the system SHALL discover Heart Rate Service (0x180D) and Battery Service (0x180F)
4. WHEN connection is lost unexpectedly THEN the system SHALL automatically attempt reconnection
5. WHEN the user requests disconnect THEN the system SHALL cleanly terminate the BLE connection

### Requirement 3: Heart Rate Data Streaming

**User Story:** As a user, I want to receive continuous heart rate measurements, so that I can monitor my current BPM in real-time.

#### Acceptance Criteria

1. WHEN connected THEN the system SHALL subscribe to Heart Rate Measurement characteristic (UUID 0x2A37)
2. WHEN a notification is received THEN the system SHALL parse the BLE packet according to Bluetooth SIG Heart Rate Profile
3. IF the packet contains RR-intervals THEN the system SHALL extract and store them for HRV calculation
4. WHEN BPM data is parsed THEN the system SHALL apply Kalman filtering before display
5. WHEN filtered data is available THEN the system SHALL emit it via StreamSink to subscribers within 100ms

### Requirement 4: Signal Processing

**User Story:** As a user, I want accurate heart rate readings even during movement, so that I can trust the data during exercise.

#### Acceptance Criteria

1. WHEN raw BPM data is received THEN the system SHALL apply a 1D Kalman filter to reduce noise
2. IF BPM value is physiologically impossible (< 30 or > 220) THEN the system SHALL reject the sample
3. WHEN RR-intervals are available THEN the system SHALL calculate RMSSD for HRV indication
4. WHEN Kalman filter is applied THEN the filtered value SHALL track true heart rate within ±5 BPM

### Requirement 5: Battery Monitoring

**User Story:** As a user, I want to know my device's battery level, so that I can avoid mid-session power loss.

#### Acceptance Criteria

1. WHEN connected THEN the system SHALL read Battery Level characteristic (UUID 0x2A19)
2. WHEN battery level changes THEN the system SHALL update the displayed value
3. IF battery level drops below 15% THEN the system SHALL display a warning notification

### Requirement 6: Connection State Machine

**User Story:** As a developer, I want a well-defined state machine for connection management, so that edge cases are handled correctly.

#### Acceptance Criteria

1. WHEN the system starts THEN it SHALL be in Idle state
2. WHEN scanning starts THEN the system SHALL transition to Scanning state
3. WHEN a device is selected THEN the system SHALL transition to Connecting state
4. WHEN connection succeeds THEN the system SHALL transition to DiscoveringServices state
5. WHEN services are discovered THEN the system SHALL transition to Connected state
6. IF connection is lost from Connected THEN the system SHALL transition to Reconnecting state
7. WHEN in Reconnecting state AND reconnection fails 3 times THEN the system SHALL transition to Idle

### Requirement 7: CLI Debug Interface

**User Story:** As a developer, I want a CLI tool for testing BLE logic on Linux, so that I can iterate quickly without Android deployment.

#### Acceptance Criteria

1. WHEN `cli scan` is executed THEN the system SHALL list discovered HR devices
2. WHEN `cli connect <device-id>` is executed THEN the system SHALL connect and stream HR data to stdout
3. WHEN `cli mock` is executed THEN the system SHALL generate simulated HR data for testing
4. WHEN streaming THEN the CLI SHALL display filtered BPM, raw BPM, and state transitions

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Each Rust module handles one concern (parsing, filtering, state, BLE)
- **Modular Design**: Domain logic isolated from I/O via traits (ports/adapters pattern)
- **Dependency Management**: Domain depends on nothing; adapters depend on domain and external crates
- **Clear Interfaces**: `BleAdapter` trait defines all BLE operations; implementations are swappable

### Performance
- Latency from BLE notification to StreamSink emission: < 100ms (P95)
- Memory allocation in hot path: minimize heap allocations
- Startup time: < 2 seconds to ready state

### Security
- No cloud data transmission; all data stays on device
- BLE pairing handled by OS; no credential storage in app

### Reliability
- Session duration: support 60+ minutes without data loss
- Automatic reconnection on transient BLE disconnections
- Graceful degradation: continue with last known values during brief signal loss

### Usability
- CLI provides clear, real-time feedback during debugging
- State transitions are logged with timestamps for troubleshooting
