import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/diagnosis_log_service.dart';
import 'filter_bar.dart';

class DiagnosisFilterBarWrapper extends StatelessWidget {
  final bool autoScroll;
  final VoidCallback onAutoScrollToggled;

  const DiagnosisFilterBarWrapper({
    super.key,
    required this.autoScroll,
    required this.onAutoScrollToggled,
  });

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DiagnosisLogService>();

    return DiagnosisFilterBar(
      sourceFilter: svc.sourceFilter,
      levelFilter: svc.levelFilter,
      searchController: TextEditingController(text: svc.searchQuery),
      autoScroll: autoScroll,
      onSourceChanged: (v) => svc.setSourceFilter(v),
      onLevelChanged: (v) => svc.setLevelFilter(v),
      onSearchChanged: (v) => svc.setSearchQuery(v),
      onAutoScrollToggled: onAutoScrollToggled,
      onClearPinned: () {},
    );
  }
}