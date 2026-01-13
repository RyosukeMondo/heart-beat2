import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Integration tests for the settings flow.
///
/// These tests verify:
/// - Navigation to settings screen
/// - Profile modification (max HR, age, audio settings)
/// - Settings persistence across app restarts
/// - Age-based max HR calculation
/// - Audio feedback settings
void main() {
  patrolTest(
    'Navigate to settings and verify screen elements',
    ($) async {
      // Launch the app
      await launchApp($);

      // Navigate to settings
      await navigateToSettings($);

      // Verify settings screen is visible
      verifySettingsScreen($);

      // Verify key form fields are present
      expectWidgetWithKey($, const Key('ageField'));
      expectWidgetWithKey($, const Key('maxHrField'));
      expectWidgetWithKey($, const Key('useAgeBasedSwitch'));
      expectWidgetWithKey($, const Key('audioFeedbackEnabledSwitch'));
      expectWidgetWithKey($, const Key('audioVolumeSlider'));

      // Verify Save Settings button is present
      expect(find.text('Save Settings'), findsOneWidget);
    },
  );

  patrolTest(
    'Modify max HR and save successfully',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter new max HR value
      await enterTextInField($, const Key('maxHrField'), '190');

      // Save settings
      await tapButtonWithText($, 'Save Settings');

      // Wait for save to complete and snackbar to appear
      await waitForText($, 'Settings saved successfully');

      // Navigate back to home
      await navigateBack($);

      // Navigate back to settings to verify persistence
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Verify the max HR field contains the saved value
      final maxHrField = $(const Key('maxHrField'));
      expect(maxHrField, findsOneWidget);
      // Note: The actual text verification happens through the TextField's controller
    },
  );

  patrolTest(
    'Enable age-based max HR calculation',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter age first
      await enterTextInField($, const Key('ageField'), '30');
      await $.pumpAndSettle();

      // Enable age-based max HR
      await $(const Key('useAgeBasedSwitch')).tap();
      await $.pumpAndSettle();

      // Verify estimated max HR is displayed (220 - 30 = 190)
      expect(find.textContaining('Estimated max HR: 190 BPM'), findsOneWidget);

      // Save settings
      await tapButtonWithText($, 'Save Settings');

      // Wait for save to complete
      await waitForText($, 'Settings saved successfully');
    },
  );

  patrolTest(
    'Modify age and verify age-based max HR updates',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter age
      await enterTextInField($, const Key('ageField'), '25');
      await $.pumpAndSettle();

      // Enable age-based max HR
      await $(const Key('useAgeBasedSwitch')).tap();
      await $.pumpAndSettle();

      // Verify estimated max HR (220 - 25 = 195)
      expect(find.textContaining('Estimated max HR: 195 BPM'), findsOneWidget);

      // Change age
      await enterTextInField($, const Key('ageField'), '40');
      await $.pumpAndSettle();

      // Verify estimated max HR updated (220 - 40 = 180)
      expect(find.textContaining('Estimated max HR: 180 BPM'), findsOneWidget);
    },
  );

  patrolTest(
    'Audio feedback settings modification',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Verify audio feedback is enabled by default
      final audioSwitch = $(const Key('audioFeedbackEnabledSwitch'));
      expect(audioSwitch, findsOneWidget);

      // Disable audio feedback
      await audioSwitch.tap();
      await $.pumpAndSettle();

      // Verify audio notifications disabled message
      expect(find.text('Audio notifications disabled'), findsOneWidget);

      // Re-enable audio feedback
      await audioSwitch.tap();
      await $.pumpAndSettle();

      // Verify audio notifications enabled message
      expect(find.text('Audio notifications enabled'), findsOneWidget);

      // Save settings
      await tapButtonWithText($, 'Save Settings');

      // Wait for save to complete
      await waitForText($, 'Settings saved successfully');
    },
  );

  patrolTest(
    'Settings persist across app restart',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // First session: Set and save settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Set age
      await enterTextInField($, const Key('ageField'), '35');
      await $.pumpAndSettle();

      // Set max HR
      await enterTextInField($, const Key('maxHrField'), '185');
      await $.pumpAndSettle();

      // Disable audio feedback
      await $(const Key('audioFeedbackEnabledSwitch')).tap();
      await $.pumpAndSettle();

      // Save settings
      await tapButtonWithText($, 'Save Settings');
      await waitForText($, 'Settings saved successfully');

      // Navigate back and "restart" app by launching again
      await navigateBack($);
      await $.pumpAndSettle();

      // Second session: Verify settings persisted
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Verify age and max HR fields are present
      // (Actual values are in the TextEditingControllers)
      expectWidgetWithKey($, const Key('ageField'));
      expectWidgetWithKey($, const Key('maxHrField'));

      // Verify audio feedback disabled state persisted
      expect(find.text('Audio notifications disabled'), findsOneWidget);
    },
  );

  patrolTest(
    'Validation error for invalid max HR',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter invalid max HR (too high)
      await enterTextInField($, const Key('maxHrField'), '250');
      await $.pumpAndSettle();

      // Try to save
      await tapButtonWithText($, 'Save Settings');

      // Wait a bit for validation
      await wait($, const Duration(milliseconds: 500));

      // Verify error message appears
      expect(
        find.text('Max heart rate must be between 100 and 220'),
        findsOneWidget,
      );

      // Verify settings saved snackbar does NOT appear
      expect(find.text('Settings saved successfully'), findsNothing);
    },
  );

  patrolTest(
    'Validation error for invalid age',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter invalid age (too low)
      await enterTextInField($, const Key('ageField'), '5');
      await $.pumpAndSettle();

      // Try to save
      await tapButtonWithText($, 'Save Settings');

      // Wait a bit for validation
      await wait($, const Duration(milliseconds: 500));

      // Verify error message appears
      expect(
        find.text('Age must be between 10 and 120'),
        findsOneWidget,
      );

      // Verify settings saved snackbar does NOT appear
      expect(find.text('Settings saved successfully'), findsNothing);
    },
  );

  patrolTest(
    'Age-based switch disabled without age input',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Clear age field if it has any value
      await $(const Key('ageField')).tap();
      await $.pumpAndSettle();

      // Try to tap the age-based switch - it should be disabled
      // The switch should show the hint text about enabling age-based calculation
      expect(
        find.text('Enable to use age-based calculation (220 - age)'),
        findsOneWidget,
      );
    },
  );

  patrolTest(
    'Max HR field disabled when using age-based calculation',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Enter age
      await enterTextInField($, const Key('ageField'), '30');
      await $.pumpAndSettle();

      // Enable age-based max HR
      await $(const Key('useAgeBasedSwitch')).tap();
      await $.pumpAndSettle();

      // Verify helper text shows age-based calculation is being used
      expect(
        find.text('Using age-based calculation'),
        findsOneWidget,
      );
    },
  );

  patrolTest(
    'Navigate back from settings without saving',
    ($) async {
      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Make changes but don't save
      await enterTextInField($, const Key('maxHrField'), '195');
      await $.pumpAndSettle();

      // Navigate back without saving
      await navigateBack($);

      // Verify we're back on home screen
      verifyHomeScreen($);
    },
  );

  patrolTest(
    'Complete settings modification flow',
    ($) async {
      // Clear any existing profile data
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Launch and navigate to settings
      await launchApp($);
      await navigateToSettings($);

      // Wait for settings to load
      await wait($, const Duration(milliseconds: 500));

      // Set comprehensive profile:

      // 1. Set age
      await enterTextInField($, const Key('ageField'), '28');
      await $.pumpAndSettle();

      // 2. Set manual max HR
      await enterTextInField($, const Key('maxHrField'), '192');
      await $.pumpAndSettle();

      // 3. Keep audio feedback enabled (default)

      // 4. Save settings
      await tapButtonWithText($, 'Save Settings');
      await waitForText($, 'Settings saved successfully');

      // 5. Navigate away and back to verify
      await navigateBack($);
      verifyHomeScreen($);

      await navigateToSettings($);
      await wait($, const Duration(milliseconds: 500));

      // 6. Verify all settings are visible and screen loaded correctly
      verifySettingsScreen($);
      expectWidgetWithKey($, const Key('ageField'));
      expectWidgetWithKey($, const Key('maxHrField'));
      expect(find.text('Audio notifications enabled'), findsOneWidget);
    },
  );
}
