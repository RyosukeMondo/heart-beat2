import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/session_screen_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionScreenState', () {
    late SessionScreenState state;

    setUp(() {
      state = SessionScreenState();
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

    test('notifyStateChange calls the callback', () {
      int callCount = 0;
      state.setOnStateChange(() {
        callCount++;
      });
      state.notifyStateChange();
      expect(callCount, equals(1));
    });

    test('setServiceRunning calls callback when state changes', () {
      int callCount = 0;
      state.setOnStateChange(() {
        callCount++;
      });
      state.setServiceRunning(true);
      expect(callCount, equals(1));
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
      state.notifyStateChange();
      // Both callbacks are stored (last one wins for _onStateChange)
      expect(callCount, equals(1));
    });

    test('state exposes correct getters', () {
      expect(state.isServiceRunning, isA<bool>());
    });
  });
}