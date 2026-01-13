# Reconnection Handling - Manual Test Plan

## Test Objective
Validate end-to-end reconnection functionality with real Coospo HW9 heart rate monitor on Android device.

## Prerequisites
- Android device with USB debugging enabled
- Coospo HW9 heart rate monitor (charged and ready)
- Physical space to test connection range (>10m)
- Development machine connected to Android device

## Test Setup

### 1. Build and Deploy Application
```bash
# Connect Android device via USB
# Ensure USB debugging is enabled and authorized

# Build and install debug APK
./scripts/adb-install.sh

# Verify app launches successfully
```

### 2. Start Log Monitoring
```bash
# In a separate terminal, monitor Rust logs
./scripts/adb-logs.sh -f
```

## Test Cases

### TC-1: Normal Connection Flow (Baseline)
**Objective:** Verify normal connection works before testing reconnection

**Steps:**
1. Launch Heart Beat app
2. Navigate to device pairing/connection screen
3. Select Coospo HW9 from device list
4. Tap "Connect"

**Expected Results:**
- ✓ Connection banner shows "Connecting..."
- ✓ Device connects successfully
- ✓ Connection banner shows "Connected" briefly then disappears
- ✓ Heart rate data displays correctly

**Logs to Check:**
- `ConnectionStatus::Connecting` emitted
- `ConnectionStatus::Connected` emitted with device_id

---

### TC-2: Reconnection with Successful Recovery
**Objective:** Verify automatic reconnection when device returns to range

**Steps:**
1. Connect to Coospo HW9 (use TC-1)
2. Start a workout session
3. Note the current heart rate and session time
4. Move the phone >10 meters away from the HR monitor (or vice versa)
5. Wait for disconnect to be detected
6. Observe reconnection attempts
7. Return phone to within range of HR monitor
8. Wait for reconnection

**Expected Results:**
- ✓ Connection banner appears showing "Reconnecting... (attempt 1/5)"
- ✓ Workout session pauses automatically
- ✓ Session timer stops incrementing
- ✓ Banner updates with attempt count: 2/5, 3/5, etc.
- ✓ Delay increases exponentially (1s, 2s, 4s, 8s, 16s)
- ✓ Upon returning to range, device reconnects
- ✓ Banner shows "Connected" briefly
- ✓ Workout session resumes automatically
- ✓ Session timer continues from paused time
- ✓ Heart rate data resumes flowing

**Logs to Check:**
```
ConnectionStatus::Disconnected
ConnectionStatus::Reconnecting { attempt: 1, max_attempts: 5 }
SessionExecutor: pause_session() called (reason: reconnection)
ConnectionStatus::Reconnecting { attempt: 2, max_attempts: 5 }
... (attempts increase)
ConnectionStatus::Connected { device_id: "..." }
SessionExecutor: resume_session() called
```

**Timing to Verify:**
- Attempt 1: ~1 second delay
- Attempt 2: ~2 seconds delay
- Attempt 3: ~4 seconds delay
- Attempt 4: ~8 seconds delay
- Attempt 5: ~16 seconds delay (capped at max_delay)

---

### TC-3: Reconnection Failure (Max Attempts Exceeded)
**Objective:** Verify behavior when device cannot reconnect after max attempts

**Steps:**
1. Connect to Coospo HW9 (use TC-1)
2. Start a workout session
3. Move phone far away from HR monitor (>10m)
4. Keep devices separated until all reconnection attempts fail
5. Observe final banner state

**Expected Results:**
- ✓ Connection banner shows "Reconnecting... (attempt 1/5)" through "Reconnecting... (attempt 5/5)"
- ✓ Workout session pauses
- ✓ After 5 attempts (~31 seconds total), banner shows "Connection lost - Retry"
- ✓ Session remains paused
- ✓ "Retry" button is visible and functional

**Logs to Check:**
```
ConnectionStatus::Disconnected
ConnectionStatus::Reconnecting { attempt: 1, max_attempts: 5 }
... (up to attempt 5)
ConnectionStatus::ReconnectFailed { reason: "Max reconnection attempts exceeded" }
SessionExecutor: session remains paused
```

---

