import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/services/service_locator.dart';
import 'admin_user_detail_screen.dart';

/// Lists every registered user and lets the admin change their plan or remove them.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<User> _users = [];
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
      final users = await services.admin.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _changePlan(User user) async {
    final selected = await showModalBottomSheet<UserPlan>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Plan pour ${user.fullName}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final plan in UserPlan.values)
                ListTile(
                  leading: Icon(_iconForPlan(plan)),
                  title: Text(plan.displayName),
                  subtitle: Text(plan.tagline),
                  trailing: user.plan == plan ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(ctx, plan),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == user.plan) return;
    try {
      final updated = await services.admin.updateUserPlan(user.id, selected);
      if (!mounted) return;
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan mis à jour : ${updated.plan.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('${user.fullName} (${user.email}) sera définitivement retiré de la plateforme.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await services.admin.deleteUser(user.id);
      if (!mounted) return;
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  IconData _iconForPlan(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Icons.eco_rounded;
      case UserPlan.premium:
        return Icons.star_rounded;
      case UserPlan.enterprise:
        return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 8),
                        Text('$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(user.initials)),
                        title: Text(user.fullName),
                        subtitle: Text(
                          '${user.email}\n${user.role.displayName} · ${user.plan.displayName}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminUserDetailScreen(user: user),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'plan') _changePlan(user);
                            if (value == 'delete') _deleteUser(user);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'plan', child: Text('Changer le plan')),
                            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
