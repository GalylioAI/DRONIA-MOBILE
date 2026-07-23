import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/service_locator.dart';

/// Landing screen displayed right after an administrator logs in.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await services.admin.getStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await services.auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = services.auth.currentUser;
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primaryGreen,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildTopBar(themeProvider),
              const SizedBox(height: 16),
              _buildHeaderCard(user?.fullName ?? 'Administrateur'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Vue d\'ensemble',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  ),
                )
              else if (_error != null)
                _buildErrorCard()
              else if (_stats != null)
                _buildStatsGrid(_stats!),
              const SizedBox(height: 20),
              Text(
                'Gestion',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.group_rounded,
                color: AppColors.info,
                title: 'Gestion des utilisateurs',
                subtitle: 'Comptes, plans, analyses & parcelles',
                onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.workspace_premium_rounded,
                color: AppColors.warning,
                title: 'Plans d\'abonnement',
                subtitle: 'Tarifs et répartition des abonnements',
                onTap: () => Navigator.pushNamed(context, AppRoutes.adminPlans),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barre supérieure : titre + toggle thème + rafraîchir + déconnexion.
  Widget _buildTopBar(ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Console administrateur',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _circleIcon(
          icon: themeProvider.isDark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          onTap: () => context.read<ThemeProvider>().toggle(),
          tooltip: themeProvider.isDark ? 'Mode clair' : 'Mode sombre',
        ),
        const SizedBox(width: 8),
        _circleIcon(
          icon: Icons.refresh_rounded,
          onTap: _refresh,
          tooltip: 'Rafraîchir',
        ),
        const SizedBox(width: 8),
        _circleIcon(
          icon: Icons.logout_rounded,
          onTap: _logout,
          tooltip: 'Déconnexion',
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _circleIcon({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
  }) {
    final c = color ?? context.colors.textPrimary;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String name) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.20),
            AppColors.tertiaryGreen.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour $name',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Espace réservé aux administrateurs DronIA',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AdminStats stats) {
    final tiles = [
      _GlassStat(icon: Icons.people_alt_rounded, label: 'Utilisateurs', value: stats.totalUsers, color: AppColors.primaryGreen),
      _GlassStat(icon: Icons.shield_rounded, label: 'Admins', value: stats.admins, color: AppColors.info),
      _GlassStat(icon: Icons.eco_rounded, label: 'Free', value: stats.freeUsers, color: AppColors.tertiaryGreen),
      _GlassStat(icon: Icons.star_rounded, label: 'Premium', value: stats.premiumUsers, color: AppColors.warning),
      _GlassStat(icon: Icons.business_rounded, label: 'Entreprise', value: stats.enterpriseUsers, color: AppColors.accentBrown),
      _GlassStat(icon: Icons.science_rounded, label: 'Analyses', value: stats.analyses, color: AppColors.info),
      _GlassStat(icon: Icons.map_rounded, label: 'Parcelles', value: stats.regions, color: AppColors.warning),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 118,
      ),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impossible de charger les statistiques.',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text('$_error', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _refresh,
              child: const Text('Réessayer', style: TextStyle(color: AppColors.primaryGreen)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte statistique « glassmorphique » colorée (style folder card).
class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
