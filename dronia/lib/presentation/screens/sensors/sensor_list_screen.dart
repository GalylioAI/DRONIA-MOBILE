import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/sensor_model.dart';

/// Modern Sensor List Screen with elegant design
class SensorListScreen extends StatefulWidget {
  const SensorListScreen({super.key});

  @override
  State<SensorListScreen> createState() => _SensorListScreenState();
}

class _SensorListScreenState extends State<SensorListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String _selectedFilter = 'all';

  final List<Sensor> _sensors = [
    Sensor(
      id: 's001',
      name: 'Humidité Sol A1',
      type: SensorType.soilMoisture,
      status: SensorStatus.online,
      location: GeoLocation(latitude: 36.8065, longitude: 10.1815),
      parcelName: 'Parcelle A',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Sensor(
      id: 's002',
      name: 'Température B1',
      type: SensorType.temperature,
      status: SensorStatus.online,
      location: GeoLocation(latitude: 36.8100, longitude: 10.1750),
      parcelName: 'Parcelle B',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    Sensor(
      id: 's003',
      name: 'Humidité Air B2',
      type: SensorType.humidity,
      status: SensorStatus.warning,
      location: GeoLocation(latitude: 36.8050, longitude: 10.1800),
      parcelName: 'Parcelle B',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Sensor(
      id: 's004',
      name: 'Capteur CO2 C1',
      type: SensorType.co2,
      status: SensorStatus.offline,
      location: GeoLocation(latitude: 36.8080, longitude: 10.1780),
      parcelName: 'Parcelle C',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<Sensor> get _filteredSensors {
    if (_selectedFilter == 'all') return _sensors;
    if (_selectedFilter == 'online') {
      return _sensors.where((s) => s.status == SensorStatus.online).toList();
    }
    if (_selectedFilter == 'warning') {
      return _sensors.where((s) => s.status == SensorStatus.warning).toList();
    }
    if (_selectedFilter == 'offline') {
      return _sensors.where((s) => s.status == SensorStatus.offline).toList();
    }
    return _sensors;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildSummaryCards()),
            SliverToBoxAdapter(child: _buildFilterTabs()),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSensorCard(_filteredSensors[index]),
                  childCount: _filteredSensors.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      backgroundColor: AppColors.backgroundDark,
      floating: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.2),
                  AppColors.primaryGreen.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sensors,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Capteurs IoT',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppColors.textSecondary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final online = _sensors
        .where((s) => s.status == SensorStatus.online)
        .length;
    final warning = _sensors
        .where((s) => s.status == SensorStatus.warning)
        .length;
    final offline = _sensors
        .where((s) => s.status == SensorStatus.offline)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreen.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('${_sensors.length}', 'Total', Icons.sensors),
            _buildSummaryDivider(),
            _buildSummaryItem(
              '$online',
              'En ligne',
              Icons.check_circle,
              Colors.white,
            ),
            _buildSummaryDivider(),
            _buildSummaryItem(
              '$warning',
              'Alerte',
              Icons.warning,
              Colors.amber,
            ),
            _buildSummaryDivider(),
            _buildSummaryItem(
              '$offline',
              'Hors ligne',
              Icons.cancel,
              Colors.red.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildSummaryItem(
    String value,
    String label,
    IconData icon, [
    Color? iconColor,
  ]) {
    return Column(
      children: [
        Icon(icon, color: iconColor ?? Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'id': 'all', 'label': 'Tous'},
      {'id': 'online', 'label': 'En ligne'},
      {'id': 'warning', 'label': 'Alertes'},
      {'id': 'offline', 'label': 'Hors ligne'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter['id']!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen.withOpacity(0.2)
                      : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.dividerColor,
                  ),
                ),
                child: Text(
                  filter['label']!,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSensorCard(Sensor sensor) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (sensor.status) {
      case SensorStatus.online:
        statusColor = AppColors.primaryGreen;
        statusIcon = Icons.check_circle;
        statusText = 'En ligne';
        break;
      case SensorStatus.warning:
        statusColor = Colors.amber;
        statusIcon = Icons.warning;
        statusText = 'Alerte';
        break;
      case SensorStatus.offline:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Hors ligne';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.help;
        statusText = 'Inconnu';
    }

    IconData sensorIcon;
    switch (sensor.type) {
      case SensorType.soilMoisture:
        sensorIcon = Icons.water_drop;
        break;
      case SensorType.temperature:
        sensorIcon = Icons.thermostat;
        break;
      case SensorType.humidity:
        sensorIcon = Icons.water;
        break;
      case SensorType.co2:
        sensorIcon = Icons.co2;
        break;
      default:
        sensorIcon = Icons.sensors;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.sensorDetail,
              arguments: sensor.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(sensorIcon, color: statusColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sensor.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sensor.parcelName ?? 'Non assigné',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(sensor.lastUpdated),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}