### TC-4: Manual Retry After Failed Reconnection
**Objective:** Verify manual retry functionality

**Steps:**
1. Continue from TC-3 (after reconnection failure)
2. Return phone to within range of HR monitor
3. Tap "Retry" button on the banner

**Expected Results:**
- ✓ New reconnection attempt starts
- ✓ Banner shows "Reconnecting... (attempt 1/5)"
- ✓ Device reconnects successfully
- ✓ Session resumes
- ✓ Heart rate data resumes

---

### TC-5: User-Initiated Pause vs. Reconnection Pause
**Objective:** Verify session doesn't auto-resume if user manually paused

**Steps:**
1. Connect to Coospo HW9 (use TC-1)
2. Start a workout session
3. Manually pause the session using app's pause button
4. Move phone away to trigger disconnect
5. Observe reconnection behavior
6. Return phone to range and wait for reconnect

**Expected Results:**
- ✓ Session remains paused (user paused it)
- ✓ Reconnection banner still shows reconnection attempts
- ✓ Device reconnects successfully
- ✓ Session does NOT auto-resume (remains in user-paused state)
- ✓ User must manually resume session

**Logs to Check:**
```
SessionExecutor: pause_session() called (reason: user_action)
ConnectionStatus::Reconnecting
ConnectionStatus::Connected
SessionExecutor: resume_session() NOT called (reason: user_paused)
```

---

### TC-6: Multiple Screens Show Connection Status
**Objective:** Verify connection banner appears on relevant screens

**Steps:**
1. Connect to Coospo HW9
2. Navigate to workout_screen.dart
3. Trigger disconnect
4. Observe banner on workout screen
5. Navigate to session_screen.dart
6. Observe banner on session screen

**Expected Results:**
- ✓ Connection banner appears at top of workout_screen.dart
- ✓ Connection banner appears at top of session_screen.dart
- ✓ Banner does not obstruct critical UI elements
- ✓ Banner state is consistent across screens

---

## Success Criteria

All test cases must pass with the following verified:
- [x] Connection banner displays correct status
- [x] Reconnection attempts increase from 1 to 5
- [x] Exponential backoff timing is correct (1s, 2s, 4s, 8s, 16s)
- [x] Session pauses on disconnect/reconnecting
- [x] Session resumes on reconnect (only if not user-paused)
- [x] Manual retry works after failure
- [x] UI is responsive and non-intrusive

## Test Log Template

```
### Test Execution: [Date/Time]
**Tester:** [Your Name]
**Device:** [Android Device Model]
**HR Monitor:** Coospo HW9

#### TC-1: Normal Connection
- Result: PASS / FAIL
- Notes:

#### TC-2: Reconnection Success
- Result: PASS / FAIL
- Reconnection Time: [X seconds]
- Notes:

#### TC-3: Reconnection Failure
- Result: PASS / FAIL
- Total Time to Failure: [X seconds]
- Notes:

#### TC-4: Manual Retry
- Result: PASS / FAIL
- Notes:

#### TC-5: User Pause vs Auto Pause
- Result: PASS / FAIL
- Notes:

#### TC-6: Multiple Screens
- Result: PASS / FAIL
- Notes:

#### Overall Result: PASS / FAIL
#### Issues Found:
1. [Issue description if any]

#### Recommendations:
1. [Any improvements needed]
```

## Troubleshooting

### Device Won't Connect
- Ensure Bluetooth is enabled on Android device
- Check HR monitor battery
- Verify HR monitor is not paired with another device
- Try `./scripts/adb-ble-debug.sh enable` to enable HCI snoop logging

### Logs Not Showing
- Verify `./scripts/adb-logs.sh -f` is running
- Check log level: `RUST_LOG=heart_beat=debug`
- Use `./scripts/adb-logs.sh --all` for verbose output

### App Crashes
- Check full logs: `./scripts/adb-logs.sh --all`
- Look for panics or errors in Rust code
- Verify all previous tasks were completed correctly

## Next Steps After Testing

1. Document test results in this file or create a new test report
2. Fix any bugs discovered during testing
3. Mark task 5.2 as complete in tasks.md
4. Create implementation log entry for task 5.2
5. Commit all changes to git
