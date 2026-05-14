import 'package:flutter/material.dart';

/// Application color palette — supports both dark and light themes.
///
/// ## Usage
/// - **Brand colors** (primary, accent, status) are theme-agnostic and used directly
///   (e.g. `AppColors.primaryGreen`).
/// - **Surface/text colors** differ between themes: prefer the context extension
///   `context.colors.bg`, `context.colors.textPrimary`, etc. (see [AppPalette] and
///   [ColorsContextExtension] in this file).
/// - The legacy dark constants (`backgroundDark`, `cardDark`, `textPrimary`, …) are
///   kept for backward compatibility — they still point to the dark-theme values.
class AppColors {
  AppColors._();

  // ─── Brand colors (theme-agnostic) ──────────────────────────────────────
  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color primaryGreenLight = Color(0xFF4ADE80);
  static const Color primaryGreenDark = Color(0xFF16A34A);
  static const Color tertiaryGreen = Color(0xFF10B981);

  static const Color accentBrown = Color(0xFF8B5CF6);
  static const Color accentBrownLight = Color(0xFFA78BFA);
  static const Color accentBrownDark = Color(0xFF7C3AED);

  // ─── DARK palette ───────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgDarkSecondary = Color(0xFF1E293B);
  static const Color cardDarkBase = Color(0xFF1E293B);
  static const Color cardDarkElevatedBase = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textHintDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);

  // ─── LIGHT palette ──────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF8FAFC); // slate-50
  static const Color bgLightSecondary = Color(0xFFF1F5F9); // slate-100
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardLightElevated = Color(0xFFFAFAFA);
  static const Color textPrimaryLight = Color(0xFF0F172A); // slate-900
  static const Color textSecondaryLight = Color(0xFF475569); // slate-600
  static const Color textHintLight = Color(0xFF94A3B8); // slate-400
  static const Color borderLight = Color(0xFFE2E8F0); // slate-200
  static const Color dividerLight = Color(0xFFF1F5F9);

  // ─── Legacy aliases (dark values — kept so existing screens keep compiling) ──
  static const Color backgroundDark = bgDark;
  static const Color backgroundDarkSecondary = bgDarkSecondary;
  static const Color cardDark = cardDarkBase;
  static const Color cardDarkElevated = cardDarkElevatedBase;
  static const Color surfaceDark = bgDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textHint = textHintDark;
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color borderGrey = borderDark;
  static const Color dividerGrey = bgDarkSecondary;
  static const Color dividerColor = borderDark;

  // ─── Legacy light aliases (kept for compatibility) ──────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color backgroundLight = bgLight;
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color surfaceGrey = Color(0xFF334155);

  // ─── Status colors (shared) ─────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF166534);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFF92400E);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFF991B1B);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF1E40AF);

  // ─── Domain colors (shared) ─────────────────────────────────────────────
  static const Color sensorOnline = Color(0xFF22C55E);
  static const Color sensorOffline = Color(0xFF64748B);
  static const Color sensorWarning = Color(0xFFF59E0B);
  static const Color sensorError = Color(0xFFEF4444);

  static const Color droneActive = Color(0xFF22C55E);
  static const Color droneIdle = Color(0xFF3B82F6);
  static const Color droneCharging = Color(0xFFF59E0B);
  static const Color droneMaintenance = Color(0xFFEF4444);

  static const List<Color> chartColors = [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  static const Color healthExcellent = Color(0xFF16A34A);
  static const Color healthGood = Color(0xFF22C55E);
  static const Color healthModerate = Color(0xFFF59E0B);
  static const Color healthPoor = Color(0xFFEF4444);
  static const Color healthCritical = Color(0xFF9333EA);

  // ─── Gradients ──────────────────────────────────────────────────────────
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
    colors: [white, bgLight],
  );
}

/// Theme-aware palette resolved from a [BuildContext].
///
/// Prefer using this over hardcoded `AppColors.backgroundDark` etc. in new
/// screens. Access via `context.colors.bg`, `context.colors.card`, etc.
class AppPalette {
  final bool isDark;

  const AppPalette(this.isDark);

  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get bgSecondary =>
      isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary;
  Color get card => isDark ? AppColors.cardDarkBase : AppColors.cardLight;
  Color get cardElevated =>
      isDark ? AppColors.cardDarkElevatedBase : AppColors.cardLightElevated;
  Color get textPrimary =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textHint =>
      isDark ? AppColors.textHintDark : AppColors.textHintLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get divider => isDark ? AppColors.dividerDark : AppColors.dividerLight;
}

/// Extension giving every widget access to the current [AppPalette] via
/// `context.colors`. Resolves based on `Theme.of(context).brightness`.
extension ColorsContextExtension on BuildContext {
  AppPalette get colors =>
      AppPalette(Theme.of(this).brightness == Brightness.dark);
}
