import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/services/service_locator.dart';

/// Read-only overview of the three plan tiers and their adoption.
class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  bool _loading = true;
  Object? _error;
  Map<UserPlan, int> _distribution = const {};

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
        _distribution = {
          UserPlan.free: stats.freeUsers,
          UserPlan.premium: stats.premiumUsers,
          UserPlan.enterprise: stats.enterpriseUsers,
        };
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans d\'abonnement'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final plan in UserPlan.values)
                      _PlanCard(plan: plan, count: _distribution[plan] ?? 0),
                  ],
                ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.count});
  final UserPlan plan;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(_iconForPlan(plan), color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.displayName, style: theme.textTheme.titleMedium),
                      Text(plan.tagline, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(label: Text('$count')),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}
