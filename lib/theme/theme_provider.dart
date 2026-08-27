import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Equivalente a io.amer.scanner.ThemeManager.
class ThemeProvider extends ChangeNotifier {
  static const int themeSystem = 0;
  static const int themeLight = 1;
  static const int themeDark = 2;

  static const String _prefName = 'theme_prefs';
  static const String _keyTheme = 'selected_theme';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  int get themeValue {
    if (_themeMode == ThemeMode.light) return themeLight;
    if (_themeMode == ThemeMode.dark) return themeDark;
    return themeSystem;
  }

  ThemeProvider() {
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_keyTheme) ?? themeSystem;
    _themeMode = _map(value);
    notifyListeners();
  }

  ThemeMode _map(int value) {
    switch (value) {
      case themeLight:
        return ThemeMode.light;
      case themeDark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveTheme(int theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, theme);
    _themeMode = _map(theme);
    notifyListeners();
  }
}
