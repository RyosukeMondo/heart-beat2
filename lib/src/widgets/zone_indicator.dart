import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Widget displaying training zone with color-coded visualization.
///
/// This stateless widget shows the current heart rate training zone
/// with appropriate colors and labels based on exercise intensity.
class ZoneIndicator extends StatelessWidget {
  /// The current training zone.
  final Zone zone;

  const ZoneIndicator({
    super.key,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = _getZoneColor();
    final zoneName = _getZoneName();

    return Container(
      key: const Key('zoneIndicator'),
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.2),
        border: Border.all(color: zoneColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            zoneName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: zoneColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the color associated with the training zone.
  Color _getZoneColor() {
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

  /// Returns the name and description of the training zone.
  String _getZoneName() {
    switch (zone) {
      case Zone.zone1:
        return 'Zone 1 (Recovery)';
      case Zone.zone2:
        return 'Zone 2 (Fat Burning)';
      case Zone.zone3:
        return 'Zone 3 (Aerobic)';
      case Zone.zone4:
        return 'Zone 4 (Threshold)';
      case Zone.zone5:
        return 'Zone 5 (Maximum)';
    }
  }
}
