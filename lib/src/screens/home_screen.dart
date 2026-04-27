import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../bridge/api_generated.dart/api.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../services/device_service.dart';
import '../services/readiness_service.dart';

/// Home screen for device scanning and selection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  String? _error;

  // Today's recommendation state
  ApiReadinessData? _readiness;
  bool _readinessLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
  }

  Future<void> _loadReadiness() async {
    try {
      final readiness = await ReadinessService.instance.loadReadiness();
      if (!mounted) return;
      setState(() {
        _readiness = readiness;
        _readinessLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _readinessLoading = false;
      });
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _devices = [];
    });

    try {
      final devices = await DeviceService.instance.scanForDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    } on BluetoothPermissionException {
      if (!mounted) return;
      setState(() {
        _error = 'Bluetooth permissions are required';
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth permissions denied. Please enable them in settings.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Scan failed: $e';
        _isScanning = false;
      });
    }
  }

  void _connectToDevice(DiscoveredDevice device) {
    Navigator.pushNamed(
      context,
      '/session',
      arguments: {'device_id': device.id, 'device_name': device.name},
    );
  }

  Color _readinessColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  IconData _readinessIcon(String level) {
    switch (level) {
      case 'Ready':
        return Icons.flash_on;
      case 'Moderate':
        return Icons.trending_flat;
      case 'Rest':
        return Icons.hotel;
      default:
        return Icons.favorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('homeScreen'),
      appBar: AppBar(
        title: const Text('Heart Beat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.pushNamed(context, '/analytics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Diagnosis',
              onPressed: () {
                Navigator.pushNamed(context, '/diagnosis');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Today's Recommendation card
          _buildTodayCard(),

          // Scan button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanForDevices,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
              ),
            ),
          ),

          // Error display
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Quick action chips
          _buildQuickActions(),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Scanning for heart rate monitors...'
                          : 'Tap "Scan for Devices" to find heart rate monitors',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.favorite),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text('RSSI: ${device.rssi} dBm'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    if (_readinessLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    if (_readiness == null) return const SizedBox.shrink();

    final r = _readiness!;
    final color = _readinessColor(r.score);
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/readiness'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Score circle
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: r.score / 100,
                          strokeWidth: 5,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      Text(
                        '${r.score}',
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Recommendation text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_readinessIcon(r.level), size: 18, color: color),
                          const SizedBox(width: 6),
                          Text(
                            "Today's Readiness",
                            style: t.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.recommendation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.fitness_center, size: 18),
              label: const Text('Workout Library'),
              onPressed: () => Navigator.pushNamed(context, '/workout-library'),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.show_chart, size: 18),
              label: const Text('Training Load'),
              onPressed: () => Navigator.pushNamed(context, '/training-load'),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Calendar'),
              onPressed: () => Navigator.pushNamed(context, '/calendar'),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.monitor_heart, size: 18),
              label: const Text('Readiness'),
              onPressed: () => Navigator.pushNamed(context, '/readiness'),
            ),
          ],
        ),
      ),
    );
  }
}
