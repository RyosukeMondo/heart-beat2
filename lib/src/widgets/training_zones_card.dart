import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class TrainingZonesCard extends StatelessWidget {
  final int? effectiveMaxHr;
  final CustomZones? zones;

  const TrainingZonesCard({
    super.key,
    required this.effectiveMaxHr,
    required this.zones,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Training Zones', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/zone-editor');
                    if (result == true) {}
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Customize'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildZoneDisplay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneDisplay(BuildContext context) {
    final effectiveMaxHr = this.effectiveMaxHr;
    if (effectiveMaxHr == null) {
      return const Text('Enter max HR or age to see zone ranges');
    }

    final zones = this.zones ?? CustomZones.defaults;

    return Column(
      children: [
        _buildZoneInfo(context, 'Zone 1 (Recovery)', '0-${zones.zone1Max}%', Colors.blue, 0, zones.zone1Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 2 (Fat Burning)', '${zones.zone1Max}-${zones.zone2Max}%', Colors.green, zones.zone1Max, zones.zone2Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 3 (Aerobic)', '${zones.zone2Max}-${zones.zone3Max}%', Colors.yellow, zones.zone2Max, zones.zone3Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 4 (Threshold)', '${zones.zone3Max}-${zones.zone4Max}%', Colors.orange, zones.zone3Max, zones.zone4Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 5 (Maximum)', '${zones.zone4Max}-100%', Colors.red, zones.zone4Max, 100, effectiveMaxHr),
      ],
    );
  }

  Widget _buildZoneInfo(
    BuildContext context,
    String name,
    String percentage,
    Color color,
    int minPercent,
    int maxPercent,
    int maxHr,
  ) {
    final minBpm = (maxHr * minPercent / 100).round();
    final maxBpm = (maxHr * maxPercent / 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text(
            '$percentage ($minBpm-$maxBpm BPM)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}