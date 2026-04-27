/// Abstraction for voice-based TTS coaching, allowing [CoachingCueService]
/// to be tested in isolation without a real [VoiceCoachingService] instance.
///
/// The concrete [VoiceCoachingService] implements this interface.
abstract class VoiceCoachingHandler {
  /// Whether voice coaching TTS is currently enabled.
  bool get isEnabled;

  /// Initialize the TTS engine.
  Future<void> initialize();

  /// Enable or disable voice coaching TTS.
  Future<void> setEnabled(bool enabled);

  /// Speak [text] through TTS.
  Future<void> speak(String text);

  /// Release TTS resources.
  Future<void> dispose();
}
