import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import 'storage_service.dart';

/// Authentication service for handling user authentication
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
  Future<User> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: LoginRequest(email: email, password: password).toJson(),
      requiresAuth: false,
    );

    final authResponse = AuthResponse.fromJson(response);

    // Save tokens and user
    await _storageService.saveToken(authResponse.tokens.accessToken);
    await _storageService.saveRefreshToken(authResponse.tokens.refreshToken);
    await _storageService.saveUserJson(authResponse.user.toJson());

    _currentUser = authResponse.user;
    return authResponse.user;
  }

  /// Register a new user
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      ).toJson(),
      requiresAuth: false,
    );

    final authResponse = AuthResponse.fromJson(response);

    // Save tokens and user
    await _storageService.saveToken(authResponse.tokens.accessToken);
    await _storageService.saveRefreshToken(authResponse.tokens.refreshToken);
    await _storageService.saveUserJson(authResponse.user.toJson());

    _currentUser = authResponse.user;
    return authResponse.user;
  }

  /// Get current user profile
  Future<User> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.profile);
    final user = User.fromJson(response);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;

    return user;
  }

  /// Update user profile
  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.profile,
      body: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
      },
    );

    final user = User.fromJson(response);
    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;

    return user;
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {
      // Ignore logout API errors, still clear local data
    }

    await _storageService.clearAuth();
    _currentUser = null;
  }

  /// Check if user is logged in (for auto-login)
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
        // Ignore parse errors
      }
    }

    // Try to refresh profile from server
    try {
      return await getProfile();
    } catch (_) {
      // If profile fetch fails, return cached user
      return _currentUser;
    }
  }

  /// Refresh authentication token
  Future<void> refreshToken() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await _apiClient.post(
      ApiEndpoints.refreshToken,
      body: {'refresh_token': refreshToken},
      requiresAuth: false,
    );

    final tokens = AuthTokens.fromJson(response);
    await _storageService.saveToken(tokens.accessToken);
    await _storageService.saveRefreshToken(tokens.refreshToken);
  }

  /// Delete user account permanently
  Future<void> deleteAccount({required String confirmationName}) async {
    await _apiClient.delete(
      ApiEndpoints.profile,
      body: {'confirmationName': confirmationName},
    );

    // Clear local data after successful deletion
    await _storageService.clearAuth();
    _currentUser = null;
  }
}
