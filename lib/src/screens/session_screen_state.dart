import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../services/hr_processor.dart';
import '../services/latency_service.dart';
import '../services/profile_service.dart';
import '../utils/zone_helpers.dart';

/// UI state and session logic for [SessionScreen].
///
/// Handles HR data processing, latency recording, and background service updates.
class SessionScreenState {
  SessionScreenState({
    HrProcessor? hrProcessor,
    LatencyServiceBase? latencyService,
  })  : _hrProcessor = hrProcessor ?? HrProcessor(ProfileService.instance),
        _latencyService = latencyService ?? LatencyService.instance;

  final HrProcessor _hrProcessor;
  final LatencyServiceBase _latencyService;

  bool _isServiceRunning = false;
  VoidCallback? _onStateChange;

  int get currentBpm => _hrProcessor.currentBpm;
  Zone get currentZone => _hrProcessor.currentZone;
  bool get isServiceRunning => _isServiceRunning;

  void setOnStateChange(VoidCallback callback) {
    _onStateChange = callback;
  }

  void setServiceRunning(bool running) {
    _isServiceRunning = running;
  }

  void initialize() {
    ProfileService.instance.loadProfile();
    _latencyService.start();
  }

  Future<void> processHrData(api.ApiFilteredHeartRate data) async {
    await _hrProcessor.process(data);
    _latencyService.recordSample(data);
    _onStateChange?.call();
  }

  Future<({int bpm, Zone zone})> extractHrData(
    api.ApiFilteredHeartRate data,
  ) async {
    final bpm = await api.hrFilteredBpm(data: data);
    final profile = ProfileService.instance.getCurrentProfile() ??
        ProfileService.instance.getDefaultProfile();
    final zone = ZoneHelpers.zoneForBpm(bpm, profile);
    return (bpm: bpm, zone: zone);
  }

  void dispose() {
    _latencyService.stop();
  }
}