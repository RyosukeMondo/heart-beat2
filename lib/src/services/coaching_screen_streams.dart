import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import 'connection_status_stream_provider.dart';
import 'hr_stream_provider.dart';

/// Manages stream subscriptions for the coaching screen.
///
/// Extracted from CoachingScreenState to reduce its responsibilities.
class CoachingScreenStreams {
  CoachingScreenStreams();

  StreamSubscription<api.ApiFilteredHeartRate>? _hrSubscription;
  StreamSubscription<api.ApiConnectionStatus>? _statusSubscription;

  /// Callback for HR data updates.
  void Function(api.ApiFilteredHeartRate data)? onHrData;

  /// Callback for connection status changes.
  void Function(api.ApiConnectionStatus status)? onStatusChange;

  /// Callback for stream errors.
  void Function(Object error, StackTrace stackTrace)? onError;

  void subscribe() {
    // HR stream
    _hrSubscription = hrStream.listen(_handleHrData, onError: (e, st) {
      debugPrint('[CoachingScreen] HR stream error: $e');
      onError?.call(e, st);
    });

    // Connection status stream
    _statusSubscription = connectionStatusStream.listen(_handleStatusChange, onError: (e, st) {
      debugPrint('[CoachingScreen] status stream error: $e');
      onError?.call(e, st);
    });

    // Coaching cue stream is consumed exclusively by CoachingCueService,
    // which delivers cues via multiple surfaces (toast, notification, TTS).
    // CoachingScreen receives cue updates via CoachingScreenState's own
    // subscription to CoachingCueService — no second subscription here.
  }

  void _handleHrData(api.ApiFilteredHeartRate data) {
    onHrData?.call(data);
  }

  void _handleStatusChange(api.ApiConnectionStatus status) {
    onStatusChange?.call(status);
  }

  void dispose() {
    _hrSubscription?.cancel();
    _statusSubscription?.cancel();
    _hrSubscription = null;
    _statusSubscription = null;
  }
}