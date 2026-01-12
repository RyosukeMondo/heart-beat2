# Requirements Document

## Introduction

Create ADB helper scripts for Android development: log filtering, quick install, permission checking, and BLE debugging. These scripts accelerate the Android debugging workflow.

## Alignment with Product Vision

Android is the primary deployment target. Fast debugging workflows are essential for shipping quality software.

## Requirements

### Requirement 1: Log Filtering Script

**User Story:** As a developer, I want filtered Android logs, so that I can see only relevant app output.

#### Acceptance Criteria

1. WHEN `adb-logs.sh` is run THEN the system SHALL clear existing logs and show filtered output
2. WHEN filtering THEN the system SHALL include heart_beat, flutter, btleplug, BluetoothGatt
3. IF adb not connected THEN the script SHALL show connection instructions

### Requirement 2: Quick Install Script

**User Story:** As a developer, I want one-command deploy, so that I can test changes quickly on device.

#### Acceptance Criteria

1. WHEN `adb-install.sh` is run THEN the system SHALL build debug APK
2. WHEN build succeeds THEN the system SHALL install APK to connected device
3. WHEN install succeeds THEN the system SHALL launch the app

### Requirement 3: Permission Debug Script

**User Story:** As a developer, I want to check app permissions, so that I can diagnose permission issues.

#### Acceptance Criteria

1. WHEN `adb-permissions.sh` is run THEN the system SHALL show all granted permissions
2. WHEN showing permissions THEN the system SHALL highlight Bluetooth-related ones

### Requirement 4: BLE Debug Script

**User Story:** As a developer, I want BLE packet logging, so that I can debug low-level BLE issues.

#### Acceptance Criteria

1. WHEN `adb-ble-debug.sh` is run THEN the system SHALL enable HCI snoop logging
2. WHEN BLE debugging is enabled THEN the system SHALL restart Bluetooth
3. IF already enabled THEN the script SHALL indicate current status

## Non-Functional Requirements

### Code Architecture and Modularity
- Each script is standalone
- Common functions extracted if reusable
- All scripts in scripts/ directory

### Usability
- Clear usage messages
- Colored output for readability
- Error messages with remediation steps
