import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';
import '../services/settings_persistence_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMockMode = false; // Default to live API mode
  bool _isDarkMode = true; // Default to dark mode (current theme)
  bool _isLoading = true; // Loading state for settings

  // API Settings
  String _apiBaseUrl = ApiConfig.defaultBaseUrl;
  bool _useApiService = ApiConfig.useApiService;

  // Image Generation Settings
  ImageGenerationBackend _defaultGenerationServer = ImageGenerationConstants.defaultBackend;

  SettingsProvider() {
    // Initialize late fields with defaults first
    _customCommands = {
      for (var backend in ImageGenerationBackend.values)
        backend: ImageGenerationConstants.defaultCommands[backend] ?? '',
    };
    _customWorkingDirectories = {
      for (var backend in ImageGenerationBackend.values)
        backend: ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '',
    };
    _customEndpoints = {
      for (var backend in ImageGenerationBackend.values)
        backend: ImageGenerationConstants.defaultEndpoints[backend] ?? '',
    };
    _customHealthCheckEndpoints = {
      for (var backend in ImageGenerationBackend.values)
        backend: ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '',
    };

    // Load settings from storage asynchronously
    _loadSettingsFromStorage();
  }

  /// Asynchronously load settings from storage and update the provider
  Future<void> _loadSettingsFromStorage() async {
    try {
      // Check environment to determine settings source
      const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
      final isDevelopment = environment.toLowerCase() == 'development';

      debugPrint('🔧 Environment detected: $environment');
      debugPrint('🏠 Development mode: $isDevelopment');

      if (isDevelopment) {
        debugPrint('📋 Using dotenv values for development (ignoring persisted settings)');
        _loadFromEnvironment();
      } else {
        debugPrint('💾 Loading settings from SharedPreferences');
        await _loadFromStorage();
      }
    } catch (e) {
      debugPrint('Error in settings loading logic: $e');
      // Keep default values if loading fails
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load settings from dotenv (for development)
  void _loadFromEnvironment() {
    // API Settings from dotenv
    _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? ApiConfig.defaultBaseUrl;
    _useApiService = dotenv.env['USE_API_SERVICE']?.toLowerCase() == 'true' || ApiConfig.useApiService;

    debugPrint('🌍 Loaded from environment:');
    debugPrint('   API Base URL: $_apiBaseUrl');
    debugPrint('   Use API Service: $_useApiService');

    // Keep other settings as defaults for development
    _useMockMode = false; // Default to live API mode for development
    _isDarkMode = true; // Default to dark mode

    // Settings loaded, no longer loading
    _isLoading = false;

    // Notify listeners that settings have been loaded
    notifyListeners();
  }

  /// Load settings from SharedPreferences (for production)
  Future<void> _loadFromStorage() async {
    final settingsData = await SettingsPersistenceService.loadSettings();

    // Update fields with loaded data
    _useMockMode = settingsData.useMockMode;
    _isDarkMode = settingsData.isDarkMode;
    _apiBaseUrl = settingsData.apiBaseUrl;
    _useApiService = settingsData.useApiService;
    _defaultGenerationServer = settingsData.defaultGenerationServer;
    _outputDirectory = settingsData.outputDirectory;
    _customCommands = Map.from(settingsData.customCommands);
    _customWorkingDirectories = Map.from(settingsData.customWorkingDirectories);
    _customEndpoints = Map.from(settingsData.customEndpoints);
    _customHealthCheckEndpoints = Map.from(settingsData.customHealthCheckEndpoints);

    debugPrint('💾 Loaded from storage:');
    debugPrint('   API Base URL: $_apiBaseUrl');
    debugPrint('   Use Mock Mode: $_useMockMode');
    debugPrint('   Dark Mode: $_isDarkMode');

    // Show SharedPreferences file location
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('📁 SharedPreferences file location: ${prefs.toString()}');
    } catch (e) {
      debugPrint('Could not determine SharedPreferences location: $e');
    }

    // Settings loaded, no longer loading
    _isLoading = false;

    // Notify listeners that settings have been loaded
    notifyListeners();
  }

  // Custom commands for each backend (initialized with defaults)
  late Map<ImageGenerationBackend, String> _customCommands;

  // Custom working directories for each backend (initialized with defaults)
  late Map<ImageGenerationBackend, String> _customWorkingDirectories;

  // Custom endpoints for each backend (initialized with defaults)
  late Map<ImageGenerationBackend, String> _customEndpoints;

  // Custom health check endpoints for each backend (initialized with defaults)
  late Map<ImageGenerationBackend, String> _customHealthCheckEndpoints;

  // Output directory for generated images
  String _outputDirectory = AppConstants.defaultOutputDirectory; // Use default from AppConstants
  String get outputDirectory => _outputDirectory;
  void setOutputDirectory(String dir) {
    if (_outputDirectory != dir) {
      _outputDirectory = dir;
      notifyListeners();
      _saveSettings();
    }
  }

  // Existing getters
  bool get useMockMode => _useMockMode;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  
  // API getters
  String get apiBaseUrl => _apiBaseUrl;
  bool get useApiService => _useApiService;
  
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
      _saveSettings();
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
      _saveSettings();
    }
  }
  
  // API methods
  void setApiBaseUrl(String url) {
    if (_apiBaseUrl != url) {
      _apiBaseUrl = url;
      notifyListeners();
      _saveSettings();
    }
  }
  
  void setUseApiService(bool value) {
    if (_useApiService != value) {
      _useApiService = value;
      notifyListeners();
    }
  }
  
  // Auto-save version of setUseApiService
  void setUseApiServiceAutoSave(bool value) {
    if (_useApiService != value) {
      _useApiService = value;
      notifyListeners();
      _saveSettings();
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
      _saveSettings();
    }
  }
  
  void setStartCommand(ImageGenerationBackend backend, String command) {
    if (_customCommands[backend] != command) {
      _customCommands[backend] = command;
      notifyListeners();
      _saveSettings();
    }
  }

  void setWorkingDirectory(ImageGenerationBackend backend, String directory) {
    if (_customWorkingDirectories[backend] != directory) {
      _customWorkingDirectories[backend] = directory;
      notifyListeners();
      _saveSettings();
    }
  }

  void setEndpoint(ImageGenerationBackend backend, String endpoint) {
    if (_customEndpoints[backend] != endpoint) {
      _customEndpoints[backend] = endpoint;
      notifyListeners();
      _saveSettings();
    }
  }

  void setHealthCheckEndpoint(ImageGenerationBackend backend, String endpoint) {
    if (_customHealthCheckEndpoints[backend] != endpoint) {
      _customHealthCheckEndpoints[backend] = endpoint;
      notifyListeners();
      _saveSettings();
    }
  }
  
  void resetToDefaults(ImageGenerationBackend backend) {
    _customCommands[backend] = ImageGenerationConstants.defaultCommands[backend] ?? '';
    _customWorkingDirectories[backend] = ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '';
    _customEndpoints[backend] = ImageGenerationConstants.defaultEndpoints[backend] ?? '';
    _customHealthCheckEndpoints[backend] = ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '';
    notifyListeners();
    _saveSettings();
  }

  /// Private method to save current settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      // Check if we're in development mode
      const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
      final isDevelopment = environment.toLowerCase() == 'development';

      if (isDevelopment) {
        debugPrint('🚫 Skipping settings save in development mode');
        return;
      }

      debugPrint('💾 Saving settings to SharedPreferences');
      await SettingsPersistenceService.saveSettings(
        useMockMode: _useMockMode,
        isDarkMode: _isDarkMode,
        apiBaseUrl: _apiBaseUrl,
        useApiService: _useApiService,
        defaultGenerationServer: _defaultGenerationServer,
        outputDirectory: _outputDirectory,
        customCommands: _customCommands,
        customWorkingDirectories: _customWorkingDirectories,
        customEndpoints: _customEndpoints,
        customHealthCheckEndpoints: _customHealthCheckEndpoints,
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Load settings from persistent storage
  static Future<SettingsProvider> loadFromStorage() async {
    final settingsData = await SettingsPersistenceService.loadSettings();

    return SettingsProvider._fromLoadedData(settingsData);
  }

  /// Private constructor for loading from storage
  SettingsProvider._fromLoadedData(SettingsData data)
      : _useMockMode = data.useMockMode,
        _isDarkMode = data.isDarkMode,
        _apiBaseUrl = data.apiBaseUrl,
        _useApiService = data.useApiService,
        _defaultGenerationServer = data.defaultGenerationServer,
        _outputDirectory = data.outputDirectory,
        _customCommands = Map.from(data.customCommands),
        _customWorkingDirectories = Map.from(data.customWorkingDirectories),
        _customEndpoints = Map.from(data.customEndpoints),
        _customHealthCheckEndpoints = Map.from(data.customHealthCheckEndpoints);
} 