# Tasks Document

## Phase 2: Biofeedback Enhancement - Audio Notifications

Implement audio feedback for heart rate zone deviations as documented in product.md ("Audio/visual notifications when heart rate deviates from target zone").

- [x] 1. Research Flutter audio packages
  - File: pubspec.yaml (for dependency selection)
  - Evaluate audioplayers, just_audio, or flutter_tts packages
  - Consider: background playback, low latency, Android compatibility
  - Decide between sound effects vs text-to-speech approach
  - Purpose: Select appropriate audio solution for biofeedback
  - _Leverage: Flutter package ecosystem research_
  - _Requirements: product.md biofeedback loop feature_
  - _Prompt: Role: Flutter Developer specializing in audio | Task: Research and evaluate Flutter audio packages for real-time biofeedback notifications, considering latency, background playback, and Android compatibility | Restrictions: Must work reliably during workout, low latency critical, battery efficient | Success: Package selected with clear rationale, compatible with foreground service, meets latency requirements_
  - **Decision**: Selected `audioplayers` v6.5.1 for superior Android audio quality, lower latency, and simpler API suited for short sound effects playback

- [x] 2. Add audio package dependency
  - File: pubspec.yaml
  - Add selected audio package (e.g., audioplayers or just_audio)
  - Run flutter pub get to install
  - Verify no conflicts with existing dependencies
  - Purpose: Enable audio playback capability
  - _Leverage: pubspec.yaml existing dependencies_
  - _Requirements: tech.md Flutter dependencies_
  - _Prompt: Role: Flutter Developer | Task: Add audio package dependency to pubspec.yaml and verify installation | Restrictions: Minimize dependency footprint, ensure Android compatibility, check for conflicts | Success: Package added, flutter pub get succeeds, no dependency conflicts_
  - **Completed**: Added audioplayers 6.5.1 with platform implementations for Android/Darwin/Linux/Windows/Web, no dependency conflicts

- [x] 3. Create AudioFeedbackService
  - File: lib/src/services/audio_feedback_service.dart
  - Implement singleton service for audio feedback
  - Methods: playZoneTooHigh(), playZoneTooLow(), playPhaseTransition()
  - Handle audio focus and ducking for background service
  - Purpose: Centralize audio feedback logic
  - _Leverage: lib/src/services/background_service.dart (service pattern)_
  - _Requirements: product.md biofeedback loop_
  - _Prompt: Role: Flutter Service Developer | Task: Create AudioFeedbackService singleton with methods for zone deviation and phase transition audio feedback | Restrictions: Must work during background execution, handle audio focus properly, be battery efficient | Success: Service plays audio reliably, works with foreground service, handles audio focus conflicts_
  - **Completed**: Created singleton service with audioplayers package integration, 3-second debouncing, volume control, enable/disable toggle, and methods for zone deviation (too high/low) and phase transition audio

- [x] 4. Create or source audio assets
  - File: assets/audio/ (new directory)
  - Create or source distinct sounds for: too_high.mp3, too_low.mp3, phase_change.mp3
  - Keep files small for fast loading (<100KB each)
  - Ensure sounds are distinct and non-intrusive
  - Purpose: Provide clear auditory feedback without annoyance
  - _Leverage: Free sound resources or simple tone generation_
  - _Requirements: product.md user experience_
  - _Prompt: Role: UX Designer with audio expertise | Task: Source or create distinct audio assets for zone deviation feedback (too high, too low) and phase transitions | Restrictions: Files must be small, sounds distinct but not annoying, appropriate for exercise context | Success: Audio files created, clearly distinguishable, appropriate volume and duration_
  - **Completed**: Generated three distinct MP3 files using ffmpeg: too_high.mp3 (800Hz, 4.6KB), too_low.mp3 (300Hz, 4.6KB), phase_change.mp3 (550Hz with fade, 3.7KB). All files are well under 100KB limit, clearly distinguishable by frequency, and appropriate for workout context.

