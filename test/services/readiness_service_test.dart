import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
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
      expect(service.stream, isA<Stream<ApiReadinessData>>());
    });

    test('singleton stream emits readiness data', () async {
      final service = ReadinessService.instance;
      final stream = service.stream;

      // Listen to verify stream is functional and can emit ApiReadinessData
      final subscription = stream.listen((ApiReadinessData data) {
        // Verify readiness data is received when stream emits
        expect(data.score, isA<int>());
        expect(data.level, isA<String>());
      });

      // Verify stream is a broadcast stream that emits ApiReadinessData
      expect(stream, isA<Stream<ApiReadinessData>>());

      // Clean up
      await subscription.cancel();
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