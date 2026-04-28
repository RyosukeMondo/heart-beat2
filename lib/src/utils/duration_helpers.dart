/// Pure helper functions for Duration formatting.
class DurationHelpers {
  /// Formats a Duration into a human-readable string.
  ///
  /// Examples:
  /// - 1h 30m 45s (when hours > 0)
  /// - 5m 30s (when hours == 0)
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }
}