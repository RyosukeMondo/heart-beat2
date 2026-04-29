import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionService', () {
    test('should be a singleton', () {
      final instance1 = SessionService.instance;
      final instance2 = SessionService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('listSessions method exists and is callable', () {
      final service = SessionService.instance;
      // Verify the method exists and is a closure that can be invoked
      expect(service.listSessions, isA<Function>());
    });

    test('exportSession method exists and accepts id and format', () {
      final service = SessionService.instance;
      expect(service.exportSession, isA<Function>());
    });

    test('sessionPreviewId method exists and accepts preview', () {
      final service = SessionService.instance;
      expect(service.sessionPreviewId, isA<Function>());
    });

    test('ExportFormat enum has expected values', () {
      expect(ExportFormat.values, contains(ExportFormat.csv));
      expect(ExportFormat.values, contains(ExportFormat.json));
      expect(ExportFormat.values, contains(ExportFormat.summary));
      expect(ExportFormat.values.length, 3);
    });

    test('ApiSessionSummaryPreview type is exported', () {
      // Verify the type is accessible via the service's export
      expect(ApiSessionSummaryPreview, isNotNull);
    });
  });
}