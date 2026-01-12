# Workout Execution - End-to-End Test Report

**Date:** 2026-01-12
**Task:** 5.1 Test workout flow end-to-end
**Status:** Automated validation completed, manual device testing required

---

## Automated Validation Results ✓

### 1. Code Compilation
- **Status:** ✓ PASSED
- **Details:** Rust project builds successfully without errors
- **Command:** `cargo build`
- **Result:** `Finished dev profile [unoptimized + debuginfo] target(s) in 7.91s`

### 2. Unit Test Suite
- **Status:** ✓ PASSED (154/154 tests)
- **Details:** All Rust unit tests pass, including:
  - Session state machine tests
  - Phase progression tests
  - Zone tracking tests
  - Pause/resume functionality tests
  - Session persistence tests
  - API integration tests

Key test results relevant to workout execution:
- `test_session_start` - ✓
- `test_session_phase_progression` - ✓
- `test_session_pause_resume` - ✓
- `test_session_manual_stop` - ✓
- `test_session_completion` - ✓
- `test_zone_tracker_too_high` - ✓
- `test_zone_tracker_too_low` - ✓
- `test_zone_tracker_return_to_zone` - ✓
- `test_get_progress` - ✓
- `test_session_persistence_save_and_load` - ✓

### 3. Training Plan Availability
- **Status:** ✓ VERIFIED
- **Available Plans:** 1 plan found
  - `tempo-run.json` (5K Tempo Run)
  - 3 phases: Warmup (Zone2, 10min) → Tempo (Zone3, 20min) → Cooldown (Zone1, 10min)
  - Total duration: 40 minutes
  - Max HR: 180 bpm

---

## Manual Testing Required ⚠️

The following tests **MUST be performed on a physical Android device** with a Bluetooth heart rate monitor to complete task 5.1:

### Prerequisites
- Android device with USB debugging enabled
- Bluetooth heart rate monitor (e.g., Polar H10, Wahoo TICKR)
- Device paired and ready
- Build APK: `./scripts/adb-install.sh`

### Test Checklist

#### 1. Workout Start Flow
- [ ] Launch Heart Beat app
- [ ] Navigate to Session screen
- [ ] Tap "Start Workout" button
- [ ] Verify plan selector bottom sheet appears
- [ ] Select "5K Tempo Run" from the list
- [ ] Verify navigation to WorkoutScreen
- [ ] Verify HR monitor connects automatically
- [ ] Verify workout starts in "Warmup" phase

**Expected:** Smooth navigation, immediate HR connection, clear phase display

#### 2. Phase Transitions
- [ ] Observe workout during Warmup phase (10 minutes)
- [ ] Verify phase progress bar advances
- [ ] Verify time remaining counts down
- [ ] Observe automatic transition from Warmup → Tempo
- [ ] Verify notification/feedback on phase transition
- [ ] Observe Tempo phase (20 minutes)
- [ ] Observe automatic transition from Tempo → Cooldown
- [ ] Verify final Cooldown phase (10 minutes)

**Expected:** Automatic phase transitions at correct times, visual feedback on transitions

#### 3. Zone Feedback
Test zone deviation feedback by intentionally moving out of target zones:

**Warmup Phase (Target: Zone 2)**
- [ ] Maintain HR in Zone 2 → Verify no zone feedback overlay
- [ ] Let HR drop to Zone 1 (too low) → Verify "SPEED UP" blue overlay with up arrow
- [ ] Increase HR back to Zone 2 → Verify overlay disappears
- [ ] Increase HR to Zone 3 (too high) → Verify "SLOW DOWN" red overlay with down arrow
- [ ] Decrease HR back to Zone 2 → Verify overlay disappears

**Tempo Phase (Target: Zone 3)**
- [ ] Maintain HR in Zone 3 → Verify no zone feedback overlay
- [ ] Let HR drop to Zone 2 (too low) → Verify "SPEED UP" overlay
- [ ] Return to Zone 3 → Verify overlay disappears
- [ ] Increase HR to Zone 4 (too high) → Verify "SLOW DOWN" overlay
- [ ] Return to Zone 3 → Verify overlay disappears

**Expected:** Immediate visual feedback when HR deviates from target zone, feedback disappears when back in zone

