/// Heart rate training zones based on percentage of max heart rate.
///
/// These zones are commonly used in exercise physiology to categorize
/// training intensity levels.
enum Zone {
  /// Zone 1: 50-60% of max HR (very light, recovery)
  zone1,

  /// Zone 2: 60-70% of max HR (light, fat burning)
  zone2,

  /// Zone 3: 70-80% of max HR (moderate, aerobic)
  zone3,

  /// Zone 4: 80-90% of max HR (hard, anaerobic threshold)
  zone4,

  /// Zone 5: 90-100% of max HR (maximum effort)
  zone5,
}