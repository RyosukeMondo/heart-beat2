import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import 'coaching_session_state.dart';
import 'coaching_screen_streams.dart';
import 'profile_service.dart';

/// UI state and session logic for [CoachingScreen].
///
/// Holds:
/// - Current BPM, zone, connection status, and cue
/// - HR processing (BPM extraction, zone mapping)
/// - Delegates timer/zone-tracking to [CoachingSessionState]
/// - Delegates stream subscriptions to [CoachingScreenStreams]
class CoachingScreenState {
  CoachingScreenState() {
    _sessionState.onUpdate = (_, __) => _onStateChange?.call();
    _streams.onHrData = _handleHrData;
    _streams.onStatusChange = _handleStatusChange;
    _streams.onCue = _handleCue;
  }

  final CoachingSessionState _sessionState = CoachingSessionState();
  final CoachingScreenStreams _streams = CoachingScreenStreams();
  final ProfileService _profileService = ProfileService.instance;

  int _currentBpm = 0;
  Zone _currentZone = Zone.zone1;
  bool _isConnected = false;
  api.ApiCue? _currentCue;
  VoidCallback? _onStateChange;

  int get currentBpm => _currentBpm;
  Zone get currentZone => _currentZone;
  bool get isConnected => _isConnected;
  api.ApiCue? get currentCue => _currentCue;
  Duration get elapsed => _sessionState.elapsed;
  bool get isPaused => _sessionState.isPaused;

  void setOnStateChange(VoidCallback callback) {
    _onStateChange = callback;
  }

  void initialize() {
    _profileService.loadProfile();
    _sessionState.start();
    _streams.subscribe();
  }

  void _handleHrData(api.ApiFilteredHeartRate data) async {
    final bpm = await api.hrFilteredBpm(data: data);
    final zone = _profileService.getZoneForBpm(bpm) ?? Zone.zone1;

    _currentBpm = bpm;
    _currentZone = zone;
    _onStateChange?.call();

    _sessionState.onZoneTick(zone);
  }

  void _handleStatusChange(api.ApiConnectionStatus status) async {
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