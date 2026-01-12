# Tasks Document

- [x] 1.1 Create export formatters in Rust
  - File: `rust/src/domain/export.rs`
  - Implement export_to_csv(), export_to_json(), export_to_summary()
  - Purpose: Generate export content
  - _Leverage: CompletedSession type, serde_json_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Rust developer | Task: Create rust/src/domain/export.rs with export_to_csv(session: &CompletedSession) -> String generating CSV with timestamp,bpm,zone,phase columns. Add export_to_json() using serde_json::to_string_pretty(). Add export_to_summary() generating human-readable text summary. | Restrictions: Pure functions, no I/O | Success: All three formats generate correctly_

- [x] 1.2 Add export API functions
  - File: `rust/src/api.rs`
  - Add export_session(id, format) returning content string
  - Add ExportFormat enum
  - Purpose: Expose export to Flutter
  - _Leverage: existing api patterns_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Rust FFI developer | Task: Add ExportFormat enum (Csv, Json, Summary). Add pub async fn export_session(id: String, format: ExportFormat) -> Result<String> that loads session from repository, calls appropriate export function, returns content string. | Restrictions: FRB-compatible types | Success: Flutter can request exports_

- [ ] 2.1 Add share_plus dependency
  - File: `pubspec.yaml`
  - Add share_plus package for native sharing
  - Purpose: Enable platform share sheets
  - _Leverage: Flutter package ecosystem_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Flutter developer | Task: Add share_plus: ^7.0.0 to pubspec.yaml dependencies. Run flutter pub get to verify installation. | Restrictions: Use stable version | Success: Package installs without conflicts_

- [ ] 2.2 Create ShareService
  - File: `lib/src/services/share_service.dart`
  - Wrap share_plus for consistent interface
  - Add shareFile() and shareText() methods
  - Purpose: Centralized share handling
  - _Leverage: share_plus package_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Flutter developer | Task: Create ShareService class with shareText(String text, String subject) using Share.share(), and shareFile(String path, String mimeType) using Share.shareXFiles(). Handle platform differences. | Restrictions: Abstract share_plus dependency | Success: Service shares content correctly_

- [ ] 3.1 Add export buttons to SessionDetailScreen
  - File: `lib/src/screens/session_detail_screen.dart`
  - Add overflow menu with Export CSV, Export JSON, Share Summary
  - Call export API and share
  - Purpose: User access to export
  - _Leverage: PopupMenuButton, ShareService_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Flutter developer | Task: Add PopupMenuButton to AppBar actions with items: Export CSV, Export JSON, Share Summary. On tap, call exportSession() API with format, write content to temp file (CSV/JSON) or share directly (text). Use ShareService. Show loading indicator during export. | Restrictions: Handle errors gracefully | Success: All export options work_

- [ ] 3.2 Add batch export to HistoryScreen
  - File: `lib/src/screens/history_screen.dart`
  - Add multi-select mode for sessions
  - Add "Export All" button when sessions selected
  - Purpose: Bulk export capability
  - _Leverage: existing HistoryScreen_
  - _Requirements: 4_
  - _Prompt: Role: Flutter developer | Task: Add selection mode to HistoryScreen with long-press to enable. Show checkboxes when in selection mode. Add FAB "Export All" when items selected. Export as ZIP containing all selected sessions as JSON. Use archive package. | Restrictions: Show progress for large exports | Success: Multiple sessions exportable at once_

- [ ] 4.1 Add export unit tests
  - File: `rust/src/domain/export.rs` (tests module)
  - Test CSV format correctness
  - Test JSON validity
  - Test summary content
  - Purpose: Validate export formatters
  - _Leverage: existing test patterns_
  - _Requirements: 1, 2, 3_
  - _Prompt: Role: Rust test developer | Task: Add tests module to export.rs. Test export_to_csv produces valid CSV with correct headers. Test export_to_json produces valid JSON parseable back to session. Test export_to_summary includes all summary fields. | Restrictions: Test edge cases (empty HR samples) | Success: All export tests pass_

- [ ] 4.2 Test export on device
  - File: N/A (manual testing)
  - Test all export options on Android
  - Verify share sheet opens correctly
  - Verify exported files are valid
  - Purpose: End-to-end validation
  - _Leverage: adb-install.sh_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: QA Engineer | Task: Build and install APK. Complete a test session. Open session detail, test each export option. Verify: CSV opens in spreadsheet app, JSON is valid, summary text is readable, batch export produces ZIP. | Restrictions: Test on real device | Success: All exports work correctly_
