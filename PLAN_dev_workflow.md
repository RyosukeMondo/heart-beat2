# Plan 4 — Developer Workflow (iproxy + log tooling)

**Status:** not started
**Owner:** —
**Parent:** [PLAN.md](PLAN.md)
**Depends on:** Phase 2 (server must be running in-app)

## Goal
One-line commands to stream device logs or query the embedded debug server
from a Mac. Zero-friction onboarding for a new dev / fresh machine.

## Context
- `iproxy` ships with `libimobiledevice` — already installed on this machine.
- `websocat` may or may not be installed on contributors' machines; script
  should fall back to `wscat` (npm) or print an install hint.

## Tasks

### Scripts
- [ ] `scripts/ios-debug-server.sh`
  - `start` → runs `iproxy 8888 8888` in the background, writes pidfile to
    `.cache/ios-debug-server.pid`.
  - `stop` → kills the pid.
  - `status` → prints pid, running state, and a probe of
    `curl -sf http://localhost:8888/healthz || echo "server not responding"`.
- [ ] `scripts/ios-logs.sh`
  - Flags: `--source=rust|dart|native|all` `--level=info|debug|warn|error`
    `--limit=N` `--follow`
  - Without `--follow`: `curl http://localhost:8888/debug/logs?...` and
    pretty-prints with `jq` (install hint if missing).
  - With `--follow`: `websocat ws://localhost:8888/ws/logs` piped through
    a small color/filter awk helper.
  - Fails loud and helpful if `iproxy` isn't running ("run
    `./scripts/ios-debug-server.sh start` first").

### Docs
- [ ] CLAUDE.md quickref row:
      ```
      | iOS USB debug logs | `./scripts/ios-debug-server.sh start && ./scripts/ios-logs.sh --follow` |
      ```
- [ ] `docs/DEVELOPER-GUIDE.md`: new section "Streaming iOS device logs over
      USB" with install steps (`brew install libimobiledevice websocat jq`)
      and a troubleshooting block.

### Nice-to-have (not blocking phase close)
- [ ] `scripts/ios-diag-bundle.sh` — downloads current log files and last
      session export via the REST API into `./tmp/diag/$(date +%s)/`.

## Acceptance criteria
- [ ] From a clean shell on the Mac, connected to the phone, with a debug
      build running: `./scripts/ios-debug-server.sh start && ./scripts/ios-logs.sh --follow`
      streams live lines.
- [ ] `./scripts/ios-logs.sh --source=rust --level=error` returns recent
      Rust errors as JSON.
- [ ] Running `--follow` with the server stopped prints a clear actionable
      error and exits non-zero.

## Notes / gotchas
- `iproxy` forwards Mac-side `localhost:8888` → device-side `localhost:8888`.
  Make sure scripts always talk to `localhost`, never `0.0.0.0` (which won't
  traverse the USB mux).
- If the user has multiple iOS devices, `iproxy -u <UDID>` is required —
  default picks one arbitrarily. Pass `--udid` through the script.

## Resume notes
- Phase 4 can start in parallel with Phase 2 — script the expected interface
  first, test against the standalone `debug-server` binary over TCP on
  localhost while the embedded version is still being built.
