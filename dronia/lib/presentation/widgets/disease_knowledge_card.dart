import 'dart:convert';
import 'dart:math' show min;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/theme/app_colors.dart';

/// Widget autonome : charge la base de maladies et affiche la fiche correspondante
/// au résultat d'une analyse IA.
///
/// Paramètres :
///   [analysisResult] — Map renvoyée par l'API (/classify/vit ou /classify/base64)
///   [selectedPlant]  — Plante choisie par l'utilisateur (optionnel)
class DiseaseKnowledgeCard extends StatefulWidget {
  final Map<String, dynamic> analysisResult;
  final String? selectedPlant;

  const DiseaseKnowledgeCard({
    super.key,
    required this.analysisResult,
    this.selectedPlant,
  });

  @override
  State<DiseaseKnowledgeCard> createState() => _DiseaseKnowledgeCardState();
}

class _DiseaseKnowledgeCardState extends State<DiseaseKnowledgeCard> {
  Map<String, dynamic>? _matched;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/data/disease_knowledge_base.json');
      final kb = json.decode(jsonStr) as Map<String, dynamic>;
      final diseases = (kb['diseases'] as List<dynamic>).cast<Map<String, dynamic>>();

      final r = widget.analysisResult;
      final diseaseType  = (r['diseaseType']  as String? ?? '').toLowerCase().trim();
      final diseaseFr    = (r['disease']       as String? ?? '').toLowerCase().trim();
      final diseaseClass = (r['diseaseClass']  as String? ?? '').toLowerCase();
      final selectedPlant = (widget.selectedPlant ??
          r['selectedPlant'] as String? ?? '').toLowerCase().trim();

      Map<String, dynamic>? best;
      int bestScore = -1;

