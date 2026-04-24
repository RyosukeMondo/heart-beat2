# Plan 1 — Unified Logging (3 sources → rolling files)

**Status:** not started
**Owner:** —
**Parent:** [PLAN.md](PLAN.md)

## Goal
Every log line from Rust backend, native platform code (Swift/Kotlin), and
Dart frontend lands in rolling files on-device AND feeds the same in-process
broadcast channel that Phase 2 will serve over HTTP/WS.

## Context (as of draft)
- Rust: `api::init_logging` (`rust/src/api.rs:358`) pipes to a Dart StreamSink
  via `FlutterLogWriter`. No file writing on the mobile path. File rotation +
  broadcast channel exist only in `init_server_logging`
  (`rust/src/logging.rs:173`) used by the standalone `debug-server` binary.
- Dart: `lib/src/services/log_service.dart` exists — behaviour unclear,
  needs an audit before extending.
- Native iOS: no capture — Swift `print` / `os_log` goes to syslog only.
- Native Android: no capture — relies on logcat.

## Tasks

### Rust (backend)
- [ ] Audit `rust/src/logging.rs` and `rust/src/api.rs:init_logging`; sketch
      a unified writer composition (stderr + file + broadcast + optional
      Flutter-sink) that both mobile and server share.
- [ ] Extend `api::init_logging(sink, log_dir: Option<String>)` — when
      `log_dir` is present, compose a file-rotating writer alongside the
      Flutter sink. Dart always passes the app docs dir on mobile.
- [ ] Ensure the mobile path populates the broadcast ring buffer that backs
      `logging::get_recent_logs` (required for Phase 2).
- [ ] Add a 7-day retention sweep at init: delete files older than N days.
- [ ] Unit test: emit one line, assert it appears in ring buffer AND in the
      dated file.
- [ ] Keep the `init_server_logging` path working (CLI + standalone binary).
      Confirm no double-init of the global subscriber.

### Dart (frontend)
- [ ] Audit `lib/src/services/log_service.dart` — decide extend vs replace.
- [ ] Install `FlutterError.onError` + `PlatformDispatcher.instance.onError`
      hooks to capture uncaught exceptions into logs.
- [ ] Wrap `debugPrint` so Dart-side prints route through the log service.
- [ ] Dart log writer: `<app_docs>/logs/heart-beat-dart.YYYY-MM-DD.log` with a
      simple daily cutover. Append-only, line-buffered, fsync on crash hook.
- [ ] Widget test: `debugPrint("x"); await logSvc.flush();` → assert line in
      file.

### Native iOS
- [ ] `ios/Runner/LogBridge.swift`: in `#if DEBUG`, dup2 `stdout`/`stderr` to
      a pipe; spawn a read-loop that forwards each line over a MethodChannel
      `heart_beat/native_log`.
- [ ] Register the channel in `AppDelegate.swift`.
- [ ] Dart handler routes incoming lines into the Dart log writer but to a
      separate file: `heart-beat-native-ios.YYYY-MM-DD.log`.
- [ ] Manual check: `NSLog("hello")` in Swift → shows up in the ios file.

### Native Android
- [ ] `android/app/src/main/kotlin/.../LogBridge.kt`: in debug builds, run
      `logcat -v threadtime --pid=$pid` and forward lines over MethodChannel.
- [ ] Mirror the Dart side; writes to `heart-beat-native-android.YYYY-MM-DD.log`.
- [ ] Manual check: `Log.i("hb", "hello")` → shows up in the android file.

### File layout
- [ ] Directory: `<app_docs>/logs/`
- [ ] Files: `heart-beat-{rust,dart,native-ios,native-android}.YYYY-MM-DD.log`
- [ ] Retention sweep on app start: delete files older than 7 days.

## Acceptance criteria
- [ ] On iPhone: open app → scan → kill → inspect all 4 source files present
      with today's events.
- [ ] A Rust panic is captured in the rust file (panic hook already exists;
      confirm it tees into the broadcast writer).
- [ ] An uncaught Dart exception lands in the dart file.

## Notes / gotchas
- `tracing::subscriber::set_global_default` may only be set once per process.
  The refactor must keep that invariant under both mobile-only and
  server+mobile init paths.
- Release builds MUST NOT dup2 stdout/stderr — that breaks anything reading
  pipes and has weird interactions with crash reporters.
- If the device docs dir is on iCloud-synced storage, be aware of latency
  spikes. `getApplicationDocumentsDirectory()` on iOS is app-container local,
  so this should be fine — double-check on first deploy.

## Resume notes
- Start with the Rust audit task. The writer composition is the keystone —
  Phase 2 and Phase 3 both depend on it.
