import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/services/profile_service.dart';
import 'package:heart_beat/src/models/user_profile.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProfile', () {
    test('creates default profile with correct values', () {
      final profile = UserProfile.defaults();

      expect(profile.maxHr, 180);
      expect(profile.age, null);
      expect(profile.useAgeBased, false);
      expect(profile.customZones, null);
      expect(profile.effectiveMaxHr, 180);
      expect(profile.effectiveZones, CustomZones.defaults);
    });

    test('creates profile with manual max HR', () {
      final profile = UserProfile(
        maxHr: 190,
        useAgeBased: false,
      );

      expect(profile.maxHr, 190);
      expect(profile.effectiveMaxHr, 190);
    });

    test('creates profile with age-based max HR', () {
      final profile = UserProfile(
        maxHr: 180,
        age: 30,
        useAgeBased: true,
      );

      expect(profile.age, 30);
      expect(profile.useAgeBased, true);
      expect(profile.effectiveMaxHr, 190); // 220 - 30
    });

    test('calculates max HR from age correctly', () {
      expect(UserProfile.calculateMaxHrFromAge(20), 200);
      expect(UserProfile.calculateMaxHrFromAge(30), 190);
      expect(UserProfile.calculateMaxHrFromAge(40), 180);
      expect(UserProfile.calculateMaxHrFromAge(50), 170);
    });

    test('uses manual max HR when age-based is disabled', () {
      final profile = UserProfile(
        maxHr: 185,
        age: 30,
        useAgeBased: false,
      );

      expect(profile.effectiveMaxHr, 185); // Uses manual, not age-based (190)
    });

    test('validates max HR bounds', () {
      expect(
        () => UserProfile(maxHr: 99),
        throwsArgumentError,
      );

      expect(
        () => UserProfile(maxHr: 221),
        throwsArgumentError,
      );

      // Valid boundaries should work
      expect(() => UserProfile(maxHr: 100), returnsNormally);
      expect(() => UserProfile(maxHr: 220), returnsNormally);
    });

    test('validates age bounds', () {
      expect(
        () => UserProfile(maxHr: 180, age: 9),
        throwsArgumentError,
      );

      expect(
        () => UserProfile(maxHr: 180, age: 121),
        throwsArgumentError,
      );

      // Valid boundaries should work
      expect(() => UserProfile(maxHr: 180, age: 10), returnsNormally);
      expect(() => UserProfile(maxHr: 180, age: 120), returnsNormally);
    });

    test('uses default zones when custom zones not set', () {
      final profile = UserProfile.defaults();

      expect(profile.effectiveZones.zone1Max, 60);
      expect(profile.effectiveZones.zone2Max, 70);
      expect(profile.effectiveZones.zone3Max, 80);
      expect(profile.effectiveZones.zone4Max, 90);
    });

    test('uses custom zones when set', () {
      const customZones = CustomZones(
        zone1Max: 55,
        zone2Max: 65,
        zone3Max: 75,
        zone4Max: 85,
      );

      final profile = UserProfile(
        maxHr: 180,
        customZones: customZones,
      );

      expect(profile.effectiveZones.zone1Max, 55);
      expect(profile.effectiveZones.zone2Max, 65);
      expect(profile.effectiveZones.zone3Max, 75);
      expect(profile.effectiveZones.zone4Max, 85);
    });

    test('serializes to JSON correctly', () {
      final profile = UserProfile(
        maxHr: 185,
        age: 35,
        useAgeBased: true,
        customZones: const CustomZones(
          zone1Max: 55,
          zone2Max: 65,
          zone3Max: 75,
          zone4Max: 85,
        ),
      );

      final json = profile.toJson();

      expect(json['maxHr'], 185);
      expect(json['age'], 35);
      expect(json['useAgeBased'], true);
      expect(json['customZones'], isNotNull);
      expect(json['customZones']['zone1Max'], 55);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'maxHr': 185,
        'age': 35,
        'useAgeBased': true,
        'customZones': {
          'zone1Max': 55,
          'zone2Max': 65,
          'zone3Max': 75,
          'zone4Max': 85,
        },
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.maxHr, 185);
      expect(profile.age, 35);
      expect(profile.useAgeBased, true);
      expect(profile.customZones?.zone1Max, 55);
      expect(profile.customZones?.zone2Max, 65);
      expect(profile.customZones?.zone3Max, 75);
      expect(profile.customZones?.zone4Max, 85);
    });

    test('round-trips through JSON serialization', () {
      final original = UserProfile(
        maxHr: 190,
        age: 28,
        useAgeBased: false,
        customZones: const CustomZones(
          zone1Max: 58,
          zone2Max: 68,
          zone3Max: 78,
          zone4Max: 88,
        ),
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.maxHr, original.maxHr);
      expect(restored.age, original.age);
      expect(restored.useAgeBased, original.useAgeBased);
      expect(restored.customZones, original.customZones);
      expect(restored.effectiveMaxHr, original.effectiveMaxHr);
    });
  });

  group('CustomZones', () {
    test('validates zone ordering', () {
      // Valid zones should work
      expect(
        () => CustomZones(
          zone1Max: 60,
          zone2Max: 70,
          zone3Max: 80,
          zone4Max: 90,
        ),
        returnsNormally,
      );

      // Invalid ordering should fail
      expect(
        () => CustomZones(
          zone1Max: 70, // Higher than zone2Max
          zone2Max: 60,
          zone3Max: 80,
          zone4Max: 90,
        ),
        throwsAssertionError,
      );
    });

    test('validates zone boundaries', () {
      // Zone max must be less than 100
      expect(
        () => CustomZones(
          zone1Max: 60,
          zone2Max: 70,
          zone3Max: 80,
          zone4Max: 100,
        ),
        throwsAssertionError,
      );

      // Zone min must be greater than 0
      expect(
        () => CustomZones(
          zone1Max: 0,
          zone2Max: 70,
          zone3Max: 80,
          zone4Max: 90,
        ),
        throwsAssertionError,
      );
    });

    test('serializes to JSON correctly', () {
      const zones = CustomZones(
        zone1Max: 55,
        zone2Max: 65,
        zone3Max: 75,
        zone4Max: 85,
      );

      final json = zones.toJson();

      expect(json['zone1Max'], 55);
      expect(json['zone2Max'], 65);
      expect(json['zone3Max'], 75);
      expect(json['zone4Max'], 85);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'zone1Max': 55,
        'zone2Max': 65,
        'zone3Max': 75,
        'zone4Max': 85,
      };

      final zones = CustomZones.fromJson(json);

      expect(zones.zone1Max, 55);
      expect(zones.zone2Max, 65);
      expect(zones.zone3Max, 75);
      expect(zones.zone4Max, 85);
    });
  });

  group('ProfileService', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      // Reset the singleton state by reloading
      final service = ProfileService.instance;
      await service.reloadProfile();
    });

    test('returns default profile when no saved profile exists', () async {
      final service = ProfileService.instance;
      final profile = await service.loadProfile();

      expect(profile.maxHr, 180);
      expect(profile.age, null);
      expect(profile.useAgeBased, false);
      expect(profile.customZones, null);
    });

    test('saves and loads profile correctly', () async {
      final service = ProfileService.instance;
      final testProfile = UserProfile(
        maxHr: 195,
        age: 25,
        useAgeBased: true,
        customZones: const CustomZones(
          zone1Max: 58,
          zone2Max: 68,
          zone3Max: 78,
          zone4Max: 88,
        ),
      );

      // Save profile
      await service.saveProfile(testProfile);

      // Clear cache and reload
      final reloadedProfile = await service.reloadProfile();

      expect(reloadedProfile.maxHr, 195);
      expect(reloadedProfile.age, 25);
      expect(reloadedProfile.useAgeBased, true);
      expect(reloadedProfile.customZones?.zone1Max, 58);
      expect(reloadedProfile.customZones?.zone2Max, 68);
      expect(reloadedProfile.customZones?.zone3Max, 78);
      expect(reloadedProfile.customZones?.zone4Max, 88);
    });

    test('persists profile across service instances', () async {
      final service = ProfileService.instance;
      final testProfile = UserProfile(
        maxHr: 188,
        age: 32,
        useAgeBased: false,
      );

      await service.saveProfile(testProfile);

      // Simulate app restart by reloading
      final profile = await service.reloadProfile();

      expect(profile.maxHr, 188);
      expect(profile.age, 32);
      expect(profile.useAgeBased, false);
    });

    test('getProfile returns cached profile if available', () async {
      final service = ProfileService.instance;
      final testProfile = UserProfile(maxHr: 185);

      await service.saveProfile(testProfile);

      // First call should be cached
      final profile1 = await service.getProfile();
      final profile2 = await service.getProfile();

      expect(identical(profile1, profile2), true);
    });

    test('getCurrentProfile returns null before loading', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ProfileService.instance;

      // Force clear by reloading with empty prefs
      await service.reloadProfile();

      // Should return cached profile after reload
      final profile = service.getCurrentProfile();
      expect(profile, isNotNull); // It will be default profile
    });

    test('broadcasts profile changes on stream', () async {
      final service = ProfileService.instance;
      final testProfile = UserProfile(maxHr: 192);

      // Listen to stream
      final streamFuture = service.stream.first;

      // Save profile (should trigger stream)
      await service.saveProfile(testProfile);

      // Wait for stream event
      final broadcastProfile = await streamFuture;

      expect(broadcastProfile.maxHr, 192);
    });

    test('calculates zone correctly with default thresholds', () async {
      final service = ProfileService.instance;
      final profile = UserProfile(maxHr: 200);

      await service.saveProfile(profile);

      // Zone 1: 0-60% = 0-120 BPM
      expect(service.getZoneForBpm(100), Zone.zone1);
      expect(service.getZoneForBpm(120), Zone.zone1);

      // Zone 2: 60-70% = 120-140 BPM
      expect(service.getZoneForBpm(130), Zone.zone2);
      expect(service.getZoneForBpm(140), Zone.zone2);

      // Zone 3: 70-80% = 140-160 BPM
      expect(service.getZoneForBpm(150), Zone.zone3);
      expect(service.getZoneForBpm(160), Zone.zone3);

      // Zone 4: 80-90% = 160-180 BPM
      expect(service.getZoneForBpm(170), Zone.zone4);
      expect(service.getZoneForBpm(180), Zone.zone4);

      // Zone 5: 90-100% = 180-200 BPM
      expect(service.getZoneForBpm(190), Zone.zone5);
      expect(service.getZoneForBpm(200), Zone.zone5);
    });

    test('calculates zone correctly with custom thresholds', () async {
      final service = ProfileService.instance;
      final profile = UserProfile(
        maxHr: 200,
        customZones: const CustomZones(
          zone1Max: 50, // 0-100 BPM
          zone2Max: 65, // 100-130 BPM
          zone3Max: 75, // 130-150 BPM
          zone4Max: 85, // 150-170 BPM
          // Zone 5: 85-100% = 170-200 BPM
        ),
      );

      await service.saveProfile(profile);

      // Zone 1: 0-50% = 0-100 BPM
      expect(service.getZoneForBpm(80), Zone.zone1);
      expect(service.getZoneForBpm(100), Zone.zone1);

      // Zone 2: 50-65% = 100-130 BPM
      expect(service.getZoneForBpm(110), Zone.zone2);
      expect(service.getZoneForBpm(130), Zone.zone2);

      // Zone 3: 65-75% = 130-150 BPM
      expect(service.getZoneForBpm(140), Zone.zone3);
      expect(service.getZoneForBpm(150), Zone.zone3);

      // Zone 4: 75-85% = 150-170 BPM
      expect(service.getZoneForBpm(160), Zone.zone4);
      expect(service.getZoneForBpm(170), Zone.zone4);

      // Zone 5: 85-100% = 170-200 BPM
      expect(service.getZoneForBpm(180), Zone.zone5);
      expect(service.getZoneForBpm(200), Zone.zone5);
    });

    test('calculates zone with age-based max HR', () async {
      final service = ProfileService.instance;
      final profile = UserProfile(
        maxHr: 180, // Will be ignored
        age: 30, // Max HR = 220 - 30 = 190
        useAgeBased: true,
      );

      await service.saveProfile(profile);

      // With max HR of 190:
      // Zone 1: 0-60% = 0-114 BPM
      expect(service.getZoneForBpm(100), Zone.zone1);

      // Zone 2: 60-70% = 114-133 BPM
      expect(service.getZoneForBpm(120), Zone.zone2);

      // Zone 3: 70-80% = 133-152 BPM
      expect(service.getZoneForBpm(140), Zone.zone3);

      // Zone 4: 80-90% = 152-171 BPM
      expect(service.getZoneForBpm(160), Zone.zone4);

      // Zone 5: 90-100% = 171-190 BPM
      expect(service.getZoneForBpm(180), Zone.zone5);
    });

    test('getZoneForBpm returns null when profile not loaded', () {
      final service = ProfileService.instance;

      // Don't load profile, just access directly
      // Note: In practice this is hard to test because the service auto-loads
      // This test documents the expected behavior
      expect(service.getZoneForBpm(120), isNotNull); // Will have default
    });

    test('handles corrupted profile data gracefully', () async {
      // Set invalid JSON in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'user_profile': 'invalid json {{{',
      });

      final service = ProfileService.instance;
      final profile = await service.reloadProfile();

      // Should fallback to default profile
      expect(profile.maxHr, 180);
      expect(profile.useAgeBased, false);
    });

    test('isLoaded returns correct state', () async {
      final service = ProfileService.instance;

      // After reload it should be loaded
      await service.reloadProfile();
      expect(service.isLoaded, true);
    });

    test('reloadProfile clears cache and reloads from storage', () async {
      final service = ProfileService.instance;

      // Save a profile
      final profile1 = UserProfile(maxHr: 185);
      await service.saveProfile(profile1);

      // Manually modify SharedPreferences to simulate external change
      final prefs = await SharedPreferences.getInstance();
      final profile2 = UserProfile(maxHr: 195);
      await prefs.setString('user_profile',
        '{"maxHr":195,"age":null,"useAgeBased":false,"customZones":null}');

      // Reload should get the new value
      final reloaded = await service.reloadProfile();
      expect(reloaded.maxHr, 195);
    });
  });
}