      for (final d in diseases) {
        if ((d['type'] as String? ?? '') == 'healthy') continue;
        final nameFr = (d['nameFr'] as String? ?? '').toLowerCase();
        final crops  = (d['cropsFr'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();
        final id = (d['id'] as String? ?? '').toLowerCase();

        int score = 0;

        // 1. Correspondance type de maladie
        if (diseaseType.isNotEmpty && nameFr.contains(diseaseType)) score += 5;
        final diseasePart = diseaseFr.contains('—')
            ? diseaseFr.split('—').last.trim()
            : diseaseFr;
        if (diseasePart.isNotEmpty && nameFr.contains(diseasePart)) score += 4;

        // 2. Plante sélectionnée
        if (selectedPlant.isNotEmpty) {
          for (final crop in crops) {
            if (crop.contains(selectedPlant) || selectedPlant.contains(crop)) {
              score += 2; break;
            }
          }
        }

        // 3. Classe du modèle
        if (diseaseClass.isNotEmpty) {
          for (final word in diseaseClass.split(RegExp(r'[_]+'))) {
            if (word.length > 3 && id.contains(word)) { score += 1; break; }
          }
        }

        if (score > bestScore) { bestScore = score; best = d; }
      }

      if (mounted) {
        setState(() {
          _matched = (best != null && bestScore >= 2) ? best : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_matched == null) return const SizedBox.shrink();

    final d = _matched!;
    final String nameFr       = d['nameFr']       as String? ?? '';
    final String scientific   = d['scientificName'] as String? ?? '';
    final String emoji        = d['emoji']         as String? ?? '🌿';
    final String type         = d['type']          as String? ?? 'fungal';
    final String severity     = d['severity']      as String? ?? 'medium';
    final bool   detectable   = d['detectable']    as bool?   ?? false;
    final String conditionsFr = d['conditionsFr']  as String? ?? '';
    final String spreadFr     = d['spreadMethod']  as String? ?? '';
    final List<dynamic> cropsFr      = d['cropsFr']      as List<dynamic>? ?? [];
    final List<dynamic> symptomsFr   = d['symptomsFr']   as List<dynamic>? ?? [];
    final List<dynamic> treatmentsFr = d['treatmentsFr'] as List<dynamic>? ?? [];
    final List<dynamic> prevention   = d['prevention']   as List<dynamic>? ?? [];
    final List<dynamic> riskMonths   = d['riskMonths']   as List<dynamic>? ?? [];
    final List<dynamic> images       = d['images']       as List<dynamic>? ?? [];

    // Couleur par type
    Color typeColor; IconData typeIcon; String typeLabel;
    switch (type) {
      case 'bacterial': typeColor = const Color(0xFFEF5350); typeIcon = Icons.science; typeLabel = 'Bactérien'; break;
      case 'viral':     typeColor = const Color(0xFFAB47BC); typeIcon = Icons.bug_report; typeLabel = 'Viral'; break;
      case 'oomycete':  typeColor = const Color(0xFF1E88E5); typeIcon = Icons.water_drop; typeLabel = 'Oomycète'; break;
      case 'pest':      typeColor = const Color(0xFFFFA726); typeIcon = Icons.pest_control; typeLabel = 'Ravageur'; break;
      default:          typeColor = const Color(0xFF26A69A); typeIcon = Icons.local_florist; typeLabel = 'Fongique';
    }

    // Couleur par sévérité
    Color sevColor; double sevPct; String sevLabel;
    switch (severity) {
      case 'critical': sevColor = AppColors.error;            sevPct = 0.95; sevLabel = 'Critique'; break;
      case 'high':     sevColor = const Color(0xFFF57C00);   sevPct = 0.75; sevLabel = 'Élevée'; break;
      case 'medium':   sevColor = AppColors.warning;          sevPct = 0.50; sevLabel = 'Modérée'; break;
      default:         sevColor = AppColors.success;          sevPct = 0.25; sevLabel = 'Faible';
    }

    final monthNames = ['J','F','M','A','M','J','J','A','S','O','N','D'];
    final riskSet = riskMonths.map((e) => e as int).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [typeColor, typeColor.withValues(alpha: 0.4)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text('Fiche Maladie', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white : Colors.black87,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: typeColor.withValues(alpha: 0.30)),
            ),
            child: Text('Base de données', style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),

        // Main card
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    typeColor.withValues(alpha: 0.10),
                    (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A2332) : Colors.white).withValues(alpha: 0.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: typeColor.withValues(alpha: 0.22), width: 1.2),
                boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Image gallery
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    child: SizedBox(
                      height: 160,
                      child: PageView.builder(
                        itemCount: min(images.length, 6),
                        itemBuilder: (_, i) {
                          final path = images[i].toString();
                          return Stack(fit: StackFit.expand, children: [
                            Image.asset(path, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: typeColor.withValues(alpha: 0.12),
                                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))),
                              )),
                            Container(decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                              ),
                            )),
                          ]);
                        },
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Header: emoji ring + name + chips
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Stack(alignment: Alignment.center, children: [
                        SizedBox(width: 64, height: 64,
                          child: CircularProgressIndicator(
                            value: sevPct, strokeWidth: 4,
                            backgroundColor: sevColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(sevColor),
                          )),
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                        ),
                      ]),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nameFr, style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        )),
                        if (scientific.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(scientific, style: TextStyle(
                            fontSize: 11, fontStyle: FontStyle.italic,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white54 : Colors.black45,
                          )),
                        ],
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _chip(typeLabel, typeColor, typeIcon),
                          _chip(sevLabel, sevColor, Icons.warning_amber_rounded),
                          if (detectable) _chip('Détectable IA', AppColors.primaryGreen, Icons.radar),
                        ]),
                      ])),
                    ]),
                    const SizedBox(height: 16),

                    // Cultures
                    if (cropsFr.isNotEmpty) ...[
                      _sectionTitle(context, 'Cultures affectées', Icons.eco_rounded, AppColors.primaryGreen),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: cropsFr.map((c) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.30)),
                          ),
                          child: Text(c.toString(), style: const TextStyle(
                            fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                        )
                      ).toList()),
                      const SizedBox(height: 16),
                    ],

                    // Mois à risque
                    if (riskSet.isNotEmpty) ...[
                      _sectionTitle(context, 'Mois à risque', Icons.calendar_today_rounded, sevColor),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(12, (i) {
                          final isRisk = riskSet.contains(i + 1);
                          return Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: isRisk ? sevColor : sevColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              boxShadow: isRisk ? [BoxShadow(color: sevColor.withValues(alpha: 0.45), blurRadius: 6)] : [],
                            ),
                            child: Center(child: Text(monthNames[i],
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                                color: isRisk ? Colors.white : Colors.grey))),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Conditions
                    if (conditionsFr.isNotEmpty) ...[
                      _sectionTitle(context, 'Conditions favorables', Icons.thermostat_rounded, const Color(0xFF1E88E5)),
                      const SizedBox(height: 8),
                      _infoBox(context, conditionsFr, const Color(0xFF1E88E5)),
                      const SizedBox(height: 16),
                    ],

                    // Symptômes
                    if (symptomsFr.isNotEmpty) ...[
                      _sectionTitle(context, 'Symptômes', Icons.search_rounded, AppColors.warning),
                      const SizedBox(height: 10),
                      ...symptomsFr.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.6)]),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.warning.withValues(alpha: 0.35), blurRadius: 6)],
                            ),
                            child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.value.toString(),
                            style: TextStyle(fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              height: 1.4))),
                        ]),
                      )),
                      const SizedBox(height: 8),
                    ],

                    // Traitements
                    if (treatmentsFr.isNotEmpty) ...[
                      _sectionTitle(context, 'Traitements', Icons.medical_services_rounded, AppColors.primaryGreen),
                      const SizedBox(height: 10),
                      ...treatmentsFr.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: AppColors.primaryGreen, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t.toString(),
                            style: TextStyle(fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              height: 1.4))),
                        ]),
                      )),
                      const SizedBox(height: 8),
                    ],

                    // Prévention
                    if (prevention.isNotEmpty) ...[
                      _sectionTitle(context, 'Prévention', Icons.shield_rounded, const Color(0xFF1E88E5)),
                      const SizedBox(height: 10),
                      ...prevention.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(color: const Color(0xFF1E88E5).withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF1E88E5), size: 13),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.toString(),
                            style: TextStyle(fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              height: 1.4))),
                        ]),
                      )),
                      const SizedBox(height: 8),
                    ],

                    // Propagation
                    if (spreadFr.isNotEmpty) ...[
                      _sectionTitle(context, 'Mode de propagation', Icons.air_rounded, const Color(0xFFAB47BC)),
                      const SizedBox(height: 8),
                      _infoBox(context, spreadFr, const Color(0xFFAB47BC)),
                    ],

                  ]),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext ctx, String label, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87)),
    ]);
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoBox(BuildContext ctx, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, height: 1.5,
        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
    );
  }
}
