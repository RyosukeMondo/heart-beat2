import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/diagnosis_log_service.dart';
import 'filter_bar.dart';

class DiagnosisFilterBarWrapper extends StatefulWidget {
  final bool autoScroll;
  final VoidCallback onAutoScrollToggled;

  const DiagnosisFilterBarWrapper({
    super.key,
    required this.autoScroll,
    required this.onAutoScrollToggled,
  });

  @override
  State<DiagnosisFilterBarWrapper> createState() =>
      _DiagnosisFilterBarWrapperState();
}

class _DiagnosisFilterBarWrapperState extends State<DiagnosisFilterBarWrapper> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DiagnosisLogService>();
    if (_searchController.text != svc.searchQuery) {
      _searchController.text = svc.searchQuery;
    }

    return DiagnosisFilterBar(
      sourceFilter: svc.sourceFilter,
      levelFilter: svc.levelFilter,
      searchController: _searchController,
      autoScroll: widget.autoScroll,
      onSourceChanged: (v) => svc.setSourceFilter(v),
      onLevelChanged: (v) => svc.setLevelFilter(v),
      onSearchChanged: (v) => svc.setSearchQuery(v),
      onAutoScrollToggled: widget.onAutoScrollToggled,
      onClearPinned: () {},
    );
  }
}