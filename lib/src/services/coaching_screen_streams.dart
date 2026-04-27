import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import 'coaching_cue_service.dart';

/// Manages stream subscriptions for the coaching screen.
///
/// Extracted from CoachingScreenState to reduce its responsibilities.
class CoachingScreenStreams {
  CoachingScreenStreams();

  StreamSubscription<api.ApiFilteredHeartRate>? _hrSubscription;
  StreamSubscription<api.ApiConnectionStatus>? _statusSubscription;
  StreamSubscription<api.ApiCue>? _cueSubscription;

  /// Callback for HR data updates.
  void Function(api.ApiFilteredHeartRate data)? onHrData;

  /// Callback for connection status changes.
  void Function(api.ApiConnectionStatus status)? onStatusChange;

  /// Callback for coaching cue updates.
  void Function(api.ApiCue cue)? onCue;

  void subscribe() {
    // HR stream
    final hrStream = api.createHrStream();
    _hrSubscription = hrStream.listen(_handleHrData, onError: (e) {
      debugPrint('[CoachingScreen] HR stream error: $e');
    });

    // Connection status stream
    final statusStream = api.createConnectionStatusStream();
    _statusSubscription = statusStream.listen(_handleStatusChange, onError: (e) {
      debugPrint('[CoachingScreen] status stream error: $e');
    });

    // Coaching cue stream
    final cueStream = CoachingCueService.instance.cueStream;
    _cueSubscription = cueStream.listen(_handleCue, onError: (e) {
      debugPrint('[CoachingScreen] cue stream error: $e');
    });
  }

  void _handleHrData(api.ApiFilteredHeartRate data) {
    onHrData?.call(data);
  }

  void _handleStatusChange(api.ApiConnectionStatus status) {
    onStatusChange?.call(status);
  }

  void _handleCue(api.ApiCue cue) {
    onCue?.call(cue);
  }

  void dispose() {
    _hrSubscription?.cancel();
    _statusSubscription?.cancel();
    _cueSubscription?.cancel();
    _hrSubscription = null;
    _statusSubscription = null;
    _cueSubscription = null;
  }
}
