import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/detection_model.dart';
import '../../../data/services/detection_service.dart';

/// Notifications screen - displays real app notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<_AppNotification> _notifications = [];
  bool _isLoading = true;

  final DetectionService _detectionService = DetectionService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    // Load detection history and convert to notifications
    final detections = await _detectionService.getDetectionHistory();

    final notifications = <_AppNotification>[];

    // Add detection-based notifications
    for (final detection in detections) {
      notifications.add(
        _AppNotification(
          id: detection.id,
          type: detection.type == DetectionType.disease
              ? _NotificationType.disease
              : _NotificationType.stress,
          title: detection.type == DetectionType.disease
              ? 'Maladie détectée'
              : 'Stress détecté',
          message:
              '${detection.label} (${(detection.confidence * 100).toStringAsFixed(0)}%) dans ${detection.zone}',
          timestamp: detection.timestamp,
          isRead: false,
          icon: detection.type == DetectionType.disease
              ? Icons.bug_report
              : Icons.warning_amber,
          color: detection.type == DetectionType.disease
              ? AppColors.error
              : AppColors.warning,
        ),
      );
    }

    // Add some system notifications
    notifications.insert(
      0,
      _AppNotification(
        id: 'system_1',
        type: _NotificationType.system,
        title: 'Bienvenue sur DronIA',
        message:
            'Votre application de surveillance agricole intelligente est prête.',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isRead: true,
        icon: Icons.check_circle,
        color: AppColors.primaryGreen,
      ),
    );

    // Add weather notification
    notifications.insert(
      1,
      _AppNotification(
        id: 'weather_1',
        type: _NotificationType.weather,
        title: 'Conditions météo favorables',
        message:
            'Température idéale pour le vol de drone aujourd\'hui (22°C, vent faible).',
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        isRead: false,
        icon: Icons.wb_sunny,
        color: AppColors.warning,
      ),
    );

    if (mounted) {
      setState(() {
        _notifications.clear();
        _notifications.addAll(notifications);
        _isLoading = false;
      });
    }
  }

  void _markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      setState(() {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      });
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Toutes les notifications marquées comme lues'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Effacer les notifications',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Voulez-vous vraiment effacer toutes les notifications ?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _notifications.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notifications effacées'),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
            child: Text(
              'Effacer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications, color: AppColors.primaryGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Notifications',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: context.colors.textSecondary,
                size: 22,
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Tout marquer comme lu',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: context.colors.textSecondary,
                size: 22,
              ),
              onPressed: _clearNotifications,
              tooltip: 'Effacer tout',
            ),
          ],
        ],
      ),
      body: FadeTransition(
              opacity: _fadeAnim,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationsList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.card,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: context.colors.textSecondary.withOpacity(0.5),
              size: 48,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Aucune notification',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vous serez notifié des détections\net alertes importantes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    // Group notifications by date
    final today = DateTime.now();
    final todayNotifications = _notifications
        .where(
          (n) =>
              n.timestamp.day == today.day &&
              n.timestamp.month == today.month &&
              n.timestamp.year == today.year,
        )
        .toList();
    final olderNotifications = _notifications
        .where(
          (n) =>
              n.timestamp.day != today.day ||
              n.timestamp.month != today.month ||
              n.timestamp.year != today.year,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (todayNotifications.isNotEmpty) ...[
            _buildSectionHeader('Aujourd\'hui'),
            SizedBox(height: 8),
            ...todayNotifications.map((n) => _buildNotificationCard(n)),
          ],
          if (olderNotifications.isNotEmpty) ...[
            if (todayNotifications.isNotEmpty) SizedBox(height: 20),
            _buildSectionHeader('Plus ancien'),
            SizedBox(height: 8),
            ...olderNotifications.map((n) => _buildNotificationCard(n)),
          ],
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.textSecondary.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(_AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: AppColors.error),
      ),
      onDismissed: (direction) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });
      },
      child: GestureDetector(
        onTap: () => _markAsRead(notification.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? context.colors.card
                : notification.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? context.colors.divider
                  : notification.color.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: notification.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: notification.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _formatTime(notification.timestamp),
                      style: TextStyle(
                        color: context.colors.textSecondary.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Notification type enum
enum _NotificationType { disease, stress, weather, system, alert }

/// App notification model
class _AppNotification {
  final String id;
  final _NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final IconData icon;
  final Color color;

  _AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.icon,
    required this.color,
  });

  _AppNotification copyWith({
    String? id,
    _NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    IconData? icon,
    Color? color,
  }) {
    return _AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}
