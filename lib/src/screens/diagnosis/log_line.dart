import 'package:flutter/material.dart';
import '../../services/diagnosis_log_service.dart';

class DiagnosisLogLine extends StatelessWidget {
  final LogEntry log;
  final Color levelColor;
  final bool isPinned;
  final VoidCallback onTap;

  const DiagnosisLogLine({
    super.key,
    required this.log,
    required this.levelColor,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      log.timestampMs,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPinned
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
            left: isPinned
                ? BorderSide(color: theme.colorScheme.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: levelColor, width: 1),
                  ),
                  child: Text(
                    log.level,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:'
                  '${timestamp.minute.toString().padLeft(2, '0')}:'
                  '${timestamp.second.toString().padLeft(2, '0')}.'
                  '${(timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.target,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPinned)
                  Icon(
                    Icons.push_pin,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              log.message,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
