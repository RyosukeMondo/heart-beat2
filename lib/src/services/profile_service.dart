import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Centralized user profile management service.
///
/// This service manages user profile persistence and provides access to the
/// current profile throughout the app. It uses SharedPreferences to store
/// the profile as a JSON string.
class ProfileService {
  ProfileService._();

  static final ProfileService _instance = ProfileService._();

  /// Singleton instance accessor.
  static ProfileService get instance => _instance;

  /// SharedPreferences key for storing user profile
  static const String _profileKey = 'user_profile';

  /// Current user profile (cached)
  UserProfile? _currentProfile;

  /// Stream controller for profile changes
  final StreamController<UserProfile> _controller =
      StreamController<UserProfile>.broadcast();

  /// Whether the profile has been loaded
  bool _isLoaded = false;

  /// Get a broadcast stream of profile updates.
  Stream<UserProfile> get stream => _controller.stream;

  /// Get the current profile, loading from storage if needed.
  ///
  /// Returns the cached profile if available, otherwise loads from
  /// SharedPreferences. If no profile exists, returns the default profile.
  Future<UserProfile> getProfile() async {
    if (_currentProfile != null) {
      return _currentProfile!;
    }
    return await loadProfile();
  }

  /// Get the current profile synchronously.
  ///
  /// Returns null if the profile hasn't been loaded yet.
  /// Use [getProfile] if you need to ensure the profile is loaded.
  UserProfile? getCurrentProfile() {
    return _currentProfile;
  }

  /// Load user profile from SharedPreferences.
  ///
  /// If no profile exists in storage, returns and caches the default profile.
  /// Broadcasts the loaded profile to listeners.
  Future<UserProfile> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _currentProfile = UserProfile.fromJson(json);
      } else {
        _currentProfile = getDefaultProfile();
      }

      _isLoaded = true;
      _controller.add(_currentProfile!);
      return _currentProfile!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading profile: $e');
      }
      // On error, use default profile
      _currentProfile = getDefaultProfile();
      _isLoaded = true;
      return _currentProfile!;
    }
  }

  /// Save user profile to SharedPreferences.
  ///
  /// Stores the profile as a JSON string and updates the cached profile.
  /// Broadcasts the new profile to listeners.
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profile.toJson());
      await prefs.setString(_profileKey, jsonString);

      _currentProfile = profile;
      _controller.add(_currentProfile!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving profile: $e');
      }
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

  /// Check if the profile has been loaded.
  bool get isLoaded => _isLoaded;

  /// Dispose of resources.
  ///
  /// Should be called when the service is no longer needed.
  void dispose() {
    _controller.close();
  }
}
