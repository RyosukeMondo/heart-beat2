import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../models/user_profile.dart';

// Re-export helpers for backwards compatibility during migration.
// New code should import the specific helper libraries directly.
export 'duration_helpers.dart';
export 'zone_helpers.dart';
export 'cue_helpers.dart';

import 'duration_helpers.dart' as duration;
import 'zone_helpers.dart' as zone;
import 'cue_helpers.dart' as cue;

/// Backwards-compatible aggregate class (deprecated - use specific helpers).
/// This class exists only to maintain API compatibility for existing code.
/// New code should import the specific helper libraries directly.
class CoachingHelpers {
  static String formatDuration(Duration d) => duration.DurationHelpers.formatDuration(d);
  static Color zoneColor(Zone z) => zone.ZoneHelpers.zoneColor(z);
  static IconData zoneIcon(Zone z) => zone.ZoneHelpers.zoneIcon(z);
  static Color cuePriorityColor(int priority) => cue.CueHelpers.cuePriorityColor(priority);
  static String priorityLabel(int priority) => cue.CueHelpers.priorityLabel(priority);
  static IconData cueSourceIcon(int source) => cue.CueHelpers.cueSourceIcon(source);
  static String cueLabelText(String label) => cue.CueHelpers.cueLabelText(label);
  static Zone zoneForBpm(int bpm, UserProfile profile) => zone.ZoneHelpers.zoneForBpm(bpm, profile);
}