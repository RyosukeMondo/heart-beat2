/// Custom training zone thresholds as percentages of max heart rate.
///
/// Each zone boundary represents the maximum percentage for that zone.
/// Zone 5 implicitly goes from zone4Max to 100%.
class CustomZones {
  /// Zone 1 upper boundary (default 60%)
  final int zone1Max;

  /// Zone 2 upper boundary (default 70%)
  final int zone2Max;

  /// Zone 3 upper boundary (default 80%)
  final int zone3Max;

  /// Zone 4 upper boundary (default 90%)
  final int zone4Max;

  const CustomZones({
    required this.zone1Max,
    required this.zone2Max,
    required this.zone3Max,
    required this.zone4Max,
  }) : assert(zone1Max > 0 && zone1Max < 100),
       assert(zone2Max > zone1Max && zone2Max < 100),
       assert(zone3Max > zone2Max && zone3Max < 100),
       assert(zone4Max > zone3Max && zone4Max < 100);

  /// Default zone thresholds
  static const CustomZones defaults = CustomZones(
    zone1Max: 60,
    zone2Max: 70,
    zone3Max: 80,
    zone4Max: 90,
  );

  /// Create CustomZones from JSON
  factory CustomZones.fromJson(Map<String, dynamic> json) {
    return CustomZones(
      zone1Max: json['zone1Max'] as int,
      zone2Max: json['zone2Max'] as int,
      zone3Max: json['zone3Max'] as int,
      zone4Max: json['zone4Max'] as int,
    );
  }

  /// Convert CustomZones to JSON
  Map<String, dynamic> toJson() {
    return {
      'zone1Max': zone1Max,
      'zone2Max': zone2Max,
      'zone3Max': zone3Max,
      'zone4Max': zone4Max,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomZones &&
          runtimeType == other.runtimeType &&
          zone1Max == other.zone1Max &&
          zone2Max == other.zone2Max &&
          zone3Max == other.zone3Max &&
          zone4Max == other.zone4Max;

  @override
  int get hashCode =>
      zone1Max.hashCode ^
      zone2Max.hashCode ^
      zone3Max.hashCode ^
      zone4Max.hashCode;
}

/// User profile containing training configuration.
///
/// This model holds the user's maximum heart rate settings and training zone
/// customization. It supports both manual max HR entry and age-based estimation.
class UserProfile {
  int _maxHr;
  int? _age;
  bool useAgeBased;
  CustomZones? customZones;
  bool audioFeedbackEnabled;
  double _audioVolume;

  /// Manual maximum heart rate in BPM
  int get maxHr => _maxHr;
  set maxHr(int value) {
    if (value < 100 || value > 220) {
      throw ArgumentError('Max heart rate must be between 100 and 220');
    }
    _maxHr = value;
  }

  /// User's age for age-based max HR estimation
  int? get age => _age;
  set age(int? value) {
    if (value != null && (value < 10 || value > 120)) {
      throw ArgumentError('Age must be between 10 and 120');
    }
    _age = value;
  }

  /// Audio feedback volume (0.0 to 1.0)
  double get audioVolume => _audioVolume;
  set audioVolume(double value) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError('Audio volume must be between 0.0 and 1.0');
    }
    _audioVolume = value;
  }

  /// The effective max heart rate (age-based if enabled, otherwise manual)
  int get effectiveMaxHr {
    if (useAgeBased && _age != null) {
      return calculateMaxHrFromAge(_age!);
    }
    return _maxHr;
  }

  /// The zone thresholds to use (custom if set, otherwise defaults)
  CustomZones get effectiveZones => customZones ?? CustomZones.defaults;

  UserProfile({
    required int maxHr,
    int? age,
    bool useAgeBased = false,
    CustomZones? customZones,
    bool audioFeedbackEnabled = true,
    double audioVolume = 0.7,
  })  : _maxHr = maxHr,
        _age = age,
        useAgeBased = useAgeBased,
        customZones = customZones,
        audioFeedbackEnabled = audioFeedbackEnabled,
        _audioVolume = audioVolume {
    // Validate in constructor
    if (maxHr < 100 || maxHr > 220) {
      throw ArgumentError('Max heart rate must be between 100 and 220');
    }
    if (age != null && (age < 10 || age > 120)) {
      throw ArgumentError('Age must be between 10 and 120');
    }
    if (audioVolume < 0.0 || audioVolume > 1.0) {
      throw ArgumentError('Audio volume must be between 0.0 and 1.0');
    }
  }

  /// Calculate max heart rate from age using the standard formula
  static int calculateMaxHrFromAge(int age) {
    return 220 - age;
  }

  /// Create a default profile
  factory UserProfile.defaults() {
    return UserProfile(
      maxHr: 180,
      useAgeBased: false,
    );
  }

  /// Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      maxHr: json['maxHr'] as int,
      age: json['age'] as int?,
      useAgeBased: json['useAgeBased'] as bool? ?? false,
      customZones: json['customZones'] != null
          ? CustomZones.fromJson(json['customZones'] as Map<String, dynamic>)
          : null,
      audioFeedbackEnabled: json['audioFeedbackEnabled'] as bool? ?? true,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 0.7,
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'maxHr': _maxHr,
      'age': _age,
      'useAgeBased': useAgeBased,
      'customZones': customZones?.toJson(),
      'audioFeedbackEnabled': audioFeedbackEnabled,
      'audioVolume': _audioVolume,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          _maxHr == other._maxHr &&
          _age == other._age &&
          useAgeBased == other.useAgeBased &&
          customZones == other.customZones &&
          audioFeedbackEnabled == other.audioFeedbackEnabled &&
          _audioVolume == other._audioVolume;

  @override
  int get hashCode =>
      _maxHr.hashCode ^
      _age.hashCode ^
      useAgeBased.hashCode ^
      customZones.hashCode ^
      audioFeedbackEnabled.hashCode ^
      _audioVolume.hashCode;
}
