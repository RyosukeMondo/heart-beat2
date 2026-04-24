# Plan 5 — Long-Session Coaching (the product)

**Status:** not started
**Owner:** —
**Parent:** [PLAN.md](PLAN.md)
**Depends on:** Phases 1, 2, 4 strongly recommended for debuggability

## Goal
User wears a HR strap and leaves the app running for **hours, ideally an
entire day**. The app observes HR continuously and issues timely coaching
cues such as:
- *"Stand up and walk for 2 minutes."*
- *"Raise heart rate to 120 bpm."*
- *"Cool down — target 90 bpm."*
- *"You've been above 150 for 8 min, ease off."*

Cues surface in-app (visual + optional TTS) and via local notifications when
the app is backgrounded / the screen is off.

## Context (what we have today)
- HR + battery + connection status streams exist in Rust
  (`rust/src/api.rs`: `create_hr_stream`, `create_battery_stream`,
  `create_connection_status_stream`).
- Reconnect logic exists in `rust/src/state/connectivity.rs` (coverage report
  visible in `rust/coverage/cobertura.xml`). How robust it is under real-world
  drops for hours is unknown — needs soak testing.
- No rule engine, no coaching cue stream, no local notification plumbing,
  no background-mode configuration, no TTS.

## Tasks

### 5.1 Platform backgrounding
- [ ] iOS: add `bluetooth-central` to `UIBackgroundModes` in
      `ios/Runner/Info.plist`. Verify BLE events keep arriving after 30 min
      of screen-off.
- [ ] iOS: audit what the app does when iOS wakes us briefly for BLE events —
      any allocation must be minimal (no Dart isolate startup per wake).
- [ ] Android: implement a **foreground service** hosting the BLE session
      (persistent notification with current HR + zone). Without this Android
      will reap BLE after a few minutes in background.
- [ ] Android: WakeLock hygiene — do NOT hold a full wake lock; rely on the
      BLE stack's waking behaviour.

### 5.2 Reconnect robustness (Rust)
- [ ] Audit `rust/src/state/connectivity.rs` — enumerate current reconnect
      states, backoff values, and what triggers "give up".
- [ ] Add jittered exponential backoff (2s → 30s cap) with max-attempts = ∞
      during an active coaching session.
- [ ] On disconnect, mark the HR as "stale" in downstream streams (tag with
      `stale: true` so the rule engine knows not to act on old data).
- [ ] Integration test: simulate a 5-min BLE drop mid-session; expect
      auto-reconnect and a single "connection lost" / "reconnected" cue pair.

### 5.3 Rule engine
- [ ] New module `rust/src/coaching/` with a pluggable rule API:
      ```rust
      trait Rule {
          fn evaluate(&mut self, sample: &HrSample, ctx: &Ctx) -> Option<Cue>;
      }
      ```
- [ ] Initial rules:
  - `TargetZoneRule { low, high }` — fire "raise HR to X" / "cool down" when
    outside the band for >30s.
  - `InactivityRule { idle_bpm_threshold, idle_duration }` — fire "stand up"
    when HR stays below threshold too long.
  - `OverworkRule { upper_bpm, max_duration }` — fire "ease off" when above
    upper for too long.
- [ ] Cue cadence throttling: don't repeat the same cue within N minutes.
- [ ] Do-not-disturb window: no audio/notification cues 22:00–07:00 by
      default, configurable.
- [ ] Unit tests: fixture HR sequences → expected cue sequences.

### 5.4 Cue delivery
- [ ] Rust: `api::create_coaching_cue_stream() -> Stream<Cue>` via frb.
- [ ] Dart side consumer routes each cue to:
  - In-app: toast/snackbar + optional animated banner on the coaching screen.
  - Local notification: `flutter_local_notifications` package (iOS + Android).
  - TTS (optional, opt-in): `flutter_tts` speaks the cue aloud.
- [ ] User preference toggles: enable notifications, enable TTS, choose voice.

### 5.5 Coaching screen UI
- [ ] New route `/coaching` (primary screen when a session is active).
- [ ] Current HR (large, live).
- [ ] Target HR band visualization (horizontal gauge or zone dial).
- [ ] Current cue card at top ("Raise HR to 120 — you're at 98").
- [ ] Session timer + time-in-zone stats.
- [ ] Pause / Stop controls.

### 5.6 All-day soak test
- [ ] Write `scripts/soak-coaching.sh` that runs mock mode in the debug
      server for 8h, feeds synthetic HR patterns, and logs cue timing.
- [ ] On-device: full 8h run with real strap. Measure:
  - BLE disconnect count
  - App cold-restart count (should be 0)
  - Battery drain (target < 20% on iPhone 16e with screen off)
  - Number of cues fired and their appropriateness (manual review)
- [ ] Fix whichever metric breaks.

## Acceptance criteria
- [ ] 8h continuous session on iPhone 16e with a real HR strap, screen off
      most of the time, no cold restarts, battery drop < 20%.
- [ ] At least three distinct cue types fired during the test and surfaced
      via notification when app was backgrounded.
- [ ] Reconnect after a forced 5-min BLE outage yields a clean
      "reconnected" cue and resumes rule evaluation.

## Notes / gotchas
- iOS state restoration for CoreBluetooth — if we need cold-wake on BLE
  events, `bluetoothCentralManager(... restoredState:)` has to be wired.
  Decide early whether that's needed; for the "app always in foreground or
  recent background" case, it isn't.
- Battery: HR sampling rate is dictated by the strap's notification cadence
  (typically 1 Hz), so we can't downsample — focus battery effort on avoiding
  Dart isolate churn and keeping the rule engine O(1) per sample.
- Privacy: HR is biometric data. Logging it to files (Phase 1) is fine for
  debug builds; release builds must not persist HR to disk without explicit
  user consent.
- Android foreground service requires a user-facing notification that can't
  be dismissed — make the notification actually useful (live HR + zone).

## Resume notes
- Start with 5.1 + 5.2 in parallel. Without background survival AND
  reconnect robustness, nothing else in this phase matters.
