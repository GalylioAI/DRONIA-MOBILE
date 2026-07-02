import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/services/service_locator.dart';

/// User-facing screen that lets an agriculteur pick a subscription plan.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _saving = false;
  UserPlan _selected = UserPlan.free;

  @override
  void initState() {
    super.initState();
    _selected = services.auth.currentUser?.plan ?? UserPlan.free;
  }

  Future<void> _confirm(UserPlan plan) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _selected = plan;
    });
    try {
      await services.auth.updateMyPlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan ${plan.displayName} activé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans d\'abonnement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Choisissez le plan qui correspond à votre exploitation.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final plan in UserPlan.values)
            _PlanCard(
              plan: plan,
              isCurrent: _selected == plan,
              loading: _saving && _selected == plan,
              onSelect: () => _confirm(plan),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.loading,
    required this.onSelect,
  });
  final UserPlan plan;
  final bool isCurrent;
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent ? theme.colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
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
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Actif',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading || isCurrent ? null : onSelect,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isCurrent ? 'Plan actif' : 'Choisir ce plan'),
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
