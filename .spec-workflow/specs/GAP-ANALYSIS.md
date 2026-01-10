# Gap Analysis: Steering Documents vs Codebase

Generated: 2026-01-11

## Overview

This document identifies gaps between the steering documents (product.md, structure.md, tech.md) and the current codebase implementation.

## Existing Implementation

### Completed Components
✅ Rust core library structure (rust/src/)
✅ Domain types: heart_rate.rs, hrv.rs, filters.rs
✅ BLE infrastructure: ports/ble_adapter.rs, adapters/btleplug_adapter.rs, adapters/mock_adapter.rs
✅ State machine: state/connectivity.rs (BLE connection states)
✅ CLI binary: bin/cli.rs
✅ Integration tests: tests/pipeline_integration.rs, tests/state_machine_integration.rs
✅ Basic project setup with Cargo.toml

## Identified Gaps

### 1. FRB API Layer (CRITICAL)
**Status:** ❌ Missing
**File:** `rust/src/api.rs`
**Reason:** Required for Flutter integration
**Impact:** HIGH - Flutter app cannot consume Rust core without this

**Spec Created:** `.spec-workflow/specs/frb-api/`
- requirements.md
- design.md
- tasks.md

### 2. Training Plan Domain (CRITICAL)
**Status:** ❌ Missing
**File:** `rust/src/domain/training_plan.rs`
**Reason:** Core feature from product.md - "Planned Training Execution"
**Impact:** HIGH - Users cannot define/execute structured workouts

**Spec Created:** `.spec-workflow/specs/training-plan/`
- requirements.md
- design.md
- tasks.md

### 3. Session State Machine (CRITICAL)
**Status:** ❌ Missing
**File:** `rust/src/state/session.rs`
**Reason:** Executes training sessions with phase transitions
**Impact:** HIGH - Training plans cannot be executed

**Spec Created:** `.spec-workflow/specs/session-state/`
- requirements.md
- design.md
- tasks.md

### 4. Notification Port (HIGH PRIORITY)
**Status:** ❌ Missing
**File:** `rust/src/ports/notification.rs`
**Reason:** Core feature from product.md - "Biofeedback Loop"
**Impact:** HIGH - No audio/visual zone deviation alerts

**Spec Created:** `.spec-workflow/specs/notification-port/`
- requirements.md
- design.md
- tasks.md

### 5. Scheduler Module (HIGH PRIORITY)
**Status:** ❌ Missing
**Directory:** `rust/src/scheduler/` (mod.rs, executor.rs)
**Reason:** Executes scheduled workouts, integrates session + HR stream
**Impact:** HIGH - Cannot run training sessions or schedule workouts

**Spec Created:** `.spec-workflow/specs/scheduler/`
- requirements.md
- design.md
- tasks.md

### 6. Flutter Application (CRITICAL)
**Status:** ❌ Missing
**Directory:** `lib/` + `pubspec.yaml` + `integration_test/`
**Reason:** Production mobile UI - end deliverable
**Impact:** CRITICAL - No mobile app, only CLI available

**Spec Created:** `.spec-workflow/specs/flutter-app/`
- requirements.md
- design.md
- tasks.md

## Dependency Graph

```
Flutter App (6)
     ↓ depends on
  FRB API (1)
     ↓ depends on
  ┌──────┼──────────┐
  ↓      ↓          ↓
Scheduler (5)  Session State (3)  Notification Port (4)
     ↓             ↓
Training Plan (2)  ←──────┘

[Numbers indicate spec priority]
```

## Implementation Sequence

### Phase 1: Domain & Ports (Foundation)
1. **training-plan** - Pure domain types, no dependencies
2. **notification-port** - Interface only, no implementation complexity

### Phase 2: State & Orchestration
3. **session-state** - Depends on training-plan
4. **scheduler** - Depends on session-state, notification-port

### Phase 3: Integration
5. **frb-api** - Exposes Rust to Flutter, depends on all Rust modules
6. **flutter-app** - Consumes FRB API, final deliverable

## Coverage Analysis

### Steering Document Compliance

**product.md Features:**
- ✅ Real-time HR Streaming (implemented: BLE + filters)
- ❌ Planned Training Execution (specs: 2, 3, 5)
- ❌ Biofeedback Loop (spec: 4)
- ✅ HRV Analysis (implemented: hrv.rs)
- ❌ Cross-Platform (CLI ✅, Android spec: 6)

**structure.md Modules:**
- ✅ domain/heart_rate.rs, hrv.rs, filters.rs
- ❌ domain/training_plan.rs (spec: 2)
- ✅ ports/ble_adapter.rs
- ❌ ports/notification.rs (spec: 4)
- ✅ adapters/btleplug_adapter.rs, mock_adapter.rs
- ✅ state/connectivity.rs
- ❌ state/session.rs (spec: 3)
- ❌ scheduler/ (spec: 5)
- ❌ api.rs (spec: 1)
- ✅ bin/cli.rs
- ❌ lib/ Flutter app (spec: 6)

**tech.md Architecture:**
- ✅ Hexagonal architecture (ports/adapters implemented)
- ✅ CLI-first development (CLI working)
- ❌ FRB v2 integration (spec: 1)
- ✅ State machine (connectivity implemented, session spec: 3)
- ❌ Scheduler (spec: 5)
- ❌ Flutter UI (spec: 6)

## Summary

**Total Gaps:** 6 major components
**Specs Created:** 6 complete mini-specs (requirements.md, design.md, tasks.md)
**Implementation Priority:** 1 → 2 → 4 → 3 → 5 → 1 → 6

All specs are ready for immediate implementation following the tasks-template format. Each task includes:
- File paths
- Clear implementation goals
- Leverage points (existing code to reference)
- Requirements traceability
- Role-specific prompts
- Success criteria

## Next Steps

1. Begin with **training-plan** (no dependencies)
2. Implement **notification-port** (simple trait)
3. Build **session-state** (uses training-plan)
4. Create **scheduler** (orchestrates everything)
5. Expose via **frb-api** (Flutter bridge)
6. Deliver **flutter-app** (final UI)

Each spec is self-contained and can be implemented autonomously following the task lists.
