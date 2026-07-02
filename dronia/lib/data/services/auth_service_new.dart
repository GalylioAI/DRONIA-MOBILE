import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import '../network/api_client.dart';
import 'storage_service.dart';

/// Authentication service backed by the VPS Next.js backend
/// (`https://dronia-tunisie.tn/api/auth/*`).
///
/// Differences from the previous Render backend:
///  - register no longer returns a token — the user must verify their email
///    via the link sent automatically before being able to log in.
///  - delete-account moved from `DELETE /auth/me` to `DELETE /auth/delete-account`.
///  - forgot password is now a 3-step OTP flow (forgot → verify-otp → reset).
///  - GET/PUT /auth/me return the user object directly (no `{ data: ... }` wrapper).
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

  /// POST /auth/login → `{ message, token, user }`.
  Future<String> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: LoginRequest(email: email, password: password).toJson(),
      requiresAuth: false,
    );

    final token = response['token'] as String;
    await _storageService.saveToken(token);

    // The login response already embeds the user — cache it without an extra round-trip.
    final userData = response['user'] as Map<String, dynamic>?;
    if (userData != null) {
      final user = User.fromJson(userData);
      await _storageService.saveUserJson(user.toJson());
      _currentUser = user;
    } else {
      await getProfile();
    }

    return token;
  }

  /// POST /auth/register → `{ message: "Compte créé. Vérifiez votre e-mail..." }`.
  /// No token is returned: the user must verify their email before logging in.
  /// Returns the success message so the UI can show it as-is.
  Future<String> register({
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

    return response['message'] as String? ??
        'Compte créé. Vérifiez votre e-mail pour activer votre compte.';
  }

  /// GET /auth/me → the user object directly (per VPS docs).
  /// Falls back to `response['data']` for backward compatibility with the old
  /// Render backend in case the call is routed there.
  Future<User> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.me);

    final userData = (response is Map<String, dynamic> && response['data'] is Map)
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    final user = User.fromJson(userData);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;
    return user;
  }

  /// PUT /auth/me — send any subset of fields; returns the updated user.
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

    final userData = (response is Map<String, dynamic> && response['data'] is Map)
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    final user = User.fromJson(userData);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;
    return user;
  }

  /// Logout. JWT is stateless server-side, so we always clear the local token.
  /// We also notify the server (best-effort) for symmetry; failure is ignored.
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout, body: const {}, requiresAuth: false);
    } catch (_) {
      // ignore: server has no session to invalidate
    }
    await _storageService.clearAuth();
    _currentUser = null;
  }

  /// Check if a token is present in local storage.
  Future<bool> isLoggedIn() async => _storageService.isLoggedIn();

  /// Restore session from local storage at app start.
  Future<User?> autoLogin() async {
    final isLoggedIn = await _storageService.isLoggedIn();
    if (!isLoggedIn) return null;

    final userJson = await _storageService.getUserJson();
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(userJson);
      } catch (_) {
        // stale cache shape — ignore
      }
    }

    try {
      return await getProfile();
    } catch (e) {
      if (_currentUser == null) {
        await logout();
        return null;
      }
      return _currentUser;
    }
  }

  Future<String?> getToken() => _storageService.getToken();

  /// PUT /auth/me/plan — switch the current user's subscription plan.
  Future<User> updateMyPlan(UserPlan plan) async {
    final response = await _apiClient.put(
      ApiEndpoints.mePlan,
      body: {'plan': plan.name},
    );

    final userData = (response is Map<String, dynamic> && response['data'] is Map)
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    final user = User.fromJson(userData);

    await _storageService.saveUserJson(user.toJson());
    _currentUser = user;
    return user;
  }

  /// DELETE /auth/delete-account — irreversible.
  /// The VPS backend takes no body; `confirmationName` is kept on the client
  /// side as a UI guard before the call is issued.
  Future<void> deleteAccount({String? confirmationName}) async {
    await _apiClient.delete(ApiEndpoints.deleteAccount);
    await _storageService.clearAuth();
    _currentUser = null;
  }

  // ------- Forgot-password OTP flow (3 steps) -------

  /// Step 1 — POST /auth/forgot-password. Always succeeds (does not reveal
  /// whether the email is registered). The 6-digit OTP is valid 15 minutes.
  Future<void> requestPasswordReset(String email) async {
    await _apiClient.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
      requiresAuth: false,
    );
  }

  /// Step 2 — POST /auth/verify-otp. Returns `true` if the code is valid,
  /// throws [ApiException] otherwise (wrong code, expired, never requested).
  Future<bool> verifyResetOtp({required String email, required String otp}) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyOtp,
      body: {'email': email, 'otp': otp},
      requiresAuth: false,
    );
    return response['success'] as bool? ?? false;
  }

  /// Step 3 — POST /auth/reset-password. Must follow a successful verify-otp
  /// call. Throws [ApiException] (403) if the OTP step was skipped.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _apiClient.post(
      ApiEndpoints.resetPassword,
      body: {'email': email, 'newPassword': newPassword},
      requiresAuth: false,
    );
  }
}
