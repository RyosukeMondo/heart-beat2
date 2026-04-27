import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;
import 'package:heart_beat/src/services/cue_stream_provider.dart';

/// Service that provides health-rule alerts (e.g. sustained low HR) to the UI
/// without coupling the screen to the coaching subsystem.
///
/// Subscribes independently to the coaching cue stream to filter for
/// health-specific cues, exposing them via [healthAlertStream] and [healthAlertState].
class HealthAlertService {
  HealthAlertService._();

  static final HealthAlertService _instance = HealthAlertService._();

  static HealthAlertService get instance => _instance;

  /// Stream of health alerts. Currently only emits for [sustained_low_hr],
  /// but this interface allows future health rules to be added without
  /// coupling additional coaching logic to the UI.
  Stream<generated.ApiCue> get healthAlertStream => _healthAlertController.stream;

  final StreamController<generated.ApiCue> _healthAlertController =
      StreamController<generated.ApiCue>.broadcast();

  /// Emits the current [HealthAlertState] whenever the health alert status changes.
  Stream<HealthAlertState> get healthAlertStateStream => _healthAlertStateController.stream;

  final StreamController<HealthAlertState> _healthAlertStateController =
      StreamController<HealthAlertState>.broadcast();

  /// The current health alert state.
  HealthAlertState get healthAlertState => _currentState;

  HealthAlertState _currentState = const HealthAlertState(HealthRuleStatus.ok, '');

  StreamSubscription<generated.ApiCue>? _cueSubscription;

  /// Start listening to the coaching cue stream and filter for health alerts.
  /// Call this once at app startup, after [CoachingCueService] is initialized.
  void startListening() {
    _cueSubscription?.cancel();
    _cueSubscription = cueStream.listen((cue) {
      if (cue.label == 'sustained_low_hr') {
        _healthAlertController.add(cue);
        _currentState = HealthAlertState(HealthRuleStatus.low, cue.message);
        _healthAlertStateController.add(_currentState);
      }
    });
    if (kDebugMode) {
      debugPrint('HealthAlertService: started listening to cue stream');
    }
  }

  /// Show a custom low-HR notification with the exact format required:
  /// title = 'Heart rate low', body = 'Average HR was {avg_bpm} bpm over
  /// the last {window_min} min', tap opens the Health screen.
  Future<void> showSustainedLowHrNotification(generated.ApiCue cue) async {
    const androidDetails = AndroidNotificationDetails(
      'health_alerts',
      'Health Alerts',
      channelDescription: 'Low heart rate health alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final avgBpm = _parseAvgBpm(cue.message);
    final windowMin = _parseWindowMin(cue.message);

    const title = 'Heart rate low';
    final body = 'Average HR was $avgBpm bpm over the last $windowMin min';

    await _notificationPlugin.show(
      cue.hashCode,
      title,
      body,
      details,
      payload: 'sustained_low_hr',
    );

    if (kDebugMode) {
      debugPrint('HealthAlertService: showed low-HR notification: $body');
    }
  }

  final FlutterLocalNotificationsPlugin _notificationPlugin =
      FlutterLocalNotificationsPlugin();

  int _parseAvgBpm(String message) {
    final match = RegExp(r'average (\d+) bpm').firstMatch(message);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  int _parseWindowMin(String message) {
    final match = RegExp(r'last ([\d.]+) min').firstMatch(message);
    if (match == null) return 0;
    return double.parse(match.group(1)!).round();
  }
}

/// Immutable health alert state containing the current rule status and detail message.
class HealthAlertState {
  final HealthRuleStatus status;
  final String detail;

  const HealthAlertState(this.status, this.detail);
}

/// Health rule status enum.
enum HealthRuleStatus { ok, low }