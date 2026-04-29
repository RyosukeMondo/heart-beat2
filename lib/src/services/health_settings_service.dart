import 'package:flutter/foundation.dart';
import 'package:heart_beat/src/services/health_settings_data.dart';
import 'package:heart_beat/src/services/health_settings_repository.dart';
import 'package:heart_beat/src/services/health_settings_bridge.dart';

export 'health_settings_data.dart';
export 'health_settings_repository.dart';
export 'health_settings_bridge.dart';

/// Service for health-monitoring settings.
///
/// State holder: owns in-memory values and notifies listeners on change.
/// Persistence is delegated to HealthSettingsRepository.
/// FFI bridge to Rust is delegated to HealthSettingsBridge.
class HealthSettingsService extends ChangeNotifier {
  HealthSettingsService._();

  static final HealthSettingsService _instance = HealthSettingsService._();

  static HealthSettingsService get instance => _instance;

  final _repo = HealthSettingsRepository();
  final _bridge = HealthSettingsBridge();

  bool _isInitialized = false;
  HealthSettingsData _data = HealthSettingsData.defaultData;

  int get lowHrThreshold => _data.lowHrThreshold;
  int get sustainedMinutes => _data.sustainedMinutes;
  int get sampleCadenceSecs => _data.sampleCadenceSecs;
  String get quietStart => _data.quietStart;
  String get quietEnd => _data.quietEnd;
  bool get notificationsEnabled => _data.notificationsEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _data = HealthSettingsData(
      lowHrThreshold: await _repo.loadInt(HealthSettingsRepository.prefLowHrThreshold, HealthSettingsRepository.defaultLowHrThreshold),
      sustainedMinutes: await _repo.loadInt(HealthSettingsRepository.prefSustainedMinutes, HealthSettingsRepository.defaultSustainedMinutes),
      sampleCadenceSecs: await _repo.loadInt(HealthSettingsRepository.prefSampleCadenceSecs, HealthSettingsRepository.defaultSampleCadenceSecs),
      quietStart: await _repo.loadString(HealthSettingsRepository.prefQuietStart, HealthSettingsRepository.defaultQuietStart),
      quietEnd: await _repo.loadString(HealthSettingsRepository.prefQuietEnd, HealthSettingsRepository.defaultQuietEnd),
      notificationsEnabled: await _repo.loadBool(HealthSettingsRepository.prefNotificationsEnabled, HealthSettingsRepository.defaultNotificationsEnabled),
    );
    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('HealthSettingsService initialized');
    }
  }

  Future<void> reload() async {
    _data = HealthSettingsData(
      lowHrThreshold: await _repo.loadInt(HealthSettingsRepository.prefLowHrThreshold, HealthSettingsRepository.defaultLowHrThreshold),
      sustainedMinutes: await _repo.loadInt(HealthSettingsRepository.prefSustainedMinutes, HealthSettingsRepository.defaultSustainedMinutes),
      sampleCadenceSecs: await _repo.loadInt(HealthSettingsRepository.prefSampleCadenceSecs, HealthSettingsRepository.defaultSampleCadenceSecs),
      quietStart: await _repo.loadString(HealthSettingsRepository.prefQuietStart, HealthSettingsRepository.defaultQuietStart),
      quietEnd: await _repo.loadString(HealthSettingsRepository.prefQuietEnd, HealthSettingsRepository.defaultQuietEnd),
      notificationsEnabled: await _repo.loadBool(HealthSettingsRepository.prefNotificationsEnabled, HealthSettingsRepository.defaultNotificationsEnabled),
    );
    notifyListeners();
  }

  Future<void> setLowHrThreshold(int value) async {
    _data = _data.copyWith(lowHrThreshold: value);
    await _repo.saveInt(HealthSettingsRepository.prefLowHrThreshold, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health low HR threshold: $value');
  }

  Future<void> setSustainedMinutes(int value) async {
    _data = _data.copyWith(sustainedMinutes: value);
    await _repo.saveInt(HealthSettingsRepository.prefSustainedMinutes, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health sustained minutes: $value');
  }

  Future<void> setSampleCadenceSecs(int value) async {
    _data = _data.copyWith(sampleCadenceSecs: value);
    await _repo.saveInt(HealthSettingsRepository.prefSampleCadenceSecs, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health sample cadence secs: $value');
  }

  Future<void> setQuietStart(String value) async {
    _data = _data.copyWith(quietStart: value);
    await _repo.saveString(HealthSettingsRepository.prefQuietStart, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health quiet start: $value');
  }

  Future<void> setQuietEnd(String value) async {
    _data = _data.copyWith(quietEnd: value);
    await _repo.saveString(HealthSettingsRepository.prefQuietEnd, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health quiet end: $value');
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _data = _data.copyWith(notificationsEnabled: value);
    await _repo.saveBool(HealthSettingsRepository.prefNotificationsEnabled, value);
    notifyListeners();
    await _bridge.push(_data);
    if (kDebugMode) debugPrint('Health notifications enabled: $value');
  }
}