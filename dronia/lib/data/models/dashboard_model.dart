/// Dashboard statistics model
class DashboardStats {
  final int activeSensors;
  final int totalSensors;
  final int activeDrones;
  final int totalDrones;
  final int pendingAlerts;
  final int totalAnalyses;
  final double averageHealthScore;
  final double areaMonitored;
  final List<RecentActivity> recentActivities;
  final List<QuickStat> quickStats;

  DashboardStats({
    required this.activeSensors,
    required this.totalSensors,
    required this.activeDrones,
    required this.totalDrones,
    required this.pendingAlerts,
    required this.totalAnalyses,
    required this.averageHealthScore,
    required this.areaMonitored,
    required this.recentActivities,
    required this.quickStats,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      activeSensors: json['active_sensors'] as int,
      totalSensors: json['total_sensors'] as int,
      activeDrones: json['active_drones'] as int,
      totalDrones: json['total_drones'] as int,
      pendingAlerts: json['pending_alerts'] as int,
      totalAnalyses: json['total_analyses'] as int,
      averageHealthScore: (json['average_health_score'] as num).toDouble(),
      areaMonitored: (json['area_monitored'] as num).toDouble(),
      recentActivities:
          (json['recent_activities'] as List<dynamic>?)
              ?.map((e) => RecentActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quickStats:
          (json['quick_stats'] as List<dynamic>?)
              ?.map((e) => QuickStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'active_sensors': activeSensors,
    'total_sensors': totalSensors,
    'active_drones': activeDrones,
    'total_drones': totalDrones,
    'pending_alerts': pendingAlerts,
    'total_analyses': totalAnalyses,
    'average_health_score': averageHealthScore,
    'area_monitored': areaMonitored,
    'recent_activities': recentActivities.map((e) => e.toJson()).toList(),
    'quick_stats': quickStats.map((e) => e.toJson()).toList(),
  };
}

/// Recent activity item
class RecentActivity {
  final String id;
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? icon;

  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.icon,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'icon': icon,
  };
}

/// Quick stat for dashboard KPI cards
class QuickStat {
  final String label;
  final String value;
  final String? unit;
  final String? trend;
  final double? trendValue;
  final String? icon;

  QuickStat({
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.trendValue,
    this.icon,
  });

  factory QuickStat.fromJson(Map<String, dynamic> json) {
    return QuickStat(
      label: json['label'] as String,
      value: json['value'] as String,
      unit: json['unit'] as String?,
      trend: json['trend'] as String?,
      trendValue: (json['trend_value'] as num?)?.toDouble(),
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'unit': unit,
    'trend': trend,
    'trend_value': trendValue,
    'icon': icon,
  };
}

/// Report model
class Report {
  final String id;
  final String title;
  final String type;
  final DateTime createdAt;
  final String? fileUrl;
  final String status;

  Report({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    this.fileUrl,
    required this.status,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fileUrl: json['file_url'] as String?,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'created_at': createdAt.toIso8601String(),
    'file_url': fileUrl,
    'status': status,
  };
}
