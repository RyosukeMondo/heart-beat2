import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart';

/// A bottom sheet widget for selecting a training plan
class PlanSelector extends StatefulWidget {
  /// Callback invoked when a plan is selected
  final void Function(String planName) onSelect;

  /// Optional plan loader function for testing.
  /// If not provided, uses the default Rust FFI listPlans() function.
  final Future<List<String>> Function()? planLoader;

  const PlanSelector({
    super.key,
    required this.onSelect,
    this.planLoader,
  });

  @override
  State<PlanSelector> createState() => _PlanSelectorState();

  /// Show the plan selector bottom sheet
  static Future<void> show(
    BuildContext context, {
    required void Function(String planName) onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PlanSelector(onSelect: onSelect),
    );
  }
}

class _PlanSelectorState extends State<PlanSelector> {
  List<String>? _plans;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use injected plan loader for testing, or default Rust FFI function
      final loader = widget.planLoader ?? listPlans;
      final plans = await loader();
      if (!mounted) return;

      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectPlan(String planName) {
    debugPrint('PlanSelector: Plan selected: $planName');
    widget.onSelect(planName);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Select Training Plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: _buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load plans',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_plans == null || _plans!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No Plans Found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Training plans should be placed in:\n~/.heart-beat/plans/',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _plans!.length,
      itemBuilder: (context, index) {
        final planName = _plans![index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.directions_run,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(planName),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            debugPrint('PlanSelector: ListTile tapped for: $planName');
            _selectPlan(planName);
          },
        );
      },
    );
  }
}
