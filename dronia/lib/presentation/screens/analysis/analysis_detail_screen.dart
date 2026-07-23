import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/analysis_history_service.dart';

/// Detailed analysis view screen - displays full analysis report
class AnalysisDetailScreen extends StatefulWidget {
  final SavedAnalysis analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  bool _isGeneratingPdf = false;

  SavedAnalysis get analysis => widget.analysis;

  bool get isHealthy => analysis.healthStatus == 'Sain';

  String get _formattedDate {
    final formatter = DateFormat('dd MMM, yyyy, HH:mm', 'fr_FR');
    return formatter.format(analysis.createdAt);
  }

  String get _diseaseName {
    if (isHealthy) return 'Aucune';
    if (analysis.results.isNotEmpty) {
      return analysis.results.first.diseaseNameFr ??
          analysis.results.first.diseaseName ??
          analysis.results.first.className;
    }
    return 'Non identifiée';
  }

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();

      // Try to load image
      pw.ImageProvider? imageProvider;
      if (analysis.imageBase64 != null && analysis.imageBase64!.isNotEmpty) {
        try {
          final bytes = base64Decode(analysis.imageBase64!);
          imageProvider = pw.MemoryImage(bytes);
        } catch (e) {
          // Ignore image errors
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DronIA - Rapport d\'Analyse',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _formattedDate,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Analysis info
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Parcelle: ${analysis.region ?? analysis.cropType}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Text('Statut: '),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: isHealthy
                              ? PdfColors.green100
                              : PdfColors.red100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          isHealthy ? 'Parcelle Saine' : 'Maladie Détectée',
                          style: pw.TextStyle(
                            color: isHealthy
                                ? PdfColors.green800
                                : PdfColors.red800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Confiance IA: ${analysis.healthScore.toStringAsFixed(0)}%',
                  ),
                  if (!isHealthy) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Maladie: $_diseaseName'),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Image if available
            if (imageProvider != null) ...[
              pw.Text(
                'Image Analysée',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Image(imageProvider, height: 200)),
              pw.SizedBox(height: 20),
            ],

            // Statistics
            pw.Text(
              'Statistiques',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Métrique', 'Valeur'],
              data: [
                [
                  'Surface Affectée',
                  '${(analysis.affectedSurface ?? 0).toStringAsFixed(1)}%',
                ],
                [
                  'Surface Saine',
                  '${(100 - (analysis.affectedSurface ?? 0)).toStringAsFixed(1)}%',
                ],
                [
                  'Perte Rendement Est.',
                  '${(analysis.estimatedYieldLoss ?? 0).toStringAsFixed(1)}%',
                ],
                [
                  'Propagation/Jour',
                  '+${(analysis.propagationRate ?? 0).toStringAsFixed(1)}%',
                ],
                ['Niveau de Risque', analysis.riskLevel ?? 'Faible'],
              ],
            ),
            pw.SizedBox(height: 20),

            // Recommendations
            if (analysis.recommendations != null &&
                analysis.recommendations!.isNotEmpty) ...[
              pw.Text(
                'Recommandations',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...analysis.recommendations!.map((rec) => pw.Bullet(text: rec)),
            ],

            // Weather if available
            if (analysis.weather != null) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Météo au moment de l\'analyse',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Température: ${analysis.weather!.temperature?.toStringAsFixed(1) ?? 'N/A'}°C | '
                'Humidité: ${analysis.weather!.humidity?.toStringAsFixed(0) ?? 'N/A'}% | '
                'Vent: ${analysis.weather!.windSpeed?.toStringAsFixed(1) ?? 'N/A'} km/h',
              ),
            ],

            // Footer
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Généré par DronIA Mobile v2.1',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'analyse_${analysis.region ?? analysis.cropType}_${DateFormat('yyyyMMdd').format(analysis.createdAt)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.arrow_back_ios_new, size: 16),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 4,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Analyse: ${analysis.region ?? analysis.cropType}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formattedDate,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _isGeneratingPdf ? null : _generatePdf,
          icon: _isGeneratingPdf
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.textSecondary,
                  ),
                )
              : Icon(Icons.picture_as_pdf, size: 18),
          label: Text('PDF'),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Terminer'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainStatusCard(),
          SizedBox(height: 16),
          _buildDetailsCard(),
          SizedBox(height: 16),
          if (!isHealthy) ...[_buildInsectsCard(), SizedBox(height: 16)],
          _buildStatsGrid(),
          SizedBox(height: 16),
          _buildImageAndMetrics(),
          SizedBox(height: 16),
          _buildRecommendationsCard(),
          SizedBox(height: 16),
          _buildBottomInfo(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [AppColors.success.withValues(alpha: 0.2), context.colors.card]
              : [AppColors.error.withValues(alpha: 0.2), context.colors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Parcelle Saine' : _diseaseName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? AppColors.success : AppColors.error,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isHealthy
                      ? 'Aucune anomalie détectée • Plante en bonne santé'
                      : 'Sévérité: ${analysis.riskLevel ?? 'Modéré'}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${analysis.healthScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                'Confiance IA',
                style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.warning_amber,
                color: isHealthy ? AppColors.success : AppColors.error,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHealthy
                      ? 'Détails de l\'État Sain'
                      : 'Maladie Détectée: $_diseaseName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? AppColors.success : AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (isHealthy) ...[
            _buildDetailRow(
              'Aucune maladie détectée',
              'La plante ne présente aucun signe de maladie ou de ravageur.',
            ),
            _buildDetailRow(
              'Santé optimale',
              'Les feuilles, tiges et fruits sont en excellent état.',
            ),
            _buildDetailRow(
              'Rendement préservé',
              'Aucun impact sur la production attendue.',
            ),
            _buildDetailRow(
              'Action recommandée',
              'Continuer les bonnes pratiques agricoles et surveiller régulièrement.',
            ),
          ] else ...[
            _buildDetailRow(
              'Diagnostic',
              '$_diseaseName détecté(e) avec ${analysis.healthScore.toStringAsFixed(0)}% de confiance',
            ),
            _buildDetailRow(
              'Sévérité',
              '${analysis.riskLevel ?? 'Modéré'} - Intervention urgente requise',
            ),
            _buildDetailRow(
              'Action requise',
              'Traitement ciblé recommandé pour limiter la propagation.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: context.colors.textSecondary)),
          Text(
            '$label: ',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsectsCard() {
    // Sample insect data for disease cases
    final insects = [
      {'name': 'Pucerons', 'severity': 'Modéré', 'color': AppColors.warning},
      {'name': 'Cochenilles', 'severity': 'Modéré', 'color': AppColors.warning},
      {'name': 'Tordeuses', 'severity': 'Modéré', 'color': AppColors.warning},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insectes Potentiels Associés',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Les insectes suivants peuvent être responsables ou favoriser cette maladie',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: insects.map((insect) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insect['name'] as String,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
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
                        color: (insect['color'] as Color).withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        insect['severity'] as String,
                        style: TextStyle(
                          color: insect['color'] as Color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final affectedSurface = analysis.affectedSurface ?? 0;
    final healthySurface = 100 - affectedSurface;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '${affectedSurface.toStringAsFixed(1)}%',
            'Surface Affectée',
            'Zone sous surveillance',
            isHealthy ? AppColors.success : AppColors.error,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${healthySurface.toStringAsFixed(1)}%',
            'Surface Saine',
            'Zone non affectée',
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.colors.textHint, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAndMetrics() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Expanded(
          flex: 2,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildAnalysisImage(),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? AppColors.success.withValues(alpha: 0.9)
                            : AppColors.error.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHealthy ? Icons.check : Icons.warning,
                            color: AppColors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isHealthy ? 'Saine' : 'Critique',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _buildLegendDot('OK', AppColors.success),
                        SizedBox(width: 8),
                        _buildLegendDot('Stress', AppColors.warning),
                        SizedBox(width: 8),
                        _buildLegendDot('Critique', AppColors.error),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Metrics column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildMetricCard(
                '${(analysis.affectedSurface ?? 0).toStringAsFixed(0)}%',
                'Surface Estimée',
                isHealthy ? 'Parcelle saine' : 'Zone sous surveillance',
                isHealthy ? AppColors.success : AppColors.error,
              ),
              SizedBox(height: 8),
              _buildMetricCard(
                '${(analysis.estimatedYieldLoss ?? 0).toStringAsFixed(0)}%',
                'Perte Rendement Est.',
                isHealthy ? 'Aucune perte' : 'Si non traité',
                isHealthy ? AppColors.success : AppColors.error,
              ),
              SizedBox(height: 8),
              _buildMetricCard(
                '+${(analysis.propagationRate ?? 0).toStringAsFixed(0)}%',
                'Propagation/Jour',
                isHealthy ? 'Nulle' : 'Estimation 5k',
                isHealthy ? AppColors.success : AppColors.warning,
              ),
              SizedBox(height: 8),
              _buildMetricCard(
                analysis.riskLevel ?? 'Faible',
                'Niveau de Risque',
                isHealthy ? 'Parcelle saine' : 'Basé sur sévérité',
                _getRiskColor(analysis.riskLevel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisImage() {
    if (analysis.imageBase64 != null && analysis.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(analysis.imageBase64!);
        return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
      } catch (e) {
        // Fall through to placeholder
      }
    }

    if (analysis.imagePath != null && analysis.imagePath!.isNotEmpty) {
      final file = File(analysis.imagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    // Placeholder
    return Container(
      color: context.colors.bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, color: context.colors.textHint, size: 48),
            SizedBox(height: 8),
            Text(
              'Image non disponible',
              style: TextStyle(color: context.colors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: AppColors.white, fontSize: 8),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String value,
    String label,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 9),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.colors.textHint, fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'critique':
        return AppColors.error;
      case 'élevé':
        return AppColors.error;
      case 'modéré':
        return AppColors.warning;
      case 'faible':
        return AppColors.success;
      default:
        return AppColors.success;
    }
  }

  Widget _buildRecommendationsCard() {
    final title = isHealthy
        ? '🌱 Parcelle en Excellente Santé'
        : '📋 Plan de Traitement - $_diseaseName';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [AppColors.success.withValues(alpha: 0.15), context.colors.card]
              : [AppColors.error.withValues(alpha: 0.15), context.colors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isHealthy ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          if (isHealthy) ...[
            Text(
              'Aucun traitement nécessaire. Continuez vos bonnes pratiques.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildActionChip(
                  Icons.calendar_today,
                  '2-3 sem.',
                  'Prochaine analyse',
                ),
                SizedBox(width: 12),
                _buildActionChip(Icons.delete_outline, '0€', 'Traitement'),
                SizedBox(width: 12),
                _buildActionChip(Icons.trending_up, '100%', 'Rendement prévu'),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRAITEMENT RECOMMANDÉ',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        analysis.recommendations?.isNotEmpty == true
                            ? analysis.recommendations!.first
                            : 'Fongicides à base de soufre ou bicarbonate de potassium.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.eco,
                            color: AppColors.info,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PRÉVENTION',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bonne circulation d\'air, éviter l\'arrosage sur les feuilles.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏱️ Intervention sous 24-48h',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Économie potentielle: traitement ciblé sur ${(analysis.affectedSurface ?? 8).toStringAsFixed(0)}% vs 100% de la parcelle',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
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
    );
  }

  Widget _buildActionChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.textSecondary, size: 20),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.colors.textHint, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weather card
        Expanded(
          child: Container(
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
                    Icon(Icons.cloud, color: AppColors.info, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'MÉTÉO ANALYSE',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherItem(
                      '${analysis.weather?.temperature?.toStringAsFixed(0) ?? '15'}°',
                      'Temp',
                    ),
                    _buildWeatherItem(
                      '${analysis.weather?.humidity?.toStringAsFixed(0) ?? '77'}%',
                      'Humid.',
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    '${analysis.weather?.windSpeed?.toStringAsFixed(0) ?? '26'} km/h W',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!isHealthy) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: AppColors.warning,
                          size: 12,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Humidité favorable propagation',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 9,
                            ),
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
        SizedBox(width: 12),
        // Info card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMATIONS D\'ANALYSE',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                _buildInfoRow('Source', 'Smartphone'),
                _buildInfoRow('Appareil', 'Camera Smartphone'),
                _buildInfoRow('Résolution', 'HD / 4K'),
                _buildInfoRow('Qualité', 'Optimale', AppColors.success),
                _buildInfoRow('Modèle IA', 'DronIA Mobile v2.1'),
                _buildInfoRow(
                  'Date capture',
                  DateFormat('dd/MM/yyyy').format(analysis.createdAt),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.colors.textHint, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 9),
          ),
          SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? context.colors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
