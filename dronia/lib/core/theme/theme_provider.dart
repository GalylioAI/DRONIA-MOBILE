import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's [ThemeMode] (light/dark/system) with SharedPreferences
/// persistence. Register once at the root of the app via [ChangeNotifierProvider]
/// and consume via `context.watch<ThemeProvider>()` to rebuild when the mode
/// changes.
class ThemeProvider extends ChangeNotifier {
  static const String _storageKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _hydrated = false;

  ThemeMode get themeMode => _themeMode;
  bool get isHydrated => _hydrated;

  /// True iff the current mode resolves to dark.
  /// For `ThemeMode.system`, the caller should use `Theme.of(context).brightness`
  /// instead — this getter returns a best-effort guess for UI toggles.
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Loads the persisted theme mode from SharedPreferences. Safe to call
  /// multiple times — hydrates only once.
  Future<void> hydrate() async {
    if (_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      _themeMode = _parseMode(stored) ?? ThemeMode.dark;
    } catch (_) {
      _themeMode = ThemeMode.dark;
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _encodeMode(mode));
    } catch (_) {
      // Persistence failure is non-fatal — in-memory mode still applies.
    }
  }

  Future<void> toggle() async {
    await setThemeMode(_themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark);
  }

  static ThemeMode? _parseMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _encodeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
