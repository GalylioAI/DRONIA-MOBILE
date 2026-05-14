import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/crop_photos.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/services/dataset_service.dart';
import '../../widgets/common/app_drawer.dart';

/// Crop Disease Knowledge Base — searchable mini-database of common crop diseases.
class DiseaseKnowledgeScreen extends StatefulWidget {
  const DiseaseKnowledgeScreen({super.key});

  @override
  State<DiseaseKnowledgeScreen> createState() => _DiseaseKnowledgeScreenState();
}

class _DiseaseKnowledgeScreenState extends State<DiseaseKnowledgeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allDiseases = [];
  List<Map<String, dynamic>> _filteredDiseases = [];
  String? _selectedTypeFilter;
  String? _selectedCropFilter;
  String? _selectedCategoryFilter;
  String? _selectedSeverityFilter;
  bool _isLoading = true;

  // Type filters
  static const Map<String, _FilterChip> _typeFilters = {
    'fungal': _FilterChip('Fongique', Icons.eco, Color(0xFF8B5CF6)),
    'bacterial': _FilterChip('Bactérien', Icons.bug_report, Color(0xFFEF4444)),
    'viral': _FilterChip('Viral', Icons.coronavirus, Color(0xFFF59E0B)),
    'oomycete': _FilterChip('Oomycète', Icons.water_drop, Color(0xFF3B82F6)),
    'pest': _FilterChip('Ravageur', Icons.pest_control, Color(0xFFEC4899)),
    'healthy': _FilterChip('Sain', Icons.check_circle, Color(0xFF22C55E)),
  };

  // Plant category filters — derived from crops via _cropToCategory map
  static const Map<String, _CategoryChip> _categoryFilters = {
    'fruits': _CategoryChip(
      'Fruits',
      '🍎',
      Color(0xFFEF4444),
    ),
    'vegetables': _CategoryChip(
      'Légumes',
      '🥕',
      Color(0xFFF59E0B),
    ),
    'cereals': _CategoryChip(
      'Céréales',
      '🌾',
      Color(0xFFCA8A04),
    ),
    'legumes': _CategoryChip(
      'Légumineuses',
      '🫘',
      Color(0xFF8B5CF6),
    ),
    'oilseeds': _CategoryChip(
      'Oléagineux',
      '🌻',
      Color(0xFFEAB308),
    ),
    'industrial': _CategoryChip(
      'Industrielles',
      '☕',
      Color(0xFF78350F),
    ),
    'tropical_root': _CategoryChip(
      'Tubercules',
      '🌱',
      Color(0xFF22C55E),
    ),
  };

  // Crop name → plant category mapping (FR + EN names)
  static const Map<String, String> _cropToCategory = {
    // Fruits
    'Pomme': 'fruits', 'Apple': 'fruits',
    'Cerise': 'fruits', 'Cherry': 'fruits',
    'Pêche': 'fruits', 'Peach': 'fruits',
    'Poire': 'fruits', 'Pear': 'fruits',
    'Prune': 'fruits', 'Plum': 'fruits',
    'Abricot': 'fruits', 'Apricot': 'fruits',
    'Raisin': 'fruits', 'Grape': 'fruits',
    'Fraise': 'fruits', 'Strawberry': 'fruits',
    'Framboise': 'fruits', 'Raspberry': 'fruits',
    'Myrtille': 'fruits', 'Blueberry': 'fruits',
    'Mangue': 'fruits', 'Mango': 'fruits',
    'Avocat': 'fruits', 'Avocado': 'fruits',
    'Papaye': 'fruits', 'Papaya': 'fruits',
    'Banane': 'fruits', 'Banana': 'fruits',
    'Ananas': 'fruits', 'Pineapple': 'fruits',
    'Orange': 'fruits',
    'Citron': 'fruits', 'Lemon': 'fruits',
    'Pamplemousse': 'fruits', 'Grapefruit': 'fruits',
    'Mandarine': 'fruits', 'Mandarin': 'fruits',
    'Olive': 'fruits',
    'Nectarine': 'fruits',
    'Cocotier': 'fruits', 'Coconut': 'fruits',
    'Palmier dattier': 'fruits', 'Date palm': 'fruits',
    // Légumes
    'Tomate': 'vegetables', 'Tomato': 'vegetables',
    'Pomme de terre': 'vegetables', 'Potato': 'vegetables',
    'Poivron': 'vegetables', 'Pepper': 'vegetables',
    'Aubergine': 'vegetables', 'Eggplant': 'vegetables',
    'Courge': 'vegetables', 'Squash': 'vegetables',
    'Concombre': 'vegetables', 'Cucumber': 'vegetables',
    'Melon': 'vegetables',
    'Pastèque': 'vegetables', 'Watermelon': 'vegetables',
    'Carotte': 'vegetables', 'Carrot': 'vegetables',
    'Oignon': 'vegetables', 'Onion': 'vegetables',
    'Ail': 'vegetables', 'Garlic': 'vegetables',
    'Poireau': 'vegetables', 'Leek': 'vegetables',
    'Chou': 'vegetables', 'Cabbage': 'vegetables',
    'Brocoli': 'vegetables', 'Broccoli': 'vegetables',
    'Chou-fleur': 'vegetables', 'Cauliflower': 'vegetables',
    'Chou frisé': 'vegetables', 'Kale': 'vegetables',
    'Laitue': 'vegetables', 'Lettuce': 'vegetables',
    'Épinard': 'vegetables', 'Spinach': 'vegetables',
    'Citrouille': 'vegetables', 'Pumpkin': 'vegetables',
    // Céréales
    'Blé': 'cereals', 'Wheat': 'cereals',
    'Maïs': 'cereals', 'Maize': 'cereals', 'Corn': 'cereals',
    'Riz': 'cereals', 'Rice': 'cereals',
    'Orge': 'cereals', 'Barley': 'cereals',
    'Avoine': 'cereals', 'Oat': 'cereals',
    'Sorgho': 'cereals', 'Sorghum': 'cereals',
    'Seigle': 'cereals', 'Rye': 'cereals',
    // Légumineuses
    'Soja': 'legumes', 'Soybean': 'legumes',
    'Haricot': 'legumes', 'Bean': 'legumes',
    'Pois': 'legumes', 'Pea': 'legumes',
    'Lentille': 'legumes', 'Lentil': 'legumes',
    'Arachide': 'legumes', 'Peanut': 'legumes',
    'Pois chiche': 'legumes', 'Chickpea': 'legumes',
    'Luzerne': 'legumes', 'Alfalfa': 'legumes',
    'Trèfle': 'legumes', 'Clover': 'legumes',
    // Oléagineux
    'Tournesol': 'oilseeds', 'Sunflower': 'oilseeds',
    'Canola': 'oilseeds', 'Colza': 'oilseeds', 'Rapeseed': 'oilseeds',
    'Sésame': 'oilseeds', 'Sesame': 'oilseeds',
    // Cultures industrielles
    'Coton': 'industrial', 'Cotton': 'industrial',
    'Tabac': 'industrial', 'Tobacco': 'industrial',
    'Canne à sucre': 'industrial', 'Sugarcane': 'industrial',
    'Café': 'industrial', 'Coffee': 'industrial',
    'Cacao': 'industrial', 'Cocoa': 'industrial',
    'Thé': 'industrial', 'Tea': 'industrial',
    // Tubercules tropicaux
    'Manioc': 'tropical_root', 'Cassava': 'tropical_root',
    'Igname': 'tropical_root', 'Yam': 'tropical_root',
    'Patate douce': 'tropical_root', 'Sweet potato': 'tropical_root',
    'Gingembre': 'tropical_root', 'Ginger': 'tropical_root',
    'Curcuma': 'tropical_root', 'Turmeric': 'tropical_root',
  };

  // Severity colors
  static const Map<String, Color> _severityColors = {
    'low': Color(0xFF22C55E),
    'medium': Color(0xFFF59E0B),
    'high': Color(0xFFEF4444),
    'critical': Color(0xFFDC2626),
  };

  /// Returns the category id for a disease (uses first matching crop).
  static String? _categoryForDisease(Map<String, dynamic> d) {
    final cropsFr = (d['cropsFr'] as List?)?.cast<String>() ?? [];
    final cropsEn = (d['crops'] as List?)?.cast<String>() ?? [];
    for (final c in [...cropsFr, ...cropsEn]) {
      final cat = _cropToCategory[c];
      if (cat != null) return cat;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadDiseases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiseases() async {
    // Knowledge-base view shows only the curated worldwide extension.
    // The PlantVillage base JSON is intentionally NOT loaded here — it stays on
    // disk because the detection model and DatasetService still rely on it,
    // but it is hidden from the user-facing list.
    final extStr = await rootBundle.loadString(
      'assets/data/world_diseases_extension.json',
    );
    final ext = json.decode(extStr) as Map<String, dynamic>;
    final list = (ext['diseases'] as List).cast<Map<String, dynamic>>();

    // Sort alphabetically by French name.
    list.sort((a, b) {
      return (a['nameFr'] as String? ?? '').compareTo(
        b['nameFr'] as String? ?? '',
      );
    });
    setState(() {
      _allDiseases = list;
      _filteredDiseases = list;
      _isLoading = false;
    });
  }

  /// Lowercase + strip diacritics so "ble" matches "Blé", "cafe" matches
  /// "café", "peche" matches "pêche", etc. — natural for users typing fast
  /// without accents on a phone keyboard.
  static String _normalize(String s) {
    s = s.toLowerCase();
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ñ': 'n', 'ç': 'c', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
    };
    final buf = StringBuffer();
    for (final ch in s.characters) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  void _applyFilters() {
    final query = _normalize(_searchController.text.trim());
    setState(() {
      _filteredDiseases = _allDiseases.where((d) {
        // Text search — accent/diacritic-insensitive across name (FR/EN),
        // scientific name, and crops (FR/EN). Multi-word queries match if
        // every term appears somewhere in the haystack.
        if (query.isNotEmpty) {
          final haystack = [
            d['name'] as String? ?? '',
            d['nameFr'] as String? ?? '',
            d['scientificName'] as String? ?? '',
            (d['cropsFr'] as List?)?.join(' ') ?? '',
            (d['crops'] as List?)?.join(' ') ?? '',
          ].map(_normalize).join(' ');
          final terms = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
          if (!terms.every(haystack.contains)) return false;
        }
        // Type filter
        if (_selectedTypeFilter != null && d['type'] != _selectedTypeFilter) {
          return false;
        }
        // Crop filter
        if (_selectedCropFilter != null) {
          final crops = (d['crops'] as List?)?.cast<String>() ?? [];
          final cropsFr = (d['cropsFr'] as List?)?.cast<String>() ?? [];
          if (!crops.contains(_selectedCropFilter) &&
              !cropsFr.contains(_selectedCropFilter)) {
            return false;
          }
        }
        // Category filter (derived from crop name)
        if (_selectedCategoryFilter != null) {
          if (_categoryForDisease(d) != _selectedCategoryFilter) return false;
        }
        // Severity filter
        if (_selectedSeverityFilter != null &&
            d['severity'] != _selectedSeverityFilter) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _resetAllFilters() {
    setState(() {
      _selectedTypeFilter = null;
      _selectedCropFilter = null;
      _selectedCategoryFilter = null;
      _selectedSeverityFilter = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _selectedTypeFilter != null ||
      _selectedCropFilter != null ||
      _selectedCategoryFilter != null ||
      _selectedSeverityFilter != null ||
      _searchController.text.isNotEmpty;

  Set<String> get _allCrops {
    final crops = <String>{};
    for (final d in _allDiseases) {
      // Prefer French crop names (UI is FR); fall back to English if missing
      final list = (d['cropsFr'] as List?)?.cast<String>() ??
          (d['crops'] as List?)?.cast<String>() ??
          [];
      crops.addAll(list);
    }
    return crops;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentRoute: AppRoutes.diseaseKnowledge),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: context.colors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/Logo_DronIA-11.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Dron',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: 'IA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.library_books_outlined,
              color: context.colors.textSecondary,
            ),
            tooltip: 'Base de connaissances',
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeroBanner()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildCategoryTabs()),
                SliverToBoxAdapter(child: _buildFilterChips()),
                SliverToBoxAdapter(child: _buildResultCount()),
                _buildDiseaseSliverList(),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }

  // Sliver version of the disease list — items lazy-build via SliverList.builder.
  Widget _buildDiseaseSliverList() {
    if (_filteredDiseases.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: context.colors.textHint.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Aucune maladie trouvée',
                  style:
                      TextStyle(color: context.colors.textSecondary, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Essayez un autre terme ou filtre',
                  style: TextStyle(color: context.colors.textHint, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList.builder(
        itemCount: _filteredDiseases.length,
        itemBuilder: (context, index) {
          final disease = _filteredDiseases[index];
          return _DiseaseCard(
            disease: disease,
            onTap: () => _showDiseaseDetail(disease),
          );
        },
      ),
    );
  }

  // ─── Hero stats banner ────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    final total = _allDiseases.length;
    final detectable = _allDiseases.where((d) => d['detectable'] == true).length;
    final critical = _allDiseases
        .where((d) => d['severity'] == 'critical')
        .length;
    final categories = _allDiseases
        .map(_categoryForDisease)
        .where((c) => c != null)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_florist,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maladies des cultures',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Base de connaissances mondiale',
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statTile(total.toString(), 'Maladies',
                    Icons.coronavirus_outlined, AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(detectable.toString(), 'Détectables',
                    Icons.visibility_outlined, AppColors.info),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(critical.toString(), 'Critiques',
                    Icons.warning_amber_rounded, const Color(0xFFDC2626)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(categories.toString(), 'Catégories',
                    Icons.category_outlined, const Color(0xFFF59E0B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Category tabs (plant categories) ─────────────────────────────────────
  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _categoryTile(
            id: null,
            label: 'Toutes',
            emoji: '🌍',
            color: AppColors.primaryGreen,
            count: _allDiseases.length,
          ),
          for (final entry in _categoryFilters.entries)
            _categoryTile(
              id: entry.key,
              label: entry.value.label,
              emoji: entry.value.emoji,
              color: entry.value.color,
              count: _allDiseases
                  .where((d) => _categoryForDisease(d) == entry.key)
                  .length,
            ),
        ],
      ),
    );
  }

  Widget _categoryTile({
    required String? id,
    required String label,
    required String emoji,
    required Color color,
    required int count,
  }) {
    final selected = _selectedCategoryFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryFilter = selected ? null : id);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: selected ? null : context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color
                : context.colors.divider.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20, height: 1.0)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : context.colors.textPrimary,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (selected ? color : context.colors.textSecondary)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? color
                      : context.colors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFilters(),
        style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Rechercher une maladie, culture ou nom scientifique…',
          hintStyle: TextStyle(color: context.colors.textHint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: context.colors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: context.colors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: context.colors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Type filters
          for (final entry in _typeFilters.entries) ...[
            _buildChip(
              label: entry.value.label,
              icon: entry.value.icon,
              color: entry.value.color,
              isSelected: _selectedTypeFilter == entry.key,
              onTap: () {
                setState(() {
                  _selectedTypeFilter = _selectedTypeFilter == entry.key
                      ? null
                      : entry.key;
                });
                _applyFilters();
              },
            ),
            SizedBox(width: 8),
          ],
          // Crop filter dropdown
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _selectedCropFilter != null
                  ? AppColors.primaryGreen.withValues(alpha: 0.15)
                  : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedCropFilter != null
                    ? AppColors.primaryGreen
                    : context.colors.divider,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCropFilter,
                icon: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
                hint: Text(
                  '🌱 Culture',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                dropdownColor: context.colors.cardElevated,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Toutes les cultures'),
                  ),
                  for (final crop in _allCrops.toList()..sort())
                    DropdownMenuItem(value: crop, child: Text(crop)),
                ],
                onChanged: (val) {
                  setState(() => _selectedCropFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          // Severity dropdown
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _selectedSeverityFilter != null
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedSeverityFilter != null
                    ? AppColors.warning
                    : context.colors.divider,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedSeverityFilter,
                icon: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
                hint: Text(
                  '⚠️ Sévérité',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                dropdownColor: context.colors.cardElevated,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Toutes sévérités')),
                  DropdownMenuItem(value: 'critical', child: Text('Critique')),
                  DropdownMenuItem(value: 'high', child: Text('Élevée')),
                  DropdownMenuItem(value: 'medium', child: Text('Moyenne')),
                  DropdownMenuItem(value: 'low', child: Text('Faible')),
                ],
                onChanged: (val) {
                  setState(() => _selectedSeverityFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          // Clear all
          if (_hasActiveFilters) ...[
            SizedBox(width: 8),
            GestureDetector(
              onTap: _resetAllFilters,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 16, color: AppColors.error),
                    SizedBox(width: 4),
                    Text(
                      'Effacer',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : context.colors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : context.colors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '${_filteredDiseases.length} maladie${_filteredDiseases.length != 1 ? 's' : ''}',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_filteredDiseases.any((d) => d['detectable'] == true))
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_filteredDiseases.where((d) => d['detectable'] == true).length} détectables par DronIA',
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showDiseaseDetail(Map<String, dynamic> disease) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DiseaseDetailPage(disease: disease)),
    );
  }
}

// ─── Disease Card ───────────────────────────────────────────────────────────

class _DiseaseCard extends StatelessWidget {
  final Map<String, dynamic> disease;
  final VoidCallback onTap;

  const _DiseaseCard({required this.disease, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = disease['type'] as String? ?? 'fungal';
    final severity = disease['severity'] as String? ?? 'medium';
    final detectable = disease['detectable'] as bool? ?? false;
    final filter = _DiseaseKnowledgeScreenState._typeFilters[type];
    final severityColor =
        _DiseaseKnowledgeScreenState._severityColors[severity] ??
        AppColors.warning;
    final cropsFr = (disease['cropsFr'] as List?)?.cast<String>() ?? [];
    final emoji = disease['emoji'] as String? ?? '🌿';
    final imagePath = disease['imagePath'] as String?;

    final severityPct = _severityPercent(severity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: image circle + title block + severity ring
              Row(
                children: [
                  // Image / emoji disc — prefer real crop photo
                  _CropDisc(
                    size: 56,
                    radius: 16,
                    cropFr: cropsFr.isNotEmpty ? cropsFr.first : null,
                    localPath: imagePath,
                    emoji: emoji,
                  ),
                  const SizedBox(width: 14),
                  // Name & scientific
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          disease['nameFr'] as String? ?? '',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          disease['scientificName'] as String? ?? '',
                          style: TextStyle(
                            color: context.colors.textHint,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Severity ring (Plantix-style %)
                  _SeverityRing(
                    percent: severityPct,
                    color: severityColor,
                    label: _severityLabel(severity),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: context.colors.divider),
              const SizedBox(height: 12),
              // Type + crops row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (filter != null)
                    _miniTag(filter.label, filter.color, filter.icon),
                  for (final crop in cropsFr.take(2))
                    _miniTag(crop, AppColors.primaryGreen, Icons.grass),
                  if (cropsFr.length > 2)
                    _miniTag('+${cropsFr.length - 2}', context.colors.textHint, null),
                  if (detectable)
                    _miniTag(
                      'Détectable',
                      AppColors.info,
                      Icons.visibility_outlined,
                    ),
                ],
              ),
              if ((disease['symptomsFr'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (disease['symptomsFr'] as List).first as String,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: context.colors.textHint,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Maps severity tier to a 0-100 indicator percentage.
  static int _severityPercent(String severity) {
    switch (severity) {
      case 'low':
        return 25;
      case 'medium':
        return 50;
      case 'high':
        return 75;
      case 'critical':
        return 95;
      default:
        return 50;
    }
  }

  static String _severityLabel(String severity) {
    switch (severity) {
      case 'low':
        return 'Faible';
      case 'medium':
        return 'Moyen';
      case 'high':
        return 'Élevé';
      case 'critical':
        return 'Critique';
      default:
        return severity;
    }
  }

  Widget _miniTag(String text, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Circular severity indicator ────────────────────────────────────────────
class _SeverityRing extends StatelessWidget {
  final int percent;
  final Color color;
  final String label;

  const _SeverityRing({
    required this.percent,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Real-photo disc with emoji fallback ────────────────────────────────────
class _CropDisc extends StatelessWidget {
  final double size;
  final double radius;
  final String? cropFr;
  final String? localPath;
  final String emoji;

  const _CropDisc({
    required this.size,
    required this.radius,
    required this.cropFr,
    required this.localPath,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final cropAsset = CropPhotos.assetFor(cropFr);
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.primaryGreen.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
    );

    // Priority: dataset image (PlantVillage) → curated crop photo → emoji
    final assetToShow = localPath ?? cropAsset;

    Widget child;
    if (assetToShow != null) {
      child = Image.asset(
        assetToShow,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      child = placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

// ─── Big hero photo with overlay gradient + emoji fallback ─────────────────
class _HeroPhoto extends StatelessWidget {
  final String? localPath;
  final String? cropFr;
  final String emoji;
  final Color accentColor;

  const _HeroPhoto({
    required this.localPath,
    required this.cropFr,
    required this.emoji,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cropAsset = CropPhotos.assetFor(cropFr);
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.25),
            accentColor.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 96)),
      ),
    );

    // Priority: dataset image (PlantVillage) → curated crop photo → emoji
    final assetToShow = localPath ?? cropAsset;

    Widget image;
    if (assetToShow != null) {
      image = Image.asset(
        assetToShow,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      image = fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // Subtle bottom gradient for legibility of overlaid badges
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Disease Detail Page ────────────────────────────────────────────────────

class _DiseaseDetailPage extends StatelessWidget {
  final Map<String, dynamic> disease;

  const _DiseaseDetailPage({required this.disease});

  @override
  Widget build(BuildContext context) {
    final type = disease['type'] as String? ?? 'fungal';
    final severity = disease['severity'] as String? ?? 'medium';
    final detectable = disease['detectable'] as bool? ?? false;
    final filter = _DiseaseKnowledgeScreenState._typeFilters[type];
    final severityColor =
        _DiseaseKnowledgeScreenState._severityColors[severity] ??
        AppColors.warning;
    final emoji = disease['emoji'] as String? ?? '🌿';
    final symptomsFr = (disease['symptomsFr'] as List?)?.cast<String>() ?? [];
    final treatmentsFr =
        (disease['treatmentsFr'] as List?)?.cast<String>() ?? [];
    final preventionList = (disease['preventionFr'] as List?)?.cast<String>() ??
        (disease['prevention'] as List?)?.cast<String>() ??
        [];
    final conditionsFr = disease['conditionsFr'] as String? ?? '';
    final spreadMethod = disease['spreadMethodFr'] as String? ??
        disease['spreadMethod'] as String? ??
        '';
    final cropsFr = (disease['cropsFr'] as List?)?.cast<String>() ?? [];
    final riskMonths = (disease['riskMonths'] as List?)?.cast<int>() ?? [];
    final imagePath = disease['imagePath'] as String?;
    final images = (disease['images'] as List?)?.cast<String>() ?? [];
    final diseaseId = disease['id'] as String? ?? '';
    // Check if this disease has dataset images (PlantVillage classes)
    final hasDataset = DatasetService.hasDatasetImages(diseaseId);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Détail de la maladie',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (imagePath != null)
            IconButton(
              icon: Icon(
                Icons.fullscreen,
                color: context.colors.textPrimary,
              ),
              onPressed: () =>
                  _openFullscreenImage(context, imagePath, images, 0),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Hero image section — big real crop photo
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: GestureDetector(
                      onTap: imagePath != null
                          ? () => _openFullscreenImage(
                              context, imagePath, images, 0)
                          : null,
                      child: _HeroPhoto(
                        localPath: imagePath,
                        cropFr: cropsFr.isNotEmpty ? cropsFr.first : null,
                        emoji: emoji,
                        accentColor: filter?.color ?? AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  if (detectable)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryGreen
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Détectable par DronIA',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Header card — disease identity + severity ring ──────
                  _headerCard(
                    context,
                    nameFr: disease['nameFr'] as String? ?? '',
                    nameEn: disease['name'] as String? ?? '',
                    scientificName: disease['scientificName'] as String? ?? '',
                    severity: severity,
                    severityColor: severityColor,
                    typeLabel: filter?.label ?? '',
                    typeIcon: filter?.icon ?? Icons.eco,
                    typeColor: filter?.color ?? AppColors.primaryGreen,
                    detectable: detectable,
                  ),

                  // ── 2. Cultures affectées card ─────────────────────────────
                  const SizedBox(height: 14),
                  _blockCard(
                    context,
                    icon: Icons.grass,
                    title: 'Cultures affectées',
                    subtitle: '${cropsFr.length} ${cropsFr.length > 1 ? 'cultures' : 'culture'}',
                    iconColor: AppColors.primaryGreen,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cropsFr
                          .map((c) => _cropChip(context, c))
                          .toList(),
                    ),
                  ),

                  // ── 3. Galerie d'images (si plusieurs) ─────────────────────
                  if (images.length > 1) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.photo_library_outlined,
                      title: 'Galerie d\'images',
                      subtitle: '${images.length} photos',
                      iconColor: AppColors.info,
                      child: SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openFullscreenImage(
                                context, images[index], images, index,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  images[index],
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 110,
                                    height: 110,
                                    color: context.colors.bgSecondary,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: context.colors.textHint,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // ── Dataset PlantVillage button ────────────────────────────
                  if (hasDataset) ...[
                    const SizedBox(height: 14),
                    _buildDatasetGalleryButton(
                      context,
                      diseaseId,
                      disease['nameFr'] as String? ?? '',
                    ),
                  ],

                  // ── 4. Mois à risque (calendrier) ──────────────────────────
                  if (riskMonths.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.calendar_month,
                      title: 'Mois à risque',
                      subtitle: '${riskMonths.length} mois',
                      iconColor: AppColors.warning,
                      child: _buildMonthChart(context, riskMonths),
                    ),
                  ],

                  // ── 5. Conditions favorables ───────────────────────────────
                  if (conditionsFr.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.thermostat,
                      title: 'Conditions favorables',
                      iconColor: AppColors.info,
                      child: _paragraph(context, conditionsFr),
                    ),
                  ],

                  // ── 6. Symptômes (liste numérotée) ─────────────────────────
                  if (symptomsFr.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.warning_amber_rounded,
                      title: 'Symptômes',
                      subtitle: '${symptomsFr.length} signes',
                      iconColor: AppColors.warning,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < symptomsFr.length; i++)
                            _numberedItem(
                              context, i + 1, symptomsFr[i], AppColors.warning,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ── 7. Traitements (cartes vertes) ─────────────────────────
                  if (treatmentsFr.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'Traitements',
                      subtitle: '${treatmentsFr.length} options',
                      iconColor: AppColors.primaryGreen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < treatmentsFr.length; i++)
                            _actionItem(
                              context,
                              icon: Icons.check_circle_outline,
                              text: treatmentsFr[i],
                              color: AppColors.primaryGreen,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ── 8. Prévention (cartes bleues) ──────────────────────────
                  if (preventionList.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.shield_outlined,
                      title: 'Prévention',
                      subtitle: '${preventionList.length} mesures',
                      iconColor: AppColors.info,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in preventionList)
                            _actionItem(
                              context,
                              icon: Icons.shield_outlined,
                              text: p,
                              color: AppColors.info,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ── 9. Mode de propagation ─────────────────────────────────
                  if (spreadMethod.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _blockCard(
                      context,
                      icon: Icons.air,
                      title: 'Mode de propagation',
                      iconColor: AppColors.accentBrown,
                      child: _paragraph(context, spreadMethod),
                    ),
                  ],

                  // ── Footer note + type info ────────────────────────────────
                  const SizedBox(height: 18),
                  _typeInfoCard(context, type, filter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header card with severity ring & main identity ───────────────────────
  Widget _headerCard(
    BuildContext context, {
    required String nameFr,
    required String nameEn,
    required String scientificName,
    required String severity,
    required Color severityColor,
    required String typeLabel,
    required IconData typeIcon,
    required Color typeColor,
    required bool detectable,
  }) {
    final pct = _DiseaseCard._severityPercent(severity);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameFr,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scientificName,
                      style: TextStyle(
                        color: context.colors.textHint,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Big severity ring
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 6,
                        backgroundColor:
                            severityColor.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(severityColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          'sévérité',
                          style: TextStyle(
                            color: context.colors.textHint,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Pills: type + severity + detectable
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(typeLabel, typeColor, typeIcon),
              _pill(_DiseaseCard._severityLabel(severity), severityColor,
                  Icons.warning_amber_rounded),
              if (detectable)
                _pill('Détectable par DronIA', AppColors.primaryGreen,
                    Icons.visibility_outlined),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Generic block card with header (icon + title + optional subtitle) ────
  Widget _blockCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cropChip(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _numberedItem(
    BuildContext context,
    int number,
    String text,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeInfoCard(
    BuildContext context,
    String type,
    _FilterChip? filter,
  ) {
    final desc = _typeDescription(type);
    if (filter == null || desc.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: filter.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: filter.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(filter.icon, color: filter.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pathogène ${filter.label.toLowerCase()}',
                  style: TextStyle(
                    color: filter.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
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

  String _typeDescription(String type) {
    switch (type) {
      case 'fungal':
        return 'Maladie causée par un champignon. Se propage souvent par les spores transportées par le vent ou les éclaboussures de pluie.';
      case 'bacterial':
        return 'Maladie causée par une bactérie. Pénètre par les blessures ou les ouvertures naturelles ; favorisée par l\'humidité.';
      case 'viral':
        return 'Maladie virale, généralement transmise par un insecte vecteur (puceron, aleurode, cicadelle). Aucun traitement curatif.';
      case 'oomycete':
        return 'Pseudo-champignon (oomycète) — biologie distincte des vrais champignons. Très virulent en conditions humides.';
      case 'pest':
        return 'Ravageur (insecte ou acarien) qui attaque directement les tissus végétaux et peut transmettre des maladies.';
      default:
        return '';
    }
  }

  Widget _buildMonthChart(BuildContext context, List<int> riskMonths) {
    const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(12, (i) {
        final isRisk = riskMonths.contains(i + 1);
        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isRisk
                    ? AppColors.warning.withValues(alpha: 0.25)
                    : context.colors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isRisk ? AppColors.warning : context.colors.divider,
                ),
              ),
              child: Center(
                child: isRisk
                    ? const Icon(
                        Icons.warning,
                        size: 12,
                        color: AppColors.warning,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              months[i],
              style: TextStyle(
                color: isRisk ? AppColors.warning : context.colors.textHint,
                fontSize: 11,
                fontWeight: isRisk ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDatasetGalleryButton(
    BuildContext context,
    String diseaseId,
    String diseaseName,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _DatasetGalleryPage(
              diseaseId: diseaseId,
              diseaseName: diseaseName,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.photo_library,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dataset PlantVillage',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '~2000 images d\'entraînement disponibles',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primaryGreen,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fullscreen Image Viewer ────────────────────────────────────────────────

void _openFullscreenImage(
  BuildContext context,
  String currentImage,
  List<String> allImages,
  int initialIndex,
) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullscreenImageViewer(
          images: allImages,
          initialIndex: initialIndex,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView with pinch-to-zoom
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.asset(
                    widget.images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          // Top bar with close button and counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    SizedBox(width: 48), // Balance the close button
                  ],
                ),
              ),
            ),
          ),
          // Swipe hint at the bottom
          if (widget.images.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.images.length,
                      (index) => Container(
                        width: index == _currentIndex ? 10 : 6,
                        height: index == _currentIndex ? 10 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentIndex
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dataset Gallery Page ───────────────────────────────────────────────────

class _DatasetGalleryPage extends StatefulWidget {
  final String diseaseId;
  final String diseaseName;

  const _DatasetGalleryPage({
    required this.diseaseId,
    required this.diseaseName,
  });

  @override
  State<_DatasetGalleryPage> createState() => _DatasetGalleryPageState();
}

class _DatasetGalleryPageState extends State<_DatasetGalleryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<DatasetImage> _images = [];
  int _currentPage = 1;
  int _totalImages = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _split = 'train';

  @override
  void initState() {
    super.initState();
    _loadImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _images.clear();
      _currentPage = 1;
    });
    try {
      final result = await DatasetService.getImages(
        diseaseId: widget.diseaseId,
        split: _split,
        page: 1,
        perPage: 40,
      );
      setState(() {
        _images.addAll(result.images);
        _totalImages = result.total;
        _totalPages = result.totalPages;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await DatasetService.getImages(
        diseaseId: widget.diseaseId,
        split: _split,
        page: _currentPage + 1,
        perPage: 40,
      );
      setState(() {
        _images.addAll(result.images);
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.diseaseName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            if (_totalImages > 0)
              Text(
                '$_totalImages images • $_split',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          // Split toggle
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: context.colors.textSecondary),
            color: context.colors.cardElevated,
            onSelected: (val) {
              _split = val;
              _loadImages();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'train',
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: _split == 'train'
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Train',
                      style: TextStyle(color: context.colors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'valid',
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: _split == 'valid'
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Validation',
                      style: TextStyle(color: context.colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _hasError
          ? _buildError()
          : _images.isEmpty && _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _buildGrid(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: context.colors.textHint),
            SizedBox(height: 16),
            Text(
              'Impossible de charger les images',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vérifiez que le serveur backend est en cours d\'exécution.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: context.colors.textHint, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadImages,
              icon: Icon(Icons.refresh),
              label: Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _images.length + (_currentPage < _totalPages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _images.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 2,
              ),
            ),
          );
        }
        final img = _images[index];
        return GestureDetector(
          onTap: () => _openFullscreen(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: img.fullUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: context.colors.card,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: context.colors.card,
                child: Icon(
                  Icons.broken_image,
                  color: context.colors.textHint,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: _NetworkImageViewer(images: _images, initialIndex: index),
          );
        },
      ),
    );
  }
}

// ─── Network Image Fullscreen Viewer ────────────────────────────────────────

class _NetworkImageViewer extends StatefulWidget {
  final List<DatasetImage> images;
  final int initialIndex;

  const _NetworkImageViewer({required this.images, required this.initialIndex});

  @override
  State<_NetworkImageViewer> createState() => _NetworkImageViewerState();
}

class _NetworkImageViewerState extends State<_NetworkImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index].fullUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: context.colors.textHint,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          // Filename at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.images[_currentIndex].filename,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Models ──────────────────────────────────────────────────────────

class _FilterChip {
  final String label;
  final IconData icon;
  final Color color;

  const _FilterChip(this.label, this.icon, this.color);
}

class _CategoryChip {
  final String label;
  final String emoji;
  final Color color;

  const _CategoryChip(this.label, this.emoji, this.color);
}
