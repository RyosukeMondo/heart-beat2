import 'package:flutter/material.dart';
import '../services/hr_history_service.dart';

/// Health screen showing rolling HR averages over 1h / 24h / 7d.
///
/// Tiles call [HrHistoryService.rollingAvg] on init and on pull-to-refresh.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  static const _window1h = 3600;
  static const _window24h = 86400;
  static const _window7d = 604800;

  double? _avg1h;
  double? _avg24h;
  double? _avg7d;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAverages();
  }

  Future<void> _loadAverages() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      HrHistoryService.instance.rollingAvg(windowSecs: _window1h),
      HrHistoryService.instance.rollingAvg(windowSecs: _window24h),
      HrHistoryService.instance.rollingAvg(windowSecs: _window7d),
    ]);
    if (!mounted) return;
    setState(() {
      _avg1h = results[0];
      _avg24h = results[1];
      _avg7d = results[2];
      _isLoading = false;
    });
  }

  String _formatAvg(double? avg) {
    if (avg == null) return '—';
    return '${avg.toStringAsFixed(0)} BPM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health')),
      body: RefreshIndicator(
        onRefresh: _loadAverages,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AverageCard(
              label: '1 Hour',
              avg: _avg1h,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
            const SizedBox(height: 12),
            _AverageCard(
              label: '24 Hours',
              avg: _avg24h,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
            const SizedBox(height: 12),
            _AverageCard(
              label: '7 Days',
              avg: _avg7d,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
          ],
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  final String label;
  final double? avg;
  final bool isLoading;
  final String Function(double?) onFormat;

  const _AverageCard({
    required this.label,
    required this.avg,
    required this.isLoading,
    required this.onFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                onFormat(avg),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: avg == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
