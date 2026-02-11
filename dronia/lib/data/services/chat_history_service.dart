import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing AI chat history persistence
class ChatHistoryService {
  static const String _chatHistoryKey = 'ai_chat_history';
  static const String _conversationsKey = 'ai_conversations';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a conversation session
  Future<void> saveConversation(ChatSession session) async {
    final prefs = await _preferences;
    final sessions = await getConversations();

    // Check if session already exists, update it
    final existingIndex = sessions.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      sessions[existingIndex] = session;
    } else {
      sessions.insert(0, session); // Add new session at the beginning
    }

    // Keep only the last 50 conversations
    final trimmedSessions = sessions.take(50).toList();

    final jsonList = trimmedSessions.map((s) => s.toJson()).toList();
    await prefs.setString(_conversationsKey, jsonEncode(jsonList));
  }

  /// Get all saved conversations
  Future<List<ChatSession>> getConversations() async {
    final prefs = await _preferences;
    final jsonStr = prefs.getString(_conversationsKey);
    if (jsonStr == null) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList.map((json) => ChatSession.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete a specific conversation
  Future<void> deleteConversation(String sessionId) async {
    final prefs = await _preferences;
    final sessions = await getConversations();
    sessions.removeWhere((s) => s.id == sessionId);

    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_conversationsKey, jsonEncode(jsonList));
  }

  /// Clear all chat history
  Future<void> clearAllHistory() async {
    final prefs = await _preferences;
    await prefs.remove(_conversationsKey);
    await prefs.remove(_chatHistoryKey);
  }
}

/// Represents a chat session/conversation
class ChatSession {
  final String id;
  final String culture;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessageData> messages;

  ChatSession({
    required this.id,
    required this.culture,
    this.locationLabel,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  String get preview {
    if (messages.isEmpty) return 'Nouvelle conversation';
    final userMessages = messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return 'Nouvelle conversation';
    return userMessages.first.text.length > 50
        ? '${userMessages.first.text.substring(0, 50)}...'
        : userMessages.first.text;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'culture': culture,
    'locationLabel': locationLabel,
    'latitude': latitude,
    'longitude': longitude,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    culture: json['culture'] as String,
    locationLabel: json['locationLabel'] as String?,
    latitude: json['latitude'] as double?,
    longitude: json['longitude'] as double?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List<dynamic>)
        .map((m) => ChatMessageData.fromJson(m))
        .toList(),
  );

  ChatSession copyWith({
    String? id,
    String? culture,
    String? locationLabel,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessageData>? messages,
  }) => ChatSession(
    id: id ?? this.id,
    culture: culture ?? this.culture,
    locationLabel: locationLabel ?? this.locationLabel,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );
}

/// Represents a single chat message
class ChatMessageData {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath; // For image attachments

  ChatMessageData({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
  };

  factory ChatMessageData.fromJson(Map<String, dynamic> json) =>
      ChatMessageData(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        imagePath: json['imagePath'] as String?,
      );
}
