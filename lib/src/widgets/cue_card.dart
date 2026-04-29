import 'package:flutter/material.dart';
import '../services/coaching_cue.dart';
import '../utils/cue_helpers.dart';

/// Widget displaying a coaching cue card with priority styling.
///
/// Shows the cue label, message, current BPM, and priority badge.
class CueCard extends StatelessWidget {
  const CueCard({super.key, required this.cue, required this.currentBpm});

  final Cue cue;
  final int currentBpm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = CueHelpers.cuePriorityColor(cue.priority.value);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.15),
        border: Border.all(color: priorityColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                CueHelpers.cueLabelText(cue.label),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: priorityColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(CueHelpers.priorityLabel(cue.priority.value), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(cue.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('BPM: $currentBpm', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}