# Plan 3 — Diagnosis GUI

**Status:** not started
**Owner:** —
**Parent:** [PLAN.md](PLAN.md)
**Depends on:** Phase 1 (log stream available to Dart)

## Goal
An in-app screen an operator or developer can reach from the UI that shows
current device + session state, live logs from every source, and buttons to
run common operations without leaving the app.

## Context
- Router lives in `lib/src/app.dart` / `lib/main.dart`. Add a `/diagnosis` route.
- Rust already exposes plenty of stream APIs (`create_hr_stream`,
  `create_battery_stream`, `create_connection_status_stream`).
- After Phase 1, a log stream is available via the same broadcast channel
  that the HTTP server uses.

## Tasks

### Entry point
- [ ] Add a `/diagnosis` route and a way to reach it (e.g. long-press on the
      app bar title, or a gear icon in the home screen's overflow menu — do
      NOT put it on the main tab bar; it's a dev/debug surface).
- [ ] Gate the entry point on `kDebugMode` OR a long-press-to-unlock flow
      for release builds (production users shouldn't stumble into it).

### Layout
- [ ] Top: **connection status card** — device name + id, state
      (disconnected/scanning/connecting/connected/reconnecting), last error,
      battery %, RSSI if available.
- [ ] Middle: **live log viewer**
  - Filter chips: source (rust / dart / native-ios / native-android / all)
  - Level dropdown: trace / debug / info / warn / error
  - Search text field
  - Color-coded level column
  - Auto-scroll toggle; tapping a line pins it
- [ ] Bottom: **operations panel**
  - Scan devices (opens bottom sheet with results)
  - Connect last device
  - Disconnect
  - Start/Stop mock mode
  - Export current session (saves to Documents, shares via Share Sheet)
  - Clear cache / force-regen default plans

### Data plumbing
- [ ] `DiagnosisController` (or a cubit/provider fitting the existing pattern)
      subscribes to the Rust streams and the log stream.
- [ ] Log stream: add `api::subscribe_logs()` Rust FFI that returns a
      broadcast receiver as a `StreamSink<LogMessage>`. Multiple subscribers
      supported (diagnosis GUI + the HTTP `/ws/logs` both tap the same channel).
- [ ] Keep the last N=2000 lines in a ring in Dart memory for quick scroll.

### Polish
- [ ] Landscape layout: status card shrinks, log viewer takes the rest.
- [ ] Copy-to-clipboard on tap-and-hold of a log line.
- [ ] "Share diagnostic bundle" button: zips `<app_docs>/logs/` + last session
      JSON, invokes Share Sheet.

## Acceptance criteria
- [ ] `/diagnosis` reachable in a debug build.
- [ ] Tap "Start mock mode" → HR lines appear in the log viewer within 1s AND
      the connection status card flips to `connected (mock)`.
- [ ] Filter to `source=rust level>=warn` and trigger a warning: only that
      line shows.
- [ ] Rotate device: log history + filters persist (don't rebuild from
      scratch).

## Notes / gotchas
- The log viewer is the one UI surface most likely to leak PII if we ever log
  HR data with user identifiers. Sanitize before logging; don't rely on the
  UI to redact.
- Avoid a full `ListView` rebuild on every log line — use a `ListView.builder`
  driven by a `ValueNotifier<List<LogMessage>>` with windowing.

## Resume notes
- Begin with 3.1 (route skeleton). Even an empty `/diagnosis` page lets
  Phase 1 + 2 wiring be exercised end-to-end against something.
