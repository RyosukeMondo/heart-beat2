import 'dart:async';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import 'profile_service.dart';

/// Processes HR data: extracts BPM and maps to zone.
///
/// Extracted from CoachingScreenState to reduce its responsibilities.
class HrProcessor {
  HrProcessor(this._profileService);

  final ProfileService _profileService;

  int _currentBpm = 0;
  Zone _currentZone = Zone.zone1;

  int get currentBpm => _currentBpm;
  Zone get currentZone => _currentZone;

  Future<void> process(api.ApiFilteredHeartRate data) async {
    final bpm = await api.hrFilteredBpm(data: data);
    final zone = _profileService.getZoneForBpm(bpm) ?? Zone.zone1;

    _currentBpm = bpm;
    _currentZone = zone;
  }
}