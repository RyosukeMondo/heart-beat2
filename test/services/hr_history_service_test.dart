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
  });
}