- [x] 5. Register audio assets in pubspec.yaml
  - File: pubspec.yaml
  - Add assets/audio/ to flutter assets section
  - Ensure assets bundled in release build
  - Verify assets accessible at runtime
  - Purpose: Make audio files available to app
  - _Leverage: pubspec.yaml flutter assets configuration_
  - _Requirements: Flutter asset bundling_
  - _Prompt: Role: Flutter Developer | Task: Register audio asset files in pubspec.yaml flutter assets section | Restrictions: Use correct path format, verify bundling works | Success: Assets registered, accessible via asset path at runtime_
  - **Completed**: Added `assets/audio/` to flutter assets section in pubspec.yaml. Verified successful bundling by building debug APK and confirming all three audio files (too_high.mp3, too_low.mp3, phase_change.mp3) are present in the APK at assets/flutter_assets/assets/audio/

- [x] 6. Integrate audio feedback with WorkoutScreen
  - File: lib/src/screens/workout_screen.dart
  - Subscribe to zone status changes from session progress stream
  - Trigger AudioFeedbackService on zone deviation (with debounce)
  - Play phase transition sound on phase change
  - Purpose: Provide real-time audio feedback during workout
  - _Leverage: lib/src/widgets/zone_feedback.dart (visual feedback integration point)_
  - _Requirements: product.md biofeedback loop_
  - _Prompt: Role: Flutter Developer | Task: Integrate AudioFeedbackService with WorkoutScreen, triggering audio on zone deviations and phase transitions | Restrictions: Debounce to avoid audio spam, coordinate with visual feedback, respect user preferences | Success: Audio plays on zone deviation, synchronized with visual feedback, not annoying during workout_
  - **Completed**: Integrated AudioFeedbackService with WorkoutScreen. Added zone status tracking (isTooLow/isTooHigh) and phase name tracking. Audio plays on zone deviation state changes (enters too low or too high) and on phase transitions. Debouncing handled by AudioFeedbackService (3 seconds). Audio triggers synchronized with visual feedback from ZoneFeedbackWidget.

- [ ] 7. Add audio settings to SettingsScreen
  - File: lib/src/screens/settings_screen.dart
  - Add toggle for audio feedback enabled/disabled
  - Add volume slider or preset options
  - Persist settings via SharedPreferences
  - Purpose: Allow users to customize audio feedback
  - _Leverage: lib/src/services/profile_service.dart (settings persistence pattern)_
  - _Requirements: product.md user preferences_
  - _Prompt: Role: Flutter UI Developer | Task: Add audio feedback settings to SettingsScreen with enable/disable toggle and volume control | Restrictions: Follow existing settings UI patterns, persist preferences, provide sensible defaults | Success: Settings UI added, preferences persisted, audio service respects settings_

- [ ] 8. Update UserProfile model for audio settings
  - File: lib/src/models/user_profile.dart
  - Add audioFeedbackEnabled boolean field
  - Add audioVolume double field (0.0-1.0)
  - Update JSON serialization
  - Purpose: Persist audio preferences with user profile
  - _Leverage: lib/src/models/user_profile.dart existing structure_
  - _Requirements: user-profile spec compatibility_
  - _Prompt: Role: Flutter Developer | Task: Extend UserProfile model to include audio feedback settings with appropriate defaults | Restrictions: Maintain backward compatibility with existing profiles, use appropriate defaults (enabled, 0.7 volume) | Success: Model extended, JSON serialization works, existing profiles load without error_

- [ ] 9. Test audio feedback end-to-end
  - File: Manual testing / integration test
  - Test audio plays correctly during workout
  - Verify audio works with screen off (foreground service)
  - Test settings persistence and respect
  - Test on physical Android device
  - Purpose: Ensure audio feedback works reliably in production
  - _Leverage: Physical test device_
  - _Requirements: product.md session reliability_
  - _Prompt: Role: QA Engineer | Task: Perform end-to-end testing of audio feedback feature on physical Android device | Restrictions: Test with screen off, test during actual workout, verify battery impact acceptable | Success: Audio plays reliably, works in background, settings respected, acceptable battery impact_
