# Test Coverage Gap Analysis

**Generated**: 2026-01-13
**Current Coverage**: 44.52% (792/1779 testable lines)
**Target**: 80% (1423/1779 lines needed)
**Gap**: 631 additional lines needed

## Executive Summary

This document identifies all modules, files, and specific line ranges that fall below the 80% coverage threshold. The analysis is based on the cobertura.xml coverage report and prioritizes gaps by criticality to guide testing efforts.

## Coverage by Module (Below 80% Threshold)

### Priority 1: CRITICAL - Core Business Logic

#### 1. API Layer (`src/api.rs`)
- **Current Coverage**: 11.33% (70/618 lines)
- **Gap**: 548 lines needed for 80%
- **Priority**: CRITICAL
- **Reason**: Main application facade, coordinates all domain and adapter layers

**Uncovered Critical Functions** (Line ranges with 0 hits):
- Lines 140-203: `HeartBeatApi::new()` - API initialization
- Lines 213-275: Device discovery and connection setup
- Lines 358-452: Session lifecycle management
- Lines 501-534: Session control (pause/resume/stop)
- Lines 552-670: Scheduled session management
- Lines 692-780: Notification handling and event propagation
- Lines 852-874: Statistics retrieval
- Lines 940-1011: Training plan operations
- Lines 1041-1077: Device management
- Lines 1103-1167: Reconnection policy operations
- Lines 1185-1259: Export functionality
- Lines 1310-1381: Various bridge method error paths
- Lines 1518-1643: Flutter bridge method implementations
- Lines 1664-1787: Additional bridge methods
- Lines 1807-1922: Session history operations
- Lines 1945-2178: Remaining bridge method implementations

**Covered Sections** (Can inform test patterns):
- Lines 797-838: Status checks and basic queries (70% coverage)
- Lines 889-906: Some initialization paths
- Lines 1396-1483: Several helper methods (good patterns to replicate)

#### 2. Scheduler/Executor (`src/scheduler/executor.rs`)
- **Current Coverage**: 44.55% (147/330 lines)
- **Gap**: 117 lines needed for 80%
- **Priority**: CRITICAL
- **Reason**: Manages session lifecycle, persistence, and scheduling

**Uncovered Critical Functions** (Line ranges with 0 hits):
- Lines 198-210: `start_scheduled_session()` - Cron execution path
- Lines 223-228: `schedule_session()` - Cron scheduling setup
- Lines 279-355: `pause()` - Session pause logic (completely untested)
- Lines 450-467: Session resume error paths
- Lines 483-538: Checkpoint recovery logic (0% coverage)
- Lines 557-557: HR processing helper (untested)
- Lines 605-613: Error handling in tick loop
- Lines 630-670: Session cancellation confirmation flow (0% coverage)
- Lines 691-715: Checkpoint save/load file operations (0% coverage)
- Lines 743-785: Progress notification edge cases
- Lines 794-804: Cleanup operations

**Covered Sections**:
- Lines 116-189: Basic constructor and initialization (good coverage)
- Lines 234-274: Session start main path (62% coverage)
- Lines 371-445: Tick loop core logic (79% coverage)
- Lines 566-622: HR data handling (75% coverage)
- Lines 675-734: Session completion (good coverage)
- Lines 828-896: State query methods (excellent coverage)

#### 3. BLE Adapter (`src/adapters/btleplug_adapter.rs`)
- **Current Coverage**: 7.41% (16/216 lines)
- **Gap**: 157 lines needed for 80%
- **Priority**: HIGH
- **Reason**: Real hardware interface, error handling is critical

**Uncovered Critical Functions** (Line ranges with 0 hits):
- Lines 126-162: `scan()` - BLE device scanning (0% coverage)
- Lines 201-300: `connect()` - Device connection handling (0% coverage)
- Lines 342-430: Service discovery and characteristic finding (0% coverage)
- Lines 441-597: `subscribe_heart_rate()` - HR notifications (0% coverage except setup)
- Lines 618-723: Battery and disconnect operations (mostly 0%)

**Covered Sections**:
- Lines 104-121: Constructor (good coverage)
- Lines 603-615: Basic setup paths

**Note**: This adapter is heavily biased toward real hardware testing. Mock-based unit tests may be limited, but critical error paths can be tested with mocked peripherals.

### Priority 2: MEDIUM - Near-Threshold Modules

