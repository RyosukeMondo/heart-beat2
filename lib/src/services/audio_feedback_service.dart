import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing audio feedback during workouts.
///
/// Provides audio notifications for:
/// - Heart rate zone deviations (too high, too low)
/// - Training phase transitions
///
/// Implemented as a singleton to ensure consistent audio state management
/// and prevent multiple simultaneous audio playback conflicts.
class AudioFeedbackService {
  AudioFeedbackService._();

  static final AudioFeedbackService _instance = AudioFeedbackService._();

  /// Singleton instance accessor.
  static AudioFeedbackService get instance => _instance;

  /// Audio player instance for sound effects
  final AudioPlayer _player = AudioPlayer();

  /// Whether audio feedback is enabled
  bool _isEnabled = true;

  /// Audio volume (0.0 to 1.0)
  double _volume = 0.7;

  /// Timestamp of last audio playback to implement debouncing
  DateTime? _lastPlaybackTime;

  /// Minimum time between audio notifications (milliseconds)
  static const int _debounceMs = 3000;

  /// Asset paths for audio files
  static const String _zoneTooHighAsset = 'assets/audio/too_high.mp3';
  static const String _zoneTooLowAsset = 'assets/audio/too_low.mp3';
  static const String _phaseTransitionAsset = 'assets/audio/phase_change.mp3';

  /// Get whether audio feedback is enabled
  bool get isEnabled => _isEnabled;

  /// Set whether audio feedback is enabled
  set isEnabled(bool value) {
    _isEnabled = value;
  }

  /// Get current volume (0.0 to 1.0)
  double get volume => _volume;

  /// Set volume (0.0 to 1.0)
  set volume(double value) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }
    _volume = value;
    _player.setVolume(_volume);
  }

  /// Initialize the audio player
  ///
  /// Should be called during app initialization to set up audio configuration.
  Future<void> initialize() async {
    try {
      // Set release mode to stop when playback completes
      await _player.setReleaseMode(ReleaseMode.stop);

      // Set initial volume
      await _player.setVolume(_volume);

      if (kDebugMode) {
        debugPrint('AudioFeedbackService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing AudioFeedbackService: $e');
      }
    }
  }

  /// Check if enough time has passed since last playback (debouncing)
  bool _shouldPlayAudio() {
    if (!_isEnabled) {
      return false;
    }

    final now = DateTime.now();
    if (_lastPlaybackTime != null) {
      final timeSinceLastPlay = now.difference(_lastPlaybackTime!).inMilliseconds;
      if (timeSinceLastPlay < _debounceMs) {
        return false;
      }
    }

    _lastPlaybackTime = now;
    return true;
  }

  /// Play audio from an asset path
  Future<void> _playAudioAsset(String assetPath) async {
    if (!_shouldPlayAudio()) {
      return;
    }

    try {
      // Stop any currently playing audio
      await _player.stop();

      // Play the new audio
      await _player.play(AssetSource(assetPath));

      if (kDebugMode) {
        debugPrint('Playing audio: $assetPath');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error playing audio $assetPath: $e');
      }
    }
  }

  /// Play audio notification for heart rate too high
  ///
  /// This is triggered when the user's heart rate exceeds the target zone.
  /// Includes debouncing to prevent audio spam during continuous deviation.
  Future<void> playZoneTooHigh() async {
    await _playAudioAsset(_zoneTooHighAsset);
  }

  /// Play audio notification for heart rate too low
  ///
  /// This is triggered when the user's heart rate falls below the target zone.
  /// Includes debouncing to prevent audio spam during continuous deviation.
  Future<void> playZoneTooLow() async {
    await _playAudioAsset(_zoneTooLowAsset);
  }

  /// Play audio notification for training phase transition
  ///
  /// This is triggered when transitioning between training phases (e.g.,
  /// warmup to work, work to recovery).
  Future<void> playPhaseTransition() async {
    await _playAudioAsset(_phaseTransitionAsset);
  }

  /// Stop any currently playing audio
  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error stopping audio: $e');
      }
    }
  }

  /// Dispose of resources
  ///
  /// Should be called when the service is no longer needed.
  /// Note: As a singleton, this is typically only called on app termination.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
