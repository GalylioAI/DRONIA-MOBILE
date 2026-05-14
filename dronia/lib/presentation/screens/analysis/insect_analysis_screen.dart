import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/network/api_client.dart';
import '../../../data/services/storage_service.dart';

/// Insect Analysis Screen - Detection and identification of insects with bounding boxes
class InsectAnalysisScreen extends StatefulWidget {
  const InsectAnalysisScreen({super.key});

  @override
  State<InsectAnalysisScreen> createState() => _InsectAnalysisScreenState();
}

class _InsectAnalysisScreenState extends State<InsectAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _api = ApiClient(storage: StorageService());

  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isLoadingHistory = false;
  Map<String, dynamic>? _analysisResult;

  // Stats from backend
  int _totalAnalyses = 0;
  int _analysesWithInsects = 0;
  int _totalInsectsDetected = 0;

  // History data
  List<Map<String, dynamic>> _allAnalyses = [];
  List<Map<String, dynamic>> _analysesWithInsectsList = [];
  List<Map<String, dynamic>> _topInsects = [];

  // Helper to normalize strings for comparison (remove accents, lowercase)
  String _normalizeString(String s) {
    return s
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ç', 'c')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _loadStatsFromBackend();
  }

  Future<void> _loadStatsFromBackend() async {
    setState(() => _isLoadingHistory = true);
    try {
      // Load stats
      final statsResponse = await _api.get('/analyses/insects/stats');
      if (statsResponse['success'] == true && statsResponse['stats'] != null) {
        final stats = statsResponse['stats'];
        setState(() {
          _totalAnalyses = stats['totalAnalyses'] ?? 0;
          _analysesWithInsects = stats['analysesWithInsects'] ?? 0;
          _totalInsectsDetected = stats['totalInsectsDetected'] ?? 0;
          _topInsects = List<Map<String, dynamic>>.from(
            stats['topInsects'] ?? [],
          );
        });
        debugPrint(
          '📊 Stats loaded: $_totalAnalyses analyses, top insects: $_topInsects',
        );
      }

      // Load all analyses history
      final historyResponse = await _api.get(
        '/analyses/insects',
        queryParams: {'limit': 50},
      );
      debugPrint(
        '📋 History response: ${historyResponse['success']}, count: ${(historyResponse['analyses'] as List?)?.length ?? 0}',
      );

      if (historyResponse['success'] == true &&
          historyResponse['analyses'] != null) {
        final analysesList = List<Map<String, dynamic>>.from(
          historyResponse['analyses'],
        );
        debugPrint('📋 Parsed ${analysesList.length} analyses');

        // Debug: print each analysis hasInsects status
        for (var a in analysesList) {
          debugPrint(
            '   Analysis hasInsects: ${a['hasInsects']} (${a['hasInsects'].runtimeType}), totalCount: ${a['totalCount']}',
          );
        }

        setState(() {
          _allAnalyses = analysesList;
          _analysesWithInsectsList = analysesList
              .where(
                (a) =>
                    a['hasInsects'] == true ||
                    a['hasInsects'] == 'true' ||
                    (a['totalCount'] ?? 0) > 0 ||
                    ((a['detections'] as List?)?.isNotEmpty ?? false),
              )
              .toList();
        });
        debugPrint(
          '📋 Analyses with insects: ${_analysesWithInsectsList.length}',
        );
        if (_allAnalyses.isNotEmpty) {
          debugPrint(
            '   First analysis detections: ${_allAnalyses.first['detections']}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveAnalysisToBackend(Map<String, dynamic> result) async {
    try {
      final detections = result['detections'] as List? ?? [];
      final hasInsects = detections.isNotEmpty;

      // Convert image to base64 for storage
      String? imageBase64;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      // Build detections list for storage
      final formattedDetections = detections
          .map(
            (d) => {
              'className': d['class'] ?? '',
              'confidence': d['confidence'] ?? 0.0,
              'bbox': d['bbox'],
              'dangerLevel': d['danger_level'],
              'impact': d['impact'],
              'treatment': d['treatment'],
              'prevention': d['prevention'],
            },
          )
          .toList();

      final body = {
        'imageBase64': imageBase64,
        'detections': formattedDetections,
        'totalCount': result['total_count'] ?? detections.length,
        'dangerLevel': result['danger_level'] ?? 'Aucun',
        'hasInsects': hasInsects,
      };

      await _api.post('/analyses/insects', body: body);

      // Add to local lists immediately for instant UI update
      final localAnalysis = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'imageBase64': imageBase64,
        'detections': formattedDetections,
        'totalCount': result['total_count'] ?? detections.length,
        'dangerLevel': result['danger_level'] ?? 'Aucun',
        'hasInsects': hasInsects,
        'createdAt': DateTime.now().toIso8601String(),
      };

      setState(() {
        _allAnalyses.insert(0, localAnalysis);
        if (hasInsects) {
          _analysesWithInsectsList.insert(0, localAnalysis);
          _totalAnalyses++;
          _analysesWithInsects++;
          _totalInsectsDetected += detections.length;

          // Update top insects
          for (var d in formattedDetections) {
            final className = d['className'] as String? ?? '';
            if (className.isNotEmpty) {
              final existingIndex = _topInsects.indexWhere(
                (i) => i['name'] == className,
              );
              if (existingIndex >= 0) {
                _topInsects[existingIndex]['count'] =
                    (_topInsects[existingIndex]['count'] ?? 0) + 1;
              } else {
                _topInsects.add({'name': className, 'count': 1});
              }
            }
          }
        }
      });

      // Also reload from backend to ensure sync
      _loadStatsFromBackend();
    } catch (e) {
      debugPrint('Error saving analysis: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _analysisResult = null;
        });
        _analyzeImage();
      }
    } catch (e) {
      _showErrorSnackbar('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/analyze/insects');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          _analysisResult = result;
        });
        // Save to backend
        await _saveAnalysisToBackend(result);
      } else {
        _showErrorSnackbar('Erreur lors de l\'analyse');
      }
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      _showMockResult();
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showMockResult() {
    setState(() {
      _analysisResult = {
        'success': true,
        'detections': [],
        'total_count': 0,
        'danger_level': 'Aucun',
        'message': 'Aucun ravageur détecté - Culture saine',
        'model': 'YOLO11s Pest Detection',
        'dataset': 'IP102 (102 espèces)',
      };
      _totalAnalyses++;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              SizedBox(height: 20),

              // Stats Cards Row
              _buildStatsCards(),
              SizedBox(height: 20),

              // Main Content - Upload Card
              _buildUploadCard(),
              SizedBox(height: 16),

              // Results (if available)
              if (_analysisResult != null) ...[
                _buildResultsCard(),
                SizedBox(height: 16),
              ],

              // Model Info Card
              _buildModelInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: 0.2),
                    AppColors.warning.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.pest_control,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Analyse des ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'Insectes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Détection IA avec YOLO11s • 102 espèces',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'ANALYSES',
            value: _isLoadingHistory ? '...' : _totalAnalyses.toString(),
            icon: Icons.search,
            iconColor: AppColors.info,
            onTap: () => _showAllAnalysesHistory(),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'AVEC INSECTES',
            value: _isLoadingHistory ? '...' : _analysesWithInsects.toString(),
            icon: Icons.bug_report,
            iconColor: AppColors.warning,
            onTap: () => _showAnalysesWithInsectsHistory(),
          ),
        ),
      ],
    );
  }

  void _showAllAnalysesHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StatefulHistoryBottomSheet(
        api: _api,
        title: 'Historique des Analyses',
        icon: Icons.search,
        iconColor: AppColors.info,
        emptyMessage: 'Aucune analyse effectuée',
        filterWithInsects: false,
        onDelete: (analysisId, analysis) =>
            _deleteAnalysis(analysisId, analysis),
        onTap: (analysis) => _showAnalysisDetailDialog(analysis),
      ),
    );
  }

  void _showAnalysesWithInsectsHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StatefulHistoryBottomSheet(
        api: _api,
        title: 'Analyses avec Insectes',
        icon: Icons.bug_report,
        iconColor: AppColors.warning,
        emptyMessage: 'Aucun insecte détecté',
        filterWithInsects: true,
        onDelete: (analysisId, analysis) =>
            _deleteAnalysis(analysisId, analysis),
        onTap: (analysis) => _showAnalysisDetailDialog(analysis),
      ),
    );
  }

  void _showDetectedInsectsHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTopInsectsBottomSheet(),
    );
  }

  void _showInsectAnalyses(String insectName) {
    // Debug: Print data to understand structure
    debugPrint('🔍 Looking for insect: $insectName');
    debugPrint('📊 All analyses: ${_allAnalyses.length}');
    debugPrint(
      '📊 Analyses with insects list: ${_analysesWithInsectsList.length}',
    );

    // Use all analyses if _analysesWithInsectsList is empty
    final analysesToSearch = _analysesWithInsectsList.isNotEmpty
        ? _analysesWithInsectsList
        : _allAnalyses;

    // Print all detections to debug
    for (var analysis in analysesToSearch) {
      debugPrint('   Analysis detections: ${analysis['detections']}');
    }

    // Filter analyses that contain this insect
    final searchName = insectName.toLowerCase().trim();
    List<Map<String, dynamic>> filteredAnalyses = [];

    for (var analysis in analysesToSearch) {
      final detections = analysis['detections'];
      if (detections == null || (detections is List && detections.isEmpty))
        continue;

      // Handle both List and other types
      final List<dynamic> detectionList = detections is List
          ? detections
          : [detections];

      bool found = false;
      for (var d in detectionList) {
        if (d is Map) {
          final className = (d['className'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          debugPrint('   Checking: "$className" vs "$searchName"');
          if (className == searchName ||
              className.contains(searchName) ||
              searchName.contains(className) ||
              _normalizeString(className) == _normalizeString(searchName)) {
            found = true;
            break;
          }
        }
      }
      if (found) {
        filteredAnalyses.add(analysis);
      }
    }

    debugPrint('✅ Found ${filteredAnalyses.length} matching analyses');

    // If no matches found, show all analyses with non-empty detections as fallback
    if (filteredAnalyses.isEmpty) {
      debugPrint('⚠️ No exact match, showing all analyses with detections');
      filteredAnalyses = _allAnalyses.where((a) {
        final detections = a['detections'];
        return detections != null &&
            detections is List &&
            detections.isNotEmpty;
      }).toList();
    }

    Navigator.pop(context); // Close the current bottom sheet

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.pest_control,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insectName,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filteredAnalyses.length} analyse(s) avec cet insecte',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: context.colors.divider, height: 1),
            // List
            Expanded(
              child: filteredAnalyses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: context.colors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aucune analyse trouvée',
                            style: TextStyle(
                              color: context.colors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredAnalyses.length,
                      itemBuilder: (context, index) {
                        final analysis = filteredAnalyses[index];
                        return _buildInsectAnalysisItem(analysis, insectName);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsectAnalysisItem(
    Map<String, dynamic> analysis,
    String highlightInsect,
  ) {
    final detections = analysis['detections'] as List? ?? [];
    final dangerLevel = analysis['dangerLevel'] ?? 'Aucun';
    final createdAt = analysis['createdAt'] != null
        ? DateTime.parse(analysis['createdAt'])
        : DateTime.now();
    final imageBase64 = analysis['imageBase64'] as String?;

    // Find the specific insect detection
    final targetDetection = detections.firstWhere(
      (d) => d['className'] == highlightInsect,
      orElse: () => {},
    );
    final confidence = targetDetection.isNotEmpty
        ? ((targetDetection['confidence'] ?? 0.0) * 100).toStringAsFixed(0)
        : '?';

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.success;
    }

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showAnalysisDetailDialog(analysis);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.colors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Thumbnail
            if (imageBase64 != null && imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Image.memory(
                  base64Decode(imageBase64),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: context.colors.card,
                    child: Icon(
                      Icons.image_not_supported,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.pest_control,
                  color: AppColors.warning.withValues(alpha: 0.5),
                  size: 32,
                ),
              ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy à HH:mm').format(createdAt),
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: dangerColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dangerLevel,
                            style: TextStyle(
                              color: dangerColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pest_control,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$confidence%',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryBottomSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Map<String, dynamic>> analyses,
    required String emptyMessage,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _loadStatsFromBackend();
                  },
                ),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          // List
          Expanded(
            child: analyses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: TextStyle(
                            color: context.colors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: analyses.length,
                    itemBuilder: (context, index) {
                      final analysis = analyses[index];
                      return _buildHistoryItem(analysis);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> analysis) {
    final detections = analysis['detections'] as List? ?? [];
    final dangerLevel = analysis['dangerLevel'] ?? 'Aucun';
    final hasInsects = analysis['hasInsects'] ?? false;
    final totalCount = analysis['totalCount'] ?? 0;
    final analysisId = analysis['id'] as String?;
    final createdAt = analysis['createdAt'] != null
        ? DateTime.parse(analysis['createdAt'])
        : DateTime.now();

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.success;
    }

    return Dismissible(
      key: Key(analysisId ?? createdAt.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: context.colors.card,
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: context.colors.textPrimary),
                ),
                content: Text(
                  'Voulez-vous supprimer cette analyse ?',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: Text('Supprimer'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) {
        _deleteAnalysis(analysisId, analysis);
      },
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          _showAnalysisDetailDialog(analysis);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.bg,
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
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasInsects
                      ? dangerColor.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasInsects ? Icons.bug_report : Icons.check_circle,
                  color: hasInsects ? dangerColor : AppColors.success,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasInsects
                          ? '$totalCount insecte(s) détecté(s)'
                          : 'Aucun insecte',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy à HH:mm').format(createdAt),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (hasInsects && detections.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: detections
                            .take(3)
                            .map(
                              (d) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  d['className'] ?? 'Inconnu',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (detections.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${detections.length - 3} autres',
                            style: TextStyle(
                              color: context.colors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              // Danger badge + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasInsects)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dangerLevel,
                        style: TextStyle(
                          color: dangerColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: context.colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAnalysis(
    String? analysisId,
    Map<String, dynamic> analysis,
  ) async {
    try {
      if (analysisId != null) {
        await _api.delete('/analyses/insects/$analysisId');
      }

      // Remove from local lists
      setState(() {
        _allAnalyses.removeWhere((a) => a['id'] == analysisId || a == analysis);
        _analysesWithInsectsList.removeWhere(
          (a) => a['id'] == analysisId || a == analysis,
        );
        _totalAnalyses = _allAnalyses.length;
        _analysesWithInsects = _analysesWithInsectsList.length;
      });

      // Reload stats from backend to ensure consistency
      _loadStatsFromBackend();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analyse supprimée'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildDetectionItemWithTap(dynamic d, Color dangerColor) {
    final className = d['className'] ?? 'Inconnu';
    final confidence = ((d['confidence'] ?? 0.0) * 100).toStringAsFixed(0);
    final detectionDangerLevel = d['dangerLevel'] as String?;
    final impact = d['impact'] as String?;

    return GestureDetector(
      onTap: () => _showDetectionInfoDialog(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pest_control,
                  size: 18,
                  color: dangerColor.withValues(alpha: 0.8),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    className,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$confidence%',
                    style: TextStyle(
                      color: dangerColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: context.colors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
            if (detectionDangerLevel != null || impact != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  if (detectionDangerLevel != null) ...[
                    Icon(Icons.warning_amber, size: 12, color: dangerColor),
                    SizedBox(width: 4),
                    Text(
                      'Danger: $detectionDangerLevel',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            SizedBox(height: 4),
            Text(
              'Appuyez pour voir les détails',
              style: TextStyle(
                color: AppColors.info.withValues(alpha: 0.7),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetectionInfoDialog(dynamic detection) {
    final className = detection['className'] ?? 'Insecte inconnu';
    final confidence = ((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(
      1,
    );
    final dangerLevel = detection['dangerLevel'] ?? 'Non défini';
    final impact = detection['impact'] as String?;
    final treatment = detection['treatment'] as String?;
    final prevention = detection['prevention'] as String?;

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.success;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.pest_control,
                        color: dangerColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Confiance: $confidence%',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: dangerColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dangerLevel,
                                  style: TextStyle(
                                    color: dangerColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: context.colors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(color: context.colors.divider),
                SizedBox(height: 16),

                // Impact
                if (impact != null && impact.isNotEmpty) ...[
                  _buildInfoSection(
                    icon: Icons.warning_amber,
                    color: AppColors.warning,
                    label: 'Impact',
                    value: impact,
                  ),
                  SizedBox(height: 16),
                ],

                // Treatment
                if (treatment != null && treatment.isNotEmpty) ...[
                  _buildInfoSection(
                    icon: Icons.medical_services,
                    color: AppColors.info,
                    label: 'Traitement recommandé',
                    value: treatment,
                  ),
                  SizedBox(height: 16),
                ],

                // Prevention
                if (prevention != null && prevention.isNotEmpty) ...[
                  _buildInfoSection(
                    icon: Icons.shield,
                    color: AppColors.success,
                    label: 'Prévention',
                    value: prevention,
                  ),
                ],

                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalysisDetailDialog(Map<String, dynamic> analysis) {
    final detections = analysis['detections'] as List? ?? [];
    final dangerLevel = analysis['dangerLevel'] ?? 'Aucun';
    final hasInsects = analysis['hasInsects'] ?? false;
    final totalCount = analysis['totalCount'] ?? 0;
    final createdAt = analysis['createdAt'] != null
        ? DateTime.parse(analysis['createdAt'])
        : DateTime.now();
    final imageBase64 = analysis['imageBase64'] as String?;

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.success;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: dangerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      hasInsects ? Icons.bug_report : Icons.check_circle,
                      color: dangerColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasInsects
                              ? '$totalCount insecte(s) détecté(s)'
                              : 'Analyse sans insecte',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMMM yyyy à HH:mm',
                            'fr_FR',
                          ).format(createdAt),
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dangerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dangerLevel,
                      style: TextStyle(
                        color: dangerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: context.colors.divider, height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image preview
                    if (imageBase64 != null && imageBase64.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.memory(
                              base64Decode(imageBase64),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: context.colors.bg,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: context.colors.textSecondary,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                            // Bounding boxes overlay
                            if (detections.isNotEmpty)
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return CustomPaint(
                                      painter: _BoundingBoxPainter(
                                        detections: detections
                                            .map(
                                              (d) => d as Map<String, dynamic>,
                                            )
                                            .toList(),
                                        imageWidth: constraints.maxWidth,
                                        imageHeight: constraints.maxHeight,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // Detections list
                    if (detections.isNotEmpty) ...[
                      Text(
                        'INSECTES DÉTECTÉS',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...detections.map(
                        (d) => _buildDetailedDetectionCard(d, dangerColor),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 32,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aucun insecte détecté',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Votre culture semble saine !',
                                    style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedDetectionCard(dynamic detection, Color baseColor) {
    final className = detection['className'] ?? 'Insecte inconnu';
    final confidence = ((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(
      1,
    );
    final dangerLevel = detection['dangerLevel'] ?? 'Non défini';
    final impact = detection['impact'] as String?;
    final treatment = detection['treatment'] as String?;
    final prevention = detection['prevention'] as String?;

    Color cardColor;
    switch (dangerLevel) {
      case 'Élevé':
        cardColor = AppColors.error;
        break;
      case 'Modéré':
        cardColor = AppColors.warning;
        break;
      default:
        cardColor = AppColors.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pest_control, color: cardColor, size: 20),
          ),
          title: Text(
            className,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                'Confiance: $confidence%',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dangerLevel,
                  style: TextStyle(
                    color: cardColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            if (impact != null && impact.isNotEmpty) ...[
              _buildInfoSection(
                icon: Icons.warning_amber,
                color: AppColors.warning,
                label: 'Impact',
                value: impact,
              ),
              SizedBox(height: 12),
            ],
            if (treatment != null && treatment.isNotEmpty) ...[
              _buildInfoSection(
                icon: Icons.medical_services,
                color: AppColors.info,
                label: 'Traitement',
                value: treatment,
              ),
              SizedBox(height: 12),
            ],
            if (prevention != null && prevention.isNotEmpty)
              _buildInfoSection(
                icon: Icons.shield,
                color: AppColors.success,
                label: 'Prévention',
                value: prevention,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInsectsBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.visibility,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insectes Détectés',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_totalInsectsDetected insectes au total',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          // Top insects list
          Expanded(
            child: _topInsects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pest_control_outlined,
                          size: 64,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun insecte détecté',
                          style: TextStyle(
                            color: context.colors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _topInsects.length,
                    itemBuilder: (context, index) {
                      final insect = _topInsects[index];
                      final name = insect['name'] ?? 'Inconnu';
                      final count = insect['count'] ?? 0;
                      final percentage = _totalInsectsDetected > 0
                          ? (count / _totalInsectsDetected * 100)
                          : 0.0;

                      return GestureDetector(
                        onTap: () => _showInsectAnalyses(name),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.bg,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$count fois',
                                    style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: context.colors.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: context.colors.divider,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.warning,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${percentage.toStringAsFixed(1)}% des détections',
                                    style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Voir les analyses →',
                                    style: TextStyle(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.divider)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.warning.withValues(alpha: 0.8),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Analyser une image',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectedImage != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _analysisResult = null;
                      });
                    },
                    icon: Icon(Icons.refresh, size: 20),
                    color: context.colors.textSecondary,
                    tooltip: 'Réinitialiser',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Upload Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isAnalyzing
                ? _buildAnalyzingState()
                : _selectedImage != null
                ? _buildImagePreview()
                : _buildUploadArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.divider,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Ajouter une image',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Appuyez pour prendre une photo ou choisir depuis la galerie',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionChip(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                SizedBox(width: 12),
                _ActionChip(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppColors.warning,
                  strokeWidth: 3,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              Icon(
                Icons.pest_control,
                color: AppColors.warning,
                size: 24,
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Analyse en cours...',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Détection des ravageurs avec YOLO11s',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedImage!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showImageSourceDialog,
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Changer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  side: BorderSide(color: context.colors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _analyzeImage,
                icon: Icon(Icons.search, size: 18),
                label: Text('Analyser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsCard() {
    final detections = _analysisResult?['detections'] as List? ?? [];
    final hasInsects = detections.isNotEmpty;
    final dangerLevel = _analysisResult?['danger_level'] ?? 'Aucun';
    final totalCount = _analysisResult?['total_count'] ?? 0;

    Color dangerColor;
    IconData dangerIcon;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        dangerIcon = Icons.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        dangerIcon = Icons.warning_amber;
        break;
      default:
        dangerColor = hasInsects ? AppColors.info : AppColors.success;
        dangerIcon = hasInsects ? Icons.info : Icons.check_circle;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dangerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result Header with danger level
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dangerColor.withValues(alpha: 0.15),
                  dangerColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(dangerIcon, color: dangerColor, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasInsects
                                ? '$totalCount ravageur(s) détecté(s)'
                                : 'Aucun ravageur détecté',
                            style: TextStyle(
                              color: dangerColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            hasInsects
                                ? 'Niveau de danger: $dangerLevel'
                                : 'Votre culture semble saine',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasInsects)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: dangerColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dangerLevel,
                          style: TextStyle(
                            color: dangerColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Image with bounding boxes preview
          if (_selectedImage != null && hasInsects) ...[
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.file(
                      _selectedImage!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    // Overlay bounding boxes
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return CustomPaint(
                            painter: _BoundingBoxPainter(
                              detections: detections
                                  .map((d) => d as Map<String, dynamic>)
                                  .toList(),
                              imageWidth: constraints.maxWidth,
                              imageHeight: constraints.maxHeight,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Detections List
          if (hasInsects)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'RAVAGEURS IDENTIFIÉS',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...detections
                      .map(
                        (d) => _buildDetectionTile(d as Map<String, dynamic>),
                      )
                      .toList(),
                ],
              ),
            ),

          // Healthy message
          if (!hasInsects)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.eco,
                          color: AppColors.success,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Culture saine',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Aucun ravageur n\'a été détecté dans cette image. Continuez à surveiller régulièrement vos cultures.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionTile(Map<String, dynamic> detection) {
    final className = detection['class'] ?? 'Inconnu';
    final confidence = ((detection['confidence'] ?? 0.0) * 100).toInt();
    final dangerLevel = detection['danger_level'] ?? 'Modéré';
    final impact = detection['impact'] ?? '';
    final treatment = detection['treatment'] ?? '';
    final prevention = detection['prevention'] ?? '';

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dangerColor.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: dangerColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.bug_report, color: dangerColor, size: 20),
        ),
        title: Text(
          className,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getConfidenceColor(confidence).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$confidence%',
                style: TextStyle(
                  color: _getConfidenceColor(confidence),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(width: 6),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: dangerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                dangerLevel,
                style: TextStyle(
                  color: dangerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        iconColor: context.colors.textSecondary,
        collapsedIconColor: context.colors.textSecondary,
        children: [
          // Impact
          if (impact.isNotEmpty)
            _buildInfoSection(
              icon: Icons.report_problem_outlined,
              label: 'Impact',
              value: impact,
              color: AppColors.error,
            ),
          // Treatment
          if (treatment.isNotEmpty)
            _buildInfoSection(
              icon: Icons.healing,
              label: 'Traitement',
              value: treatment,
              color: AppColors.success,
            ),
          // Prevention
          if (prevention.isNotEmpty)
            _buildInfoSection(
              icon: Icons.shield_outlined,
              label: 'Prévention',
              value: prevention,
              color: AppColors.info,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return AppColors.success;
    if (confidence >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildModelInfoCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.memory,
                  color: AppColors.info,
                  size: 18,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'À propos du modèle',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _InfoRow(
            icon: Icons.psychology,
            label: 'Modèle',
            value: 'YOLO11s Pest Detection',
          ),
          SizedBox(height: 10),
          _InfoRow(
            icon: Icons.category,
            label: 'Dataset',
            value: 'IP102 (102 espèces)',
          ),
          SizedBox(height: 10),
          _InfoRow(
            icon: Icons.speed,
            label: 'Précision',
            value: 'Confiance affichée par détection',
          ),
          SizedBox(height: 16),
          // Tips Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.warning.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Conseils',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Utilisez des images nettes et bien éclairées\n'
                  '• Centrez les insectes dans le cadre\n'
                  '• Évitez les images floues ou sombres',
                  style: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Sélectionner une image',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt,
                      label: 'Caméra',
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library,
                      label: 'Galerie',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable Components

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.warning, size: 18),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.colors.textHint, size: 16),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing bounding boxes on detected insects
class _BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double imageWidth;
  final double imageHeight;

  _BoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final bbox = detection['bbox'] as Map<String, dynamic>?;
      if (bbox == null) continue;

      final dangerLevel = detection['danger_level'] ?? 'Modéré';
      Color boxColor;
      switch (dangerLevel) {
        case 'Élevé':
          boxColor = Color(0xFFE53935); // Red
          break;
        case 'Modéré':
          boxColor = Color(0xFFFF9800); // Orange
          break;
        default:
          boxColor = Color(0xFF2196F3); // Blue
      }

      // Convert percentage to pixels
      final x1 = (bbox['x1'] as num).toDouble() / 100 * size.width;
      final y1 = (bbox['y1'] as num).toDouble() / 100 * size.height;
      final x2 = (bbox['x2'] as num).toDouble() / 100 * size.width;
      final y2 = (bbox['y2'] as num).toDouble() / 100 * size.height;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);

      // Draw box border
      final borderPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(rect, borderPaint);

      // Draw semi-transparent fill
      final fillPaint = Paint()
        ..color = boxColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Draw label background
      final className = detection['class'] ?? 'Insecte';
      final confidence = ((detection['confidence'] ?? 0.0) * 100).toInt();
      final labelText = '$className ($confidence%)';

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      );
      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      final labelWidth = textPainter.width + 8;
      final labelHeight = textPainter.height + 4;
      final labelRect = Rect.fromLTWH(
        x1,
        y1 - labelHeight > 0 ? y1 - labelHeight : y1,
        labelWidth,
        labelHeight,
      );

      final labelPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(labelRect, labelPaint);

      // Draw label text
      textPainter.paint(canvas, Offset(labelRect.left + 4, labelRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}

/// Stateful bottom sheet that loads history data when opened
class _StatefulHistoryBottomSheet extends StatefulWidget {
  final ApiClient api;
  final String title;
  final IconData icon;
  final Color iconColor;
  final String emptyMessage;
  final bool filterWithInsects;
  final Function(String?, Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onTap;

  const _StatefulHistoryBottomSheet({
    required this.api,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.emptyMessage,
    required this.filterWithInsects,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_StatefulHistoryBottomSheet> createState() =>
      _StatefulHistoryBottomSheetState();
}

class _StatefulHistoryBottomSheetState
    extends State<_StatefulHistoryBottomSheet> {
  List<Map<String, dynamic>> _analyses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.api.get(
        '/analyses/insects',
        queryParams: {'limit': 100},
      );

      debugPrint(
        '📋 History API response: success=${response['success']}, analyses count=${(response['analyses'] as List?)?.length ?? 0}',
      );

      if (response['success'] == true && response['analyses'] != null) {
        final List<Map<String, dynamic>> analysesList =
            List<Map<String, dynamic>>.from(response['analyses']);

        // Debug each analysis
        for (var a in analysesList) {
          debugPrint(
            '   Analysis: id=${a['id']}, hasInsects=${a['hasInsects']}, totalCount=${a['totalCount']}, detections=${(a['detections'] as List?)?.length ?? 0}',
          );
        }

        setState(() {
          if (widget.filterWithInsects) {
            _analyses = analysesList
                .where(
                  (a) =>
                      a['hasInsects'] == true ||
                      (a['totalCount'] ?? 0) > 0 ||
                      ((a['detections'] as List?)?.isNotEmpty ?? false),
                )
                .toList();
          } else {
            _analyses = analysesList;
          }
          _isLoading = false;
        });

        debugPrint('📋 Filtered analyses: ${_analyses.length}');
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Impossible de charger l\'historique';
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading history: $e');
      setState(() {
        _isLoading = false;
        _error = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoading
                            ? 'Chargement...'
                            : '${_analyses.length} analyse(s)',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          // List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error.withValues(alpha: 0.7),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: context.colors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        TextButton(
                          onPressed: _loadData,
                          child: Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _analyses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.emptyMessage,
                          style: TextStyle(
                            color: context.colors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _analyses.length,
                    itemBuilder: (context, index) {
                      final analysis = _analyses[index];
                      return _buildHistoryItemInSheet(analysis);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItemInSheet(Map<String, dynamic> analysis) {
    final detections = analysis['detections'] as List? ?? [];
    final dangerLevel = analysis['dangerLevel'] ?? 'Aucun';
    final hasInsects = analysis['hasInsects'] ?? false;
    final totalCount = analysis['totalCount'] ?? 0;
    final analysisId = analysis['id'] as String?;
    final createdAt = analysis['createdAt'] != null
        ? DateTime.parse(analysis['createdAt'])
        : DateTime.now();

    Color dangerColor;
    switch (dangerLevel) {
      case 'Élevé':
        dangerColor = AppColors.error;
        break;
      case 'Modéré':
        dangerColor = AppColors.warning;
        break;
      default:
        dangerColor = AppColors.success;
    }

    return Dismissible(
      key: Key(analysisId ?? createdAt.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: context.colors.card,
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: context.colors.textPrimary),
                ),
                content: Text(
                  'Voulez-vous supprimer cette analyse ?',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: Text('Supprimer'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) async {
        // Remove from local list
        setState(() {
          _analyses.removeWhere((a) => a['id'] == analysisId || a == analysis);
        });
        // Call parent delete function
        widget.onDelete(analysisId, analysis);
      },
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          widget.onTap(analysis);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.divider.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // Thumbnail or icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: analysis['imageBase64'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          base64Decode(analysis['imageBase64']),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.bug_report,
                            color: dangerColor,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(Icons.bug_report, color: dangerColor, size: 24),
              ),
              SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasInsects || totalCount > 0 || detections.isNotEmpty
                          ? '${totalCount > 0 ? totalCount : detections.length} insecte(s) détecté(s)'
                          : 'Aucun insecte détecté',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy à HH:mm').format(createdAt),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (detections.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        detections
                                .take(2)
                                .map((d) => d['className'] ?? '')
                                .join(', ') +
                            (detections.length > 2 ? '...' : ''),
                        style: TextStyle(
                          color: context.colors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Danger badge & arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dangerLevel != 'Aucun')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dangerLevel,
                        style: TextStyle(
                          color: dangerColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: context.colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
