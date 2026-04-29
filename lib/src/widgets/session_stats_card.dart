import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../utils/duration_helpers.dart';

/// Widget displaying session statistics including elapsed time and current zone.
class SessionStatsCard extends StatelessWidget {
  const SessionStatsCard({
    super.key,
    required this.elapsed,
    required this.currentZone,
    required this.zoneIcon,
  });

  final Duration elapsed;
  final Zone currentZone;
  final IconData zoneIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(theme, 'Session', DurationHelpers.formatDuration(elapsed), Icons.timer),
          _statItem(theme, 'Zone', currentZone.name.replaceAll('zone', 'Z'), zoneIcon),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}