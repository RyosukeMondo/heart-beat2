import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Session screen for live HR monitoring during workouts
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Stream<api.ApiFilteredHeartRate>? _hrStream;
  String? _deviceName;
  bool _isConnecting = true;
  String? _errorMessage;
  int _maxHr = 180; // Default max HR, will be loaded from settings

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final deviceId = args['device_id'] as String;
      _deviceName = args['device_name'] as String?;
      _connectToDevice(deviceId);
    }
  }

  Future<void> _connectToDevice(String deviceId) async {
    try {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      // Connect to the device
      await api.connectDevice(deviceId: deviceId);

      // Create the HR stream
      final stream = api.createHrStream();

      if (!mounted) return;

      setState(() {
        _hrStream = stream;
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _errorMessage = 'Failed to connect: $e';
      });
    }
  }

  @override
  void dispose() {
    // Stream will be automatically cleaned up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_deviceName ?? 'Session'),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: _hrStream != null
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Start workout tracking
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Start Workout - Coming Soon')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
            )
          : null,
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to device...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hrStream == null) {
      return const Center(
        child: Text('No HR stream available'),
      );
    }

    return StreamBuilder<api.ApiFilteredHeartRate>(
      stream: _hrStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Waiting for heart rate data...'),
              ],
            ),
          );
        }

        return _buildHrDisplay(snapshot.data!, colorScheme);
      },
    );
  }

  Widget _buildHrDisplay(api.ApiFilteredHeartRate data, ColorScheme colorScheme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _extractHrData(data),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final hrData = snapshot.data!;
        final bpm = hrData['bpm'] as int;
        final zone = hrData['zone'] as Zone;
        final batteryLevel = hrData['battery'] as int?;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BPM Display
              Text(
                '$bpm',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'BPM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 32),

              // Zone Indicator
              _buildZoneIndicator(zone, colorScheme),

              const SizedBox(height: 32),

              // Battery Indicator
              if (batteryLevel != null && batteryLevel < 20)
                Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.battery_alert,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Battery Low: $batteryLevel%',
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _extractHrData(api.ApiFilteredHeartRate data) async {
    final bpm = await api.hrFilteredBpm(data: data);
    final zone = await api.hrZone(data: data, maxHr: _maxHr);
    final battery = await api.hrBatteryLevel(data: data);

    return {
      'bpm': bpm,
      'zone': zone,
      'battery': battery,
    };
  }

  Widget _buildZoneIndicator(Zone zone, ColorScheme colorScheme) {
    final zoneColor = _getZoneColor(zone);
    final zoneName = _getZoneName(zone);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.2),
        border: Border.all(color: zoneColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            zoneName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: zoneColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getZoneColor(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return Colors.blue;
      case Zone.zone2:
        return Colors.green;
      case Zone.zone3:
        return Colors.yellow.shade700;
      case Zone.zone4:
        return Colors.orange;
      case Zone.zone5:
        return Colors.red;
    }
  }

  String _getZoneName(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return 'Zone 1 (Recovery)';
      case Zone.zone2:
        return 'Zone 2 (Fat Burning)';
      case Zone.zone3:
        return 'Zone 3 (Aerobic)';
      case Zone.zone4:
        return 'Zone 4 (Threshold)';
      case Zone.zone5:
        return 'Zone 5 (Maximum)';
    }
  }
}
