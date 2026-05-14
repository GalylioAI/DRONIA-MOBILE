import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/intervention_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../dashboard/dashboard_screen.dart';
import '../analysis/analysis_wizard_screen.dart';
import '../analysis/analysis_history_screen.dart';
import '../drone/drone_monitoring_screen.dart';
import '../drone/planned_interventions_screen.dart';
import '../weather/weather_history_screen.dart';
import '../weather/weather_forecast_screen.dart';
import '../sensors/soil_monitor_screen.dart';
import '../ai/agricultural_advisor_screen.dart';
import '../map/heatmap_screen.dart';
import '../map/field_monitoring_screen.dart';
import '../profile/profile_screen.dart';
import '../analysis/insect_analysis_screen.dart';

/// Main home screen with sidebar navigation matching Dronia website
class HomeScreen extends StatefulWidget {
  /// Tab index to open on first build. Defaults to 0 (Tableau de bord).
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex = widget.initialIndex;
  int _pendingInterventionsCount = 0;
  final InterventionService _interventionService = InterventionService();

  @override
  void initState() {
    super.initState();
    _loadPendingInterventionsCount();
  }

  Future<void> _loadPendingInterventionsCount() async {
    final count = await _interventionService.getPendingCount();
    if (mounted) {
      setState(() => _pendingInterventionsCount = count);
    }
  }

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Tableau de bord',
    ),
    _NavItem(
      icon: Icons.precision_manufacturing_outlined,
      activeIcon: Icons.precision_manufacturing,
      label: 'Mode Drone',
      badge: 'LIVE',
      badgeColor: AppColors.error,
    ),
    _NavItem(
      icon: Icons.cloud_upload_outlined,
      activeIcon: Icons.cloud_upload,
      label: 'Upload Photo',
    ),
    _NavItem(
      icon: Icons.bug_report_outlined,
      activeIcon: Icons.bug_report,
      label: 'Analyse des Insectes',
    ),
    _NavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Historique',
    ),
    _NavItem(
      icon: Icons.cloud_outlined,
      activeIcon: Icons.cloud,
      label: 'Météo Historique',
    ),
    _NavItem(
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny,
      label: 'Prédiction Météo',
    ),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Heatmap'),
    _NavItem(
      icon: Icons.satellite_alt_outlined,
      activeIcon: Icons.satellite_alt,
      label: 'Surveillance Cultures',
      badge: 'NEW',
      badgeColor: AppColors.primaryGreen,
    ),
    _NavItem(
      icon: Icons.grass_outlined,
      activeIcon: Icons.grass,
      label: 'Surveillance Sols',
      badge: 'NEW',
      badgeColor: AppColors.primaryGreen,
    ),
    _NavItem(
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology,
      label: 'Conseiller IA',
      badge: 'AI',
      badgeColor: AppColors.info,
    ),
    _NavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person,
      label: 'Mon Profil',
    ),
  ];

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onNavigate: _onItemTapped);
      case 1:
        return DroneMonitoringScreen();
      case 2:
        return AnalysisWizardScreen();
      case 3:
        return InsectAnalysisScreen();
      case 4:
        return AnalysisHistoryScreen();
      case 5:
        return WeatherHistoryScreen();
      case 6:
        return WeatherForecastScreen();
      case 7:
        return HeatmapScreen();
      case 8:
        return FieldMonitoringScreen();
      case 9:
        return SoilMonitorScreen();
      case 10:
        return AgriculturalAdvisorScreen();
      case 11:
        return ProfileScreen();
      default:
        return DashboardScreen(onNavigate: _onItemTapped);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Close drawer on mobile after selection
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Déconnexion',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final storage = StorageService();
      await storage.clearAll();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isWideScreen ? null : _buildAppBar(),
      drawer: isWideScreen
          ? null
          : AppDrawer(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
            ),
      body: Row(
        children: [
          if (isWideScreen) _buildSidebar(),
          Expanded(child: _getScreen(_selectedIndex)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: context.colors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/Logo_DronIA-11.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Dron',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: 'IA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Calendar icon for planned interventions
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.calendar_month_outlined,
                color: context.colors.textSecondary,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlannedInterventionsScreen(),
                  ),
                );
                _loadPendingInterventionsCount();
              },
            ),
            if (_pendingInterventionsCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _pendingInterventionsCount > 9
                        ? '9+'
                        : '$_pendingInterventionsCount',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Notifications icon
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: context.colors.textSecondary,
          ),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: context.colors.bg,
        border: Border(
          right: BorderSide(color: context.colors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) => _buildNavItem(index),
            ),
          ),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/Logo_DronIA-11.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Dron',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'IA',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'AGRONOMIE DE PRÉCISION',
                style: TextStyle(
                  fontSize: 10,
                  color: context.colors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? item.activeIcon : item.icon,
          color: isSelected ? AppColors.primaryGreen : context.colors.textSecondary,
          size: 22,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : context.colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      item.badgeColor?.withValues(alpha: 0.2) ??
                      AppColors.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(
                    color: item.badgeColor ?? AppColors.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _onItemTapped(index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.colors.divider, width: 1),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppColors.error, size: 22),
        title: const Text(
          'Déconnexion',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: _handleLogout,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  final Color? badgeColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
    this.badgeColor,
  });
}
