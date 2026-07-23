import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/services/service_locator.dart';

/// Détail admin d'un utilisateur : profil + ses analyses + ses parcelles.
class AdminUserDetailScreen extends StatefulWidget {
  final User user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _analyses = const [];
  List<Map<String, dynamic>> _regions = const [];
  double _totalHectares = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analyses = await services.admin.getUserAnalyses(widget.user.id);
      final regionsData = await services.admin.getUserRegions(widget.user.id);
      if (!mounted) return;
      setState(() {
        _analyses = analyses;
        _regions = regionsData.regions;
        _totalHectares = regionsData.totalHectares;
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
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: Text(u.fullName.trim().isEmpty ? u.email : u.fullName),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
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
                        FilledButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProfileCard(u),
                      const SizedBox(height: 16),
                      _buildCounters(),
                      const SizedBox(height: 16),
                      _sectionTitle('Analyses (${_analyses.length})', Icons.science_rounded),
                      const SizedBox(height: 8),
                      if (_analyses.isEmpty)
                        _emptyTile('Aucune analyse pour cet utilisateur')
                      else
                        ..._analyses.map(_buildAnalysisTile),
                      const SizedBox(height: 16),
                      _sectionTitle('Parcelles (${_regions.length})', Icons.map_rounded),
                      const SizedBox(height: 8),
                      if (_regions.isEmpty)
                        _emptyTile('Aucune parcelle pour cet utilisateur')
                      else
                        ..._regions.map(_buildRegionTile),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileCard(User u) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 28, child: Text(u.initials)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.fullName.trim().isEmpty ? '(sans nom)' : u.fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(u.email, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(u.role.displayName),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(u.plan.displayName),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounters() {
    return Row(
      children: [
        Expanded(
          child: _counterCard(
            Icons.science_rounded,
            '${_analyses.length}',
            'Analyses',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _counterCard(
            Icons.map_rounded,
            '${_regions.length}',
            'Parcelles',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _counterCard(
            Icons.landscape_rounded,
            _totalHectares.toStringAsFixed(1),
            'Hectares',
          ),
        ),
      ],
    );
  }

  Widget _counterCard(IconData icon, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _emptyTile(String text) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inbox_outlined),
        title: Text(text),
      ),
    );
  }

  Widget _buildAnalysisTile(Map<String, dynamic> a) {
    final crop = (a['cropType'] ?? '').toString();
    final disease = (a['disease'] ?? '—').toString();
    final status = (a['healthStatus'] ?? '').toString();
    final conf = a['confidence'];
    final confPct = conf is num
        ? (conf <= 1 ? (conf * 100).round() : conf.round())
        : null;
    final healthy = status.toLowerCase().contains('sain');
    return Card(
      child: ListTile(
        leading: Icon(
          healthy ? Icons.check_circle : Icons.coronavirus_rounded,
          color: healthy ? Colors.green : Colors.redAccent,
        ),
        title: Text(disease),
        subtitle: Text(
          [
            if (crop.isNotEmpty) crop,
            if (status.isNotEmpty) status,
            _formatDate(a['createdAt']),
          ].where((e) => e.isNotEmpty).join(' · '),
        ),
        trailing: confPct != null ? Text('$confPct%') : null,
      ),
    );
  }

  Widget _buildRegionTile(Map<String, dynamic> r) {
    final name = (r['name'] ?? 'Parcelle').toString();
    final ha = r['hectares'];
    final crop = (r['cropType'] ?? '').toString();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.terrain_rounded),
        title: Text(name),
        subtitle: Text(
          [
            if (crop.isNotEmpty) crop,
            _formatDate(r['createdAt']),
          ].where((e) => e.isNotEmpty).join(' · '),
        ),
        trailing: ha != null ? Text('${(ha as num).toStringAsFixed(2)} ha') : null,
      ),
    );
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
