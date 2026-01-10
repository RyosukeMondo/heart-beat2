import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../widgets/hr_display.dart';
import '../widgets/zone_indicator.dart';
import '../widgets/battery_indicator.dart';
import '../services/background_service.dart';

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
  final int _maxHr = 180; // Default max HR, will be loaded from settings
  final BackgroundService _backgroundService = BackgroundService();
  bool _isServiceRunning = false;

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

      // Start background service to maintain connection during screen lock
      await _startBackgroundService();

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

  Future<void> _startBackgroundService() async {
    final started = await _backgroundService.startService();
    if (started && mounted) {
      setState(() {
        _isServiceRunning = true;
      });
    }
  }

  @override
  void dispose() {
    // Stop background service when leaving session
    if (_isServiceRunning) {
      _backgroundService.stopService();
    }
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

        // Update background service notification with current BPM and zone
        if (_isServiceRunning) {
          _backgroundService.updateBpm(bpm, zone: zone.name);
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BPM Display
              HrDisplay(bpm: bpm),

              const SizedBox(height: 32),

              // Zone Indicator
              ZoneIndicator(zone: zone),

              const SizedBox(height: 32),

              // Battery Indicator
              if (batteryLevel != null)
                BatteryIndicator(batteryLevel: batteryLevel),
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
}
