# Tasks Document

- [ ] 1.1 Create adb-logs.sh script
  - File: `scripts/adb-logs.sh`
  - Clear logcat and show filtered output
  - Filter for heart_beat, flutter, btleplug, BluetoothGatt
  - Add color coding for log levels
  - Purpose: Easy log viewing during Android development
  - _Leverage: existing ble-*.sh scripts for patterns_
  - _Requirements: 1_
  - _Prompt: Implement the task for spec android-debug-scripts, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/adb-logs.sh that: 1) checks for connected device, 2) clears logcat with adb logcat -c, 3) shows filtered logs with grep for heart_beat|flutter|btleplug|BluetoothGatt. Add --follow flag for continuous output. Use color codes for ERROR (red), WARN (yellow), INFO (green). | Restrictions: Bash only, no external dependencies | Success: Script shows filtered, colored logs | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.2 Create adb-install.sh script
  - File: `scripts/adb-install.sh`
  - Build debug APK using build-android.sh
  - Install APK to connected device
  - Launch app after install
  - Purpose: One-command Android deploy
  - _Leverage: build-android.sh_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec android-debug-scripts, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/adb-install.sh that: 1) checks for connected device, 2) sets ANDROID_NDK_HOME and calls ./build-android.sh --debug, 3) runs adb install -r on the APK, 4) launches app with adb shell am start. Add --release flag option. Show progress with colors. | Restrictions: Reuse build-android.sh, don't duplicate build logic | Success: Script builds, installs, and launches app | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.3 Create adb-permissions.sh script
  - File: `scripts/adb-permissions.sh`
  - Show app permissions via dumpsys
  - Highlight Bluetooth-related permissions
  - Purpose: Diagnose permission issues
  - _Leverage: adb shell dumpsys package_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec android-debug-scripts, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/adb-permissions.sh that runs adb shell dumpsys package com.example.heart_beat and filters for granted permissions. Highlight BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION with colors. Show granted=true vs granted=false status. | Restrictions: Use dumpsys, parse output with grep/awk | Success: Script shows clear permission status | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.4 Create adb-ble-debug.sh script
  - File: `scripts/adb-ble-debug.sh`
  - Enable/disable HCI snoop logging
  - Restart Bluetooth service
  - Purpose: Low-level BLE debugging
  - _Leverage: adb shell settings commands_
  - _Requirements: 4_
  - _Prompt: Implement the task for spec android-debug-scripts, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/adb-ble-debug.sh with subcommands: enable, disable, status. Use adb shell settings put secure bluetooth_hci_log 1/0. Restart Bluetooth with adb shell svc bluetooth disable/enable. Show current status and instructions for viewing HCI logs. | Restrictions: Requires USB debugging enabled | Success: Script toggles BLE debug mode | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.5 Test all scripts with Pixel 9a
  - File: N/A (testing)
  - Test each script with connected device
  - Verify error handling
  - Purpose: Validate scripts work correctly
  - _Leverage: connected Pixel 9a_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Implement the task for spec android-debug-scripts, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Test all adb-*.sh scripts with connected Pixel 9a: 1) adb-logs.sh shows filtered logs, 2) adb-install.sh builds and deploys, 3) adb-permissions.sh shows permissions, 4) adb-ble-debug.sh toggles BLE debug. Test error cases (disconnect device, etc.). | Restrictions: Test on real device | Success: All scripts work as documented | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_
