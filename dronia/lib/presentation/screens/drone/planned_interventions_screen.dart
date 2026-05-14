import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/intervention_model.dart';
import '../../../data/services/intervention_service.dart';

/// Screen to display planned interventions
class PlannedInterventionsScreen extends StatefulWidget {
  const PlannedInterventionsScreen({super.key});

  @override
  State<PlannedInterventionsScreen> createState() =>
      _PlannedInterventionsScreenState();
}

class _PlannedInterventionsScreenState
    extends State<PlannedInterventionsScreen> {
  final InterventionService _interventionService = InterventionService();
  List<Intervention> _interventions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInterventions();
  }

  Future<void> _loadInterventions() async {
    setState(() => _isLoading = true);
    // Load from backend first, fallback to local
    List<Intervention> interventions;
    try {
      interventions = await _interventionService.getInterventionsFromBackend();
      if (interventions.isEmpty) {
        // Fallback to local storage if backend is empty
        interventions = await _interventionService.getInterventions();
      }
    } catch (e) {
      interventions = await _interventionService.getInterventions();
    }
    // Sort by scheduled date (upcoming first)
    interventions.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    setState(() {
      _interventions = interventions;
      _isLoading = false;
    });
  }

  Future<void> _deleteIntervention(Intervention intervention) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer l\'intervention?',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Voulez-vous supprimer l\'intervention pour "${intervention.detectionLabel}"?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _interventionService.deleteIntervention(intervention.id);
      _loadInterventions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Intervention supprimée'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(
    Intervention intervention,
    InterventionStatus status,
  ) async {
    await _interventionService.updateInterventionStatus(
      intervention.id,
      status,
    );
    _loadInterventions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour: ${status.displayName}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Interventions Planifiées',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_interventions.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh, color: context.colors.textSecondary),
              onPressed: _loadInterventions,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _interventions.isEmpty
          ? _buildEmptyState()
          : _buildInterventionsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: context.colors.textSecondary,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Aucune intervention planifiée',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les interventions planifiées depuis les détections apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionsList() {
    // Group by status
    final pending = _interventions
        .where((i) => i.status == InterventionStatus.pending)
        .toList();
    final inProgress = _interventions
        .where((i) => i.status == InterventionStatus.inProgress)
        .toList();
    final completed = _interventions
        .where((i) => i.status == InterventionStatus.completed)
        .toList();
    final cancelled = _interventions
        .where((i) => i.status == InterventionStatus.cancelled)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadInterventions,
      color: AppColors.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          _buildSummaryCard(),
          SizedBox(height: 16),

          // Pending
          if (pending.isNotEmpty) ...[
            _buildSectionHeader(
              'En attente',
              pending.length,
              AppColors.warning,
            ),
            SizedBox(height: 8),
            ...pending.map((i) => _buildInterventionCard(i)),
            SizedBox(height: 16),
          ],

          // In Progress
          if (inProgress.isNotEmpty) ...[
            _buildSectionHeader('En cours', inProgress.length, AppColors.info),
            SizedBox(height: 8),
            ...inProgress.map((i) => _buildInterventionCard(i)),
            SizedBox(height: 16),
          ],

          // Completed
          if (completed.isNotEmpty) ...[
            _buildSectionHeader(
              'Terminées',
              completed.length,
              AppColors.primaryGreen,
            ),
            SizedBox(height: 8),
            ...completed.map((i) => _buildInterventionCard(i)),
            SizedBox(height: 16),
          ],

          // Cancelled
          if (cancelled.isNotEmpty) ...[
            _buildSectionHeader(
              'Annulées',
              cancelled.length,
              context.colors.textSecondary,
            ),
            SizedBox(height: 8),
            ...cancelled.map((i) => _buildInterventionCard(i)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final pending = _interventions
        .where((i) => i.status == InterventionStatus.pending)
        .length;
    final completed = _interventions
        .where((i) => i.status == InterventionStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('$pending', 'En attente', AppColors.warning),
          _buildStatItem('$completed', 'Terminées', AppColors.primaryGreen),
          _buildStatItem('${_interventions.length}', 'Total', AppColors.info),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterventionCard(Intervention intervention) {
    final isOverdue =
        intervention.status == InterventionStatus.pending &&
        intervention.scheduledDate.isBefore(DateTime.now());

    Color statusColor;
    switch (intervention.status) {
      case InterventionStatus.pending:
        statusColor = isOverdue ? AppColors.error : AppColors.warning;
        break;
      case InterventionStatus.inProgress:
        statusColor = AppColors.info;
        break;
      case InterventionStatus.completed:
        statusColor = AppColors.primaryGreen;
        break;
      case InterventionStatus.cancelled:
        statusColor = context.colors.textSecondary;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppColors.error.withOpacity(0.5)
              : context.colors.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showInterventionDetails(intervention),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getInterventionIcon(intervention.interventionType),
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intervention.interventionType,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            intervention.detectionLabel,
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOverdue
                            ? 'En retard'
                            : intervention.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Date and time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: context.colors.textSecondary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${intervention.scheduledDate.day.toString().padLeft(2, '0')}/${intervention.scheduledDate.month.toString().padLeft(2, '0')}/${intervention.scheduledDate.year}',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      color: context.colors.textSecondary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      intervention.scheduledTime,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(
                      Icons.location_on_outlined,
                      color: context.colors.textSecondary,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        intervention.zone,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Notes preview if any
                if (intervention.notes != null &&
                    intervention.notes!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    intervention.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getInterventionIcon(String type) {
    switch (type) {
      case 'Traitement phytosanitaire':
        return Icons.science;
      case 'Inspection manuelle':
        return Icons.search;
      case 'Irrigation ciblée':
        return Icons.water_drop;
      case 'Prélèvement échantillon':
        return Icons.biotech;
      case 'Application engrais':
        return Icons.eco;
      default:
        return Icons.assignment;
    }
  }

  void _showInterventionDetails(Intervention intervention) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getInterventionIcon(intervention.interventionType),
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intervention.interventionType,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              intervention.status.displayName,
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Detection info
                _buildDetailRow(
                  Icons.bug_report,
                  'Détection',
                  '${intervention.detectionLabel} (${(intervention.detectionConfidence * 100).toStringAsFixed(0)}%)',
                ),
                SizedBox(height: 12),

                // Date
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  '${intervention.scheduledDate.day.toString().padLeft(2, '0')}/${intervention.scheduledDate.month.toString().padLeft(2, '0')}/${intervention.scheduledDate.year}',
                ),
                SizedBox(height: 12),

                // Time
                _buildDetailRow(
                  Icons.access_time,
                  'Heure',
                  intervention.scheduledTime,
                ),
                SizedBox(height: 12),

                // Zone
                _buildDetailRow(Icons.location_on, 'Zone', intervention.zone),

                // Notes
                if (intervention.notes != null &&
                    intervention.notes!.isNotEmpty) ...[
                  SizedBox(height: 12),
                  _buildDetailRow(Icons.notes, 'Notes', intervention.notes!),
                ],

                SizedBox(height: 24),

                // Action buttons
                if (intervention.status == InterventionStatus.pending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(
                              intervention,
                              InterventionStatus.cancelled,
                            );
                          },
                          icon: Icon(Icons.cancel, size: 18),
                          label: Text('Annuler'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(
                              intervention,
                              InterventionStatus.inProgress,
                            );
                          },
                          icon: Icon(Icons.play_arrow, size: 18),
                          label: Text('Démarrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (intervention.status ==
                    InterventionStatus.inProgress) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateStatus(
                          intervention,
                          InterventionStatus.completed,
                        );
                      },
                      icon: Icon(Icons.check, size: 18),
                      label: Text('Marquer comme terminée'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 10),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteIntervention(intervention);
                    },
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('Supprimer'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.textSecondary, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
