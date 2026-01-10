import 'package:flutter_background_service/flutter_background_service.dart';

/// Background service for maintaining HR streaming during workouts.
/// Implements Android Foreground Service to keep app alive when screen locked.
class BackgroundService {
  static const String _channelId = 'heart_beat_channel';
  static const int _notificationId = 888;

  /// Initialize the background service configuration.
  /// Must be called before startService().
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Heart Rate Monitor',
        initialNotificationContent: 'Preparing...',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  /// Entry point for the background service.
  /// Handles service lifecycle and BPM updates.
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Handle stop service event
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    // Handle BPM updates from the app
    service.on('updateBpm').listen((event) {
      if (service is AndroidServiceInstance) {
        final bpm = event?['bpm'] as int?;
        final zone = event?['zone'] as String?;

        if (bpm != null) {
          final content = zone != null
              ? 'Current: $bpm BPM - Zone: $zone'
              : 'Current: $bpm BPM';

          service.setForegroundNotificationInfo(
            title: 'Heart Rate Monitor',
            content: content,
          );
        }
      }
    });

    // Send ready signal to the app
    service.invoke('serviceReady');
  }

  /// Start the background service.
  /// Returns true if started successfully.
  Future<bool> startService() async {
    final service = FlutterBackgroundService();
    return await service.startService();
  }

  /// Stop the background service.
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Update the notification with current BPM and optional zone.
  void updateBpm(int bpm, {String? zone}) {
    final service = FlutterBackgroundService();
    service.invoke('updateBpm', {
      'bpm': bpm,
      if (zone != null) 'zone': zone,
    });
  }

  /// Check if the service is currently running.
  Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
