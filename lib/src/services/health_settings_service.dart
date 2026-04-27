import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';

/// Repository for persisted health-monitoring settings.
///
/// Pure I/O: reads and writes SharedPreferences keys only.
/// No ChangeNotifier, no Rust bridge, no business logic.
class HealthSettingsRepository {
  HealthSettingsRepository._();

  static final HealthSettingsRepository _instance = HealthSettingsRepository._();

  static HealthSettingsRepository get instance => _instance;

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
  // Read
  // ---------------------------------------------------------------------------

  Future<int> readLowHrThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefLowHrThreshold) ?? defaultLowHrThreshold;
  }

  Future<int> readSustainedMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefSustainedMinutes) ?? defaultSustainedMinutes;
  }

  Future<int> readSampleCadenceSecs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefSampleCadenceSecs) ?? defaultSampleCadenceSecs;
  }

  Future<String> readQuietStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefQuietStart) ?? defaultQuietStart;
  }

  Future<String> readQuietEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefQuietEnd) ?? defaultQuietEnd;
  }

  Future<bool> readNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefNotificationsEnabled) ?? defaultNotificationsEnabled;
  }

  /// Load all values at once.
  Future<HealthSettingsData> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return HealthSettingsData(
      lowHrThreshold: prefs.getInt(_prefLowHrThreshold) ?? defaultLowHrThreshold,
      sustainedMinutes: prefs.getInt(_prefSustainedMinutes) ?? defaultSustainedMinutes,
      sampleCadenceSecs: prefs.getInt(_prefSampleCadenceSecs) ?? defaultSampleCadenceSecs,
      quietStart: prefs.getString(_prefQuietStart) ?? defaultQuietStart,
      quietEnd: prefs.getString(_prefQuietEnd) ?? defaultQuietEnd,
      notificationsEnabled: prefs.getBool(_prefNotificationsEnabled) ?? defaultNotificationsEnabled,
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<void> writeLowHrThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLowHrThreshold, value);
  }

  Future<void> writeSustainedMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSustainedMinutes, value);
  }

  Future<void> writeSampleCadenceSecs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSampleCadenceSecs, value);
  }

  Future<void> writeQuietStart(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuietStart, value);
  }

  Future<void> writeQuietEnd(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuietEnd, value);
  }

  Future<void> writeNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotificationsEnabled, value);
  }
}

/// Immutable settings data bundle.
class HealthSettingsData {
  final int lowHrThreshold;
  final int sustainedMinutes;
  final int sampleCadenceSecs;
  final String quietStart;
  final String quietEnd;
  final bool notificationsEnabled;

  const HealthSettingsData({
    required this.lowHrThreshold,
    required this.sustainedMinutes,
    required this.sampleCadenceSecs,
    required this.quietStart,
    required this.quietEnd,
    required this.notificationsEnabled,
  });
}

/// Service for health-monitoring settings.
///
/// State holder + Rust bridge: owns in-memory values, notifies listeners
/// on change, and pushes updated settings to the Rust rule engine.
///
/// Persistence is delegated to [HealthSettingsRepository].
class HealthSettingsService extends ChangeNotifier {
  HealthSettingsService._();

  static final HealthSettingsService _instance = HealthSettingsService._();

  static HealthSettingsService get instance => _instance;

  final HealthSettingsRepository _repo = HealthSettingsRepository.instance;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isInitialized = false;

  int _lowHrThreshold = HealthSettingsRepository.defaultLowHrThreshold;
  int _sustainedMinutes = HealthSettingsRepository.defaultSustainedMinutes;
  int _sampleCadenceSecs = HealthSettingsRepository.defaultSampleCadenceSecs;
  String _quietStart = HealthSettingsRepository.defaultQuietStart;
  String _quietEnd = HealthSettingsRepository.defaultQuietEnd;
  bool _notificationsEnabled = HealthSettingsRepository.defaultNotificationsEnabled;

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

    final data = await _repo.loadAll();
    _lowHrThreshold = data.lowHrThreshold;
    _sustainedMinutes = data.sustainedMinutes;
    _sampleCadenceSecs = data.sampleCadenceSecs;
    _quietStart = data.quietStart;
    _quietEnd = data.quietEnd;
    _notificationsEnabled = data.notificationsEnabled;

    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('HealthSettingsService initialized');
    }
  }

  /// Re-read all values from SharedPreferences and notify listeners.
  /// Used in tests to simulate a fresh load.
  Future<void> reload() async {
    final data = await _repo.loadAll();
    _lowHrThreshold = data.lowHrThreshold;
    _sustainedMinutes = data.sustainedMinutes;
    _sampleCadenceSecs = data.sampleCadenceSecs;
    _quietStart = data.quietStart;
    _quietEnd = data.quietEnd;
    _notificationsEnabled = data.notificationsEnabled;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Setters — persist then notify
  // ---------------------------------------------------------------------------

  Future<void> setLowHrThreshold(int value) async {
    _lowHrThreshold = value;
    await _repo.writeLowHrThreshold(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health low HR threshold: $value');
    }
  }

  Future<void> setSustainedMinutes(int value) async {
    _sustainedMinutes = value;
    await _repo.writeSustainedMinutes(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health sustained minutes: $value');
    }
  }

  Future<void> setSampleCadenceSecs(int value) async {
    _sampleCadenceSecs = value;
    await _repo.writeSampleCadenceSecs(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health sample cadence secs: $value');
    }
  }

  Future<void> setQuietStart(String value) async {
    _quietStart = value;
    await _repo.writeQuietStart(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health quiet start: $value');
    }
  }

  Future<void> setQuietEnd(String value) async {
    _quietEnd = value;
    await _repo.writeQuietEnd(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health quiet end: $value');
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _repo.writeNotificationsEnabled(value);
    notifyListeners();
    await _pushToRust();
    if (kDebugMode) {
      debugPrint('Health notifications enabled: $value');
    }
  }
}
