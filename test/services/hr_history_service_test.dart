import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;
import 'package:heart_beat/src/services/hr_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HrHistoryService', () {
    test('should be a singleton', () {
      final instance1 = HrHistoryService.instance;
      final instance2 = HrHistoryService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('has correct method signatures', () {
      // Verify HrHistoryService has the three public methods with correct signatures
      // by checking they are assignable to the expected function types (compile-time check)
      final service = HrHistoryService.instance;

      // latestSample: () -> Future<ApiSample?>
      Future<generated.ApiSample?> Function() latestSample;
      latestSample = service.latestSample;
      expect(latestSample, isNotNull);

      // samplesInRange: ({required int, required int}) -> Future<List<ApiSample>>
      Future<List<generated.ApiSample>> Function({required int startMs, required int endMs}) samplesInRange;
      samplesInRange = service.samplesInRange;
      expect(samplesInRange, isNotNull);

      // rollingAvg: ({required int}) -> Future<double?>
      Future<double?> Function({required int windowSecs}) rollingAvg;
      rollingAvg = service.rollingAvg;
      expect(rollingAvg, isNotNull);
    });

    test('singleton instance is the same object across calls', () {
      final instance1 = HrHistoryService.instance;
      final instance2 = HrHistoryService.instance;
      final instance3 = HrHistoryService.instance;

      // All references point to the same singleton
      expect(identical(instance1, instance2), isTrue);
      expect(identical(instance2, instance3), isTrue);
      expect(identical(instance1, instance3), isTrue);
    });

    test('singleton has all three query methods', () {
      final service = HrHistoryService.instance;

      // Verify all three methods are present and callable
      expect(service.latestSample, isNotNull);
      expect(service.samplesInRange, isNotNull);
      expect(service.rollingAvg, isNotNull);

      // Each method should be a function (not null)
      // We only verify the methods are not null - actual invocation
      // requires RustLib.init() which is not available in unit tests
      expect(service.latestSample, isA<Function>());
      expect(service.samplesInRange, isA<Function>());
      expect(service.rollingAvg, isA<Function>());
    });

    test('singleton identity preserved across multiple accesses', () {
      // Access the singleton multiple times
      final first = HrHistoryService.instance;
      final second = HrHistoryService.instance;

      // Should be the exact same object instance
      expect(identical(first, second), isTrue);

      // Multiple accesses should all return the same reference
      for (int i = 0; i < 5; i++) {
        expect(identical(HrHistoryService.instance, first), isTrue);
      }
    });
  });
}
