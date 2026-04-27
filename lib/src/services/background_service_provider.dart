import 'package:flutter/foundation.dart';
import 'background_service.dart';

/// ChangeNotifier wrapper for BackgroundService enabling DI via Provider.
///
/// This wraps the BackgroundService singleton to expose it through the
/// widget tree using Provider pattern, satisfying the clean architecture
/// boundary requirement that UI layer should receive services via DI.
class BackgroundServiceProvider extends ChangeNotifier {
  BackgroundServiceProvider._();

  static final BackgroundServiceProvider _instance =
      BackgroundServiceProvider._();

  static BackgroundServiceProvider get instance => _instance;

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start the background service.
  Future<bool> startService() async {
    final started = await BackgroundService.instance.startService();
    if (started) {
      _isRunning = true;
      notifyListeners();
    }
    return started;
  }

  /// Stop the background service.
  Future<void> stopService() async {
    await BackgroundService.instance.stopService();
    _isRunning = false;
    notifyListeners();
  }

  /// Update the notification with current BPM and optional zone.
  void updateBpm(int bpm, {String? zone}) {
    BackgroundService.instance.updateBpm(bpm, zone: zone);
  }
}