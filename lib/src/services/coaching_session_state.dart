import 'dart:async';
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Manages coaching session state: timer, zone time tracking, pause state.
///
/// Extracted from CoachingScreenState to reduce its responsibilities.
abstract class CoachingSessionState {
  CoachingSessionState();

  /// Callback invoked on every tick with current elapsed time and zone times.
  void Function(Duration elapsed, Map<Zone, Duration> zoneTime)? onUpdate;

  Duration get elapsed;
  bool get isPaused;
  Map<Zone, Duration> get zoneTime;

  void start();
  void pause();
  void resume();
  void togglePause();
  void onZoneTick(Zone zone);
  void dispose();
}

class CoachingSessionStateImpl implements CoachingSessionState {
  CoachingSessionStateImpl();

  DateTime? _sessionStartTime;
  Duration _elapsed = Duration.zero;
  Timer? _sessionTimer;
  bool _isPaused = false;

  final Map<Zone, Duration> _zoneTime = {
    Zone.zone1: Duration.zero,
    Zone.zone2: Duration.zero,
    Zone.zone3: Duration.zero,
    Zone.zone4: Duration.zero,
    Zone.zone5: Duration.zero,
  };
  Zone? _lastZone;

  @override
  void Function(Duration elapsed, Map<Zone, Duration> zoneTime)? onUpdate;

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isPaused => _isPaused;

  @override
  Map<Zone, Duration> get zoneTime => Map.unmodifiable(_zoneTime);

  @override
  void start() {
    _sessionStartTime = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _elapsed = DateTime.now().difference(_sessionStartTime!);
        onUpdate?.call(_elapsed, _zoneTime);
      }
    });
  }

  @override
  void pause() {
    _isPaused = true;
    onUpdate?.call(_elapsed, _zoneTime);
  }

  @override
  void resume() {
    _isPaused = false;
    onUpdate?.call(_elapsed, _zoneTime);
  }

  @override
  void togglePause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  @override
  void onZoneTick(Zone zone) {
    if (_lastZone != null && !_isPaused) {
      _zoneTime[_lastZone!] = _zoneTime[_lastZone!]! + const Duration(seconds: 1);
    }
    _lastZone = zone;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }
}