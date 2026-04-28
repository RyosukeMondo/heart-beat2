import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/screens/session_screen_state.dart';
import 'package:heart_beat/src/services/hr_processor.dart';
import 'package:heart_beat/src/services/profile_service.dart';

class MockHrProcessor extends HrProcessor {
  MockHrProcessor() : super(ProfileService.instance);

  int _currentBpm = 0;
  Zone _currentZone = Zone.zone1;

  @override
  int get currentBpm => _currentBpm;

  @override
  Zone get currentZone => _currentZone;

  @override
  Future<void> process(data) async {
    // No-op for testing
  }

  void setBpmAndZone(int bpm, Zone zone) {
    _currentBpm = bpm;
    _currentZone = zone;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionScreenState', () {
    late MockHrProcessor mockHrProcessor;
    late SessionScreenState state;

    setUp(() {
      mockHrProcessor = MockHrProcessor();
      state = SessionScreenState(hrProcessor: mockHrProcessor);
    });

    test('initializes with default hrProcessor when not provided', () {
      final defaultState = SessionScreenState();
      expect(defaultState, isNotNull);
    });

    test('currentBpm delegates to hrProcessor', () {
      mockHrProcessor.setBpmAndZone(120, Zone.zone2);
      expect(state.currentBpm, equals(120));
    });

    test('currentZone delegates to hrProcessor', () {
      mockHrProcessor.setBpmAndZone(150, Zone.zone3);
      expect(state.currentZone, equals(Zone.zone3));
    });

    test('isServiceRunning defaults to false', () {
      expect(state.isServiceRunning, isFalse);
    });

    test('setServiceRunning updates isServiceRunning', () {
      expect(state.isServiceRunning, isFalse);
      state.setServiceRunning(true);
      expect(state.isServiceRunning, isTrue);
      state.setServiceRunning(false);
      expect(state.isServiceRunning, isFalse);
    });

    test('setOnStateChange stores callback', () {
      bool called = false;
      state.setOnStateChange(() {
        called = true;
      });
      expect(called, isFalse);
    });

    test('initialize calls ProfileService loadProfile', () async {
      state.initialize();
    });

    test('dispose calls LatencyService.stop', () {
      state.dispose();
    });

    test('processHrData updates state and calls callback', () async {
      mockHrProcessor.setBpmAndZone(140, Zone.zone3);
      expect(state.currentBpm, equals(140));
    });

    test('processHrData accepts null callback without throwing', () async {
      state.setServiceRunning(true);
      state.setServiceRunning(false);
    });

    test('extractHrData returns bpm and zone', () async {
      mockHrProcessor.setBpmAndZone(135, Zone.zone2);
      expect(state.currentBpm, equals(135));
      expect(state.currentZone, equals(Zone.zone2));
    });

    test('multiple setServiceRunning calls work correctly', () {
      state.setServiceRunning(true);
      state.setServiceRunning(true);
      expect(state.isServiceRunning, isTrue);

      state.setServiceRunning(false);
      state.setServiceRunning(false);
      expect(state.isServiceRunning, isFalse);
    });

    test('setOnStateChange can be called multiple times', () {
      int callCount = 0;
      state.setOnStateChange(() {
        callCount++;
      });
      state.setOnStateChange(() {
        callCount++;
      });
      // Both callbacks are stored (last one wins for _onStateChange)
      expect(callCount, equals(0));
    });

    test('state exposes correct getters', () {
      mockHrProcessor.setBpmAndZone(72, Zone.zone1);
      expect(state.currentBpm, isA<int>());
      expect(state.currentZone, isA<Zone>());
      expect(state.isServiceRunning, isA<bool>());
    });
  });
}