import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../widgets/hr_display.dart';
import '../widgets/zone_indicator.dart';
import '../widgets/phase_progress.dart';
import '../widgets/zone_feedback.dart';
import '../widgets/session_controls.dart';
import '../widgets/connection_banner.dart';
import 'dart:async';

/// Workout execution screen that displays real-time workout progress.
///
/// Shows the current phase, time remaining, heart rate, zone status, and provides
/// controls for pausing/resuming and stopping the workout.
class WorkoutScreen extends StatefulWidget {
  /// The name of the training plan to execute.
  final String planName;

  const WorkoutScreen({
    super.key,
    required this.planName,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Stream<api.ApiSessionProgress>? _progressStream;
  StreamSubscription<api.ApiSessionProgress>? _progressSubscription;

  // Current workout state
  api.ApiSessionProgress? _currentProgress;
  String _currentState = '';
  int _currentBpm = 0;
  String _currentPhaseName = '';
  int _phaseElapsed = 0;
  int _phaseRemaining = 0;
  int _totalElapsed = 0;
  int _totalRemaining = 0;
  api.ApiZoneStatus? _zoneStatus;
  Zone? _targetZone;

  bool _isStarting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startWorkout();
  }

  Future<void> _startWorkout() async {
    try {
      setState(() {
        _isStarting = true;
        _errorMessage = null;
      });

      // Start the workout
      await api.startWorkout(planName: widget.planName);

      // Create the progress stream
      final stream = api.createSessionProgressStream();

      if (!mounted) return;

      // Subscribe to progress updates
      _progressSubscription = stream.listen(
        (progress) async {
          if (!mounted) return;

          // Extract all the values we need
          final state = await api.sessionProgressState(progress: progress);
          final stateString = await api.sessionStateToString(state: state);
          final bpm = await api.sessionProgressCurrentBpm(progress: progress);
          final phaseProgress = await api.sessionProgressPhaseProgress(progress: progress);
          final phaseName = await api.phaseProgressPhaseName(progress: phaseProgress);
          final phaseElapsed = await api.phaseProgressElapsedSecs(progress: phaseProgress);
          final phaseRemaining = await api.phaseProgressRemainingSecs(progress: phaseProgress);
          final totalElapsed = await api.sessionProgressTotalElapsedSecs(progress: progress);
          final totalRemaining = await api.sessionProgressTotalRemainingSecs(progress: progress);
          final zoneStatusObj = await api.sessionProgressZoneStatus(progress: progress);
          final targetZone = await api.phaseProgressTargetZone(progress: phaseProgress);

          if (!mounted) return;

          setState(() {
            _currentProgress = progress;
            _currentState = stateString;
            _currentBpm = bpm;
            _currentPhaseName = phaseName;
            _phaseElapsed = phaseElapsed;
            _phaseRemaining = phaseRemaining;
            _totalElapsed = totalElapsed;
            _totalRemaining = totalRemaining;
            _zoneStatus = zoneStatusObj;
            _targetZone = targetZone;
            _isStarting = false;
          });

          // Check if workout is complete
          if (stateString == 'Completed' || stateString == 'Stopped') {
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Stream error: $error';
            _isStarting = false;
          });
        },
      );

      setState(() {
        _progressStream = stream;
        _isStarting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isStarting = false;
        _errorMessage = 'Failed to start workout: $e';
      });
    }
  }

  Future<void> _pauseWorkout() async {
    try {
      await api.pauseWorkout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pause: $e')),
      );
    }
  }

  Future<void> _resumeWorkout() async {
    try {
      await api.resumeWorkout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resume: $e')),
      );
    }
  }

  Future<void> _stopWorkout() async {
    try {
      await api.stopWorkout();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop: $e')),
      );
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.planName),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isStarting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting workout...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentProgress == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for workout data...'),
          ],
        ),
      );
    }

    return _buildWorkoutDisplay(colorScheme);
  }

  Widget _buildWorkoutDisplay(ColorScheme colorScheme) {
    return Column(
      children: [
        // Connection status banner
        const ConnectionBanner(),

        // Main content area
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Heart rate display
                HrDisplay(bpm: _currentBpm),

                const SizedBox(height: 32),

                // Zone indicator
                if (_targetZone != null)
                  ZoneIndicator(zone: _targetZone!),

                const SizedBox(height: 32),

                // Zone feedback
                if (_zoneStatus != null)
                  ZoneFeedbackWidget(zoneStatus: _zoneStatus!),

                const SizedBox(height: 32),

                // Phase progress widget
                PhaseProgressWidget(
                  phaseName: _currentPhaseName,
                  targetZone: _targetZone!,
                  elapsedSecs: _phaseElapsed,
                  remainingSecs: _phaseRemaining,
                ),

                const SizedBox(height: 16),

                // Total time remaining
                Text(
                  'Total remaining: ${_formatTime(_totalRemaining)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                // State indicator (for debugging)
                const SizedBox(height: 8),
                Text(
                  _currentState,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),

        // Control buttons
        SessionControls(
          currentState: _currentState,
          onPause: _pauseWorkout,
          onResume: _resumeWorkout,
          onStop: _stopWorkout,
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
