import 'package:flutter/material.dart';
import '../core/database/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = PreferencesService.isDarkMode;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    PreferencesService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      PreferencesService.setDarkMode(value);
      notifyListeners();
    }
  }
}
