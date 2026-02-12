import '../../core/constants/app_constants.dart';
import '../models/dashboard_model.dart';
import '../network/api_client.dart';

/// Service for dashboard data
class DashboardService {
  final ApiClient _apiClient;

  DashboardService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    final response = await _apiClient.get(ApiEndpoints.dashboardStats);
    return DashboardStats.fromJson(response);
  }

  /// Get reports
  Future<List<Report>> getReports({
    int page = 1,
    int limit = AppConstants.defaultPageSize,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.reports,
      queryParams: {'page': page, 'limit': limit},
    );

    final list = response['data'] as List<dynamic>;
    return list.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get report by ID
  Future<Report> getReport(String reportId) async {
    final response = await _apiClient.get(ApiEndpoints.reportDetail(reportId));
    return Report.fromJson(response);
  }

  /// Export report as PDF
  Future<String> exportReport(String reportId) async {
    final response = await _apiClient.get(ApiEndpoints.reportExport(reportId));
    return response['download_url'] as String;
  }
}
