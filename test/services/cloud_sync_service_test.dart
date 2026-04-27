import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_sync_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    await CloudSyncService.instance.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CloudSyncService', () {
    test('should be a singleton', () {
      final instance1 = CloudSyncService.instance;
      final instance2 = CloudSyncService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    group('initialize', () {
      test('completes without error', () async {
        final service = CloudSyncService.instance;
        await service.initialize();
      });

      test('is idempotent', () async {
        final service = CloudSyncService.instance;
        await service.initialize();
        await service.initialize();
      });
    });

    group('importSessions', () {
      test('throws FileSystemException for non-existent file', () async {
        final service = CloudSyncService.instance;
        await service.initialize();

        expect(
          () => service.importSessions('/nonexistent/path/backup.json'),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('throws FormatException for invalid JSON', () async {
        final service = CloudSyncService.instance;
        await service.initialize();

        final invalidFile = File('${tempDir.path}/invalid.json');
        await invalidFile.writeAsString('not valid json');

        expect(
          () => service.importSessions(invalidFile.path),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for backup missing version field', () async {
        final service = CloudSyncService.instance;
        await service.initialize();

        final invalidFile = File('${tempDir.path}/no_version.json');
        await invalidFile.writeAsString('{"sessions": []}');

        expect(
          () => service.importSessions(invalidFile.path),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for backup missing sessions array', () async {
        final service = CloudSyncService.instance;
        await service.initialize();

        final invalidFile = File('${tempDir.path}/no_sessions.json');
        await invalidFile.writeAsString('{"version": 1}');

        expect(
          () => service.importSessions(invalidFile.path),
          throwsA(isA<FormatException>()),
        );
      });

      test('returns session count for valid backup file', () async {
        final service = CloudSyncService.instance;
        await service.initialize();

        final validFile = File('${tempDir.path}/valid_backup.json');
        await validFile.writeAsString('''
{
  "version": 1,
  "sessions": [{"id": "1"}, {"id": "2"}, {"id": "3"}]
}
''');

        final count = await service.importSessions(validFile.path);

        expect(count, equals(3));
      });
    });

    group('dispose', () {
      test('throws StateError after dispose when calling exportAllSessions',
          () async {
        final service = CloudSyncService.instance;
        await service.initialize();
        await service.dispose();

        expect(
          () => service.exportAllSessions(),
          throwsA(isA<StateError>()),
        );
      });

      test('allows re-initialization after dispose', () async {
        final service = CloudSyncService.instance;
        await service.initialize();
        await service.dispose();

        await service.initialize();
        // Re-initialize should not throw
        await service.initialize();
      });
    });
  });
}
