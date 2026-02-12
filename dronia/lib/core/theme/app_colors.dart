import 'package:flutter/material.dart';

/// Application color palette
/// Based on Dronia website dark theme with green accents
class AppColors {
  AppColors._();

  // Primary Colors - Green (Agriculture theme - matches website)
  static const Color primaryGreen = Color(
    0xFF22C55E,
  ); // Bright green from website
  static const Color primaryGreenLight = Color(0xFF4ADE80);
  static const Color primaryGreenDark = Color(0xFF16A34A);
  static const Color tertiaryGreen = Color(0xFF10B981);

  // Accent Colors - For variety
  static const Color accentBrown = Color(0xFF8B5CF6); // Purple accent
  static const Color accentBrownLight = Color(0xFFA78BFA);
  static const Color accentBrownDark = Color(0xFF7C3AED);

  // Dark Theme Background Colors (matching website)
  static const Color backgroundDark = Color(0xFF0F172A); // Very dark blue-black
  static const Color backgroundDarkSecondary = Color(
    0xFF1E293B,
  ); // Slightly lighter
  static const Color cardDark = Color(0xFF1E293B); // Card background
  static const Color cardDarkElevated = Color(0xFF334155); // Elevated card
  static const Color surfaceDark = Color(0xFF0F172A);

  // Legacy Light Theme Colors (kept for compatibility)
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color backgroundLight = Color(0xFFF5F7F5);
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color surfaceGrey = Color(0xFF334155);

  // Text Colors for Dark Theme
  static const Color textPrimary = Color(0xFFF8FAFC); // White text
  static const Color textSecondary = Color(0xFF94A3B8); // Muted gray
  static const Color textHint = Color(0xFF64748B); // Even more muted
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Border & Divider Colors
  static const Color borderGrey = Color(0xFF334155);
  static const Color dividerGrey = Color(0xFF1E293B);
  static const Color dividerColor = Color(0xFF334155);

  // Status Colors (matching website badges)
  static const Color success = Color(0xFF22C55E); // Green
  static const Color successLight = Color(0xFF166534);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFF92400E);
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFF991B1B);
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF1E40AF);

  // Sensor Status Colors
  static const Color sensorOnline = Color(0xFF22C55E);
  static const Color sensorOffline = Color(0xFF64748B);
  static const Color sensorWarning = Color(0xFFF59E0B);
  static const Color sensorError = Color(0xFFEF4444);

  // Drone Status Colors
  static const Color droneActive = Color(0xFF22C55E);
  static const Color droneIdle = Color(0xFF3B82F6);
  static const Color droneCharging = Color(0xFFF59E0B);
  static const Color droneMaintenance = Color(0xFFEF4444);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF22C55E), // Primary Green
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  // Health Status Colors (for crop health)
  static const Color healthExcellent = Color(0xFF16A34A);
  static const Color healthGood = Color(0xFF22C55E);
  static const Color healthModerate = Color(0xFFF59E0B);
  static const Color healthPoor = Color(0xFFEF4444);
  static const Color healthCritical = Color(0xFF9333EA);

  // Gradient for cards and backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, tertiaryGreen],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBrown, accentBrownDark],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, backgroundLight],
  );
}
