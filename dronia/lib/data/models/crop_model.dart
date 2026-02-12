/// Crop model matching the Next.js backend
class Crop {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? category;
  final List<String>? diseases;
  final SeasonInfo? season;

  Crop({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.category,
    this.diseases,
    this.season,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      diseases: (json['diseases'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      season: json['season'] != null
          ? SeasonInfo.fromJson(json['season'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'category': category,
    'diseases': diseases,
    'season': season?.toJson(),
  };
}

/// Season information for crops
class SeasonInfo {
  final String? planting;
  final String? harvest;

  SeasonInfo({this.planting, this.harvest});

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      planting: json['planting'] as String?,
      harvest: json['harvest'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'planting': planting, 'harvest': harvest};
}

/// Response wrapper for crops list
class CropsResponse {
  final bool success;
  final List<Crop> data;

  CropsResponse({required this.success, required this.data});

  factory CropsResponse.fromJson(Map<String, dynamic> json) {
    return CropsResponse(
      success: json['success'] as bool? ?? true,
      data: (json['data'] as List<dynamic>)
          .map((e) => Crop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
