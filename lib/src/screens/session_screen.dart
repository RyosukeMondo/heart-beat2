import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../widgets/hr_display.dart';
import '../widgets/zone_indicator.dart';
import '../widgets/battery_indicator.dart';
import '../widgets/plan_selector.dart';
import '../widgets/connection_banner.dart';
import '../services/background_service_provider.dart';
import 'dart:async';
import 'session_screen_state.dart';

/// Session screen for live HR monitoring during workouts
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Stream<api.ApiFilteredHeartRate>? _hrStream;
  StreamSubscription<api.ApiBatteryLevel>? _batterySubscription;
  int? _batteryLevel;
  String? _deviceName;
  bool _isConnecting = true;
  String? _errorMessage;
  final SessionScreenState _state = SessionScreenState();
  bool _hasInitialized = false;
  final Stopwatch _sessionTimer = Stopwatch();
  Timer? _sessionTimerTicker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once to prevent reconnection on navigation events
    if (_hasInitialized) return;
    _hasInitialized = true;

    // Get route arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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

      // Initialize state (loads profile and starts latency tracking)
      _state.initialize();

      // Create the HR stream
      final stream = api.createHrStream();

      // Create the battery stream and subscribe to updates
      final batteryStream = api.createBatteryStream();
      _batterySubscription = batteryStream.listen((batteryLevel) {
        if (mounted) {
          setState(() {
            _batteryLevel = batteryLevel.level;
          });
        }
      });

      // Start background service to maintain connection during screen lock
      await _startBackgroundService();

      if (!mounted) return;

      setState(() {
        _hrStream = stream;
        _isConnecting = false;
      });

      // Start session timer
      _sessionTimer.start();
      _sessionTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
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
    final bgService = context.read<BackgroundServiceProvider>();
    final started = await bgService.startService();
    if (started && mounted) {
      _state.setServiceRunning(true);
    }
  }

  Future<void> _disconnectDevice() async {
    // Show confirmation dialog
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: const Text(
          'Are you sure you want to disconnect? This will end your current session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (shouldDisconnect != true) return;

    // Capture provider reference before async gap
    // ignore: use_build_context_synchronously
    final bgService = _state.isServiceRunning
        // ignore: use_build_context_synchronously
        ? Provider.of<BackgroundServiceProvider>(context, listen: false)
        : null;

    try {
      // Call disconnect API
      await api.disconnect();

      // Stop background service
      if (bgService != null) {
        await bgService.stopService();
      }

      // Navigate back to home
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error if disconnect fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Stop background service when leaving session
    if (_state.isServiceRunning) {
      final bgService = context.read<BackgroundServiceProvider>();
      bgService.stopService();
    }
    // Clean up battery subscription
    _batterySubscription?.cancel();
    _sessionTimer.stop();
    _sessionTimerTicker?.cancel();
    // Clean up state
    _state.dispose();
    // Stream will be automatically cleaned up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('sessionScreen'),
      appBar: AppBar(
        title: Text(_deviceName ?? 'Session'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        actions: [
          if (_hrStream != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              tooltip: 'Disconnect',
              onPressed: _disconnectDevice,
            ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: _hrStream != null
          ? FloatingActionButton.extended(
              onPressed: () {
                debugPrint('SessionScreen: Start Workout FAB tapped');
                PlanSelector.show(
                  context,
                  onSelect: (planName) {
                    debugPrint(
                      'SessionScreen: Plan selected callback: $planName',
                    );
                    // Use rootNavigator to escape the modal bottom sheet context
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/workout/$planName');
                  },
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
      return const Center(child: Text('No HR stream available'));
    }

    return StreamBuilder<api.ApiFilteredHeartRate>(
      stream: _hrStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
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

        // Process HR data and record latency (fire and forget - state updates independently)
        unawaited(_state.processHrData(snapshot.data!));

        return _buildHrDisplay(snapshot.data!, colorScheme);
      },
    );
  }

  Widget _buildHrDisplay(
    api.ApiFilteredHeartRate data,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<({int bpm, Zone zone})>(
      future: _state.extractHrData(data),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bpm = snapshot.data!.bpm;
        final zone = snapshot.data!.zone;

        // Update background service notification with current BPM and zone
        if (_state.isServiceRunning) {
          final bgService = context.read<BackgroundServiceProvider>();
          bgService.updateBpm(bpm, zone: zone.name);
        }

        return Column(
          children: [
            // Connection status banner
            const ConnectionBanner(),

            // Main content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // BPM Display
                    HrDisplay(bpm: bpm),

                    const SizedBox(height: 16),

                    // Session Timer
                    Text(
                      _formatElapsedTime(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                    ),

                    const SizedBox(height: 32),

                    // Zone Indicator
                    ZoneIndicator(zone: zone),

                    const SizedBox(height: 32),

                    // Battery Indicator
                    if (_batteryLevel != null)
                      BatteryIndicator(batteryLevel: _batteryLevel!),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatElapsedTime() {
    final elapsed = _sessionTimer.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (elapsed.inHours > 0) {
      final hours = elapsed.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
