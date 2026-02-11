import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/intervention_service.dart';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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
        return const DroneMonitoringScreen();
      case 2:
        return const AnalysisWizardScreen();
      case 3:
        return const InsectAnalysisScreen();
      case 4:
        return const AnalysisHistoryScreen();
      case 5:
        return const WeatherHistoryScreen();
      case 6:
        return const WeatherForecastScreen();
      case 7:
        return const HeatmapScreen();
      case 8:
        return const FieldMonitoringScreen();
      case 9:
        return const SoilMonitorScreen();
      case 10:
        return const AgriculturalAdvisorScreen();
      case 11:
        return const ProfileScreen();
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
        backgroundColor: AppColors.cardDark,
        title: const Text(
          'Déconnexion',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Déconnexion'),
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
      backgroundColor: AppColors.backgroundDark,
      appBar: isWideScreen ? null : _buildAppBar(),
      drawer: isWideScreen ? null : _buildDrawer(),
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
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/Drone_Logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Dron',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlannedInterventionsScreen(),
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
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _pendingInterventionsCount > 9
                        ? '9+'
                        : '$_pendingInterventionsCount',
                    style: const TextStyle(
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
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundDark,
      child: Column(
        children: [
          _buildDrawerHeader(),
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

  Widget _buildDrawerHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/Drone_Logo.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Dron',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
              const Text(
                'AGRONOMIE DE PRÉCISION',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          right: BorderSide(color: AppColors.dividerColor, width: 1),
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
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/Drone_Logo.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Dron',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
              const Text(
                'AGRONOMIE DE PRÉCISION',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
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
          color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
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
                      : AppColors.textPrimary,
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
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.dividerColor, width: 1),
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
