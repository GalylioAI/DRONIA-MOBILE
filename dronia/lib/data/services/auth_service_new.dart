import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import '../network/api_client.dart';
import 'storage_service.dart';

/// Authentication service matching the Next.js backend
class AuthService {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthService({
    required ApiClient apiClient,
    required StorageService storageService,
  }) : _apiClient = apiClient,
       _storageService = storageService;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Login with email and password
  /// Backend returns: { token: string }
  Future<String> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: LoginRequest(email: email, password: password).toJson(),
      requiresAuth: false,
    );

    final token = response['token'] as String;

    // Save token
    await _storageService.saveToken(token);

    // Fetch user profile after login
    await getProfile();

    return token;
  }

  /// Register a new user
  /// Backend returns: { token: string, user: User, success: true } on success
  Future<bool> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    Location? location,
    List<String>? plantTypes,
    String? profileImage,
    double? totalSurface,
    String? soilType,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        location: location,
        plantTypes: plantTypes,
        profileImage: profileImage,
        totalSurface: totalSurface,
        soilType: soilType,
      ).toJson(),
      requiresAuth: false,
    );

    // Save token if returned (auto-login after registration)
    final token = response['token'] as String?;
    if (token != null) {
      await _storageService.saveToken(token);

      // Try to get user from response
      final userData = response['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = User.fromJson(userData);
        await _storageService.saveUserJson(user.toJson());
        _currentUser = user;
      }
    }

    return response['success'] as bool? ?? true;
  }

  /// Get current user profile
  /// Backend returns: { success: true, data: User }
  Future<User> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.me);

    final userData = response['data'] as Map<String, dynamic>;
    final user = User.fromJson(userData);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;

    return user;
  }

  /// Update user profile
  /// Backend returns: { success: true, data: User }
  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    Location? location,
    List<String>? plantTypes,
    String? profileImage,
    double? totalSurface,
    String? soilType,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.me,
      body: UpdateProfileRequest(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        location: location,
        plantTypes: plantTypes,
        profileImage: profileImage,
        totalSurface: totalSurface,
        soilType: soilType,
      ).toJson(),
    );

    final userData = response['data'] as Map<String, dynamic>;
    final user = User.fromJson(userData);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;

    return user;
  }

  /// Logout - clear local auth data
  Future<void> logout() async {
    await _storageService.clearAuth();
    _currentUser = null;
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _storageService.isLoggedIn();
  }

  /// Auto login - restore session from storage
  Future<User?> autoLogin() async {
    final isLoggedIn = await _storageService.isLoggedIn();
    if (!isLoggedIn) return null;

    // Try to get cached user first
    final userJson = await _storageService.getUserJson();
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(userJson);
      } catch (_) {
        // Ignore parse errors for cached data
      }
    }

    // Try to refresh profile from server
    try {
      return await getProfile();
    } catch (e) {
      // If profile fetch fails (e.g., token expired), return cached user
      // or null to trigger re-login
      if (_currentUser == null) {
        await logout();
        return null;
      }
      return _currentUser;
    }
  }

  /// Get current token
  Future<String?> getToken() async {
    return await _storageService.getToken();
  }

  /// Delete user account permanently
  /// Requires user to confirm by typing their first name
  Future<void> deleteAccount({required String confirmationName}) async {
    await _apiClient.delete(
      ApiEndpoints.me,
      body: {'confirmationName': confirmationName},
    );

    // Clear local data after successful deletion
    await _storageService.clearAuth();
    _currentUser = null;
  }
}
