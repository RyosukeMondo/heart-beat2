import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:heart_beat/src/services/health_alert_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (MethodCall methodCall) async {
            return null;
          },
        );

    FlutterLocalNotificationsPlatform.instance = _MockFlutterLocalNotificationsPlatform();
  });

  group('HealthAlertService', () {
    late HealthAlertService service;

    setUp(() {
      service = HealthAlertService.instance;
    });

    tearDown(() {
      // No-op: HealthAlertService is a singleton without dispose method
    });

    test('should be a singleton', () {
      final instance1 = HealthAlertService.instance;
      final instance2 = HealthAlertService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize with ok status and empty detail', () {
      expect(service.healthAlertState.status, HealthRuleStatus.ok);
      expect(service.healthAlertState.detail, isEmpty);
    });

    test('healthAlertStream emits HealthAlert when sustained_low_hr is received', () async {
      final controller = StreamController<RawCue>.broadcast();
      service.startListening(controller.stream);

      final cue = RawCue(
        label: 'sustained_low_hr',
        message: 'Average HR was 55 bpm over the last 1 min',
      );

      final future = service.healthAlertStream.first;
      controller.add(cue);
      final emitted = await future;

      expect(emitted.label, 'sustained_low_hr');
      expect(emitted.message, contains('55 bpm'));
      expect(emitted.avgBpm, 55);
      expect(emitted.windowMin, 1);

      controller.close();
    });

    test('healthAlertState updates to low when sustained_low_hr cue is received', () async {
      final controller = StreamController<RawCue>.broadcast();
      service.startListening(controller.stream);

      final cue = RawCue(
        label: 'sustained_low_hr',
        message: 'Average HR was 55 bpm over the last 1 min',
      );

      controller.add(cue);

      await Future.delayed(Duration.zero);

      expect(service.healthAlertState.status, HealthRuleStatus.low);
      expect(service.healthAlertState.detail, contains('55 bpm'));

      controller.close();
    });

    test('healthAlertStateStream emits updated state on sustained_low_hr', () async {
      final controller = StreamController<RawCue>.broadcast();
      service.startListening(controller.stream);

      final cue = RawCue(
        label: 'sustained_low_hr',
        message: 'Average HR was 55 bpm over the last 1 min',
      );

      final future = service.healthAlertStateStream.first;
      controller.add(cue);
      final state = await future;

      expect(state.status, HealthRuleStatus.low);
      expect(state.detail, contains('55 bpm'));

      controller.close();
    });

    test('does not emit healthAlertStream for non-sustained_low_hr cues', () async {
      // Note: HealthAlertService is a singleton and _currentState persists.
      // Only sustained_low_hr cues transition state to 'low'.
      // This test verifies that non-sustained_low_hr cues do NOT trigger
      // healthAlertStream emissions, but the state may still reflect a prior low.
      final controller = StreamController<RawCue>.broadcast();
      service.startListening(controller.stream);

      final cue = RawCue(
        label: 'raise_hr',
        message: 'Heart rate is below target zone',
      );

      // Create a future that should never complete (no emission expected)
      final streamFuture = service.healthAlertStream.first;
      controller.add(cue);

      // Race: if stream emits, we lose. If it times out, non-sustained_low_hr was filtered correctly.
      final result = await streamFuture.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => const HealthAlert(label: '', message: '', avgBpm: 0, windowMin: 0),
      );

      expect(result.label, isEmpty, reason: 'non-sustained_low_hr cue should not emit to healthAlertStream');

      controller.close();
    });

    test('showSustainedLowHrNotification parses HealthAlert correctly', () async {
      const alert = HealthAlert(
        label: 'sustained_low_hr',
        message: 'Average HR was 62 bpm over the last 5 min',
        avgBpm: 62,
        windowMin: 5,
      );

      // Should not throw
      await service.showSustainedLowHrNotification(alert);
    });
  });
}

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