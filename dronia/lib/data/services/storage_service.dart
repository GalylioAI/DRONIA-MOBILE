import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Secure storage service for persisting data locally
///
/// This service uses generic JSON storage for user data to support
/// different User model implementations during migration.
class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save authentication token
  Future<void> saveToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.tokenKey, token);
  }

  /// Get authentication token
  Future<String?> getToken() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.tokenKey);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.refreshTokenKey, token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.refreshTokenKey);
  }

  /// Save user data as JSON
  /// Accepts any object with a toJson() method
  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.userKey, json.encode(userJson));
  }

  /// Get user data as raw JSON Map
  /// Allows callers to deserialize to their specific User model
  Future<Map<String, dynamic>?> getUserJson() async {
    final prefs = await _preferences;
    final userJsonStr = prefs.getString(AppConstants.userKey);
    if (userJsonStr == null) return null;

    try {
      return json.decode(userJsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    final prefs = await _preferences;
    return prefs.getBool(AppConstants.onboardingKey) ?? false;
  }

  /// Set onboarding complete
  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(AppConstants.onboardingKey, value);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear all auth data (logout)
  Future<void> clearAuth() async {
    // Migration debugging: surface every caller so we can detect implicit
    // logouts (e.g. a 401-handler clearing the token without UI confirmation).
    // ignore: avoid_print
    print('🚪 StorageService.clearAuth() called\n${StackTrace.current}');
    final prefs = await _preferences;
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.clear();
  }

  /// Save generic string value
  Future<void> saveString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  /// Get generic string value
  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Save generic bool value
  Future<void> saveBool(String key, bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(key, value);
  }

  /// Get generic bool value
  Future<bool?> getBool(String key) async {
    final prefs = await _preferences;
    return prefs.getBool(key);
  }

  /// Remove a specific key
  Future<void> remove(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }
}
