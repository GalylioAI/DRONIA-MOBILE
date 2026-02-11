// Example: How to use backend services in screens
//
// This file demonstrates patterns for using all backend services
// Use these patterns to replace mock data with real API calls

import '../services/services.dart';
import '../models/models.dart';

// ============================================================
// WEATHER SERVICE EXAMPLES
// ============================================================

/// Get current weather for user's location
Future<void> fetchCurrentWeather({
  required double lat,
  required double lng,
}) async {
  try {
    final weather = await services.weather.getCurrentWeather(
      lat: lat,
      lng: lng,
    );

    print('Temperature: ${weather.temperatureDisplay}');
    print('Humidity: ${weather.humidityDisplay}');
    print('Wind: ${weather.windSpeedDisplay} ${weather.windDirection}');
    print('Description: ${weather.description}');
    print('Icon URL: ${weather.iconUrl}');
  } catch (e) {
    print('Error fetching weather: $e');
  }
}

/// Get 7-day forecast
Future<void> fetchForecast({double? lat, double? lng, String? country}) async {
  try {
    final response = await services.weather.getForecast(
      lat: lat,
      lng: lng,
      country: country,
      days: 7,
    );

    for (final day in response.forecast) {
      print('${day.date}: ${day.tempMin}°C - ${day.tempMax}°C');
    }
  } catch (e) {
    print('Error fetching forecast: $e');
  }
}

// ============================================================
// PREDICTION SERVICE EXAMPLES
// ============================================================

/// Analyze an image for disease detection
Future<Prediction?> analyzeImage({
  required String base64Image,
  required double lat,
  required double lng,
  required String region,
}) async {
  try {
    final prediction = await services.predictions.analyzeBase64Image(
      base64Image: base64Image,
      region: region,
      lat: lat,
      lng: lng,
    );

    print('Disease: ${prediction.result.disease}');
    print(
      'Confidence: ${(prediction.result.confidence * 100).toStringAsFixed(1)}%',
    );
    print('Severity: ${prediction.result.severity}');
    print('Status: ${prediction.result.generalStatus}');

    if (prediction.result.recommendations != null) {
      print('Treatment: ${prediction.result.recommendations!.treatment}');
      print('Prevention: ${prediction.result.recommendations!.prevention}');
    }

    return prediction;
  } catch (e) {
    print('Error analyzing image: $e');
    return null;
  }
}

/// Get prediction history
Future<List<Prediction>> fetchPredictionHistory() async {
  try {
    return await services.predictions.getPredictions();
  } catch (e) {
    print('Error fetching predictions: $e');
    return [];
  }
}

// ============================================================
// SOIL DATA SERVICE EXAMPLES
// ============================================================

/// Get comprehensive soil data
Future<SoilData?> fetchSoilData({
  required double lat,
  required double lon,
}) async {
  try {
    final data = await services.soilData.getSoilData(lat: lat, lon: lon);

    print('Soil Moisture Status: ${data.soilMoisture.status}');
    print('Average Soil Temp: ${data.soilTemperature.average}°C');
    print('Air Quality: ${data.airQuality.category}');
    print('Overall Pest Risk: ${data.pestRisk.overallRisk}');

    // Active pests
    for (final pest in data.pestRisk.pests.where((p) => p.isActive)) {
      print('Active Pest: ${pest.name} (${pest.icon})');
    }

    return data;
  } catch (e) {
    print('Error fetching soil data: $e');
    return null;
  }
}

// ============================================================
// ADVISOR SERVICE EXAMPLES
// ============================================================

/// Get AI-powered advisories
Future<List<Advisory>> fetchAdvisories({
  required double lat,
  required double lng,
  String? crop,
}) async {
  try {
    return await services.advisor.getAdvisories(lat: lat, lng: lng, crop: crop);
  } catch (e) {
    print('Error fetching advisories: $e');
    return [];
  }
}

/// Chat with AI advisor
Future<String> askAdvisor({
  required String question,
  double? lat,
  double? lng,
  String? cropType,
}) async {
  try {
    final response = await services.advisor.sendMessage(
      message: question,
      lat: lat,
      lng: lng,
      cropType: cropType,
    );

    return response.content;
  } catch (e) {
    print('Error chatting with advisor: $e');
    return 'Désolé, je n\'ai pas pu répondre à votre question.';
  }
}

// ============================================================
// CROP SERVICE EXAMPLES
// ============================================================

/// Get all available crops
Future<List<Crop>> fetchCrops() async {
  try {
    return await services.crops.getCrops();
  } catch (e) {
    print('Error fetching crops: $e');
    return [];
  }
}

/// Search crops
Future<List<Crop>> searchCrops(String query) async {
  try {
    return await services.crops.searchCrops(query);
  } catch (e) {
    print('Error searching crops: $e');
    return [];
  }
}

// ============================================================
// SATELLITE SERVICE EXAMPLES
// ============================================================

/// Get NDVI satellite data
Future<NdviResult?> fetchNdviData({
  required double lat,
  required double lng,
}) async {
  try {
    return await services.satellite.getLatestNdvi(
      latitude: lat,
      longitude: lng,
    );
  } catch (e) {
    print('Error fetching NDVI data: $e');
    return null;
  }
}

// ============================================================
// DASHBOARD DATA AGGREGATION EXAMPLE
// ============================================================

/// Aggregate all data for dashboard
Future<DashboardData> fetchDashboardData({
  required double lat,
  required double lng,
  String? crop,
}) async {
  // Fetch data in parallel for better performance
  // Using separate try-catch for nullable results
  CurrentWeather? weather;
  SoilData? soilData;
  List<Advisory> advisories = [];
  List<Prediction> predictions = [];

  try {
    final results = await Future.wait(
      [
        services.weather.getCurrentWeather(lat: lat, lng: lng),
        services.soilData.getSoilData(lat: lat, lon: lng),
        services.advisor.getAdvisories(lat: lat, lng: lng, crop: crop),
        services.predictions.getPredictions(),
      ].map((future) => future.catchError((e) => throw e)),
    );

    weather = results[0] as CurrentWeather?;
    soilData = results[1] as SoilData?;
    advisories = results[2] as List<Advisory>;
    predictions = results[3] as List<Prediction>;
  } catch (_) {
    // Individual fetches with error handling
    try {
      weather = await services.weather.getCurrentWeather(lat: lat, lng: lng);
    } catch (_) {}
    try {
      soilData = await services.soilData.getSoilData(lat: lat, lon: lng);
    } catch (_) {}
    try {
      advisories = await services.advisor.getAdvisories(
        lat: lat,
        lng: lng,
        crop: crop,
      );
    } catch (_) {}
    try {
      predictions = await services.predictions.getPredictions();
    } catch (_) {}
  }

  return DashboardData(
    weather: weather,
    soilData: soilData,
    advisories: advisories,
    recentPredictions: predictions,
  );
}

/// Dashboard data model
class DashboardData {
  final CurrentWeather? weather;
  final SoilData? soilData;
  final List<Advisory> advisories;
  final List<Prediction> recentPredictions;

  DashboardData({
    this.weather,
    this.soilData,
    this.advisories = const [],
    this.recentPredictions = const [],
  });

  int get healthyPlantCount =>
      recentPredictions.where((p) => p.result.isHealthy).length;

  int get diseasedPlantCount =>
      recentPredictions.where((p) => !p.result.isHealthy).length;

  int get highPriorityAdvisoryCount =>
      advisories.where((a) => a.priority == AdvisoryPriority.high).length;
}
