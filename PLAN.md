# Heart Beat — Active Plans

Top-level dashboard. Detail lives in each `PLAN_<slug>.md`.

## North Star
**Product goal:** the user wears a HR strap, the app runs all day, and prompts
them in real time to act (*"stand up"*, *"raise HR to 120"*, *"cool down"*).
That's Phase 5. Phases 1–4 are the infrastructure that lets us build and
diagnose Phase 5 reliably over USB from a Mac.

## How to resume (read me first in a fresh session)
1. Scan **Progress tracker** below — find the lowest-numbered milestone
   that is still `[ ]` or `[~]`.
2. Open the matching `PLAN_<slug>.md` file and read its Context + Resume notes.
3. Start work on the first non-`[x]` task in that phase file. Flip it to `[~]`.
4. When done, flip to `[x]` in both the phase file AND the matching milestone
   in this file. Commit plan edits alongside the code change.
5. Don't re-plan unless the code surprises you. If it does, update the phase
   file's **Notes** section before changing tasks.

## Conventions
- `[ ]` pending · `[~]` in progress · `[x]` done · `[-]` dropped (add reason inline)
- PLAN.md mirrors milestone-level state; fine-grained tasks live in phase files.
- Flip both the phase line AND the matching milestone when state changes.

## Phases
| # | Status | Plan | One-liner |
|---|--------|------|-----------|
| 1 | `[ ]` | [Unified logging](PLAN_logging.md) | Rust + Dart + native iOS/Android logs → rolling files on device |
| 2 | `[ ]` | [Embedded debug server](PLAN_debug_server.md) | In-app axum HTTP/WS, reachable from Mac via `iproxy 8888 8888` |
| 3 | `[ ]` | [Diagnosis GUI](PLAN_diagnosis_gui.md) | In-app screen: live state, log viewer, operations panel |
| 4 | `[ ]` | [Developer workflow](PLAN_dev_workflow.md) | Scripts + docs for iproxy log streaming from Mac |
| 5 | `[ ]` | [Long-session coaching](PLAN_coaching.md) | All-day BLE session + rule-driven prompts ("stand up", "raise HR to 120") |
| 6 | `[~]` | Background HR monitoring & low-HR alerts | Persistent HR store + configurable low-HR rule → notification + Health screen |

## Progress tracker
Milestone-level rollup. These mirror the big checkpoints inside each phase
file; the per-file tasks are finer-grained.

### Phase 1 — Unified logging
- [x] 1.1 Rust writer refactor (file + broadcast + Flutter-sink share one fanout)
- [x] 1.2 Dart capture (debugPrint hook, `FlutterError.onError`, rolling file writer)
- [x] 1.3 Native iOS log bridge (DEBUG-only stdout/stderr dup → MethodChannel → file)
- [x] 1.4 Native Android log bridge (logcat forward → MethodChannel → file)
- [x] 1.5 Retention sweep (7-day) + acceptance tests pass on device

### Phase 2 — Embedded debug server
- [x] 2.1 Extract `build_router()` from `bin/debug_server.rs` into library module
- [x] 2.2 `api::start_debug_server(port)` spawned on tokio, idempotent, debug-gated
- [x] 2.3 Dart `main()` calls `startDebugServer(8888)` in `kDebugMode` on iOS/Android
- [x] 2.4 Mac → device round-trip verified: `iproxy 8888 8888` + `curl /debug/logs`
- [x] 2.5 Source/level filters (`?source=rust&level=info`) on `/debug/logs` + `/ws/logs`

### Phase 3 — Diagnosis GUI
- [x] 3.1 `/diagnosis` route + skeleton layout
- [x] 3.2 Live log viewer (filter by source/level, color-coded, auto-scroll toggle)
- [x] 3.3 Connection status card (device, connected/scanning, RSSI if available)
- [x] 3.4 Operations panel (scan / connect last / disconnect / mock / export / clear cache)

### Phase 4 — Developer workflow
- [x] 4.1 `scripts/ios-debug-server.sh` (iproxy wrapper: start/stop/status)
- [x] 4.2 `scripts/ios-logs.sh` (REST fetch + WS follow, filters)
- [x] 4.3 CLAUDE.md quickref entry + `brew install libimobiledevice` doc

### Phase 5 — Long-session coaching
- [x] 5.1 iOS background modes (`bluetooth-central`) + Android foreground service for BLE
- [x] 5.2 Robust reconnect loop in Rust (survive drops, throttle retries, battery-aware)
- [x] 5.3 Rule engine (target zone, inactivity timer, cue cadence, do-not-disturb window)
- [x] 5.4 Coaching cue FFI stream + delivery surfaces (in-app toast, local notification, optional TTS)
- [x] 5.5 Coaching screen UI (current cue, live HR vs target band, countdown)
- [x] 5.6 All-day soak test (8h+ on-device) — no disconnect regressions, battery <20% drain

### Phase 6 — Background HR monitoring & low-HR alerts
- [x] 6.1 Persistent HR sample store (Rust JSONL + `samples_in_range` / `rolling_avg` / `latest_sample`)
- [x] 6.2 User settings for monitoring (`HealthSettingsService` + `HealthSettingsScreen`)
- [x] 6.3 Sustained-low-HR alert rule (Rust `low_hr_rule`, hysteresis, quiet-hours suppression)
- [x] 6.4 Health screen (live BPM, 1h/24h/7d averages, 24h sparkline, status banner)
- [ ] 6.5 Manual soak test (4h on-device, threshold 70 / sustained 10 min)

## Cross-cutting decisions
- **Log directory:** `<app_docs>/logs/` (from `path_provider.getApplicationDocumentsDirectory()`).
- **File naming:** `heart-beat-<source>.YYYY-MM-DD.log` (daily rotation, 7-day retention).
- **Sources:** `rust`, `dart`, `native-ios`, `native-android`.
- **Debug server port:** 8888 (matches the standalone `debug-server` binary).
- **Debug-only surface:** the embedded server and native-log capture MUST be
  gated on `kDebugMode` / `#[cfg(debug_assertions)]`. Release builds don't
  open sockets or tee syslog.
- **Single source of truth for logs:** the in-process broadcast channel. Both
  the diagnosis GUI and the HTTP server read from it, so the on-device view
  and the curl output always match.
- **Coaching cues:** emitted by a Rust rule engine; delivered via FFI stream +
  local notifications + optional TTS. One code path, multiple surfaces.

## Dependencies between phases
- Phase 2 depends on Phase 1's broadcast-channel fanout.
- Phase 3 depends on Phase 1's log stream API; can optionally consume Phase 2's
  `/api/*` (not required — FFI works fine).
- Phase 4 depends on Phase 2 being reachable.
- Phase 5 is orthogonal to 1–4 for correctness, but hard to debug without them.
  Do at least 1 + 2 + 4 before deep work on 5.

## Log of major plan changes
- **Initial draft:** Phases 1–5 sketched. No tasks started.
