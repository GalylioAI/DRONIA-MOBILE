/// Maps a French crop name to a bundled local asset photo.
///
/// Photos live in `assets/data/crop_photos/` (registered in pubspec.yaml).
/// Each crop has one curated photo; the disease detail page hero and the
/// list-card disc both load from this map.
class CropPhotos {
  CropPhotos._();

  static const String _root = 'assets/data/crop_photos/';

  /// French crop name → asset path
  static const Map<String, String> _paths = {
    // Fruits tempérés
    'Pomme': '${_root}apple.jpg',
    'Cerise': '${_root}cherry.jpg',
    'Pêche': '${_root}peach.jpg',
    'Nectarine': '${_root}nectarine.jpg',
    'Poire': '${_root}pear.jpg',
    'Prune': '${_root}plum.jpg',
    'Abricot': '${_root}apricot.jpg',
    'Raisin': '${_root}grape.jpg',
    'Fraise': '${_root}strawberry.jpg',
    // Fruits tropicaux
    'Mangue': '${_root}mango.jpg',
    'Avocat': '${_root}avocado.jpg',
    'Papaye': '${_root}papaya.jpg',
    'Banane': '${_root}banana.jpg',
    'Ananas': '${_root}pineapple.jpg',
    'Cocotier': '${_root}coconut.jpg',
    'Palmier dattier': '${_root}date_palm.jpg',
    // Agrumes
    'Orange': '${_root}orange.jpg',
    'Citron': '${_root}lemon.jpg',
    'Pamplemousse': '${_root}grapefruit.jpg',
    'Mandarine': '${_root}mandarin.jpg',
    'Olive': '${_root}olive.jpg',
    // Légumes solanacées
    'Tomate': '${_root}tomato.jpg',
    'Pomme de terre': '${_root}potato.jpg',
    'Poivron': '${_root}pepper.jpg',
    // Cucurbitacées
    'Courge': '${_root}squash.jpg',
    'Citrouille': '${_root}pumpkin.jpg',
    'Concombre': '${_root}cucumber.jpg',
    'Melon': '${_root}melon.jpg',
    'Pastèque': '${_root}watermelon.jpg',
    // Légumes racines & bulbes
    'Carotte': '${_root}carrot.jpg',
    'Oignon': '${_root}onion.jpg',
    'Ail': '${_root}garlic.jpg',
    'Poireau': '${_root}leek.jpg',
    // Choux & feuilles
    'Chou': '${_root}cabbage.jpg',
    'Brocoli': '${_root}broccoli.jpg',
    'Chou-fleur': '${_root}cauliflower.jpg',
    'Chou frisé': '${_root}kale.jpg',
    'Laitue': '${_root}lettuce.jpg',
    'Épinard': '${_root}spinach.jpg',
    // Céréales
    'Blé': '${_root}wheat.jpg',
    'Maïs': '${_root}maize.jpg',
    'Riz': '${_root}rice.jpg',
    'Orge': '${_root}barley.jpg',
    'Avoine': '${_root}oat.png',
    'Sorgho': '${_root}sorghum.jpg',
    // Légumineuses
    'Soja': '${_root}soybean.jpg',
    'Haricot': '${_root}bean.jpg',
    'Arachide': '${_root}peanut.jpg',
    'Pois chiche': '${_root}chickpea.jpg',
    // Oléagineux
    'Tournesol': '${_root}sunflower.jpg',
    'Canola': '${_root}canola.jpg',
    'Colza': '${_root}rapeseed.jpg',
    // Industrielles
    'Coton': '${_root}cotton.jpg',
    'Tabac': '${_root}tobacco.jpg',
    'Canne à sucre': '${_root}sugarcane.jpg',
    'Café': '${_root}coffee.jpg',
    'Cacao': '${_root}cocoa.jpg',
    'Thé': '${_root}tea.jpg',
    // Tubercules tropicaux
    'Manioc': '${_root}cassava.jpg',
    'Gingembre': '${_root}ginger.jpg',
    // Forestier
    'Pin': '${_root}pine.jpg',
    'Orme': '${_root}elm.jpg',
  };

  /// Returns the bundled asset path for the given French crop name,
  /// or `null` if no photo is mapped.
  static String? assetFor(String? cropFr) {
    if (cropFr == null) return null;
    return _paths[cropFr];
  }

  /// True iff a photo asset is mapped for this crop.
  static bool has(String? cropFr) => cropFr != null && _paths.containsKey(cropFr);
}
