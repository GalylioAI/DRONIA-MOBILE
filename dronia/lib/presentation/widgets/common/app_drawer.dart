import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/storage_service.dart';

/// Shared app drawer used across all pages.
/// When used from home screen, pass [onItemTapped] and [selectedIndex]
/// so items switch tabs. From other pages items navigate to home.
class AppDrawer extends StatelessWidget {
  /// Callback when a tab-based item is tapped (home screen only).
  final void Function(int index)? onItemTapped;

  /// Currently selected tab index (for highlighting).
  final int selectedIndex;

  /// Currently active route name (for highlighting route-based items).
  final String? currentRoute;

  const AppDrawer({
    super.key,
    this.onItemTapped,
    this.selectedIndex = -1,
    this.currentRoute,
  });

  // All nav items matching the home screen's tab order
  static const List<_DrawerNavItem> _navItems = [
    _DrawerNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Tableau de bord',
    ),
    _DrawerNavItem(
      icon: Icons.precision_manufacturing_outlined,
      activeIcon: Icons.precision_manufacturing,
      label: 'Mode Drone',
      badge: 'LIVE',
      badgeColor: AppColors.error,
    ),
    _DrawerNavItem(
      icon: Icons.cloud_upload_outlined,
      activeIcon: Icons.cloud_upload,
      label: 'Upload Photo',
    ),
    _DrawerNavItem(
      icon: Icons.bug_report_outlined,
      activeIcon: Icons.bug_report,
      label: 'Analyse des Insectes',
    ),
    _DrawerNavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Historique',
    ),
    _DrawerNavItem(
      icon: Icons.cloud_outlined,
      activeIcon: Icons.cloud,
      label: 'Météo Historique',
    ),
    _DrawerNavItem(
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny,
      label: 'Prédiction Météo',
    ),
    _DrawerNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Heatmap',
    ),
    _DrawerNavItem(
      icon: Icons.satellite_alt_outlined,
      activeIcon: Icons.satellite_alt,
      label: 'Surveillance Cultures',
      badge: 'NEW',
      badgeColor: AppColors.primaryGreen,
    ),
    _DrawerNavItem(
      icon: Icons.grass_outlined,
      activeIcon: Icons.grass,
      label: 'Surveillance Sols',
      badge: 'NEW',
      badgeColor: AppColors.primaryGreen,
    ),
    _DrawerNavItem(
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology,
      label: 'Conseiller IA',
      badge: 'AI',
      badgeColor: AppColors.info,
    ),
    _DrawerNavItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person,
      label: 'Mon Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDroneFleet = currentRoute == AppRoutes.droneFleet;
    final bool isDiseaseKB = currentRoute == AppRoutes.diseaseKnowledge;
    final bool isSettings = currentRoute == AppRoutes.settings;
    final colors = context.colors;

    return Drawer(
      backgroundColor: colors.bg,
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (int index = 0; index < _navItems.length; index++) ...[
                  _buildNavItem(context, index),
                  // Insert Drone Fleet after Mode Drone (index 1)
                  if (index == 1) ...[
                    _buildRouteItem(
                      context,
                      icon: Icons.flight_outlined,
                      activeIcon: Icons.flight,
                      label: 'Flotte de Drones',
                      badge: '3D',
                      badgeColor: AppColors.accentBrown,
                      route: AppRoutes.droneFleet,
                      isSelected: isDroneFleet,
                    ),
                    _buildRouteItem(
                      context,
                      icon: Icons.biotech_outlined,
                      activeIcon: Icons.biotech,
                      label: 'Maladies des Cultures',
                      badge: 'KB',
                      badgeColor: AppColors.warning,
                      route: AppRoutes.diseaseKnowledge,
                      isSelected: isDiseaseKB,
                    ),
                  ],
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: colors.divider, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'RÉGLAGES',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: colors.textHint,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.divider, height: 1)),
                    ],
                  ),
                ),
                _buildRouteItem(
                  context,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Paramètres',
                  route: AppRoutes.settings,
                  isSelected: isSettings,
                ),
              ],
            ),
          ),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
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
          const SizedBox(width: 12),
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
                        color: colors.textPrimary,
                      ),
                    ),
                    const TextSpan(
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
                  color: colors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final item = _navItems[index];
    final isSelected = selectedIndex == index && currentRoute == null;
    final colors = context.colors;

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
          color: isSelected ? AppColors.primaryGreen : colors.textSecondary,
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
                      : colors.textPrimary,
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
        onTap: () {
          Navigator.pop(context); // close drawer
          if (onItemTapped != null) {
            // We're on the home screen — switch tab in place.
            onItemTapped!(index);
          } else {
            // We're on another page — navigate to home and open directly
            // on the requested tab (no double-tap detour through dashboard).
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.home,
              arguments: index,
            );
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildRouteItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isSelected,
    String? badge,
    Color? badgeColor,
  }) {
    final colors = context.colors;
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
          isSelected ? activeIcon : icon,
          color: isSelected ? AppColors.primaryGreen : colors.textSecondary,
          size: 22,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      badgeColor?.withValues(alpha: 0.2) ??
                      AppColors.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? AppColors.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          if (!isSelected) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider, width: 1)),
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
        onTap: () => _handleLogout(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storage = StorageService();
      await storage.clearAuth();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }
}

class _DrawerNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  final Color? badgeColor;

  const _DrawerNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
    this.badgeColor,
  });
}
