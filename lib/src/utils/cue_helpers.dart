import 'package:flutter/material.dart';

/// Pure helper functions for coaching cues.
class CueHelpers {
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