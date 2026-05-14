import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

/// Service to browse the PlantVillage dataset images via backend API.
class DatasetService {
  static String get _baseUrl => AppConstants.baseUrl;

  /// PlantVillage disease IDs that have dataset folders.
  static const Set<String> _datasetDiseaseIds = {
    'apple_scab',
    'apple_black_rot',
    'apple_cedar_rust',
    'apple_healthy',
    'blueberry_healthy',
    'cherry_powdery_mildew',
    'cherry_healthy',
    'corn_gray_leaf_spot',
    'corn_common_rust',
    'corn_northern_leaf_blight',
    'corn_healthy',
    'grape_black_rot',
    'grape_esca',
    'grape_leaf_blight',
    'grape_healthy',
    'orange_citrus_greening',
    'peach_bacterial_spot',
    'peach_healthy',
    'pepper_bacterial_spot',
    'pepper_healthy',
    'potato_early_blight',
    'potato_late_blight',
    'potato_healthy',
    'raspberry_healthy',
    'soybean_healthy',
    'squash_powdery_mildew',
    'strawberry_leaf_scorch',
    'strawberry_healthy',
    'tomato_bacterial_spot',
    'tomato_early_blight',
    'tomato_late_blight',
    'tomato_leaf_mold',
    'tomato_septoria',
    'tomato_spider_mites',
    'tomato_target_spot',
    'tomato_yellow_leaf_curl',
    'tomato_mosaic_virus',
    'tomato_healthy',
  };

  /// Check if a disease ID has dataset images.
  static bool hasDatasetImages(String diseaseId) =>
      _datasetDiseaseIds.contains(diseaseId);

  /// Get paginated images for a disease class.
  static Future<DatasetImagesResult> getImages({
    required String diseaseId,
    String split = 'train',
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/dataset/images/$diseaseId?split=$split&page=$page&per_page=$perPage',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DatasetImagesResult.fromJson(data);
    }
    throw Exception('Failed to load images: ${response.statusCode}');
  }

  /// Get random sample images for a disease class.
  static Future<List<DatasetImage>> getRandomImages({
    required String diseaseId,
    int count = 5,
    String split = 'train',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/dataset/random/$diseaseId?count=$count&split=$split',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final images = (data['images'] as List)
          .map((e) => DatasetImage.fromJson(e as Map<String, dynamic>))
          .toList();
      return images;
    }
    return [];
  }

  /// Get full image URL from relative path.
  static String imageUrl(String relativePath) {
    return '$_baseUrl$relativePath';
  }

  /// Get dataset statistics.
  static Future<Map<String, dynamic>> getStats() async {
    final uri = Uri.parse('$_baseUrl/dataset/stats');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load stats: ${response.statusCode}');
  }
}

class DatasetImagesResult {
  final String diseaseId;
  final String split;
  final int total;
  final int page;
  final int perPage;
  final int totalPages;
  final List<DatasetImage> images;

  DatasetImagesResult({
    required this.diseaseId,
    required this.split,
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
    required this.images,
  });

  factory DatasetImagesResult.fromJson(Map<String, dynamic> json) {
    return DatasetImagesResult(
      diseaseId: json['diseaseId'] as String? ?? '',
      split: json['split'] as String? ?? 'train',
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      perPage: json['perPage'] as int? ?? 20,
      totalPages: json['totalPages'] as int? ?? 0,
      images:
          (json['images'] as List?)
              ?.map((e) => DatasetImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DatasetImage {
  final String filename;
  final String url;

  DatasetImage({required this.filename, required this.url});

  factory DatasetImage.fromJson(Map<String, dynamic> json) {
    return DatasetImage(
      filename: json['filename'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  /// Get the full URL for rendering.
  String get fullUrl => DatasetService.imageUrl(url);
}
