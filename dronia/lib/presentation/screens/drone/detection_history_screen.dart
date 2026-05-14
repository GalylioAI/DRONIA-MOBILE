import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/detection_model.dart';
import '../../../data/services/detection_service.dart';

/// Screen displaying the history of all crop disease detections
class DetectionHistoryScreen extends StatefulWidget {
  /// Optional detection ID to open details popup automatically
  final String? openDetectionId;

  const DetectionHistoryScreen({super.key, this.openDetectionId});

  @override
  State<DetectionHistoryScreen> createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  final DetectionService _detectionService = DetectionService();
  List<Detection> _detections = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, disease, stress
  String? _pendingDetectionId;

  @override
  void initState() {
    super.initState();
    _pendingDetectionId = widget.openDetectionId;
    _loadDetections();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we received arguments through navigation
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['openDetectionId'] != null) {
      _pendingDetectionId = args['openDetectionId'] as String;
      // Reload to open the detection
      if (!_isLoading && _detections.isNotEmpty) {
        _openPendingDetection();
      }
    }
  }

  Future<void> _loadDetections() async {
    setState(() => _isLoading = true);

    final detections = await _detectionService.getDetectionHistory();

    setState(() {
      _detections = detections;
      _isLoading = false;
    });

    // Open pending detection after loading
    _openPendingDetection();
  }

  void _openPendingDetection() {
    if (_pendingDetectionId != null && _detections.isNotEmpty) {
      // Find the detection by ID
      final detection = _detections.firstWhere(
        (d) => d.id == _pendingDetectionId,
        orElse: () => _detections.first,
      );

      // Clear the pending ID
      final detectionToOpen = detection;
      _pendingDetectionId = null;

      // Open the details popup after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDetectionDetails(detectionToOpen);
      });
    }
  }

  List<Detection> get _filteredDetections {
    if (_filterType == 'all') return _detections;
    if (_filterType == 'disease') {
      return _detections.where((d) => d.type == DetectionType.disease).toList();
    }
    if (_filterType == 'stress') {
      return _detections.where((d) => d.type == DetectionType.stress).toList();
    }
    return _detections;
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Effacer l\'historique?',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Cette action supprimera toutes les détections enregistrées. Cette action est irréversible.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _detectionService.clearHistory();
      _loadDetections();
    }
  }

  Future<void> _deleteDetection(String id) async {
    await _detectionService.deleteDetection(id);
    _loadDetections();
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
        title: Text(
          'Historique Détections',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_detections.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          _buildStats(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _filteredDetections.isEmpty
                ? _buildEmptyState()
                : _buildDetectionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterChip('Tous', 'all'),
          SizedBox(width: 8),
          _buildFilterChip('Maladies', 'disease'),
          SizedBox(width: 8),
          _buildFilterChip('Stress', 'stress'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    final Color color;

    switch (value) {
      case 'disease':
        color = AppColors.error;
        break;
      case 'stress':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.primaryGreen;
    }

    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : context.colors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : context.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final diseaseCount = _detections
        .where((d) => d.type == DetectionType.disease)
        .length;
    final stressCount = _detections
        .where((d) => d.type == DetectionType.stress)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_detections.length}', 'Total', AppColors.info),
          _buildStatItem('$diseaseCount', 'Maladies', AppColors.error),
          _buildStatItem('$stressCount', 'Stress', AppColors.warning),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: context.colors.textSecondary.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Aucune détection',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _filterType == 'all'
                ? 'Les détections apparaîtront ici'
                : 'Aucune détection de ce type',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionsList() {
    // Group detections by date
    final groupedDetections = <String, List<Detection>>{};

    for (final detection in _filteredDetections) {
      final dateKey = DateFormat(
        'dd MMMM yyyy',
        'fr_FR',
      ).format(detection.timestamp);
      groupedDetections.putIfAbsent(dateKey, () => []).add(detection);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedDetections.length,
      itemBuilder: (context, index) {
        final date = groupedDetections.keys.elementAt(index);
        final detections = groupedDetections[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                date,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...detections.map((detection) => _buildDetectionCard(detection)),
          ],
        );
      },
    );
  }

  Widget _buildDetectionCard(Detection detection) {
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : detection.type == DetectionType.stress
        ? AppColors.warning
        : AppColors.primaryGreen;

    final icon = detection.type == DetectionType.disease
        ? Icons.bug_report
        : detection.type == DetectionType.stress
        ? Icons.warning_amber
        : Icons.check_circle;

    final typeLabel = detection.type == DetectionType.disease
        ? 'Maladie'
        : detection.type == DetectionType.stress
        ? 'Stress'
        : 'Sain';

    return Dismissible(
      key: Key(detection.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteDetection(detection.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            detection.label,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        detection.zone,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(detection.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm:ss').format(detection.timestamp),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to map location
                    },
                    icon: Icon(Icons.map, size: 16),
                    label: Text('Localiser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showDetectionDetails(detection);
                    },
                    icon: Icon(Icons.info_outline, size: 16),
                    label: Text('Détails'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      side: BorderSide(color: context.colors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetectionDetails(Detection detection) {
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : detection.type == DetectionType.stress
        ? AppColors.warning
        : AppColors.primaryGreen;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  detection.label,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.colors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Type', detection.type.displayName, color),
            _buildDetailRow(
              'Confiance',
              '${(detection.confidence * 100).toStringAsFixed(1)}%',
              color,
            ),
            _buildDetailRow('Zone', detection.zone, AppColors.info),
            _buildDetailRow(
              'Date',
              DateFormat('dd/MM/yyyy à HH:mm:ss').format(detection.timestamp),
              context.colors.textSecondary,
            ),
            _buildDetailRow('ID', detection.id, context.colors.textSecondary),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to map
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('Voir sur la carte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
