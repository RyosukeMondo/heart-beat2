import 'dart:async' hide Zone;
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart' show Zone;
import '../services/coaching_cue.dart';
import '../services/coaching_screen_streams.dart';
import '../services/coaching_session_state.dart';
import '../services/coaching_cue_service.dart';
import '../services/profile_service.dart';

/// UI state and session logic for [CoachingScreen].
///
/// Coordinates [CoachingScreenStreams], [CoachingSessionState], and [HrProcessor].
/// Cue stream subscription is owned directly here (not via [CoachingScreenStreams])
/// to avoid duplicate consumption — [CoachingCueService] owns the single subscription.
class CoachingScreenState {
  CoachingScreenState({
    CoachingScreenStreams? streams,
    CoachingSessionState? sessionState,
    CoachingCueService? cueService,
  })  : _streams = streams ?? CoachingScreenStreams(),
        _sessionState = sessionState ?? CoachingSessionStateImpl(),
        _cueService = cueService ?? CoachingCueService.instance {
    _sessionState.onUpdate = (_, __) => _onStateChange?.call();
  }

  final CoachingScreenStreams _streams;
  final CoachingSessionState _sessionState;
  final CoachingCueService _cueService;

  Cue? _currentCue;
  VoidCallback? _onStateChange;
  StreamSubscription<Cue>? _cueSubscription;

  int get currentBpm => _streams.currentBpm;
  Zone get currentZone => _streams.currentZone;
  bool get isConnected => _streams.isConnected;
  Cue? get currentCue => _currentCue;
  Duration get elapsed => _sessionState.elapsed;
  bool get isPaused => _sessionState.isPaused;

  void setOnStateChange(VoidCallback callback) {
    _onStateChange = callback;
  }

  void initialize() {
    ProfileService.instance.loadProfile();
    _sessionState.start();
    _streams.onHrData = _handleHrData;
    _streams.subscribe();
    _cueSubscription = _cueService.cueStream.listen(_handleCue);
  }

  void _handleHrData(int bpm, Zone zone) {
    _sessionState.onZoneTick(zone);
    _onStateChange?.call();
  }

  void _handleCue(Cue cue) {
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
    _cueSubscription?.cancel();
    _cueSubscription = null;
  }
}