#### 4. Session Controls - Pause/Resume
- [ ] During active workout, tap Pause button
- [ ] Verify workout pauses (timer stops, no phase progression)
- [ ] Verify HR continues to display live data
- [ ] Wait 30 seconds
- [ ] Tap Resume button
- [ ] Verify workout resumes from paused time (no time lost)
- [ ] Verify phase progression continues
- [ ] Verify remaining time is accurate

**Expected:** Pause stops time tracking but not HR monitoring, resume continues exactly where paused

#### 5. Session Controls - Stop with Confirmation
- [ ] During active workout, tap Stop button
- [ ] Verify confirmation dialog appears with message
- [ ] Tap Cancel on dialog
- [ ] Verify workout continues (not stopped)
- [ ] Tap Stop button again
- [ ] Tap Confirm on dialog
- [ ] Verify workout stops immediately
- [ ] Verify return to previous screen

**Expected:** Stop requires confirmation, cancel returns to workout, confirm stops and saves

#### 6. Session Persistence
After completing stop test above:
- [ ] Navigate to session history/logs
- [ ] Verify stopped session appears in history
- [ ] Verify session data saved correctly:
  - Workout name: "5K Tempo Run"
  - Duration: Time from start to stop
  - Phases completed: Partial workout
  - HR data: Captured samples
- [ ] Verify session can be viewed in detail

**Expected:** Session saved even when stopped early, all data preserved

#### 7. Complete Workout Flow
- [ ] Start a fresh "5K Tempo Run" workout
- [ ] Complete all 3 phases (40 minutes total)
- [ ] Verify workout completes automatically after Cooldown
- [ ] Verify completion notification/feedback
- [ ] Verify automatic return to session screen or completion screen
- [ ] Verify completed session saved in history
- [ ] Verify session marked as "Completed" (not stopped)

**Expected:** Full workout completion, clear completion feedback, saved as complete

#### 8. Real-Time Updates
Throughout all tests above, verify:
- [ ] HR updates at least once per second
- [ ] Phase progress bar animates smoothly
- [ ] Time remaining updates every second
- [ ] Zone status reflects real-time HR
- [ ] UI remains responsive during workout

**Expected:** Smooth 1Hz updates, no lag or freezing

#### 9. Edge Cases
- [ ] Start workout, let HR monitor disconnect during workout → Verify reconnection or appropriate error handling
- [ ] Start workout, put app in background → Verify workout continues
- [ ] Return to app → Verify UI updates with current state
- [ ] Start workout, rotate device → Verify landscape layout works
- [ ] Battery low scenario → Verify workout can continue

**Expected:** Robust handling of disconnections, background operation, orientation changes

---

## Test Configuration

**Test Plan Used:** `tempo-run.json`
```json
{
  "name": "5K Tempo Run",
  "phases": [
    {"name": "Warmup", "target_zone": "Zone2", "duration_secs": 600},
    {"name": "Tempo", "target_zone": "Zone3", "duration_secs": 1200},
    {"name": "Cooldown", "target_zone": "Zone1", "duration_secs": 600}
  ],
  "max_hr": 180
}
```

**Zone Calculations (Max HR: 180)**
- Zone 1 (Recovery): 90-108 bpm (50-60%)
- Zone 2 (Endurance): 108-126 bpm (60-70%)
- Zone 3 (Tempo): 126-144 bpm (70-80%)
- Zone 4 (Threshold): 144-162 bpm (80-90%)
- Zone 5 (VO2 Max): 162-180 bpm (90-100%)

---

## Known Issues / Observations

*(To be filled during manual testing)*

---

## Test Execution Instructions

### Build and Deploy
```bash
# Connect Android device via USB
# Enable USB debugging on device

# Build and install
./scripts/adb-install.sh

# Monitor logs during testing
./scripts/adb-logs.sh

# If BLE debugging needed
./scripts/adb-ble-debug.sh enable
```

### Testing Tips
1. Use a short test plan initially to verify flow quickly
2. Test with real HR monitor for authentic zone feedback
3. Keep logcat open to catch any errors
4. Test in both portrait and landscape orientations
5. Ensure device stays awake during workout (adjust screen timeout)

---

## Sign-off

**Automated Validation:** ✓ Complete
**Manual Device Testing:** ⚠️ Pending (requires physical device + HR monitor)

**Next Steps:**
1. Connect Android device
2. Pair Bluetooth HR monitor
3. Execute manual test checklist
4. Document results and any issues found
5. Mark task 5.1 as complete when all tests pass
