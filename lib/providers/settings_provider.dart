import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMockMode = true; // Default to mock mode for development

  bool get useMockMode => _useMockMode;

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
} 