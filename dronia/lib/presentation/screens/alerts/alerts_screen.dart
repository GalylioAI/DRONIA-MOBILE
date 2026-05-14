import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alert_model.dart';

/// Alerts screen showing all system alerts
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock alerts data
  List<Alert> _alerts = [
    Alert(
      id: 'a001',
      type: AlertType.disease,
      severity: AlertSeverity.high,
      title: 'Disease Detected',
      message:
          'Leaf blight detected in Field A - Zone 3. Immediate action recommended.',
      createdAt: DateTime.now().subtract(Duration(hours: 2)),
      isRead: false,
      sourceType: 'field',
      sourceId: 'Field A',
    ),
    Alert(
      id: 'a002',
      type: AlertType.sensor,
      severity: AlertSeverity.medium,
      title: 'Low Soil Moisture',
      message:
          'Soil moisture level dropped below 30% in Field B. Consider irrigation.',
      createdAt: DateTime.now().subtract(Duration(hours: 5)),
      isRead: false,
      sourceType: 'field',
      sourceId: 'Field B',
    ),
    Alert(
      id: 'a003',
      type: AlertType.drone,
      severity: AlertSeverity.low,
      title: 'Drone Battery Low',
      message: 'Drone Alpha battery at 15%. Returning to base for charging.',
      createdAt: DateTime.now().subtract(Duration(hours: 8)),
      isRead: true,
    ),
    Alert(
      id: 'a004',
      type: AlertType.weather,
      severity: AlertSeverity.medium,
      title: 'Weather Alert',
      message:
          'Heavy rain expected in the next 24 hours. Plan activities accordingly.',
      createdAt: DateTime.now().subtract(Duration(days: 1)),
      isRead: true,
    ),
    Alert(
      id: 'a005',
      type: AlertType.pest,
      severity: AlertSeverity.critical,
      title: 'Pest Infestation Detected',
      message:
          'Aphid infestation identified in Field C. Urgent treatment required.',
      createdAt: DateTime.now().subtract(Duration(days: 2)),
      isRead: true,
      sourceType: 'field',
      sourceId: 'Field C',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadAlerts = _alerts.where((a) => !a.isRead).toList();
    final readAlerts = _alerts.where((a) => a.isRead).toList();

    return Column(
      children: [
        // Alert Summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${unreadAlerts.length} Unread Alerts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    Text(
                      'Requires your attention',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _markAllAsRead,
                child: Text('Mark All Read'),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: context.colors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          tabs: [
            Tab(text: 'All (${_alerts.length})'),
            Tab(text: 'Unread (${unreadAlerts.length})'),
            Tab(text: 'Read (${readAlerts.length})'),
          ],
        ),

        // Alert Lists
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAlertList(_alerts),
              _buildAlertList(unreadAlerts),
              _buildAlertList(readAlerts),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertList(List<Alert> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: context.colors.textHint,
            ),
            SizedBox(height: 16),
            Text(
              'No alerts',
              style: TextStyle(fontSize: 18, color: context.colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: AppColors.white),
      ),
      onDismissed: (_) => _deleteAlert(alert),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alert.isRead
              ? AppColors.white
              : _getSeverityColor(alert.severity).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead
                ? context.colors.divider
                : _getSeverityColor(alert.severity).withValues(alpha: 0.3),
          ),
          boxShadow: alert.isRead
              ? null
              : [
                  BoxShadow(
                    color: _getSeverityColor(
                      alert.severity,
                    ).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(
                      alert.severity,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getAlertIcon(alert.type),
                    color: _getSeverityColor(alert.severity),
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: alert.isRead
                              ? FontWeight.w500
                              : FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatTime(alert.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSeverityBadge(alert.severity),
              ],
            ),
            SizedBox(height: 12),
            Text(
              alert.message,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            if (alert.sourceId != null) ...[
              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: context.colors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      alert.sourceId!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(AlertSeverity severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getSeverityColor(severity),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getSeverityText(severity),
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Color(0xFFD32F2F);
      case AlertSeverity.high:
        return AppColors.error;
      case AlertSeverity.medium:
        return AppColors.warning;
      case AlertSeverity.low:
        return AppColors.info;
      case AlertSeverity.info:
        return context.colors.textSecondary;
    }
  }

  String _getSeverityText(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return 'CRITICAL';
      case AlertSeverity.high:
        return 'HIGH';
      case AlertSeverity.medium:
        return 'MEDIUM';
      case AlertSeverity.low:
        return 'LOW';
      case AlertSeverity.info:
        return 'INFO';
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.disease:
        return Icons.bug_report;
      case AlertType.pest:
        return Icons.pest_control;
      case AlertType.weather:
        return Icons.cloud;
      case AlertType.sensor:
        return Icons.sensors;
      case AlertType.drone:
        return Icons.precision_manufacturing;
      case AlertType.system:
        return Icons.settings;
      case AlertType.recommendation:
        return Icons.lightbulb;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _markAllAsRead() {
    setState(() {
      _alerts = _alerts.map((alert) => alert.copyWith(isRead: true)).toList();
    });
  }

  void _deleteAlert(Alert alert) {
    setState(() {
      _alerts.removeWhere((a) => a.id == alert.id);
    });
  }
}
