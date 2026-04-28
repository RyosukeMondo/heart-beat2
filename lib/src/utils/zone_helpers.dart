import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../models/user_profile.dart';

/// Pure helper functions for heart rate zones.
class ZoneHelpers {
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

  /// Calculate which training zone a given heart rate falls into.
  ///
  /// Uses the profile's effective max HR and zone thresholds
  /// (custom if set, otherwise defaults) to determine the appropriate zone.
  ///
  /// Zone boundaries:
  /// - Zone 1: 0% to zone1Max% of max HR
  /// - Zone 2: zone1Max% to zone2Max% of max HR
  /// - Zone 3: zone2Max% to zone3Max% of max HR
  /// - Zone 4: zone3Max% to zone4Max% of max HR
  /// - Zone 5: zone4Max% to 100% of max HR
  static Zone zoneForBpm(int bpm, UserProfile profile) {
    final maxHr = profile.effectiveMaxHr;
    final zones = profile.effectiveZones;

    // Calculate percentage of max HR
    final percentage = (bpm / maxHr * 100).round();

    // Determine zone based on thresholds
    if (percentage <= zones.zone1Max) {
      return Zone.zone1;
    } else if (percentage <= zones.zone2Max) {
      return Zone.zone2;
    } else if (percentage <= zones.zone3Max) {
      return Zone.zone3;
    } else if (percentage <= zones.zone4Max) {
      return Zone.zone4;
    } else {
      return Zone.zone5;
    }
  }
}