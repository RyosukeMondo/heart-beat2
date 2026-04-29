import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/zone.dart';
import 'connection_status_stream_provider.dart';
import 'hr_stream_provider.dart';
import 'hr_processor.dart';
import 'profile_service.dart';

/// Manages stream subscriptions for the coaching screen.
///
/// Handles HR data processing and owns the callbacks for HR updates and
/// connection status changes. Extracted from CoachingScreenState to reduce
/// its responsibilities.
class CoachingScreenStreams {
  CoachingScreenStreams({HrProcessor? hrProcessor})
      : _hrProcessor = hrProcessor ?? HrProcessor(ProfileService.instance);

  final HrProcessor _hrProcessor;

  StreamSubscription<ApiFilteredHeartRate>? _hrSubscription;
  StreamSubscription<ApiConnectionStatus>? _statusSubscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  int get currentBpm => _hrProcessor.currentBpm;
  Zone get currentZone => _hrProcessor.currentZone;

  /// Callback for HR data updates (bpm, zone).
  void Function(int bpm, Zone zone)? onHrData;

  /// Callback for connection status changes (deprecated — use isConnected instead).
  void Function(ApiConnectionStatus status)? onStatusChange;

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

  Future<void> _handleHrData(ApiFilteredHeartRate data) async {
    await _hrProcessor.process(data);
    onHrData?.call(_hrProcessor.currentBpm, _hrProcessor.currentZone);
  }

  Future<void> _handleStatusChange(ApiConnectionStatus status) async {
    _isConnected = await connectionStatusIsConnected(status: status);
  }

  void dispose() {
    _hrSubscription?.cancel();
    _statusSubscription?.cancel();
    _hrSubscription = null;
    _statusSubscription = null;
  }
}