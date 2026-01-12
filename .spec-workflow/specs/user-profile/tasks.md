# Tasks Document

- [x] 1.1 Create UserProfile model in Flutter
  - File: `lib/src/models/user_profile.dart`
  - Define UserProfile class with maxHr, age, useAgeBased, customZones
  - Add JSON serialization
  - Purpose: Profile data model
  - _Leverage: existing settings screen max HR logic_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: Flutter developer | Task: Create lib/src/models/user_profile.dart with UserProfile class. Fields: maxHr (int), age (int?), useAgeBased (bool), customZones (CustomZones?). Add CustomZones class with zone1Max through zone4Max (percentages). Add toJson() and fromJson() methods. | Restrictions: Validate in setters | Success: Model serializes correctly_

- [x] 1.2 Create ProfileService
  - File: `lib/src/services/profile_service.dart`
  - Implement singleton with load/save/get methods
  - Use SharedPreferences for persistence
  - Purpose: Profile management
  - _Leverage: existing SharedPreferences usage_
  - _Requirements: 4_
  - _Prompt: Role: Flutter developer | Task: Create ProfileService singleton in lib/src/services/profile_service.dart. Methods: loadProfile() -> UserProfile (from SharedPreferences), saveProfile(UserProfile), getDefaultProfile(). Store as JSON string in SharedPreferences key 'user_profile'. Load on app start. | Restrictions: Thread-safe singleton | Success: Profile persists across restarts_

- [x] 2.1 Add age-based max HR calculator
  - File: `lib/src/models/user_profile.dart`
  - Add calculateMaxHrFromAge(age) method
  - Use formula: 220 - age
  - Purpose: Estimate max HR
  - _Leverage: standard formula_
  - _Requirements: 2_
  - _Prompt: Role: Flutter developer | Task: Add static method calculateMaxHrFromAge(int age) -> int returning 220 - age. Add getter estimatedMaxHr on UserProfile that uses age if useAgeBased is true. | Restrictions: Return null if age not set | Success: Age-based calculation works_

- [x] 2.2 Add zone calculation with custom zones
  - File: `lib/src/services/profile_service.dart`
  - Add getZoneForBpm(bpm) using profile zones
  - Support both default and custom zones
  - Purpose: Zone calculation
  - _Leverage: existing Zone enum_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Add getZoneForBpm(int bpm) -> Zone method to ProfileService. If customZones set, use custom thresholds. Otherwise use defaults (50/60/70/80/90%). Calculate thresholds from effective maxHr (actual or age-based). | Restrictions: Return Zone enum | Success: Correct zone returned_

- [ ] 3.1 Enhance SettingsScreen with profile editing
  - File: `lib/src/screens/settings_screen.dart`
  - Add age input with max HR estimation toggle
  - Show calculated zones based on settings
  - Purpose: Complete profile UI
  - _Leverage: existing settings screen_
  - _Requirements: 1, 2_
  - _Prompt: Role: Flutter developer | Task: Enhance settings_screen.dart: Add age TextField, Switch for "Use age-based max HR", show estimated max HR when enabled. Display current zones as colored bars with BPM ranges. Save to ProfileService on change. | Restrictions: Maintain existing max HR field | Success: Profile editable in settings_

- [ ] 3.2 Add custom zone editor
  - File: `lib/src/screens/zone_editor_screen.dart`
  - Slider-based zone threshold editor
  - Validate no overlap
  - Purpose: Advanced zone customization
  - _Leverage: RangeSlider widget_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Create ZoneEditorScreen with 4 Sliders for zone boundaries (zone1Max through zone4Max). Show visual preview of zones as colored bars. Validate ascending order. Save button calls ProfileService.saveProfile(). Access from SettingsScreen. | Restrictions: Clear visual feedback | Success: Custom zones configurable_

- [ ] 4.1 Integrate profile with zone displays
  - File: `lib/src/widgets/zone_indicator.dart`
  - Use ProfileService for zone calculation
  - Purpose: Profile-aware zone display
  - _Leverage: existing zone_indicator.dart_
  - _Requirements: 1, 3_
  - _Prompt: Role: Flutter developer | Task: Update zone_indicator.dart to get zone from ProfileService.getZoneForBpm() instead of hardcoded thresholds. Ensure zone colors match profile-based calculation. | Restrictions: Don't break existing display | Success: Zone indicator uses profile_

- [ ] 4.2 Add profile unit tests
  - File: `test/services/profile_service_test.dart`
  - Test profile save/load
  - Test zone calculation with custom zones
  - Test age-based max HR
  - Purpose: Validate profile logic
  - _Leverage: flutter_test_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: Flutter test developer | Task: Create test/services/profile_service_test.dart. Test: default profile creation, save/load round-trip, zone calculation with default thresholds, zone calculation with custom thresholds, age-based max HR calculation. Use mock SharedPreferences. | Restrictions: Isolated tests | Success: All profile tests pass_
