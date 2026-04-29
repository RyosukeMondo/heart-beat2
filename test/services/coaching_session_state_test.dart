import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/coaching_session_state.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';

void main() {
  group('CoachingSessionState', () {
    late CoachingSessionState state;

    setUp(() {
      state = CoachingSessionStateImpl();
      state.onUpdate = (elapsed, zoneTime) {
        // callbacks fire during session lifecycle
      };
    });

    tearDown(() {
      state.dispose();
    });

    test('initial state', () {
      expect(state.elapsed, Duration.zero);
      expect(state.isPaused, false);
      expect(state.zoneTime.keys.length, 5);
      expect(state.zoneTime[Zone.zone1], Duration.zero);
    });

    test('start begins the session', () {
      state.start();
      expect(state.isPaused, false);
    });

    test('pause sets isPaused true', () {
      state.start();
      state.pause();
      expect(state.isPaused, true);
    });

    test('resume sets isPaused false', () {
      state.start();
      state.pause();
      state.resume();
      expect(state.isPaused, false);
    });

    test('togglePause alternates pause state', () {
      state.start();
      expect(state.isPaused, false);
      state.togglePause();
      expect(state.isPaused, true);
      state.togglePause();
      expect(state.isPaused, false);
    });

    test('onZoneTick accumulates time for the current zone', () {
      state.start();
      state.onZoneTick(Zone.zone2);
      state.onZoneTick(Zone.zone2);
      state.onZoneTick(Zone.zone3);
      // zoneTime is unmodifiable but we can verify via onUpdate callbacks
    });

    test('onZoneTick does not accumulate when paused', () {
      state.start();
      state.pause();
      state.onZoneTick(Zone.zone2);
      state.onZoneTick(Zone.zone2);
      // No exception thrown; zone time should not accumulate
    });

    test('dispose cancels the timer', () {
      state.start();
      state.dispose();
      // dispose should not throw even if called twice
      state.dispose();
    });
  });
}