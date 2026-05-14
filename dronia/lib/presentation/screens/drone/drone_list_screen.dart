import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/drone_model.dart';

/// Drone list screen - Modern elegant design
class DroneListScreen extends StatefulWidget {
  const DroneListScreen({super.key});

  @override
  State<DroneListScreen> createState() => _DroneListScreenState();
}

class _DroneListScreenState extends State<DroneListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'all';

  // Mock drone data
  final List<Drone> _drones = [
    Drone(
      id: 'd001',
      name: 'Drone Alpha',
      model: 'DJI Mavic 3',
      status: DroneStatus.active,
      batteryLevel: 78,
      lastUpdated: DateTime.now().subtract(Duration(minutes: 5)),
    ),
    Drone(
      id: 'd002',
      name: 'Drone Beta',
      model: 'DJI Phantom 4',
      status: DroneStatus.idle,
      batteryLevel: 100,
      lastUpdated: DateTime.now().subtract(Duration(hours: 1)),
    ),
    Drone(
      id: 'd003',
      name: 'Drone Gamma',
      model: 'DJI Agras T30',
      status: DroneStatus.charging,
      batteryLevel: 45,
      lastUpdated: DateTime.now().subtract(Duration(hours: 2)),
    ),
    Drone(
      id: 'd004',
      name: 'Drone Delta',
      model: 'DJI Mini 3 Pro',
      status: DroneStatus.offline,
      batteryLevel: 0,
      lastUpdated: DateTime.now().subtract(Duration(days: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Drone> get _filteredDrones {
    if (_selectedFilter == 'all') return _drones;
    return _drones.where((d) {
      switch (_selectedFilter) {
        case 'active':
          return d.status == DroneStatus.active;
        case 'idle':
          return d.status == DroneStatus.idle;
        case 'charging':
          return d.status == DroneStatus.charging;
        case 'offline':
          return d.status == DroneStatus.offline;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _refreshData() async {
    await Future.delayed(Duration(seconds: 1));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFleetOverview(),
                SizedBox(height: 20),
                _buildQuickActions(),
                SizedBox(height: 20),
                _buildFilterTabs(),
                SizedBox(height: 16),
                _buildDronesList(),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetOverview() {
    final activeCount = _drones
        .where((d) => d.status == DroneStatus.active)
        .length;
    final idleCount = _drones.where((d) => d.status == DroneStatus.idle).length;
    final chargingCount = _drones
        .where((d) => d.status == DroneStatus.charging)
        .length;
    final offlineCount = _drones
        .where((d) => d.status == DroneStatus.offline)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentBrown,
            AppColors.accentBrown.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBrown.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flotte de Drones',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_drones.length} drones enregistrés',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.precision_manufacturing,
                  color: AppColors.white,
                  size: 36,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              _buildStatusPill(activeCount, 'En vol', AppColors.success),
              SizedBox(width: 10),
              _buildStatusPill(idleCount, 'En veille', AppColors.info),
              SizedBox(width: 10),
              _buildStatusPill(chargingCount, 'Charge', AppColors.warning),
              SizedBox(width: 10),
              _buildStatusPill(offlineCount, 'Hors ligne', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(int count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.play_circle_outline,
            label: 'Démarrer Mission',
            color: AppColors.primaryGreen,
            onTap: () {},
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.map_outlined,
            label: 'Voir Carte',
            color: AppColors.info,
            onTap: () {
              // Navigate to map view
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'id': 'all', 'label': 'Tous', 'count': _drones.length},
      {
        'id': 'active',
        'label': 'En vol',
        'count': _drones.where((d) => d.status == DroneStatus.active).length,
      },
      {
        'id': 'idle',
        'label': 'Veille',
        'count': _drones.where((d) => d.status == DroneStatus.idle).length,
      },
      {
        'id': 'charging',
        'label': 'Charge',
        'count': _drones.where((d) => d.status == DroneStatus.charging).length,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedFilter = filter['id'] as String),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.white
                            : context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if ((filter['count'] as int) > 0) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.white.withValues(alpha: 0.2)
                              : context.colors.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filter['count']}',
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.white
                                : context.colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDronesList() {
    final drones = _filteredDrones;

    if (drones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.precision_manufacturing_outlined,
              size: 48,
              color: context.colors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Aucun drone trouvé',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              color: AppColors.accentBrown,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Mes Drones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            Spacer(),
            Text(
              '${drones.length} résultats',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...drones.map((drone) => _buildDroneCard(drone)),
      ],
    );
  }

  Widget _buildDroneCard(Drone drone) {
    final statusColor = _getStatusColor(drone.status);
    final statusLabel = _getStatusLabel(drone.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: drone.status == DroneStatus.active
              ? statusColor.withValues(alpha: 0.4)
              : context.colors.divider,
        ),
        boxShadow: [
          if (drone.status == DroneStatus.active)
            BoxShadow(
              color: statusColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.droneDetail,
              arguments: drone,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Drone icon with status glow
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.3),
                            statusColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.precision_manufacturing,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.card,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drone.name,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            drone.model,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Battery and info row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Battery indicator
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _getBatteryIcon(drone.batteryLevel),
                              color: _getBatteryColor(drone.batteryLevel),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${drone.batteryLevel}%',
                                    style: TextStyle(
                                      color: _getBatteryColor(
                                        drone.batteryLevel,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: drone.batteryLevel / 100,
                                      backgroundColor: context.colors.divider,
                                      valueColor: AlwaysStoppedAnimation(
                                        _getBatteryColor(drone.batteryLevel),
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: context.colors.divider,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      // Last update
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: context.colors.textSecondary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dernière activité',
                                    style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _formatLastUpdated(drone.lastUpdated),
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DroneStatus status) {
    switch (status) {
      case DroneStatus.active:
        return AppColors.success;
      case DroneStatus.idle:
        return AppColors.info;
      case DroneStatus.charging:
        return AppColors.warning;
      case DroneStatus.offline:
        return AppColors.error;
      case DroneStatus.maintenance:
        return AppColors.accentBrown;
    }
  }

  String _getStatusLabel(DroneStatus status) {
    switch (status) {
      case DroneStatus.active:
        return 'En vol';
      case DroneStatus.idle:
        return 'En veille';
      case DroneStatus.charging:
        return 'En charge';
      case DroneStatus.offline:
        return 'Hors ligne';
      case DroneStatus.maintenance:
        return 'Maintenance';
    }
  }

  Color _getBatteryColor(int level) {
    if (level > 60) return AppColors.success;
    if (level > 30) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return Icons.battery_full;
    if (level > 60) return Icons.battery_5_bar;
    if (level > 40) return Icons.battery_4_bar;
    if (level > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  String _formatLastUpdated(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    }
    return 'Il y a ${diff.inDays}j';
  }
}
