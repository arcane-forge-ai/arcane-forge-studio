import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMockMode = true; // Default to mock mode for development
  bool _isDarkMode = true; // Default to dark mode (current theme)
  
  // Image Generation Settings
  ImageGenerationBackend _defaultGenerationServer = ImageGenerationConstants.defaultBackend;
  
  // Custom commands for each backend (initialized with defaults)
  final Map<ImageGenerationBackend, String> _customCommands = {
    for (var backend in ImageGenerationBackend.values)
      backend: ImageGenerationConstants.defaultCommands[backend] ?? '',
  };
  
  // Custom working directories for each backend (initialized with defaults)
  final Map<ImageGenerationBackend, String> _customWorkingDirectories = {
    for (var backend in ImageGenerationBackend.values)
      backend: ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '',
  };
  
  // Custom endpoints for each backend (initialized with defaults)
  final Map<ImageGenerationBackend, String> _customEndpoints = {
    for (var backend in ImageGenerationBackend.values)
      backend: ImageGenerationConstants.defaultEndpoints[backend] ?? '',
  };
  
  // Custom health check endpoints for each backend (initialized with defaults)
  final Map<ImageGenerationBackend, String> _customHealthCheckEndpoints = {
    for (var backend in ImageGenerationBackend.values)
      backend: ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '',
  };

  // Existing getters
  bool get useMockMode => _useMockMode;
  bool get isDarkMode => _isDarkMode;
  
  // Image Generation getters
  ImageGenerationBackend get defaultGenerationServer => _defaultGenerationServer;
  
  String getStartCommand(ImageGenerationBackend backend) {
    return _customCommands[backend] ?? ImageGenerationConstants.defaultCommands[backend] ?? '';
  }
  
  String getWorkingDirectory(ImageGenerationBackend backend) {
    return _customWorkingDirectories[backend] ?? ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '';
  }
  
  String getEndpoint(ImageGenerationBackend backend) {
    return _customEndpoints[backend] ?? ImageGenerationConstants.defaultEndpoints[backend] ?? '';
  }
  
  String getHealthCheckEndpoint(ImageGenerationBackend backend) {
    return _customHealthCheckEndpoints[backend] ?? ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '';
  }

  // Existing methods
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

  // Auto-save version of setMockMode
  void setMockModeAutoSave(bool value) {
    if (_useMockMode != value) {
      _useMockMode = value;
      notifyListeners();
      // Here you would typically call a save function
      // For now, we'll just notify listeners which will trigger UI updates
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

  // Auto-save version of setThemeMode
  void setThemeModeAutoSave(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
      // Here you would typically call a save function
      // For now, we'll just notify listeners which will trigger UI updates
    }
  }
  
  // Image Generation methods
  void setDefaultGenerationServer(ImageGenerationBackend backend) {
    if (_defaultGenerationServer != backend) {
      _defaultGenerationServer = backend;
      notifyListeners();
    }
  }

  // Auto-save version of setDefaultGenerationServer
  void setDefaultGenerationServerAutoSave(ImageGenerationBackend backend) {
    if (_defaultGenerationServer != backend) {
      _defaultGenerationServer = backend;
      notifyListeners();
      // Here you would typically call a save function
      // For now, we'll just notify listeners which will trigger UI updates
    }
  }
  
  void setStartCommand(ImageGenerationBackend backend, String command) {
    if (_customCommands[backend] != command) {
      _customCommands[backend] = command;
      notifyListeners();
    }
  }
  
  void setWorkingDirectory(ImageGenerationBackend backend, String directory) {
    if (_customWorkingDirectories[backend] != directory) {
      _customWorkingDirectories[backend] = directory;
      notifyListeners();
    }
  }
  
  void setEndpoint(ImageGenerationBackend backend, String endpoint) {
    if (_customEndpoints[backend] != endpoint) {
      _customEndpoints[backend] = endpoint;
      notifyListeners();
    }
  }
  
  void setHealthCheckEndpoint(ImageGenerationBackend backend, String endpoint) {
    if (_customHealthCheckEndpoints[backend] != endpoint) {
      _customHealthCheckEndpoints[backend] = endpoint;
      notifyListeners();
    }
  }
  
  void resetToDefaults(ImageGenerationBackend backend) {
    _customCommands[backend] = ImageGenerationConstants.defaultCommands[backend] ?? '';
    _customWorkingDirectories[backend] = ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '';
    _customEndpoints[backend] = ImageGenerationConstants.defaultEndpoints[backend] ?? '';
    _customHealthCheckEndpoints[backend] = ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '';
    notifyListeners();
  }
} 