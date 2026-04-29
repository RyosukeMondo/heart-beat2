import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/health_settings_data.dart';

/// Bridges Dart settings to the Rust rule engine via FFI.
class HealthSettingsBridge {
  Future<void> push(HealthSettingsData settings) async {
    final startParts = settings.quietStart.split(':');
    final endParts = settings.quietEnd.split(':');
    final startHour = int.tryParse(startParts[0]) ?? 22;
    final endHour = int.tryParse(endParts[0]) ?? 7;
    await updateHealthSettings(
      thresholdBpm: settings.lowHrThreshold,
      sustainedSecs: BigInt.from(settings.sustainedMinutes * 60),
      quietStartHour: startHour,
      quietEndHour: endHour,
      notificationsEnabled: settings.notificationsEnabled,
    );
  }
}