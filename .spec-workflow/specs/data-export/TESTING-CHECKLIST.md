# Data Export Feature - Device Testing Checklist

## Prerequisites
- Android device connected via USB
- USB debugging enabled
- Device authorized for this computer

## Build and Install
```bash
./scripts/adb-install.sh
```

## Test Scenarios

### 1. CSV Export (SessionDetailScreen)
**Steps:**
1. Open the app and complete a test training session (or use existing session)
2. Navigate to History screen
3. Tap on a completed session to open SessionDetailScreen
4. Tap the overflow menu (three dots) in the app bar
5. Select "Export CSV"
6. Wait for export to complete
7. Choose a target app from the share sheet (e.g., Drive, Gmail, Files)

**Expected Results:**
- ✓ Loading indicator appears during export
- ✓ Share sheet opens with CSV file
- ✓ CSV file can be opened in spreadsheet apps (Google Sheets, Excel)
- ✓ CSV contains correct columns: timestamp, bpm, zone, phase
- ✓ Data matches session values
- ✓ No errors or crashes

### 2. JSON Export (SessionDetailScreen)
**Steps:**
1. From SessionDetailScreen, tap overflow menu
2. Select "Export JSON"
3. Choose target app from share sheet

**Expected Results:**
- ✓ Share sheet opens with JSON file
- ✓ JSON file is valid (can be parsed)
- ✓ JSON contains all session data (metadata, HR samples, zones)
- ✓ Formatting is pretty-printed and readable
- ✓ No errors or crashes

### 3. Summary Export (SessionDetailScreen)
**Steps:**
1. From SessionDetailScreen, tap overflow menu
2. Select "Share Summary"
3. Choose target app (Messages, Email, etc.)

**Expected Results:**
- ✓ Share sheet opens with text content
- ✓ Summary includes: session date, duration, average HR, max HR, training zones
- ✓ Text is human-readable and well-formatted
- ✓ Data is accurate
- ✓ No errors or crashes

### 4. Batch Export (HistoryScreen)
**Steps:**
1. Navigate to History screen
2. Long-press on a session to enable selection mode
3. Checkboxes should appear on all session cards
4. Select 2-3 sessions by tapping them
5. Tap the "Export All" FAB (Floating Action Button)
6. Wait for ZIP creation (progress indicator should show)
7. Choose target app from share sheet

**Expected Results:**
- ✓ Selection mode activates on long-press
- ✓ Checkboxes appear and function correctly
- ✓ "Export All" FAB appears when items are selected
- ✓ Progress indicator shows during ZIP creation
- ✓ Share sheet opens with ZIP file
- ✓ ZIP file contains all selected sessions as JSON files
- ✓ Each JSON file is named appropriately (session ID or date)
- ✓ All JSON files in ZIP are valid
- ✓ No errors or crashes

### 5. Edge Cases
**Test these scenarios:**
- Export a session with no HR data (should handle gracefully)
- Export a very long session (30+ minutes)
- Export immediately after completing a session
- Cancel selection mode without exporting
- Attempt export with no sessions selected (button should be disabled/hidden)

### 6. Error Handling
**Test these scenarios:**
- Trigger export while device storage is full (should show error)
- Cancel share sheet (should return to app without issues)
- Rotate device during export (should maintain state)

## Verification with ADB Logs
While testing, monitor logs for errors:
```bash
./scripts/adb-logs.sh -f export
```

## Success Criteria
All test scenarios pass with:
- ✓ No crashes or exceptions
- ✓ All exported files are valid and contain correct data
- ✓ Share functionality works across different target apps
- ✓ Loading states and progress indicators work correctly
- ✓ Error cases are handled gracefully

## Notes
- Test on actual Android device (not emulator) for best results
- Test with both debug and release builds if possible
- Verify exported files can be imported/opened in external apps
- Check logs for any Rust panics or Flutter exceptions
