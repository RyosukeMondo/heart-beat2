import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService', () {
    test('should be a singleton', () {
      final instance1 = CloudSyncService.instance;
      final instance2 = CloudSyncService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('has correct method signatures', () {
      final service = CloudSyncService.instance;

      // initialize: () -> Future<void>
      Future<void> Function() initialize;
      initialize = service.initialize;
      expect(initialize, isNotNull);

      // exportAllSessions: () -> Future<String>
      Future<String> Function() exportAllSessions;
      exportAllSessions = service.exportAllSessions;
      expect(exportAllSessions, isNotNull);

      // importSessions: (String) -> Future<int>
      Future<int> Function(String) importSessions;
      importSessions = service.importSessions;
      expect(importSessions, isNotNull);

      // getSyncStatus: () -> Future<_SyncStatus>
      var getSyncStatus = service.getSyncStatus;
      expect(getSyncStatus, isNotNull);

      // createBackup: () -> Future<void>
      Future<void> Function() createBackup;
      createBackup = service.createBackup;
      expect(createBackup, isNotNull);

      // dispose: () -> Future<void>
      Future<void> Function() dispose;
      dispose = service.dispose;
      expect(dispose, isNotNull);
    });
  });
}
