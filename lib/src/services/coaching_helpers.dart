import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Pure helper functions for the coaching screen.
///
/// These are extracted from _CoachingScreenState so they can be tested
/// directly without instantiating the full screen (which requires FFI).
class CoachingHelpers {
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

  /// Returns the color associated with a heart rate zone.
  static Color zoneColor(Zone zone) {
    switch (zone) {
      case Zone.zone1: return Colors.blue;
      case Zone.zone2: return Colors.green;
      case Zone.zone3: return Colors.yellow.shade700;
      case Zone.zone4: return Colors.orange;
      case Zone.zone5: return Colors.red;
    }
  }

  /// Returns the icon associated with a heart rate zone.
  static IconData zoneIcon(Zone zone) {
    switch (zone) {
      case Zone.zone1: return Icons.airline_seat_recline_extra;
      case Zone.zone2: return Icons.directions_walk;
      case Zone.zone3: return Icons.directions_run;
      case Zone.zone4: return Icons.sports_gymnastics;
      case Zone.zone5: return Icons.local_fire_department;
    }
  }

  /// Returns the color for a coaching cue priority level.
  static Color cuePriorityColor(int priority) {
    switch (priority) {
      case 0: return Colors.grey;
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  /// Returns the label text for a coaching cue priority level.
  static String priorityLabel(int priority) {
    switch (priority) {
      case 0: return 'LOW';
      case 1: return 'NORMAL';
      case 2: return 'HIGH';
      case 3: return 'CRITICAL';
      default: return 'UNKNOWN';
    }
  }

  /// Returns the icon for a coaching cue source.
  static IconData cueSourceIcon(int source) {
    switch (source) {
      case 0: return Icons.track_changes;
      case 1: return Icons.airline_seat_flat;
      case 2: return Icons.whatshot;
      default: return Icons.info;
    }
  }

  /// Formats a coaching cue label into display text.
  static String cueLabelText(String label) {
    switch (label) {
      case 'raise_hr': return 'Raise HR';
      case 'cool_down': return 'Cool Down';
      case 'stand_up': return 'Stand Up';
      case 'ease_off': return 'Ease Off';
      default:
        return label.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }
}