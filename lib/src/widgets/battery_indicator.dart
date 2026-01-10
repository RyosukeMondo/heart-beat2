import 'package:flutter/material.dart';

/// Widget displaying battery level warning when battery is low.
///
/// This stateless widget shows a warning card with battery icon
/// when the device battery level drops below 20%.
class BatteryIndicator extends StatelessWidget {
  /// The battery level percentage (0-100).
  final int batteryLevel;

  /// Whether to show the indicator. Typically shown when battery < 20%.
  final bool show;

  const BatteryIndicator({
    super.key,
    required this.batteryLevel,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!show || batteryLevel >= 20) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.battery_alert,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Text(
              'Battery Low: $batteryLevel%',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
