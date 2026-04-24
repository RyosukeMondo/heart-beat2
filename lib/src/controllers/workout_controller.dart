import 'dart:async';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../services/audio_feedback_service.dart';
import '../services/latency_service.dart';
import '../services/voice_coaching_service.dart';

/// State emitted by [WorkoutController] during workout execution.
class WorkoutState {
  final api.ApiSessionProgress? progress;
  final String state;
  final int bpm;
  final String phaseName;
  final int phaseElapsed;
  final int phaseRemaining;
  final int totalRemaining;
  final api.ApiZoneStatus? zoneStatus;
  final Zone? targetZone;
  final bool isStarting;
  final String? error;

  const WorkoutState({
    this.progress,
    this.state = '',
    this.bpm = 0,
    this.phaseName = '',
    this.phaseElapsed = 0,
    this.phaseRemaining = 0,
    this.totalRemaining = 0,
    this.zoneStatus,
    this.targetZone,
    this.isStarting = true,
    this.error,
  });

  WorkoutState copyWith({
    api.ApiSessionProgress? progress,
    String? state,
    int? bpm,
    String? phaseName,
    int? phaseElapsed,
    int? phaseRemaining,
    int? totalRemaining,
    api.ApiZoneStatus? zoneStatus,
    Zone? targetZone,
    bool? isStarting,
    String? error,
  }) {
    return WorkoutState(
      progress: progress ?? this.progress,
      state: state ?? this.state,
      bpm: bpm ?? this.bpm,
      phaseName: phaseName ?? this.phaseName,
      phaseElapsed: phaseElapsed ?? this.phaseElapsed,
      phaseRemaining: phaseRemaining ?? this.phaseRemaining,
      totalRemaining: totalRemaining ?? this.totalRemaining,
      zoneStatus: zoneStatus ?? this.zoneStatus,
      targetZone: targetZone ?? this.targetZone,
      isStarting: isStarting ?? this.isStarting,
      error: error,
    );
  }
}

/// Controller that mediates workout execution and service interactions.
///
/// Decouples [WorkoutScreen] from direct service dependencies by handling
/// [VoiceCoachingService], [AudioFeedbackService], and [LatencyService]
/// calls internally.
class WorkoutController {
  final VoiceCoachingService _voiceCoaching;
  final AudioFeedbackService _audioFeedback;
  final LatencyService _latency;

  StreamSubscription<api.ApiSessionProgress>? _progressSubscription;

  // Previous state tracking for audio feedback
  String _previousPhaseName = '';
  bool _previousIsTooLow = false;
  bool _previousIsTooHigh = false;

  final _stateController = StreamController<WorkoutState>.broadcast();
  WorkoutState _currentState = const WorkoutState();

  /// Stream of [WorkoutState] updates.
  Stream<WorkoutState> get stateStream => _stateController.stream;

  /// Current workout state.
  WorkoutState get currentState => _currentState;

  /// Callback invoked when the workout completes or is stopped.
  void Function()? onWorkoutEnded;

  WorkoutController({
    VoiceCoachingService? voiceCoaching,
    AudioFeedbackService? audioFeedback,
    LatencyService? latency,
  })  : _voiceCoaching = voiceCoaching ?? VoiceCoachingService.instance,
        _audioFeedback = audioFeedback ?? AudioFeedbackService.instance,
        _latency = latency ?? LatencyService.instance;

  /// Initialize the controller and start the workout.
  Future<void> startWorkout(String planName) async {
    _latency.start();
    _voiceCoaching.initialize();

    _updateState(const WorkoutState(isStarting: true, error: null));

    try {
      await api.startWorkout(planName: planName);
      final stream = api.createSessionProgressStream();
      _progressSubscription = stream.listen(_onProgress);
    } catch (e) {
      _updateState(WorkoutState(isStarting: false, error: 'Failed to start workout: $e'));
    }
  }

