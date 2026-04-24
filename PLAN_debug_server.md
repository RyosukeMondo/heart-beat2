# Plan 2 — Embedded Debug HTTP/WS Server

**Status:** not started
**Owner:** —
**Parent:** [PLAN.md](PLAN.md)
**Depends on:** Phase 1 (broadcast-channel fanout)

## Goal
The running iOS/Android app exposes `/api/*`, `/debug/logs`, `/ws/logs` on
port 8888. Reachable from a Mac via `iproxy 8888 8888`. Operations that
already exist in the standalone binary (scan/connect/workout) are reusable
over the same surface.

## Context (as of draft)
- `rust/src/bin/debug_server.rs` has the full router: REST devices/workout/
  sessions + `/debug/logs` + `/ws/logs`. It binds to `0.0.0.0:8888`.
- Nothing currently starts this router from the Flutter path.
- `axum` / `tokio` / `tower-http` are already library-level deps in `Cargo.toml`.
- `iproxy` is installed (`/opt/homebrew/bin/iproxy`).

## Tasks

### Rust
- [ ] Move `build_router()` + every handler fn + their DTOs out of
      `rust/src/bin/debug_server.rs` into a new library module
      `rust/src/debug_http.rs`. Keep the binary as a thin shim that just
      parses args and calls the library.
- [ ] Add `api::start_debug_server(port: u16) -> Result<()>`:
      - `#[cfg(debug_assertions)]`-gated; in release builds it's a no-op that
        returns Ok.
      - Idempotent via a `OnceLock<tokio::task::JoinHandle<()>>`.
      - On bind failure, log a warning and return Ok (do not block app start).
- [ ] Regenerate FFI bindings (check whether the repo uses `flutter_rust_bridge_codegen`
      or a custom `just` target; run it and commit the regenerated files).
- [ ] Confirm the existing standalone binary still works unchanged.

### Dart
- [x] Call `startDebugServer(port: 8888)` from `lib/main.dart` right after
      `RustLib.init`, inside an `if (kDebugMode)` guard.
- [x] Log the bound URL to the Dart log writer so it's obvious in dev.

### Verification
- [ ] `iproxy 8888 8888` running on Mac →
      `curl -s http://localhost:8888/debug/logs?limit=20` returns JSON.
- [ ] `websocat ws://localhost:8888/ws/logs` streams lines live as the app
      emits them.
- [ ] Once Phase 1 ships: `/debug/logs?source=rust&level=info` filters.

## Acceptance criteria
- [ ] Round-trip: scan in the app, fetch `/debug/logs?limit=10` from Mac,
      see a `scan_devices` line.
- [ ] Release build of the app makes NO outbound bind (verify with
      `lsof -p $(pgrep Runner)` on a release IPA after install).
- [ ] Port collision (8888 in use) logs a warning, app continues normally.

## Notes / gotchas
- Release-build guard belt-and-braces: Dart `kDebugMode` *and* Rust
  `#[cfg(debug_assertions)]`. Missing either one is a security footgun.
- On iOS the app has no accepted-connections entitlement issue for localhost;
  USB muxing via `iproxy` is loopback on the device side.
- When regenerating FFI, the generated `frb_generated.rs` and
  `lib/src/bridge/api_generated.dart/` both change — commit together.

## Resume notes
- Start with the Rust refactor (2.1). Once `build_router()` is in the
  library, the rest falls into place fast.
