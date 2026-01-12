import 'package:flutter/material.dart';

/// Widget providing pause/resume and stop controls for workout sessions.
///
/// Features:
/// - Large, glove-friendly touch targets (48dp minimum)
/// - Pause/Resume toggle button that adapts based on session state
/// - Stop button with confirmation dialog to prevent accidental termination
/// - Visual distinction for the destructive stop action
///
/// Designed for reliable control during active workouts, even with gloves.
class SessionControls extends StatelessWidget {
  /// The current session state (e.g., "Running", "Paused")
  final String currentState;

  /// Callback invoked when the workout is paused.
  final VoidCallback onPause;

  /// Callback invoked when the workout is resumed.
  final VoidCallback onResume;

  /// Callback invoked when the workout is stopped (after confirmation).
  final VoidCallback onStop;

  const SessionControls({
    super.key,
    required this.currentState,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  Future<void> _handleStop(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Workout?'),
        content: const Text(
          'Are you sure you want to stop this workout? Your progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onStop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaused = currentState == 'Paused';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Pause/Resume button
            ElevatedButton.icon(
              onPressed: isPaused ? onResume : onPause,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 56), // 56dp > 48dp minimum
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            // Stop button with destructive styling
            ElevatedButton.icon(
              onPressed: () => _handleStop(context),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                minimumSize: const Size(140, 56), // 56dp > 48dp minimum
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
