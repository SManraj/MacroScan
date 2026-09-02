import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global singleton — access from any screen without passing through the tree,
// the same pattern used by authService in this codebase.
final themeNotifier = ThemeNotifier();

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'theme_mode'; // stored as: 'system' | 'light' | 'dark'

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Call once at app startup (before runApp) to restore the saved preference.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
      case ThemeMode.system:
        await prefs.setString(_key, 'system');
    }
  }

  /// Human-readable label for the settings UI.
  String get label {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
