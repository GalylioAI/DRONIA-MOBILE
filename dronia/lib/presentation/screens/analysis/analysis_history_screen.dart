import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/analysis_history_service.dart';

/// Analysis history screen - mobile responsive with cards
class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  String _searchQuery = '';
  String _statusFilter = 'Tous';
  String _cultureFilter = 'Toutes';
  final List<String> _statusOptions = ['Tous', 'Sain', 'Maladie', 'Stress'];
  final List<String> _cultureOptions = [
    'Toutes',
    'Tomate',
    'Vigne',
    'Blé',
    'Maïs',
    'Olivier',
    'P. de terre',
    'Carotte',
    'Salade',
    'Autre',
  ];

  final AnalysisHistoryService _historyService = AnalysisHistoryService();
  List<SavedAnalysis> _analyses = [];
  AnalysisStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // Clear old local data to ensure we only use backend
    await _historyService.clearLocalAnalyses();
    await _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() => _isLoading = true);
    try {
      final status = _statusFilter == 'Tous' ? null : _statusFilter;
      final cropType = _cultureFilter == 'Toutes' ? null : _cultureFilter;

      final analyses = await _historyService.getAnalyses(
        status: status,
        cropType: cropType,
      );
      final stats = await _historyService.getStats();

      if (mounted) {
        setState(() {
          _analyses = analyses;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAnalysis(String analysisId) async {
    await _historyService.deleteAnalysis(analysisId);
    _loadAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAnalyses,
                color: AppColors.primaryGreen,
                backgroundColor: AppColors.cardDark,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      _buildAnalysisList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAllAnalyses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text(
          'Supprimer tout?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Cela supprimera TOUTES vos analyses de l\'historique. Cette action est irréversible.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _historyService.deleteAllAnalyses();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les analyses ont été supprimées'),
          ),
        );
        _loadAnalyses();
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(bottom: BorderSide(color: AppColors.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historique',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Vos analyses de cultures',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_analyses.isNotEmpty)
            IconButton(
              onPressed: _deleteAllAnalyses,
              icon: const Icon(Icons.delete_sweep, color: AppColors.error),
              tooltip: 'Supprimer tout',
            ),
          IconButton(
            onPressed: _loadAnalyses,
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _stats?.total ?? _analyses.length;
    final saines =
        _stats?.healthy ??
        _analyses.where((a) => a.healthStatus == 'Sain').length;
    final maladies =
        _stats?.disease ??
        _analyses.where((a) => a.healthStatus == 'Maladie').length;
    final stress =
        _stats?.stress ??
        _analyses.where((a) => a.healthStatus == 'Stress').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatChip('$total', 'Total', AppColors.primaryGreen),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('$saines', 'Saines', AppColors.success)),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip('$maladies', 'Maladies', AppColors.error),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('$stress', 'Stress', AppColors.warning)),
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              hintStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.backgroundDark,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(_statusFilter, _statusOptions, (v) {
                  setState(() => _statusFilter = v!);
                  _loadAnalyses();
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(_cultureFilter, _cultureOptions, (v) {
                  setState(() => _cultureFilter = v!);
                  _loadAnalyses();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.cardDark,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
            size: 18,
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAnalysisList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // Local filtering by search query (status/culture already filtered by API)
    final filteredAnalyses = _analyses.where((a) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return a.id.toLowerCase().contains(query) ||
            a.cropType.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    if (filteredAnalyses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucune analyse trouvée',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadAnalyses,
              icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
              label: const Text(
                'Actualiser',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAnalyses,
      color: AppColors.primaryGreen,
      child: Column(
        children: filteredAnalyses.map((a) => _buildAnalysisCard(a)).toList(),
      ),
    );
  }

  Widget _buildAnalysisCard(SavedAnalysis analysis) {
    Color statusColor;
    switch (analysis.healthStatus) {
      case 'Sain':
        statusColor = AppColors.success;
        break;
      case 'Maladie':
        statusColor = AppColors.error;
        break;
      case 'Stress':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    final dateFormatter = DateFormat('dd/MM/yyyy');
    final dateStr = dateFormatter.format(analysis.createdAt);
    final confidence = analysis.healthScore.toInt();

    return Dismissible(
      key: Key(analysis.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text(
              'Supprimer cette analyse ?',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'Cette action est irréversible.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteAnalysis(analysis.id),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.analysisDetail,
            arguments: analysis,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _getCultureEmoji(analysis.cropType),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                analysis.cropType,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    analysis.healthStatus,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${analysis.id.substring(0, 12)}... • $dateStr',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    color: AppColors.cardDark,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteAnalysis(analysis.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: AppColors.error,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Score de santé',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$confidence%',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: confidence / 100,
                            backgroundColor: AppColors.backgroundDark,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      analysis.analysisMode.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCultureEmoji(String culture) {
    switch (culture) {
      case 'Tomate':
        return '🍅';
      case 'Vigne':
        return '🍇';
      case 'Blé':
        return '🌾';
      case 'Maïs':
        return '🌽';
      case 'Olivier':
        return '🫒';
      case 'P. de terre':
        return '🥔';
      case 'Carotte':
        return '🥕';
      case 'Salade':
        return '🥬';
      default:
        return '🌱';
    }
  }
}
