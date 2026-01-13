# Baseline Test Coverage Report

**Date**: 2026-01-13
**Overall Coverage**: 15.46% (792/5122 lines covered)
**Target**: 80% minimum coverage

## Coverage by Module

### Domain Layer (Core Business Logic)
| Module | Coverage | Lines Covered | Total Lines | Status |
|--------|----------|---------------|-------------|--------|
| `domain/battery.rs` | 100% | 4/4 | 4 | ✅ Meets target |
| `domain/export.rs` | 91.67% | 44/48 | 48 | ✅ Meets target |
| `domain/filters.rs` | 100% | 23/23 | 23 | ✅ Meets target |
| `domain/heart_rate.rs` | 100% | 44/44 | 44 | ✅ Meets target |
| `domain/hrv.rs` | 100% | 26/26 | 26 | ✅ Meets target |
| `domain/reconnection.rs` | 100% | 12/12 | 12 | ✅ Meets target |
| `domain/session_history.rs` | 100% | 12/12 | 12 | ✅ Meets target |
| `domain/session_progress.rs` | 85.71% | 12/14 | 14 | ✅ Meets target |
| `domain/training_plan.rs` | 100% | 23/23 | 23 | ✅ Meets target |

**Domain Layer Summary**: 200/206 lines (97.09%) ✅

### Adapter Layer (Infrastructure)
| Module | Coverage | Lines Covered | Total Lines | Status |
|--------|----------|---------------|-------------|--------|
| `adapters/btleplug_adapter.rs` | 7.41% | 16/216 | 216 | ❌ Below target |
| `adapters/cli_notification_adapter.rs` | 100% | 14/14 | 14 | ✅ Meets target |
| `adapters/file_session_repository.rs` | 89.01% | 81/91 | 91 | ✅ Meets target |
| `adapters/mock_adapter.rs` | 91.76% | 78/85 | 85 | ✅ Meets target |
| `adapters/mock_notification_adapter.rs` | 84.62% | 11/13 | 13 | ✅ Meets target |

**Adapter Layer Summary**: 200/419 lines (47.73%) ❌

### State Machine Layer
| Module | Coverage | Lines Covered | Total Lines | Status |
|--------|----------|---------------|-------------|--------|
| `state/connectivity.rs` | 83.58% | 56/67 | 67 | ✅ Meets target |
| `state/session.rs` | 85.61% | 119/139 | 139 | ✅ Meets target |

**State Machine Layer Summary**: 175/206 lines (84.95%) ✅

### Scheduler/Executor Layer
| Module | Coverage | Lines Covered | Total Lines | Status |
|--------|----------|---------------|-------------|--------|
| `scheduler/executor.rs` | 44.55% | 147/330 | 330 | ❌ Below target |

**Scheduler/Executor Summary**: 147/330 lines (44.55%) ❌

### API Layer
| Module | Coverage | Lines Covered | Total Lines | Status |
|--------|----------|---------------|-------------|--------|
| `api.rs` | 11.33% | 70/618 | 618 | ❌ Below target |

**API Layer Summary**: 70/618 lines (11.33%) ❌

### Generated/Excluded Code
| Module | Coverage | Lines Covered | Total Lines | Note |
|--------|----------|---------------|-------------|------|
| `frb_generated.rs` | 0% | 0/2498 | 2498 | Generated code - excluded |
| `bin/cli.rs` | 0% | 0/845 | 845 | CLI binary - difficult to test |

## Critical Gaps Identified

### High Priority (Critical Business Logic)

1. **`scheduler/executor.rs` (44.55% coverage, 330 lines)**
   - **Missing**: Session lifecycle (start, pause, resume, stop)
   - **Missing**: Checkpoint persistence and recovery edge cases
   - **Missing**: Cron scheduling error handling
   - **Impact**: HIGH - Core session management functionality

