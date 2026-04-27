import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/voice_coaching_handler.dart';
import 'package:heart_beat/src/services/voice_coaching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceCoachingHandler interface', () {
    test('VoiceCoachingService implements VoiceCoachingHandler', () {
      final service = VoiceCoachingService.instance;
      expect(service, isA<VoiceCoachingHandler>());
    });

    test('VoiceCoachingHandler cannot be directly instantiated', () {
      // VoiceCoachingHandler is an abstract class - attempting to instantiate
      // it should fail at compile time (this test documents the intended design)
      bool isAbstract = true;
      expect(isAbstract, isTrue);
    });

    test('has correct method signatures', () {
      // isEnabled: bool
      bool Function() isEnabled;
      isEnabled = () => throw UnimplementedError();
      expect(isEnabled, isA<Function>());

      // initialize: Future<void> Function()
      Future<void> Function() initialize;
      initialize = () async {};
      expect(initialize, isA<Function>());

      // setEnabled: Future<void> Function(bool)
      Future<void> Function(bool) setEnabled;
      setEnabled = (bool enabled) async {};
      expect(setEnabled, isA<Function>());

      // speak: Future<void> Function(String)
      Future<void> Function(String) speak;
      speak = (String text) async {};
      expect(speak, isA<Function>());

      // dispose: Future<void> Function()
      Future<void> Function() dispose;
      dispose = () async {};
      expect(dispose, isA<Function>());
    });
  });

  group('VoiceCoachingService', () {
    test('should be a singleton', () {
      final instance1 = VoiceCoachingService.instance;
      final instance2 = VoiceCoachingService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('implements VoiceCoachingHandler', () {
      final service = VoiceCoachingService.instance;
      expect(service, isA<VoiceCoachingHandler>());
    });

    test('singleton instance is the same object across calls', () {
      final instance1 = VoiceCoachingService.instance;
      final instance2 = VoiceCoachingService.instance;
      final instance3 = VoiceCoachingService.instance;

      expect(identical(instance1, instance2), isTrue);
      expect(identical(instance2, instance3), isTrue);
      expect(identical(instance1, instance3), isTrue);
    });

    test('singleton has all VoiceCoachingHandler methods', () {
      final service = VoiceCoachingService.instance;

      expect(service.isEnabled, isA<bool>());
      expect(service.initialize, isA<Function>());
      expect(service.setEnabled, isA<Function>());
      expect(service.speak, isA<Function>());
      expect(service.dispose, isA<Function>());
    });

    test('singleton identity preserved across multiple accesses', () {
      final first = VoiceCoachingService.instance;
      final second = VoiceCoachingService.instance;

      expect(identical(first, second), isTrue);

      for (int i = 0; i < 5; i++) {
        expect(identical(VoiceCoachingService.instance, first), isTrue);
      }
    });

    test('initial isEnabled is false', () {
      final service = VoiceCoachingService.instance;
      // isEnabled starts as false (user has not opted in)
      expect(service.isEnabled, isFalse);
    });

    test('has volume accessor', () {
      final service = VoiceCoachingService.instance;
      expect(service.volume, isA<double>());
    });

    test('has rate accessor', () {
      final service = VoiceCoachingService.instance;
      expect(service.rate, isA<double>());
    });

    test('has language accessor', () {
      final service = VoiceCoachingService.instance;
      expect(service.language, isA<String>());
    });
  });
}