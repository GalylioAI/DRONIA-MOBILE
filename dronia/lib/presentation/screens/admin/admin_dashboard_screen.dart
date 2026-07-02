import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Console administrateur'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(name: user?.fullName ?? 'Administrateur'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorTile(error: _error!, onRetry: _refresh)
            else if (_stats != null)
              _StatsGrid(stats: _stats!),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.group_rounded,
              title: 'Gestion des utilisateurs',
              subtitle: 'Lister les comptes, changer leur plan, supprimer',
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers),
            ),
            _ActionTile(
              icon: Icons.workspace_premium_rounded,
              title: 'Plans d\'abonnement',
              subtitle: 'Consulter les tarifs et la répartition',
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminPlans),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.shield_moon_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour $name', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Espace réservé aux administrateurs DronIA',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(icon: Icons.people_alt_rounded, label: 'Utilisateurs', value: stats.totalUsers),
      _StatTile(icon: Icons.shield_rounded, label: 'Admins', value: stats.admins),
      _StatTile(icon: Icons.eco_rounded, label: 'Free', value: stats.freeUsers),
      _StatTile(icon: Icons.star_rounded, label: 'Premium', value: stats.premiumUsers),
      _StatTile(icon: Icons.business_rounded, label: 'Entreprise', value: stats.enterpriseUsers),
      _StatTile(icon: Icons.science_rounded, label: 'Analyses', value: stats.analyses),
      _StatTile(icon: Icons.map_rounded, label: 'Parcelles', value: stats.regions),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text('$value', style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Impossible de charger les statistiques.'),
            const SizedBox(height: 4),
            Text('$error', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onRetry, child: const Text('Réessayer')),
            ),
          ],
        ),
      ),
    );
  }
}