#### 4. State Machine - Connectivity (`src/state/connectivity.rs`)
- **Current Coverage**: 83.58% (56/67 lines)
- **Gap**: 2 lines needed for 80% (already exceeds)
- **Priority**: MEDIUM (cleanup)
- **Reason**: Already meets threshold, but has specific untested edges

**Uncovered Lines**:
- Lines 105, 113-114, 118: Initial state setup edge cases
- Lines 165, 180: Error path variants
- Lines 194: State transition error branch
- Lines 288-289, 293-294: Additional transition guards

**Assessment**: 11 lines uncovered, mostly error branches. Easy wins for pushing to 90%+.

#### 5. State Machine - Session (`src/state/session.rs`)
- **Current Coverage**: 85.61% (119/139 lines)
- **Gap**: Already exceeds 80%
- **Priority**: MEDIUM (cleanup)
- **Reason**: Good coverage, minor gaps remain

**Uncovered Lines**:
- Line 71: Error variant
- Lines 159, 192, 206: State transition error branches
- Lines 225-226, 232-233: Edge case handlers
- Lines 269-270: Specific state guard
- Lines 313-314: Error path
- Lines 353, 362, 380, 400, 454, 464-465: Various error branches and edge cases

**Assessment**: 20 lines uncovered. Mostly error handling and edge cases. Should target 90%+.

### Priority 3: LOW - Domain Layer (High Coverage)

Most domain modules already exceed 90% coverage:

#### 6. Domain - Export (`src/domain/export.rs`)
- **Current Coverage**: 91.67% (44/48 lines)
- **Gap**: Already exceeds target
- **Uncovered Lines**: 49, 55-56, 60 (4 lines)
- **Priority**: LOW

#### 7. Domain - Session Progress (`src/domain/session_progress.rs`)
- **Current Coverage**: 85.71% (12/14 lines)
- **Gap**: Already exceeds target
- **Uncovered Lines**: 100, 116 (2 lines)
- **Priority**: LOW

### Modules ABOVE 90% (Excellent Coverage)

✅ Domain Layer Summary: 97.09% (200/206 lines)
- `domain/battery.rs`: 100%
- `domain/filters.rs`: 100%
- `domain/heart_rate.rs`: 100%
- `domain/hrv.rs`: 100%
- `domain/reconnection.rs`: 100%
- `domain/session_history.rs`: 100%
- `domain/training_plan.rs`: 100%

✅ Adapter Layer (High Coverage):
- `adapters/cli_notification_adapter.rs`: 100%
- `adapters/file_session_repository.rs`: 89.01%
- `adapters/mock_adapter.rs`: 91.76%
- `adapters/mock_notification_adapter.rs`: 84.62%

## Prioritized Testing Strategy

### Phase 1: Critical Path Testing (Target: 60% overall)
Focus on the highest-impact modules with lowest coverage:

1. **API Layer (`api.rs`)** - Add 400 lines of coverage
   - Test session lifecycle: start, pause, resume, stop
   - Test device connection flow
   - Test error propagation from domain to UI
   - Test concurrent session access
   - **Expected gain**: +400 lines

2. **Scheduler/Executor (`executor.rs`)** - Add 117 lines
   - Test pause/resume with different pause reasons
   - Test checkpoint save/load/recovery
   - Test scheduled session triggering
   - Test session cancellation flow
   - **Expected gain**: +117 lines

**Phase 1 Total**: +517 lines → 73.5% overall coverage

### Phase 2: Hardware Adapter Testing (Target: 70% overall)
3. **BLE Adapter (`btleplug_adapter.rs`)** - Add 100-120 lines
   - Mock peripheral for connection tests
   - Test service discovery failures
   - Test characteristic subscription errors
   - Test battery read failures
   - **Expected gain**: +114 lines (aiming for 60% on this module, not 80%, due to hardware dependency)

**Phase 2 Total**: +631 lines → **80.0% overall coverage** ✅

### Phase 3: Polish (Target: 85%+ overall)
4. **State Machines** - Add 30 lines
   - Cover remaining error branches
   - Test invalid transition handling
   - **Expected gain**: +30 lines → 85.2%

5. **Domain Layer Gaps** - Add 6 lines
   - Complete export edge cases
   - **Expected gain**: +6 lines → 85.5%

## Specific Function Coverage Gaps

### API Layer - Critical Uncovered Functions

