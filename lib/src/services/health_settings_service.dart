import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
export 'package:heart_beat/src/bridge/api_generated.dart/api.dart' show updateHealthSettings;

/// Service for persisted health-monitoring settings.
///
/// Manages the user-configurable parameters for the sustained-low-HR alert:
/// - low-HR threshold (bpm)
/// - sustained window duration (minutes)
/// - sampling cadence (seconds)
/// - quiet hours (start / end as HH:mm)
/// - master notification toggle
///
/// All values round-trip through SharedPreferences and notify listeners on change.
class HealthSettingsService extends ChangeNotifier {
  HealthSettingsService._();

  static final HealthSettingsService _instance = HealthSettingsService._();

  static HealthSettingsService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Preferences keys
  // ---------------------------------------------------------------------------

  static const _prefLowHrThreshold = 'health_low_hr_threshold';
  static const _prefSustainedMinutes = 'health_sustained_minutes';
  static const _prefSampleCadenceSecs = 'health_sample_cadence_secs';
  static const _prefQuietStart = 'health_quiet_start';
  static const _prefQuietEnd = 'health_quiet_end';
  static const _prefNotificationsEnabled = 'health_notifications_enabled';

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------

  static const int defaultLowHrThreshold = 70;
  static const int defaultSustainedMinutes = 10;
  static const int defaultSampleCadenceSecs = 5;
  static const String defaultQuietStart = '22:00';
  static const String defaultQuietEnd = '07:00';
  static const bool defaultNotificationsEnabled = true;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isInitialized = false;

  int _lowHrThreshold = defaultLowHrThreshold;
  int _sustainedMinutes = defaultSustainedMinutes;
  int _sampleCadenceSecs = defaultSampleCadenceSecs;
  String _quietStart = defaultQuietStart;
  String _quietEnd = defaultQuietEnd;
  bool _notificationsEnabled = defaultNotificationsEnabled;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  int get lowHrThreshold => _lowHrThreshold;
  int get sustainedMinutes => _sustainedMinutes;
  int get sampleCadenceSecs => _sampleCadenceSecs;
  String get quietStart => _quietStart;
  String get quietEnd => _quietEnd;
  bool get notificationsEnabled => _notificationsEnabled;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _lowHrThreshold = prefs.getInt(_prefLowHrThreshold) ?? defaultLowHrThreshold;
    _sustainedMinutes = prefs.getInt(_prefSustainedMinutes) ?? defaultSustainedMinutes;
    _sampleCadenceSecs = prefs.getInt(_prefSampleCadenceSecs) ?? defaultSampleCadenceSecs;
    _quietStart = prefs.getString(_prefQuietStart) ?? defaultQuietStart;
    _quietEnd = prefs.getString(_prefQuietEnd) ?? defaultQuietEnd;
    _notificationsEnabled = prefs.getBool(_prefNotificationsEnabled) ?? defaultNotificationsEnabled;

    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('HealthSettingsService initialized');
    }
  }

  /// Re-read all values from SharedPreferences and notify listeners.
  /// Used in tests to simulate a fresh load.
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    _lowHrThreshold = prefs.getInt(_prefLowHrThreshold) ?? defaultLowHrThreshold;
    _sustainedMinutes = prefs.getInt(_prefSustainedMinutes) ?? defaultSustainedMinutes;
    _sampleCadenceSecs = prefs.getInt(_prefSampleCadenceSecs) ?? defaultSampleCadenceSecs;
    _quietStart = prefs.getString(_prefQuietStart) ?? defaultQuietStart;
    _quietEnd = prefs.getString(_prefQuietEnd) ?? defaultQuietEnd;
    _notificationsEnabled = prefs.getBool(_prefNotificationsEnabled) ?? defaultNotificationsEnabled;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Setters — persist then notify
  // ---------------------------------------------------------------------------

  Future<void> setLowHrThreshold(int value) async {
    _lowHrThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLowHrThreshold, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health low HR threshold: $value');
    }
  }

  Future<void> _pushToRust() async {
    final startParts = _quietStart.split(':');
    final endParts = _quietEnd.split(':');
    final startHour = int.tryParse(startParts[0]) ?? 22;
    final endHour = int.tryParse(endParts[0]) ?? 7;
    await updateHealthSettings(
      thresholdBpm: _lowHrThreshold,
      sustainedSecs: BigInt.from(_sustainedMinutes * 60),
      quietStartHour: startHour,
      quietEndHour: endHour,
      notificationsEnabled: _notificationsEnabled,
    );
  }

  Future<void> setSustainedMinutes(int value) async {
    _sustainedMinutes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSustainedMinutes, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health sustained minutes: $value');
    }
  }

  Future<void> setSampleCadenceSecs(int value) async {
    _sampleCadenceSecs = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSampleCadenceSecs, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health sample cadence secs: $value');
    }
  }

  Future<void> setQuietStart(String value) async {
    _quietStart = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuietStart, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health quiet start: $value');
    }
  }

  Future<void> setQuietEnd(String value) async {
    _quietEnd = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuietEnd, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health quiet end: $value');
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotificationsEnabled, value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health notifications enabled: $value');
    }
  }
}
