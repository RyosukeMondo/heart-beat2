import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/diagnosis_log_service.dart';
import 'log_line.dart';

class DiagnosisLogList extends StatefulWidget {
  final bool autoScroll;

  const DiagnosisLogList({super.key, required this.autoScroll});

  @override
  State<DiagnosisLogList> createState() => _DiagnosisLogListState();
}

class _DiagnosisLogListState extends State<DiagnosisLogList> {
  final ScrollController _scrollController = ScrollController();
  int? _pinnedIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePinned(int index) {
    setState(() => _pinnedIndex = (_pinnedIndex == index) ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DiagnosisLogService>();
    final allLogs = svc.logs;
    final filtered = svc.filterLogs(allLogs);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          allLogs.isEmpty
              ? 'No logs yet'
              : 'No logs match filters',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final isPinned = _pinnedIndex == index;
        return DiagnosisLogLine(
          log: log,
          levelColor: svc.levelColor(log.level),
          isPinned: isPinned,
          onTap: () => _togglePinned(index),
        );
      },
    );
  }
}