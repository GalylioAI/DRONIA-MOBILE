import '../../core/constants/app_constants.dart';
import '../models/advisory_model.dart';
import '../network/api_client.dart';

/// Service for agricultural advisor functionality
class AdvisorService {
  final ApiClient _apiClient;

  // Conversation history for chat
  final List<ChatMessage> _conversationHistory = [];
  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  AdvisorService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get advisories based on location and crop
  /// Backend returns list of Advisory objects based on weather and crop conditions
  Future<List<Advisory>> getAdvisories({
    required double lat,
    required double lng,
    String? crop,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
    };

    if (crop != null && crop.isNotEmpty) {
      queryParams['crop'] = crop;
    }

    final response = await _apiClient.get(
      ApiEndpoints.advisor,
      queryParams: queryParams,
      requiresAuth: false,
    );

    // Backend returns array of advisories
    if (response is List) {
      return response
          .map((e) => Advisory.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Or it might be wrapped in a data field
    if (response['data'] != null) {
      return (response['data'] as List)
          .map((e) => Advisory.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Get high priority advisories
  Future<List<Advisory>> getHighPriorityAdvisories({
    required double lat,
    required double lng,
    String? crop,
  }) async {
    final advisories = await getAdvisories(lat: lat, lng: lng, crop: crop);
    return advisories
        .where((a) => a.priority == AdvisoryPriority.high)
        .toList();
  }

  /// Send a message to the AI chat advisor
  /// Backend returns: { response: string, success: bool }
  Future<ChatMessage> sendMessage({
    required String message,
    double? lat,
    double? lng,
    String? cropType,
    String? concerns,
  }) async {
    // Add user message to history
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: message,
      timestamp: DateTime.now(),
    );
    _conversationHistory.add(userMessage);

    // Send to backend
    final response = await _apiClient.post(
      ApiEndpoints.advisorChat,
      body: ChatRequest(
        message: message,
        context: ChatContext(
          lat: lat,
          lng: lng,
          cropType: cropType,
          concerns: concerns,
        ),
        conversationHistory: _conversationHistory,
      ).toJson(),
      requiresAuth: false,
    );

    final chatResponse = ChatResponse.fromJson(response);

    // Add assistant message to history
    final assistantMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.assistant,
      content: chatResponse.response,
      timestamp: DateTime.now(),
    );
    _conversationHistory.add(assistantMessage);

    return assistantMessage;
  }

  /// Clear conversation history
  void clearConversation() {
    _conversationHistory.clear();
  }

  /// Get advisories grouped by type
  Future<Map<AdvisoryType, List<Advisory>>> getAdvisoriesGroupedByType({
    required double lat,
    required double lng,
    String? crop,
  }) async {
    final advisories = await getAdvisories(lat: lat, lng: lng, crop: crop);
    final grouped = <AdvisoryType, List<Advisory>>{};

    for (final advisory in advisories) {
      grouped.putIfAbsent(advisory.type, () => []).add(advisory);
    }

    return grouped;
  }

  /// Get weather-based advisories only
  Future<List<Advisory>> getWeatherBasedAdvisories({
    required double lat,
    required double lng,
    String? crop,
  }) async {
    final advisories = await getAdvisories(lat: lat, lng: lng, crop: crop);
    return advisories.where((a) => a.weatherBased).toList();
  }

  /// Get advisories count by priority
  Future<Map<AdvisoryPriority, int>> getAdvisoriesCountByPriority({
    required double lat,
    required double lng,
    String? crop,
  }) async {
    final advisories = await getAdvisories(lat: lat, lng: lng, crop: crop);
    return {
      AdvisoryPriority.high: advisories
          .where((a) => a.priority == AdvisoryPriority.high)
          .length,
      AdvisoryPriority.medium: advisories
          .where((a) => a.priority == AdvisoryPriority.medium)
          .length,
      AdvisoryPriority.low: advisories
          .where((a) => a.priority == AdvisoryPriority.low)
          .length,
    };
  }
}
