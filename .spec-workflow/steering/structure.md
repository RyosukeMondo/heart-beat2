# Project Structure

## Directory Organization

```
heart-beat2/
├── rust/                           # Rust core library
│   ├── src/
│   │   ├── lib.rs                  # Library root, re-exports
│   │   ├── api.rs                  # FRB-exposed API for Flutter
│   │   ├── domain/                 # Pure business logic (no I/O)
│   │   │   ├── mod.rs
│   │   │   ├── heart_rate.rs       # HR measurement types, zone calculation
│   │   │   ├── hrv.rs              # HRV analysis (RMSSD, SDNN)
│   │   │   ├── training_plan.rs    # Training session definitions
│   │   │   └── filters.rs          # Kalman filter, signal processing
│   │   ├── ports/                  # Interface definitions (traits)
│   │   │   ├── mod.rs
│   │   │   ├── ble_adapter.rs      # BleAdapter trait
│   │   │   └── notification.rs     # NotificationPort trait
│   │   ├── adapters/               # Concrete implementations
│   │   │   ├── mod.rs
│   │   │   ├── btleplug_adapter.rs # btleplug BLE implementation
│   │   │   └── mock_adapter.rs     # Mock for testing
│   │   ├── state/                  # State machine (statig)
│   │   │   ├── mod.rs
│   │   │   ├── connectivity.rs     # BLE connection states
│   │   │   └── session.rs          # Training session states
│   │   └── scheduler/              # Training plan execution
│   │       ├── mod.rs
│   │       └── executor.rs         # Cron-based plan runner
│   ├── bin/
│   │   └── cli.rs                  # Standalone CLI binary for debugging
│   ├── tests/                      # Integration tests
│   │   ├── ble_integration.rs
│   │   └── session_flow.rs
│   └── Cargo.toml
├── lib/                            # Flutter app
│   ├── main.dart                   # App entry point
│   ├── src/
│   │   ├── bridge/                 # FRB generated bindings
│   │   │   └── api_generated.dart
│   │   ├── screens/                # UI screens
│   │   │   ├── home_screen.dart
│   │   │   ├── session_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── widgets/                # Reusable widgets
│   │   │   ├── hr_display.dart
│   │   │   ├── zone_indicator.dart
│   │   │   └── battery_status.dart
│   │   └── services/               # Flutter-side services
│   │       ├── permission_service.dart
│   │       └── background_service.dart
│   └── test/                       # Dart unit tests
├── integration_test/               # Patrol E2E tests
│   └── app_test.dart
├── docs/                           # Documentation
│   └── research.md                 # Original research document
├── .spec-workflow/                 # Spec workflow files
│   ├── steering/                   # Steering documents
│   │   ├── product.md
│   │   ├── tech.md
│   │   └── structure.md
│   ├── specs/                      # Feature specifications
│   └── templates/                  # Spec templates
├── pubspec.yaml                    # Flutter dependencies
└── README.md                       # Project overview
```

## Naming Conventions

### Files
- **Rust Modules**: `snake_case.rs` (e.g., `heart_rate.rs`, `ble_adapter.rs`)
- **Dart Files**: `snake_case.dart` (e.g., `home_screen.dart`, `hr_display.dart`)
- **Tests (Rust)**: `[module]_test.rs` or in `tests/` directory
- **Tests (Dart)**: `[file]_test.dart`

### Code
- **Rust Structs/Enums**: `PascalCase` (e.g., `HeartRateMeasurement`, `SessionState`)
- **Rust Functions**: `snake_case` (e.g., `parse_heart_rate`, `calculate_hrv`)
- **Rust Constants**: `SCREAMING_SNAKE_CASE` (e.g., `HR_SERVICE_UUID`)
- **Rust Traits**: `PascalCase` with descriptive names (e.g., `BleAdapter`)
- **Dart Classes**: `PascalCase` (e.g., `HomeScreen`, `HrDisplay`)
- **Dart Functions/Methods**: `camelCase` (e.g., `onDataReceived`)
- **Dart Constants**: `camelCase` or `SCREAMING_SNAKE_CASE` for compile-time

