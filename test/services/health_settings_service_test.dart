import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/health_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthSettingsService', () {
    test('should be a singleton', () {
      final instance1 = HealthSettingsService.instance;
      final instance2 = HealthSettingsService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('has correct default values', () {
      const expected = HealthSettingsData(
        lowHrThreshold: HealthSettingsService.defaultLowHrThreshold,
        sustainedMinutes: HealthSettingsService.defaultSustainedMinutes,
        sampleCadenceSecs: HealthSettingsService.defaultSampleCadenceSecs,
        quietStart: HealthSettingsService.defaultQuietStart,
        quietEnd: HealthSettingsService.defaultQuietEnd,
        notificationsEnabled: HealthSettingsService.defaultNotificationsEnabled,
      );
      expect(expected.lowHrThreshold, 70);
      expect(expected.sustainedMinutes, 10);
      expect(expected.sampleCadenceSecs, 5);
      expect(expected.quietStart, '22:00');
      expect(expected.quietEnd, '07:00');
      expect(expected.notificationsEnabled, true);
    });

    test('singleton instance is the same object across calls', () {
      final instance1 = HealthSettingsService.instance;
      final instance2 = HealthSettingsService.instance;
      final instance3 = HealthSettingsService.instance;

      expect(identical(instance1, instance2), isTrue);
      expect(identical(instance2, instance3), isTrue);
      expect(identical(instance1, instance3), isTrue);
    });

    test('singleton has all expected accessors', () {
      final service = HealthSettingsService.instance;

      expect(service.lowHrThreshold, isNotNull);
      expect(service.sustainedMinutes, isNotNull);
      expect(service.sampleCadenceSecs, isNotNull);
      expect(service.quietStart, isNotNull);
      expect(service.quietEnd, isNotNull);
      expect(service.notificationsEnabled, isNotNull);
    });

    test('singleton has all expected setters', () {
      final service = HealthSettingsService.instance;

      expect(service.setLowHrThreshold, isA<Function>());
      expect(service.setSustainedMinutes, isA<Function>());
      expect(service.setSampleCadenceSecs, isA<Function>());
      expect(service.setQuietStart, isA<Function>());
      expect(service.setQuietEnd, isA<Function>());
      expect(service.setNotificationsEnabled, isA<Function>());
    });

    test('singleton has initialize and reload methods', () {
      final service = HealthSettingsService.instance;

      expect(service.initialize, isA<Function>());
      expect(service.reload, isA<Function>());
    });
  });
}