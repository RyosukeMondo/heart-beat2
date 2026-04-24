import 'package:flutter/material.dart';

/// Widget showing time spent in each heart rate zone
class SessionDetailTimeInZone extends StatelessWidget {
  final int durationSecs;
  final List<int> timeInZone;

  const SessionDetailTimeInZone({
    super.key,
    required this.durationSecs,
    required this.timeInZone,
  });

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (durationSecs == 0) {
      return const SizedBox.shrink();
    }

    final zoneNames = ['Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5'];
    final zoneColors = [
      Colors.grey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time in Heart Rate Zones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (index) {
              final time = timeInZone[index];
              final percentage = (time / durationSecs * 100).toStringAsFixed(1);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          zoneNames[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '${_formatDuration(time)} ($percentage%)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: time / durationSecs,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(zoneColors[index]),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
