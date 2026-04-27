import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadinessService', () {
    test('should be a singleton', () {
      final instance1 = ReadinessService.instance;
      final instance2 = ReadinessService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('singleton instance is the same object across calls', () {
      final instance1 = ReadinessService.instance;
      final instance2 = ReadinessService.instance;
      final instance3 = ReadinessService.instance;

      expect(identical(instance1, instance2), isTrue);
      expect(identical(instance2, instance3), isTrue);
      expect(identical(instance1, instance3), isTrue);
    });

    test('singleton has stream accessor', () {
      final service = ReadinessService.instance;
      expect(service.stream, isNotNull);
    });

    test('singleton has cachedReadiness accessor', () {
      final service = ReadinessService.instance;
      expect(service.cachedReadiness, isNull);
    });

    test('singleton has loadReadiness method', () {
      final service = ReadinessService.instance;
      expect(service.loadReadiness, isA<Function>());
    });

    test('singleton has dispose method', () {
      final service = ReadinessService.instance;
      expect(service.dispose, isA<Function>());
    });
  });
}