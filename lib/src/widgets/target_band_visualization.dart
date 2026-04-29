import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../models/user_profile.dart';

/// Widget displaying the target heart rate band visualization.
///
/// Shows a colored bar representing HR zones with the current BPM marker,
/// along with zone labels and the current target zone name.
class TargetBandVisualization extends StatelessWidget {
  const TargetBandVisualization({
    super.key,
    required this.currentBpm,
    required this.currentZone,
    required this.profile,
  });

  final int currentBpm;
  final Zone currentZone;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHr = profile.effectiveMaxHr;
    final zones = profile.effectiveZones;

    final z1Pct = zones.zone1Max / 100.0;
    final z2Pct = zones.zone2Max / 100.0;
    final z3Pct = zones.zone3Max / 100.0;
    final z4Pct = zones.zone4Max / 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _zoneLabel('Z1', Colors.blue),
              Expanded(child: _zoneLabel('Z2', Colors.green)),
              Expanded(child: _zoneLabel('Z3', Colors.yellow.shade700)),
              Expanded(child: _zoneLabel('Z4', Colors.orange)),
              _zoneLabel('Z5', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Row(
                children: [
                  _zoneFill(z1Pct, Colors.blue, currentBpm / maxHr),
                  _zoneFill(z2Pct - z1Pct, Colors.green, currentBpm / maxHr),
                  _zoneFill(z3Pct - z2Pct, Colors.yellow.shade700, currentBpm / maxHr),
                  _zoneFill(z4Pct - z3Pct, Colors.orange, currentBpm / maxHr),
                  _zoneFill(1.0 - z4Pct, Colors.red, currentBpm / maxHr),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(maxHr * 0.5).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.6).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.7).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.8).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.9).round()}', style: theme.textTheme.labelSmall),
              Text('$maxHr', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Target Zone: ${currentZone.name.replaceAll('zone', 'Zone ')}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _zoneLabel(String label, Color color) {
    return Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center);
  }

  Widget _zoneFill(double fraction, Color color, double bpmFraction) {
    return Expanded(flex: (fraction * 100).round(), child: Container(color: color.withValues(alpha: 0.3)));
  }
}