  void _onProgress(api.ApiSessionProgress progress) async {
    final state = await api.sessionProgressState(progress: progress);
    final stateString = await api.sessionStateToString(state: state);
    final bpm = await api.sessionProgressCurrentBpm(progress: progress);
    final phaseProgress = await api.sessionProgressPhaseProgress(progress: progress);
    final phaseName = await api.phaseProgressPhaseName(progress: phaseProgress);
    final phaseElapsed = await api.phaseProgressElapsedSecs(progress: phaseProgress);
    final phaseRemaining = await api.phaseProgressRemainingSecs(progress: phaseProgress);
    final totalRemaining = await api.sessionProgressTotalRemainingSecs(progress: progress);
    final zoneStatusObj = await api.sessionProgressZoneStatus(progress: progress);
    final targetZone = await api.phaseProgressTargetZone(progress: phaseProgress);

    final isInZone = await api.zoneStatusIsInZone(status: zoneStatusObj);
    final isTooLow = await api.zoneStatusIsTooLow(status: zoneStatusObj);
    final isTooHigh = await api.zoneStatusIsTooHigh(status: zoneStatusObj);

    // Zone deviation audio feedback
    final zoneName = targetZone.name;
    if (!isInZone) {
      if (isTooLow && !_previousIsTooLow) {
        _audioFeedback.playZoneTooLow();
        _voiceCoaching.announceZoneDeviation(false, zoneName);
      } else if (isTooHigh && !_previousIsTooHigh) {
        _audioFeedback.playZoneTooHigh();
        _voiceCoaching.announceZoneDeviation(true, zoneName);
      }
    }

    // Phase transition audio feedback
    if (_previousPhaseName.isNotEmpty && _previousPhaseName != phaseName) {
      _audioFeedback.playPhaseTransition();
      _voiceCoaching.announcePhaseComplete(_previousPhaseName);
      final totalPhaseSecs = phaseElapsed + phaseRemaining;
      _voiceCoaching.announcePhaseStart(phaseName, zoneName, totalPhaseSecs);
    }

    // Countdown announcements for last 3 seconds of phase
    if (phaseRemaining >= 1 && phaseRemaining <= 3) {
      _voiceCoaching.announceCountdown(phaseRemaining);
    }

    // Halfway announcement
    final totalPhaseDuration = phaseElapsed + phaseRemaining;
    final halfPoint = totalPhaseDuration ~/ 2;
    if (totalPhaseDuration > 0 && phaseElapsed == halfPoint) {
      _voiceCoaching.announceHalfway(phaseName, phaseRemaining);
    }

    _updateState(WorkoutState(
      progress: progress,
      state: stateString,
      bpm: bpm,
      phaseName: phaseName,
      phaseElapsed: phaseElapsed,
      phaseRemaining: phaseRemaining,
      totalRemaining: totalRemaining,
      zoneStatus: zoneStatusObj,
      targetZone: targetZone,
      isStarting: false,
    ));

    // Update previous state
    _previousPhaseName = phaseName;
    _previousIsTooLow = isTooLow;
    _previousIsTooHigh = isTooHigh;

    // Check if workout is complete
    if (stateString == 'Completed') {
      final totalElapsedMins = (phaseElapsed + totalRemaining) ~/ 60;
      _voiceCoaching.announceWorkoutComplete(totalElapsedMins, bpm);
      onWorkoutEnded?.call();
    } else if (stateString == 'Stopped') {
      onWorkoutEnded?.call();
    }
  }

  void _updateState(WorkoutState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> pauseWorkout() async {
    try {
      await api.pauseWorkout();
    } catch (_) {
      // Error handling can be added via state if needed
    }
  }

  Future<void> resumeWorkout() async {
    try {
      await api.resumeWorkout();
    } catch (_) {
      // Error handling can be added via state if needed
    }
  }

  Future<void> stopWorkout() async {
    try {
      await api.stopWorkout();
    } catch (_) {
      // Error handling can be added via state if needed
    }
  }

  /// Release resources.
  void dispose() {
    _progressSubscription?.cancel();
    _latency.stop();
    _stateController.close();
  }
}