## Import Patterns

### Import Order (Rust)
```rust
// 1. Standard library
use std::collections::HashMap;

// 2. External crates
use anyhow::Result;
use tokio::sync::mpsc;

// 3. Internal modules (crate::)
use crate::domain::heart_rate::HeartRateMeasurement;
use crate::ports::ble_adapter::BleAdapter;
```

### Import Order (Dart)
```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter SDK
import 'package:flutter/material.dart';

// 3. External packages
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

// 4. Internal imports
import '../bridge/api_generated.dart';
import '../widgets/hr_display.dart';
```

## Code Structure Patterns

### Rust Module Organization
```rust
// 1. Module-level documentation
//! Heart rate measurement and zone calculation

// 2. Imports
use crate::ports::ble_adapter::BleAdapter;

// 3. Type definitions
pub struct HeartRateMeasurement { ... }

// 4. Trait implementations
impl HeartRateMeasurement { ... }

// 5. Public functions
pub fn calculate_zone(bpm: u16, max_hr: u16) -> Zone { ... }

// 6. Private helpers
fn validate_bpm(bpm: u16) -> Result<u16> { ... }

// 7. Tests (in same file or tests/)
#[cfg(test)]
mod tests { ... }
```

### Flutter Widget Organization
```dart
// 1. Imports
import 'package:flutter/material.dart';

// 2. Widget class
class HrDisplay extends StatelessWidget {
  // 3. Constructor and properties
  final int bpm;
  const HrDisplay({required this.bpm});

  // 4. Build method
  @override
  Widget build(BuildContext context) { ... }

  // 5. Private helper methods
  Color _getZoneColor() { ... }
}
```

## Code Organization Principles

1. **Hexagonal Separation**: Domain logic in `domain/` has zero dependencies on adapters or external crates (except pure computation libraries)
2. **Trait-Based Abstraction**: All I/O accessed through traits in `ports/`, implemented in `adapters/`
3. **CLI Parity**: `bin/cli.rs` uses same domain and adapter code as Flutter app
4. **Test Isolation**: Unit tests mock at trait boundaries; integration tests use mock adapters

## Module Boundaries

### Dependency Direction
```
┌─────────────────────────────────────────────┐
│                  Flutter UI                  │
│              (depends on bridge)             │
└──────────────────────┬──────────────────────┘
                       │ FRB
┌──────────────────────┴──────────────────────┐
│               api.rs (FRB API)              │
│           (depends on domain, adapters)      │
└──────────────────────┬──────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌───────────┐  ┌───────────┐  ┌───────────┐
│  adapters │  │   state   │  │ scheduler │
│(implements│  │  (uses    │  │  (uses    │
│  ports)   │  │  domain)  │  │  domain)  │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      │              │              │
      └──────────────┼──────────────┘
                     ▼
              ┌───────────┐
              │   ports   │
              │  (traits) │
              └─────┬─────┘
                    │
                    ▼
              ┌───────────┐
              │  domain   │
              │ (pure fn) │
              └───────────┘
```

**Rules:**
- `domain/` depends on nothing except std and pure computation crates
- `ports/` defines traits, depends only on domain types
- `adapters/` implements traits, may depend on external I/O crates
- `state/` and `scheduler/` use domain types and port traits
- `api.rs` orchestrates everything for FRB exposure

## Code Size Guidelines

- **Rust Files**: Max ~500 lines; split into submodules if larger
- **Rust Functions**: Max ~50 lines; extract helpers for clarity
- **Dart Widgets**: Max ~200 lines; extract sub-widgets if complex
- **Nesting Depth**: Max 4 levels; flatten with early returns or helper functions

## Documentation Standards

- **Rust**: Doc comments (`///`) on all public items; `//!` for module docs
- **Dart**: Doc comments (`///`) on public classes and methods
- **Complex Logic**: Inline comments explaining "why", not "what"
- **README**: Project setup, CLI usage, development workflow
