import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMockMode = true; // Default to mock mode for development
  bool _isDarkMode = true; // Default to dark mode (current theme)

  bool get useMockMode => _useMockMode;
  bool get isDarkMode => _isDarkMode;

  void toggleMockMode() {
    _useMockMode = !_useMockMode;
    notifyListeners();
  }

  void setMockMode(bool value) {
    if (_useMockMode != value) {
      _useMockMode = value;
      notifyListeners();
    }
  }

  void toggleThemeMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setThemeMode(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }
} 