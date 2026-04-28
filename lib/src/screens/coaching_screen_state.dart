import 'dart:async' hide Zone;
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart' show Zone;
import '../services/hr_processor.dart';
import '../services/coaching_session_state.dart';
import '../services/coaching_screen_streams.dart';
import '../services/profile_service.dart';

/// UI state and session logic for [CoachingScreen].
///
/// Coordinates [CoachingScreenStreams], [CoachingSessionState], and [HrProcessor].
class CoachingScreenState {
  CoachingScreenState({
    required CoachingSessionState sessionState,
    CoachingScreenStreams? streams,
    HrProcessor? hrProcessor,
  })  : _sessionState = sessionState,
        _streams = streams ?? CoachingScreenStreams(),
        _hrProcessor = hrProcessor ?? HrProcessor(ProfileService.instance) {
    _sessionState.onUpdate = (_, __) => _onStateChange?.call();
    _streams.onHrData = _handleHrData;
    _streams.onStatusChange = _handleStatusChange;
    _streams.onCue = _handleCue;
  }

  final CoachingScreenStreams _streams;
  final CoachingSessionState _sessionState;
  final HrProcessor _hrProcessor;

  bool _isConnected = false;
  api.ApiCue? _currentCue;
  VoidCallback? _onStateChange;

  int get currentBpm => _hrProcessor.currentBpm;
  Zone get currentZone => _hrProcessor.currentZone;
  bool get isConnected => _isConnected;
  api.ApiCue? get currentCue => _currentCue;
  Duration get elapsed => _sessionState.elapsed;
  bool get isPaused => _sessionState.isPaused;

  void setOnStateChange(VoidCallback callback) {
    _onStateChange = callback;
  }

  void initialize() {
    ProfileService.instance.loadProfile();
    _sessionState.start();
    _streams.subscribe();
  }

  Future<void> _handleHrData(api.ApiFilteredHeartRate data) async {
    await _hrProcessor.process(data);
    _onStateChange?.call();
    _sessionState.onZoneTick(_hrProcessor.currentZone);
  }

  Future<void> _handleStatusChange(api.ApiConnectionStatus status) async {
    final isConn = await api.connectionStatusIsConnected(status: status);
    _isConnected = isConn;
    _onStateChange?.call();
  }

  void _handleCue(api.ApiCue cue) {
    _currentCue = cue;
    _onStateChange?.call();
  }

  void togglePause() {
    _sessionState.togglePause();
    _onStateChange?.call();
  }

  Future<void> stopSession() async {
    await api.disconnect();
  }

  void dispose() {
    _streams.dispose();
    _sessionState.dispose();
  }
}