import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Widget displaying the current phase progress with a progress bar and timing information.
///
/// Shows the phase name, visual progress bar colored by the target zone,
/// and elapsed/remaining time. Designed to be easily readable at arm's length
/// during active workouts.
class PhaseProgressWidget extends StatelessWidget {
  /// The name of the current phase (e.g., "Warmup", "Work", "Recovery").
  final String phaseName;

  /// The target heart rate zone for this phase.
  final Zone targetZone;

  /// Time elapsed in this phase in seconds.
  final int elapsedSecs;

  /// Time remaining in this phase in seconds.
  final int remainingSecs;

  const PhaseProgressWidget({
    super.key,
    required this.phaseName,
    required this.targetZone,
    required this.elapsedSecs,
    required this.remainingSecs,
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = _getZoneColor(targetZone);
    final phaseFraction = remainingSecs > 0
        ? elapsedSecs / (elapsedSecs + remainingSecs)
        : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phase name prominently displayed
          Text(
            phaseName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Progress bar with zone color
          LinearProgressIndicator(
            value: phaseFraction,
            minHeight: 12,
            backgroundColor: zoneColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(zoneColor),
            borderRadius: BorderRadius.circular(6),
          ),

          const SizedBox(height: 12),

          // Time display: elapsed / total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Elapsed: ${_formatTime(elapsedSecs)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                'Remaining: ${_formatTime(remainingSecs)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Total phase duration
          Text(
            'Total: ${_formatTime(elapsedSecs + remainingSecs)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// Returns the color associated with the training zone.
  Color _getZoneColor(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return Colors.blue;
      case Zone.zone2:
        return Colors.green;
      case Zone.zone3:
        return Colors.yellow.shade700;
      case Zone.zone4:
        return Colors.orange;
      case Zone.zone5:
        return Colors.red;
    }
  }

  /// Formats seconds into MM:SS format.
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
