import 'package:flutter/material.dart';

class DiagnosisFilterBar extends StatelessWidget {
  final String? sourceFilter;
  final String? levelFilter;
  final TextEditingController searchController;
  final bool autoScroll;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onLevelChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAutoScrollToggled;
  final VoidCallback onClearPinned;

  const DiagnosisFilterBar({
    super.key,
    required this.sourceFilter,
    required this.levelFilter,
    required this.searchController,
    required this.autoScroll,
    required this.onSourceChanged,
    required this.onLevelChanged,
    required this.onSearchChanged,
    required this.onAutoScrollToggled,
    required this.onClearPinned,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Source: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...['all', 'rust', 'dart'].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(s.toUpperCase()),
                        selected: (sourceFilter ?? 'all') == s,
                        onSelected: (_) => onSourceChanged(s == 'all' ? null : s),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: levelFilter ?? 'all',
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'trace', child: Text('TRACE')),
                    DropdownMenuItem(value: 'debug', child: Text('DEBUG')),
                    DropdownMenuItem(value: 'info', child: Text('INFO')),
                    DropdownMenuItem(value: 'warn', child: Text('WARN')),
                    DropdownMenuItem(value: 'error', child: Text('ERROR')),
                  ],
                  onChanged: (v) => onLevelChanged(v == 'all' ? null : v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  autoScroll ? Icons.vertical_align_bottom : Icons.push_pin,
                  color: autoScroll ? Colors.green : Colors.orange,
                ),
                tooltip: autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF (pinned)',
                onPressed: onAutoScrollToggled,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
