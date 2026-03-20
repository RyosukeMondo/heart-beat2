import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service for providing voice-based coaching during workouts via TTS.
///
/// Complements [AudioFeedbackService] (which plays sound effects) by
/// delivering spoken prompts for phase transitions, zone deviations,
/// countdowns, and workout summaries.
///
/// Implemented as a singleton to prevent overlapping speech and ensure
/// consistent TTS engine state.
class VoiceCoachingService {
  VoiceCoachingService._();

  static final VoiceCoachingService _instance = VoiceCoachingService._();

  /// Singleton instance accessor.
  static VoiceCoachingService get instance => _instance;

  /// TTS engine instance.
  final FlutterTts _tts = FlutterTts();

  /// Whether voice coaching is enabled (off by default, user opts in).
  bool isEnabled = false;

  /// Speech volume (0.0 to 1.0).
  double _volume = 0.8;

  /// Speech rate (0.0 to 1.0).
  double _rate = 0.5;

  /// TTS language code.
  final String _language = 'en-US';

  /// Timestamp of last spoken prompt for debouncing.
  DateTime? _lastSpokenTime;

  /// Minimum time between voice prompts (milliseconds).
  static const int _debounceMs = 5000;

  /// Current volume.
  double get volume => _volume;

  /// Current speech rate.
  double get rate => _rate;

  /// Current language.
  String get language => _language;

  // ---------------------------------------------------------------------------
  // Initialization & configuration
  // ---------------------------------------------------------------------------

  /// Initialize the TTS engine.
  ///
  /// Should be called during app initialization before any coaching methods.
  Future<void> initialize() async {
    try {
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_volume);

      if (kDebugMode) {
        debugPrint('VoiceCoachingService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing VoiceCoachingService: $e');
      }
    }
  }

  /// Enable or disable voice coaching.
  void setEnabled(bool enabled) {
    isEnabled = enabled;
    if (!enabled) {
      _tts.stop();
    }
    if (kDebugMode) {
      debugPrint('VoiceCoachingService enabled: $enabled');
    }
  }

  /// Set speech volume (0.0 to 1.0).
  Future<void> setVolume(double vol) async {
    if (vol < 0.0 || vol > 1.0) {
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }
    _volume = vol;
    await _tts.setVolume(_volume);
  }

  /// Set speech rate (0.0 to 1.0).
  Future<void> setRate(double rate) async {
    if (rate < 0.0 || rate > 1.0) {
      throw ArgumentError('Rate must be between 0.0 and 1.0');
    }
    _rate = rate;
    await _tts.setSpeechRate(_rate);
  }

  // ---------------------------------------------------------------------------
  // Core speech logic
  // ---------------------------------------------------------------------------

  /// Check if enough time has passed since the last prompt (debouncing).
  bool _shouldSpeak() {
    if (!isEnabled) return false;

    final now = DateTime.now();
    if (_lastSpokenTime != null) {
      final elapsed = now.difference(_lastSpokenTime!).inMilliseconds;
      if (elapsed < _debounceMs) return false;
    }

    _lastSpokenTime = now;
    return true;
  }

  /// Speak [text] through TTS if enabled and debounce allows.
  ///
  /// When [bypassDebounce] is true the debounce check is skipped (used for
  /// phase announcements that must always be heard).
  @visibleForTesting
  Future<void> speak(String text, {bool bypassDebounce = false}) async {
    if (!isEnabled) return;

    if (!bypassDebounce && !_shouldSpeak()) return;

    // Update timestamp even on bypass so subsequent non-bypass calls debounce.
    if (bypassDebounce) _lastSpokenTime = DateTime.now();

    try {
      await _tts.stop();
      await _tts.speak(text);

      if (kDebugMode) {
        debugPrint('VoiceCoaching: "$text"');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error speaking text: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Coaching announcements
  // ---------------------------------------------------------------------------

  /// Announce the start of a training phase.
  ///
  /// Always bypasses debounce so the user never misses a phase transition.
  Future<void> announcePhaseStart(
    String phaseName,
    String zoneName,
    int durationSecs,
  ) async {
    final duration = _formatDuration(durationSecs);
    await speak(
      'Starting $phaseName. Target zone $zoneName. $duration.',
      bypassDebounce: true,
    );
  }

  /// Announce that a training phase is complete.
  ///
  /// Always bypasses debounce.
  Future<void> announcePhaseComplete(String phaseName) async {
    await speak('$phaseName complete. Nice work.', bypassDebounce: true);
  }

  /// Announce a heart-rate zone deviation.
  Future<void> announceZoneDeviation(bool tooHigh, String targetZone) async {
    final message = tooHigh
        ? 'Heart rate too high. Ease back to $targetZone.'
        : 'Heart rate too low. Pick it up to $targetZone.';
    await speak(message);
  }

  /// Announce the halfway point of a phase.
  Future<void> announceHalfway(String phaseName, int remainingSecs) async {
    final remaining = _formatDuration(remainingSecs);
    await speak('Halfway through $phaseName. $remaining remaining.');
  }

  /// Announce workout completion with summary stats.
  ///
  /// Always bypasses debounce.
  Future<void> announceWorkoutComplete(int totalMins, int avgHr) async {
    await speak(
      'Workout complete. $totalMins minutes. '
      'Average heart rate $avgHr.',
      bypassDebounce: true,
    );
  }

  /// Announce a countdown (only speaks for 3, 2, 1).
  ///
  /// Always bypasses debounce.
  Future<void> announceCountdown(int seconds) async {
    const words = {3: 'Three', 2: 'Two', 1: 'One'};
    final word = words[seconds];
    if (word == null) return;
    await speak('$word...', bypassDebounce: true);
  }

  /// Announce the current heart rate.
  Future<void> announceCurrentHr(int bpm) async {
    await speak('Heart rate: $bpm');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Format a duration in seconds to a human-readable string.
  ///
  /// Examples:
  /// - 150 → "2 minutes 30 seconds"
  /// - 60  → "1 minute"
  /// - 45  → "45 seconds"
  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    final parts = <String>[];
    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (seconds > 0) {
      parts.add('$seconds ${seconds == 1 ? 'second' : 'seconds'}');
    }

    return parts.isEmpty ? '0 seconds' : parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Stop TTS and release resources.
  ///
  /// As a singleton this is typically only called on app termination.
  Future<void> dispose() async {
    try {
      await _tts.stop();
      if (kDebugMode) {
        debugPrint('VoiceCoachingService disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disposing VoiceCoachingService: $e');
      }
    }
  }
}
