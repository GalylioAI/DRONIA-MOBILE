import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Region model representing an agricultural zone
class Region {
  final String id;
  final String name;
  final List<LatLng> points;
  final double hectares;
  final Color color;
  final int humidity;
  final int temperature;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Region({
    required this.id,
    required this.name,
    required this.points,
    required this.hectares,
    required this.color,
    required this.humidity,
    required this.temperature,
    required this.createdAt,
    this.updatedAt,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      name: json['name'] as String,
      points: (json['points'] as List<dynamic>)
          .map(
            (p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ),
          )
          .toList(),
      hectares: (json['hectares'] as num).toDouble(),
      color: Color(json['color'] as int),
      humidity: json['humidity'] as int? ?? 60,
      temperature: json['temperature'] as int? ?? 25,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'hectares': hectares,
    'color': color.value,
    'humidity': humidity,
    'temperature': temperature,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Region copyWith({
    String? id,
    String? name,
    List<LatLng>? points,
    double? hectares,
    Color? color,
    int? humidity,
    int? temperature,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Region(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      hectares: hectares ?? this.hectares,
      color: color ?? this.color,
      humidity: humidity ?? this.humidity,
      temperature: temperature ?? this.temperature,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
