import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import '../network/api_client.dart';

/// Snapshot of the figures shown on the admin home screen.
class AdminStats {
  final int totalUsers;
  final int admins;
  final int freeUsers;
  final int premiumUsers;
  final int enterpriseUsers;
  final int analyses;
  final int regions;

  AdminStats({
    required this.totalUsers,
    required this.admins,
    required this.freeUsers,
    required this.premiumUsers,
    required this.enterpriseUsers,
    required this.analyses,
    required this.regions,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final plans = (json['plans'] as Map<String, dynamic>?) ?? const {};
    int read(dynamic v) => (v is num) ? v.toInt() : 0;
    return AdminStats(
      totalUsers: read(json['totalUsers']),
      admins: read(json['admins']),
      freeUsers: read(plans['free']),
      premiumUsers: read(plans['premium']),
      enterpriseUsers: read(plans['enterprise']),
      analyses: read(json['analyses']),
      regions: read(json['regions']),
    );
  }
}

/// HTTP layer used by every admin-only screen.
class AdminService {
  final ApiClient _apiClient;

  AdminService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<AdminStats> getStats() async {
    final response = await _apiClient.get(ApiEndpoints.adminStats);
    final payload = response is Map<String, dynamic>
        ? (response['data'] as Map<String, dynamic>? ?? response)
        : <String, dynamic>{};
    return AdminStats.fromJson(payload);
  }

  Future<List<User>> listUsers() async {
    final response = await _apiClient.get(ApiEndpoints.adminUsers);
    final List<dynamic> raw = response is Map<String, dynamic>
        ? (response['data'] as List<dynamic>? ?? const [])
        : (response is List<dynamic> ? response : const []);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(User.fromJson)
        .toList(growable: false);
  }

  Future<User> updateUserPlan(String userId, UserPlan plan) async {
    final response = await _apiClient.put(
      ApiEndpoints.adminUserPlan(userId),
      body: {'plan': plan.name},
    );
    final payload = response is Map<String, dynamic>
        ? (response['data'] as Map<String, dynamic>? ?? response)
        : <String, dynamic>{};
    return User.fromJson(payload);
  }

  Future<void> deleteUser(String userId) async {
    await _apiClient.delete(ApiEndpoints.adminUser(userId));
  }

  /// Analyses (maladies) d'un utilisateur donné — admin uniquement.
  Future<List<Map<String, dynamic>>> getUserAnalyses(String userId) async {
    final response = await _apiClient.get(ApiEndpoints.adminUserAnalyses(userId));
    final List<dynamic> raw = response is Map<String, dynamic>
        ? (response['data'] as List<dynamic>? ?? const [])
        : const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Parcelles/régions d'un utilisateur donné — admin uniquement.
  /// Renvoie la liste + le total d'hectares.
  Future<({List<Map<String, dynamic>> regions, double totalHectares})>
      getUserRegions(String userId) async {
    final response = await _apiClient.get(ApiEndpoints.adminUserRegions(userId));
    final map = response is Map<String, dynamic> ? response : <String, dynamic>{};
    final List<dynamic> raw = map['data'] as List<dynamic>? ?? const [];
    final total = (map['totalHectares'] as num?)?.toDouble() ?? 0;
    return (
      regions: raw.whereType<Map<String, dynamic>>().toList(growable: false),
      totalHectares: total,
    );
  }
}
