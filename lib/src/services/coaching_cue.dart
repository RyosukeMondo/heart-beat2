// Represents a coaching cue with a stable, Dart-native interface.
// This type is not generated from Rust bindings, providing a stable
// boundary between the FFI layer and the service layer.

// Priority levels for coaching cues.
enum CuePriority {
  low(0),
  normal(1),
  high(2),
  critical(3);

  const CuePriority(this.value);
  final int value;

  static CuePriority fromInt(int value) {
    return CuePriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CuePriority.normal,
    );
  }
}

/// A coaching directive — the stable Dart representation of a cue
/// from the Rust rule engine.
///
/// Used as the public interface type for [CoachingCueService] instead
/// of the auto-generated [ApiCue] from the FFI bridge.
class Cue {
  const Cue({
    required this.id,
    required this.label,
    required this.message,
    required this.priority,
    required this.generatedAt,
  });

  /// Unique identifier for this cue instance.
  final String id;

  /// Short machine-readable label, e.g. `"raise_hr"`.
  final String label;

  /// Human-readable message for the user.
  final String message;

  /// Priority level of the cue.
  final CuePriority priority;

  /// When this cue was generated.
  final DateTime generatedAt;

  /// Priority as an integer (0=Low, 1=Normal, 2=High, 3=Critical).
  /// Used for comparison operations.
  int get priorityValue => priority.value;
}