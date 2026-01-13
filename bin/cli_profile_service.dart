import 'dart:io';
import 'dart:convert';
import 'package:heart_beat/src/models/user_profile.dart';

/// CLI-specific profile service that uses file-based storage instead of SharedPreferences.
///
/// This service provides the same interface as ProfileService but works in pure Dart CLI
/// environments without Flutter dependencies.
class CliProfileService {
  CliProfileService._();

  static final CliProfileService _instance = CliProfileService._();

  /// Singleton instance accessor.
  static CliProfileService get instance => _instance;

  /// File name for storing user profile
  static const String _profileFileName = 'user_profile.json';

  /// Current user profile (cached)
  UserProfile? _currentProfile;

  /// Get the data directory path
  String _getDataDir() {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) {
      throw Exception('Could not determine home directory');
    }
    return '$homeDir/.heart_beat';
  }

  /// Get the profile file path
  String _getProfileFilePath() {
    return '${_getDataDir()}/$_profileFileName';
  }

  /// Get the current profile, loading from storage if needed.
  ///
  /// Returns the cached profile if available, otherwise loads from file.
  /// If no profile exists, returns the default profile.
  Future<UserProfile> getProfile() async {
    if (_currentProfile != null) {
      return _currentProfile!;
    }
    return await loadProfile();
  }

  /// Load user profile from file storage.
  ///
  /// If no profile exists in storage, returns and caches the default profile.
  Future<UserProfile> loadProfile() async {
    try {
      final file = File(_getProfileFilePath());

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _currentProfile = UserProfile.fromJson(json);
      } else {
        _currentProfile = getDefaultProfile();
      }

      return _currentProfile!;
    } catch (e) {
      // On error, use default profile
      _currentProfile = getDefaultProfile();
      return _currentProfile!;
    }
  }

  /// Save user profile to file storage.
  ///
  /// Stores the profile as a JSON file and updates the cached profile.
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final file = File(_getProfileFilePath());

      // Ensure data directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final jsonString = jsonEncode(profile.toJson());
      await file.writeAsString(jsonString);

      _currentProfile = profile;
    } catch (e) {
      rethrow;
    }
  }

  /// Get the default user profile.
  ///
  /// Returns a profile with sensible defaults:
  /// - Max HR: 180 BPM
  /// - Age-based calculation: disabled
  /// - Custom zones: null (uses default zones)
  UserProfile getDefaultProfile() {
    return UserProfile.defaults();
  }

  /// Clear the cached profile and reload from storage.
  ///
  /// Useful for testing or forcing a refresh from persistent storage.
  Future<UserProfile> reloadProfile() async {
    _currentProfile = null;
    return await loadProfile();
  }
}