2. **`adapters/btleplug_adapter.rs` (7.41% coverage, 216 lines)**
   - **Missing**: BLE connection error handling
   - **Missing**: Service discovery edge cases
   - **Missing**: HR characteristic subscription failures
   - **Missing**: Battery read failures
   - **Impact**: HIGH - Real BLE hardware interface

3. **`api.rs` (11.33% coverage, 618 lines)**
   - **Missing**: API error propagation
   - **Missing**: Concurrent session management
   - **Missing**: Resource cleanup
   - **Missing**: Bridge method error handling
   - **Impact**: MEDIUM - Facade layer between UI and domain

### Medium Priority (Infrastructure)

4. **`domain/export.rs` (91.67% coverage, 48 lines)**
   - **Missing**: 4 lines of edge case handling
   - **Impact**: LOW - Nearly complete coverage

5. **`domain/session_progress.rs` (85.71% coverage, 14 lines)**
   - **Missing**: 2 lines of variant handling
   - **Impact**: LOW - Minor gaps

6. **`state/connectivity.rs` (83.58% coverage, 67 lines)**
   - **Missing**: 11 lines of state transition edge cases
   - **Impact**: LOW - Good coverage, minor gaps

7. **`state/session.rs` (85.61% coverage, 139 lines)**
   - **Missing**: 20 lines of state transition handling
   - **Impact**: LOW - Good coverage, minor gaps

### Low Priority (Test/Mock Code)

8. **`adapters/mock_notification_adapter.rs` (84.62% coverage)**
   - Already well-tested, used in integration tests

## Test Types Executed

- **Unit Tests**: 173 tests in main binary
- **Integration Tests**:
  - State Machine Integration: 6 tests
  - Pipeline Integration: 4 tests
  - Kalman Integration: 6 tests
  - Latency Tests: 3 tests
  - Session History: 3 tests

## Recommendations

### Phase 1: Critical Gaps (Target: 80% overall)
1. Add comprehensive tests for `scheduler/executor.rs` (task 8)
   - Focus: Session lifecycle, persistence, error handling
   - Expected gain: ~183 lines (55% of 330)

2. Add comprehensive tests for `adapters/btleplug_adapter.rs` (task 6)
   - Focus: Connection errors, service discovery, subscription failures
   - Expected gain: ~157 lines (73% of 216)

3. Add comprehensive tests for `api.rs`
   - Focus: Error propagation, concurrent access, resource cleanup
   - Expected gain: ~425 lines (69% of 618)

### Phase 2: Minor Gaps (Target: 90%+)
4. Complete remaining state machine tests (task 7)
   - Fill gaps in `state/connectivity.rs` and `state/session.rs`
   - Expected gain: ~31 lines

5. Complete domain layer (tasks 5)
   - Fill minor gaps in `domain/export.rs` and `domain/session_progress.rs`
   - Expected gain: ~6 lines

### Estimated Coverage After All Tests
- Current: 15.46% (792/5122 lines)
- After Phase 1: ~47% (+765 lines, 1557/5122)
- After Phase 2: ~49% (+37 lines, 1594/5122)

**Note**: The low overall percentage is heavily influenced by:
- Generated code (`frb_generated.rs`): 2498 lines (48.8% of total)
- CLI binary (`bin/cli.rs`): 845 lines (16.5% of total)

### Adjusted Coverage (Excluding Generated/CLI)
- **Testable codebase**: 1779 lines (5122 - 2498 - 845)
- **Current coverage of testable code**: 44.5% (792/1779)
- **Target**: 80% (1423/1779 lines)
- **Lines needed**: 631 additional lines

## Configuration Needs

1. Create `tarpaulin.toml` to:
   - Exclude `frb_generated.rs` from coverage calculation
   - Exclude `bin/cli.rs` from coverage requirement (UI/integration tested separately)
   - Set threshold at 80% for non-excluded code
   - Configure HTML + XML output for CI

2. Update CI workflow to:
   - Run coverage on every PR
   - Enforce 80% threshold (excluding generated code)
   - Upload coverage reports

## HTML Report Location
`rust/coverage/tarpaulin-report.html`
