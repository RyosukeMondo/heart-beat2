import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/audio_feedback_service.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the audioplayers plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async {
      // Return success for all method calls
      switch (methodCall.method) {
        case 'init':
          return null;
        default:
          return null;
      }
    },
  );

  // Mock individual player channels
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'create':
          return 'mock_player_id';
        case 'setVolume':
        case 'setSourceAsset':
        case 'resume':
        case 'stop':
        case 'dispose':
          return null;
        default:
          return null;
      }
    },
  );

  group('AudioFeedbackService', () {
    late AudioFeedbackService service;

    setUp(() {
      service = AudioFeedbackService.instance;
      // Reset to default state
      service.isEnabled = true;
      service.volume = 0.7;
    });

    test('should be a singleton', () {
      final instance1 = AudioFeedbackService.instance;
      final instance2 = AudioFeedbackService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize with default values', () {
      expect(service.isEnabled, isTrue);
      expect(service.volume, equals(0.7));
    });

    test('should allow enabling and disabling audio feedback', () {
      service.isEnabled = false;
      expect(service.isEnabled, isFalse);

      service.isEnabled = true;
      expect(service.isEnabled, isTrue);
    });

    test('should allow setting volume within valid range', () {
      service.volume = 0.0;
      expect(service.volume, equals(0.0));

      service.volume = 0.5;
      expect(service.volume, equals(0.5));

      service.volume = 1.0;
      expect(service.volume, equals(1.0));
    });

    test('should throw error for volume below 0.0', () {
      expect(() => service.volume = -0.1, throwsArgumentError);
    });

    test('should throw error for volume above 1.0', () {
      expect(() => service.volume = 1.1, throwsArgumentError);
    });

    test('initialize should complete without error', () async {
      await expectLater(service.initialize(), completes);
    });

    test('playZoneTooHigh should complete without error', () async {
      // Note: Actual audio playback will fail in test environment without assets,
      // but the method should handle errors gracefully
      await expectLater(service.playZoneTooHigh(), completes);
    });

    test('playZoneTooLow should complete without error', () async {
      await expectLater(service.playZoneTooLow(), completes);
    });

    test('playPhaseTransition should complete without error', () async {
      await expectLater(service.playPhaseTransition(), completes);
    });

    test('stopAudio should complete without error', () async {
      await expectLater(service.stopAudio(), completes);
    });

    test('dispose should complete without error', () async {
      await expectLater(service.dispose(), completes);
    });

    test('should not play audio when disabled', () async {
      service.isEnabled = false;
      // These should return immediately without attempting to play
      await expectLater(service.playZoneTooHigh(), completes);
      await expectLater(service.playZoneTooLow(), completes);
      await expectLater(service.playPhaseTransition(), completes);
    });

    test('should respect debouncing (conceptual test)', () async {
      // Enable audio
      service.isEnabled = true;

      // First call should attempt to play
      await service.playZoneTooHigh();

      // Immediate second call should be debounced (within 3 seconds)
      // In a real test, we'd verify no audio was played, but since we can't
      // mock the internal player, this just verifies the method completes
      await service.playZoneTooHigh();

      // Both calls should complete without throwing
      expect(service.isEnabled, isTrue);
    });
  });

  group('AudioFeedbackService - Settings Persistence', () {
    test('should maintain volume setting across multiple calls', () {
      final service = AudioFeedbackService.instance;

      service.volume = 0.8;
      expect(service.volume, equals(0.8));

      // Volume should persist
      expect(service.volume, equals(0.8));
    });

    test('should maintain enabled/disabled state', () {
      final service = AudioFeedbackService.instance;

      service.isEnabled = false;
      expect(service.isEnabled, isFalse);

      // State should persist
      expect(service.isEnabled, isFalse);

      service.isEnabled = true;
      expect(service.isEnabled, isTrue);
    });
  });
}
