import 'package:flutter/material.dart';
import '../controllers/workout_controller.dart';
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

  const WorkoutScreen({super.key, required this.planName});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final WorkoutController _controller;
  StreamSubscription<WorkoutState>? _stateSubscription;

  WorkoutState _state = const WorkoutState();

  @override
  void initState() {
    super.initState();
    _controller = WorkoutController();
    _controller.onWorkoutEnded = _onWorkoutEnded;
    _stateSubscription = _controller.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });
    _controller.startWorkout(widget.planName);
  }

  void _onWorkoutEnded() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('workoutScreen'),
      appBar: AppBar(
        title: Text(widget.planName),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_state.isStarting) {
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

    if (_state.error != null) {
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
                  _state.error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_state.progress == null) {
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
                HrDisplay(bpm: _state.bpm),

                const SizedBox(height: 32),

                // Zone indicator
                if (_state.targetZone != null) ZoneIndicator(zone: _state.targetZone!),

                const SizedBox(height: 32),

                // Zone feedback
                if (_state.zoneStatus != null)
                  ZoneFeedbackWidget(zoneStatus: _state.zoneStatus!),

                const SizedBox(height: 32),

                // Phase progress widget
                PhaseProgressWidget(
                  phaseName: _state.phaseName,
                  targetZone: _state.targetZone!,
                  elapsedSecs: _state.phaseElapsed,
                  remainingSecs: _state.phaseRemaining,
                ),

                const SizedBox(height: 16),

                // Total time remaining
                Text(
                  'Total remaining: ${_formatTime(_state.totalRemaining)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                // State indicator (for debugging)
                const SizedBox(height: 8),
                Text(
                  _state.state,
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
          currentState: _state.state,
          onPause: _controller.pauseWorkout,
          onResume: _controller.resumeWorkout,
          onStop: _controller.stopWorkout,
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