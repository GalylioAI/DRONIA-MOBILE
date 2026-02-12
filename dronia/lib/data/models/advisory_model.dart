/// Agricultural advisory model matching the Next.js backend
class Advisory {
  final String id;
  final AdvisoryType type;
  final String title;
  final String description;
  final AdvisoryPriority priority;
  final String icon;
  final List<String> actionItems;
  final bool weatherBased;
  final DateTime timestamp;

  Advisory({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.icon,
    required this.actionItems,
    required this.weatherBased,
    required this.timestamp,
  });

  factory Advisory.fromJson(Map<String, dynamic> json) {
    return Advisory(
      id: json['id'] as String,
      type: AdvisoryType.fromString(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      priority: AdvisoryPriority.fromString(json['priority'] as String),
      icon: json['icon'] as String? ?? '📋',
      actionItems:
          (json['actionItems'] as List<dynamic>?)?.cast<String>() ?? [],
      weatherBased: json['weatherBased'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'priority': priority.name,
    'icon': icon,
    'actionItems': actionItems,
    'weatherBased': weatherBased,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Advisory types
enum AdvisoryType {
  irrigation,
  fertilizer,
  pest,
  harvest,
  planting,
  general;

  static AdvisoryType fromString(String value) {
    return AdvisoryType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AdvisoryType.general,
    );
  }

  String get displayName {
    switch (this) {
      case AdvisoryType.irrigation:
        return 'Irrigation';
      case AdvisoryType.fertilizer:
        return 'Fertilisation';
      case AdvisoryType.pest:
        return 'Ravageurs';
      case AdvisoryType.harvest:
        return 'Récolte';
      case AdvisoryType.planting:
        return 'Plantation';
      case AdvisoryType.general:
        return 'Général';
    }
  }
}

/// Advisory priority levels
enum AdvisoryPriority {
  high,
  medium,
  low;

  static AdvisoryPriority fromString(String value) {
    return AdvisoryPriority.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AdvisoryPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case AdvisoryPriority.high:
        return 'Haute';
      case AdvisoryPriority.medium:
        return 'Moyenne';
      case AdvisoryPriority.low:
        return 'Basse';
    }
  }

  String get color {
    switch (this) {
      case AdvisoryPriority.high:
        return '#f44336';
      case AdvisoryPriority.medium:
        return '#FF9800';
      case AdvisoryPriority.low:
        return '#4CAF50';
    }
  }
}

/// Chat message model for AI advisor
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.fromString(json['role'] as String),
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Chat roles
enum ChatRole {
  user,
  assistant;

  static ChatRole fromString(String value) {
    return ChatRole.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ChatRole.user,
    );
  }
}

/// Chat context for AI advisor
class ChatContext {
  final double? lat;
  final double? lng;
  final String? cropType;
  final String? concerns;

  ChatContext({this.lat, this.lng, this.cropType, this.concerns});

  Map<String, dynamic> toJson() => {
    'location': lat != null && lng != null ? {'lat': lat, 'lng': lng} : null,
    'cropType': cropType ?? '',
    'concerns': concerns ?? '',
  };
}

/// Chat request model
class ChatRequest {
  final String message;
  final ChatContext context;
  final List<ChatMessage> conversationHistory;

  ChatRequest({
    required this.message,
    required this.context,
    required this.conversationHistory,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'context': context.toJson(),
    'conversationHistory': conversationHistory
        .map((e) => {'role': e.role.name, 'content': e.content})
        .toList(),
  };
}

/// Chat response model
class ChatResponse {
  final String response;
  final bool success;

  ChatResponse({required this.response, required this.success});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] as String? ?? json['message'] as String? ?? '',
      success: json['success'] as bool? ?? true,
    );
  }
}
