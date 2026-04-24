import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/coaching_cue_service.dart';
import 'package:heart_beat/src/services/voice_coaching_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock the FlutterLocalNotificationsPlugin method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (MethodCall methodCall) async {
            return null;
          },
        );

    // Mock the flutter_tts method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'setLanguage':
              case 'setSpeechRate':
              case 'setVolume':
              case 'stop':
              case 'speak':
                return null;
              default:
                return null;
            }
          },
        );

    // Set up a mock platform instance for testing
    FlutterLocalNotificationsPlatform.instance = _MockFlutterLocalNotificationsPlatform();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CoachingCueService', () {
    late CoachingCueService service;

    setUp(() async {
      await CoachingCueService.instance.initialize();
      service = CoachingCueService.instance;
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should be a singleton', () {
      final instance1 = CoachingCueService.instance;
      final instance2 = CoachingCueService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize with default preference values', () {
      expect(service.notificationsEnabled, isTrue);
      expect(service.inAppToastEnabled, isTrue);
      expect(service.ttsEnabled, isFalse);
    });

    test('should allow enabling and disabling notifications', () async {
      await service.setNotificationsEnabled(false);
      expect(service.notificationsEnabled, isFalse);

      await service.setNotificationsEnabled(true);
      expect(service.notificationsEnabled, isTrue);
    });

    test('should allow enabling and disabling TTS', () async {
      await service.setTtsEnabled(true);
      expect(service.ttsEnabled, isTrue);

      await service.setTtsEnabled(false);
      expect(service.ttsEnabled, isFalse);
    });

    test('should allow enabling and disabling in-app toast', () async {
      await service.setInAppToastEnabled(false);
      expect(service.inAppToastEnabled, isFalse);

      await service.setInAppToastEnabled(true);
      expect(service.inAppToastEnabled, isTrue);
    });

    test('initialize should complete without error', () async {
      final freshService = CoachingCueService.instance;
      await expectLater(freshService.initialize(), completes);
    });

    test('dispose should complete without error', () async {
      await expectLater(service.dispose(), completes);
    });
  });
}

/// A mock implementation of FlutterLocalNotificationsPlatform for testing.
class _MockFlutterLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  _MockFlutterLocalNotificationsPlatform() : super();

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return const NotificationAppLaunchDetails(false);
  }

  @override
  Future<void> show(int id, String? title, String? body, {String? payload}) async {
    // No-op for testing
  }

  @override
  Future<void> cancel(int id) async {
    // No-op for testing
  }

  @override
  Future<void> cancelAll() async {
    // No-op for testing
  }
}
