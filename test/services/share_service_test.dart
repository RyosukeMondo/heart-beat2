import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareService', () {
    test('should be a singleton', () {
      final instance1 = ShareService.instance;
      final instance2 = ShareService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('has shareText method', () {
      final service = ShareService.instance;
      expect(service.shareText, isNotNull);
    });

    test('has shareFile method', () {
      final service = ShareService.instance;
      expect(service.shareFile, isNotNull);
    });

    test('has shareFiles method', () {
      final service = ShareService.instance;
      expect(service.shareFiles, isNotNull);
    });
  });
}
