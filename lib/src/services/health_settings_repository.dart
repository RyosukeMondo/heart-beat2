import 'package:shared_preferences/shared_preferences.dart';

/// Handles SharedPreferences persistence for health settings.
class HealthSettingsRepository {
  static const prefLowHrThreshold = 'health_low_hr_threshold';
  static const prefSustainedMinutes = 'health_sustained_minutes';
  static const prefSampleCadenceSecs = 'health_sample_cadence_secs';
  static const prefQuietStart = 'health_quiet_start';
  static const prefQuietEnd = 'health_quiet_end';
  static const prefNotificationsEnabled = 'health_notifications_enabled';

  static const int defaultLowHrThreshold = 70;
  static const int defaultSustainedMinutes = 10;
  static const int defaultSampleCadenceSecs = 5;
  static const String defaultQuietStart = '22:00';
  static const String defaultQuietEnd = '07:00';
  static const bool defaultNotificationsEnabled = true;

  Future<int> loadInt(String key, int defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  Future<String> loadString(String key, String defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  Future<bool> loadBool(String key, bool defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}