| Function | Lines | Status | Testing Notes |
|----------|-------|--------|---------------|
| `HeartBeatApi::new()` | 140-160 | ❌ 0% | Initialization path - MUST TEST |
| `api_discover_devices()` | 177-203 | ❌ 0% | Device scanning - CRITICAL |
| `api_connect_device()` | 231-275 | ❌ 0% | Connection flow - CRITICAL |
| `api_start_session()` | 358-452 | ❌ 0% | Session start - CRITICAL |
| `api_pause_session()` | 501-534 | ❌ 0% | Pause handling - CRITICAL |
| `api_schedule_session()` | 552-596 | ❌ 0% | Cron scheduling - CRITICAL |
| `api_cancel_scheduled()` | 599-644 | ❌ 0% | Schedule cancel - CRITICAL |
| `api_get_device_stats()` | 852 | ❌ 0% | Statistics - MEDIUM |
| `api_*_training_plan()` | 940-1011 | ❌ 0% | Plan operations - HIGH |
| `api_export_*()` | 1185-1259 | ❌ 0% | Export operations - MEDIUM |
| Bridge methods | 1518-2178 | ❌ 0% | Flutter FFI - MEDIUM |

### Executor - Critical Uncovered Functions

| Function | Lines | Status | Testing Notes |
|----------|-------|--------|---------------|
| `pause()` | 279-355 | ❌ 0% | CRITICAL - Session pause completely untested |
| `schedule_session()` | 223-228 | ❌ 0% | CRITICAL - Cron setup |
| `start_scheduled_session()` | 198-210 | ❌ 0% | CRITICAL - Cron trigger |
| `recover_from_checkpoint()` | 483-538 | ❌ 0% | CRITICAL - Crash recovery |
| `confirm_cancel()` | 630-670 | ❌ 0% | HIGH - User confirmation flow |
| `save_checkpoint()` | 691-715 | ❌ 0% | HIGH - Persistence |
| `load_checkpoint()` | 691-715 | ❌ 0% | HIGH - Restoration |

### BLE Adapter - Critical Uncovered Functions

| Function | Lines | Status | Testing Notes |
|----------|-------|--------|---------------|
| `scan()` | 126-162 | ❌ 0% | CRITICAL - Device discovery |
| `connect()` | 201-300 | ❌ 0% | CRITICAL - Connection handling |
| `find_hr_service()` | 342-430 | ❌ 0% | HIGH - Service discovery |
| `subscribe_heart_rate()` | 441-597 | ❌ 0% | CRITICAL - HR notifications |
| `read_battery_level()` | 618-686 | ❌ 0% | MEDIUM - Battery monitoring |

## Test Implementation Guidance

### API Layer Test Pattern
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_api_start_session_success() {
        // Setup: Create API with mock adapters
        // Action: Call api_start_session()
        // Assert: Session starts, state transitions correctly
    }

    #[tokio::test]
    async fn test_api_start_session_no_device() {
        // Test error path: no device connected
    }

    #[tokio::test]
    async fn test_api_pause_resume_session() {
        // Test full pause/resume cycle
    }

    // Add ~20-30 tests covering all critical paths
}
```

### Executor Test Pattern
```rust
#[tokio::test]
async fn test_executor_pause_user_initiated() {
    // Test user-initiated pause
}

#[tokio::test]
async fn test_executor_pause_connection_loss() {
    // Test automatic pause on disconnect
}

#[tokio::test]
async fn test_checkpoint_save_and_recover() {
    // Test crash recovery flow
}

#[tokio::test]
async fn test_scheduled_session_execution() {
    // Test cron-triggered session start
}
```

### BLE Adapter Test Pattern
```rust
#[tokio::test]
async fn test_btleplug_connect_success() {
    // Use mock Peripheral
    // Test successful connection
}

#[tokio::test]
async fn test_btleplug_connect_service_not_found() {
    // Test error when HR service missing
}

#[tokio::test]
async fn test_btleplug_subscribe_hr_notifications() {
    // Test characteristic subscription
}
```

## Summary

**Current State**: 792/1779 lines covered (44.52%)
**Target State**: 1423/1779 lines covered (80.0%)
**Lines Needed**: 631 lines

**Critical Path**:
1. API Layer: +400 lines
2. Executor: +117 lines
3. BLE Adapter: +114 lines
**Total**: +631 lines → **80% coverage achieved** ✅

**Effort Estimate**:
- Phase 1 (API + Executor): ~15-20 comprehensive tests
- Phase 2 (BLE Adapter): ~8-12 tests with mocked peripherals
- Phase 3 (Polish): ~5-8 tests for edge cases

**Next Steps**: Proceed with task 5 (domain gaps), task 6 (adapter gaps), task 7 (state machine gaps), and task 8 (executor gaps) in priority order.
