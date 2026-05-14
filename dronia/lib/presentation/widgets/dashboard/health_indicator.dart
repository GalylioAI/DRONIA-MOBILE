import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';

/// Health score indicator with circular progress
class HealthIndicator extends StatelessWidget {
  final double healthScore;
  final String label;

  const HealthIndicator({
    super.key,
    required this.healthScore,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = UIHelper.getHealthColor(healthScore);
    final healthLevel = _getHealthLevel(healthScore);

    return Row(
      children: [
        // Circular progress indicator
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: healthScore / 100,
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${healthScore.toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 20),
        // Health details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(healthLevel.emoji, style: TextStyle(fontSize: 24)),
              SizedBox(height: 4),
              Text(
                healthLevel.displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _HealthLevel _getHealthLevel(double score) {
    if (score >= 80) return _HealthLevel.excellent;
    if (score >= 60) return _HealthLevel.good;
    if (score >= 40) return _HealthLevel.moderate;
    if (score >= 20) return _HealthLevel.poor;
    return _HealthLevel.critical;
  }
}

enum _HealthLevel {
  excellent,
  good,
  moderate,
  poor,
  critical;

  String get displayName {
    switch (this) {
      case _HealthLevel.excellent:
        return 'Excellent';
      case _HealthLevel.good:
        return 'Good';
      case _HealthLevel.moderate:
        return 'Moderate';
      case _HealthLevel.poor:
        return 'Poor';
      case _HealthLevel.critical:
        return 'Critical';
    }
  }

  String get emoji {
    switch (this) {
      case _HealthLevel.excellent:
        return '🌟';
      case _HealthLevel.good:
        return '✅';
      case _HealthLevel.moderate:
        return '⚠️';
      case _HealthLevel.poor:
        return '🔶';
      case _HealthLevel.critical:
        return '🔴';
    }
  }
}
