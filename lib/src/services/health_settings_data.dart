/// Immutable settings data bundle.
class HealthSettingsData {
  final int lowHrThreshold;
  final int sustainedMinutes;
  final int sampleCadenceSecs;
  final String quietStart;
  final String quietEnd;
  final bool notificationsEnabled;

  const HealthSettingsData({
    required this.lowHrThreshold,
    required this.sustainedMinutes,
    required this.sampleCadenceSecs,
    required this.quietStart,
    required this.quietEnd,
    required this.notificationsEnabled,
  });

  HealthSettingsData copyWith({
    int? lowHrThreshold,
    int? sustainedMinutes,
    int? sampleCadenceSecs,
    String? quietStart,
    String? quietEnd,
    bool? notificationsEnabled,
  }) {
    return HealthSettingsData(
      lowHrThreshold: lowHrThreshold ?? this.lowHrThreshold,
      sustainedMinutes: sustainedMinutes ?? this.sustainedMinutes,
      sampleCadenceSecs: sampleCadenceSecs ?? this.sampleCadenceSecs,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  static const defaultData = HealthSettingsData(
    lowHrThreshold: 70,
    sustainedMinutes: 10,
    sampleCadenceSecs: 5,
    quietStart: '22:00',
    quietEnd: '07:00',
    notificationsEnabled: true,
  );
}