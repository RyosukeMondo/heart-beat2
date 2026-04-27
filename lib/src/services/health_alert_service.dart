import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;

/// Service that provides health-rule alerts (e.g. sustained low HR) to the UI
/// without coupling the screen to the coaching subsystem.
///
/// Shares the single [CoachingCueService.cueStream] subscription, filtering for
/// health-specific cues and exposing them via a dedicated [healthAlertStream].
class HealthAlertService {
  HealthAlertService._();

  static final HealthAlertService _instance = HealthAlertService._();

  static HealthAlertService get instance => _instance;

  /// Stream of health alerts. Currently only emits for [sustained_low_hr],
  /// but this interface allows future health rules to be added without
  /// coupling additional coaching logic to the UI.
  ///
  /// Requires [setCoachingCueStream] to be called before first use.
  Stream<generated.ApiCue> get healthAlertStream => _coachingCueStream.where(
        (cue) => cue.label == 'sustained_low_hr',
      );

  Stream<generated.ApiCue> _coachingCueStream = const Stream.empty();

  /// Set the coaching cue stream to filter for health alerts.
  void setCoachingCueStream(Stream<generated.ApiCue> stream) {
    _coachingCueStream = stream;
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