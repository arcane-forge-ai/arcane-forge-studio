import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../models/download_models.dart';
import '../services/a1111_installer_service.dart';
import '../utils/app_constants.dart';
import '../services/settings_persistence_service.dart';
import 'package:dio/dio.dart';

class SettingsProvider extends ChangeNotifier {
  bool _useMockMode = false; // Default to live API mode
  bool _isDarkMode = true; // Default to dark mode (current theme)
  bool _isLoading = true; // Loading state for settings

  // API Settings
  String _apiBaseUrl = ApiConfig.defaultBaseUrl;
  bool _useApiService = ApiConfig.useApiService;

  // Image Generation Settings
  ImageGenerationBackend _defaultGenerationServer = ImageGenerationConstants.defaultBackend;
  A1111Mode _a1111Mode = ImageGenerationConstants.defaultA1111Mode;

  // A1111 installer state
  InstallerStatus a1111Status = InstallerStatus.idle;
  double? a1111Progress; // 0..1 when downloading
  int? a1111Received;
  int? a1111Total;
  String? a1111Error;
  CancelToken? _a1111CancelToken;
  final A1111InstallerService _installer = A1111InstallerService();

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

    // Check if A1111 is already installed
    if (!kIsWeb) {
      _checkA1111Installation();
    } else {
      a1111Status = InstallerStatus.completed;
    }
  }

  Future<void> _checkA1111Installation() async {
    if (kIsWeb) return;

    final packagesDir = Directory('packages');
    final isInstalled = await _installer.isInstalled(packagesDir);
    if (isInstalled) {
      a1111Status = InstallerStatus.completed;
      notifyListeners();
    }
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
    _apiBaseUrl = _normalizeApiUrl(dotenv.env['API_BASE_URL'] ?? ApiConfig.defaultBaseUrl);
    _useApiService = dotenv.env['USE_API_SERVICE']?.toLowerCase() == 'true' || ApiConfig.useApiService;

    // A1111 Mode from dotenv
    final a1111ModeString = dotenv.env['A1111_MODE']?.toLowerCase();
    if (a1111ModeString == 'online') {
      _a1111Mode = A1111Mode.online;
    } else if (a1111ModeString == 'local') {
      _a1111Mode = A1111Mode.local;
    } else {
      // If not specified or invalid, use the default from constants
      _a1111Mode = ImageGenerationConstants.defaultA1111Mode;
    }

    debugPrint('🌍 Loaded from environment:');
    debugPrint('   API Base URL: $_apiBaseUrl');
    debugPrint('   Use API Service: $_useApiService');
    debugPrint('   A1111 Mode: $_a1111Mode');

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
    _apiBaseUrl = _normalizeApiUrl(settingsData.apiBaseUrl);
    _useApiService = settingsData.useApiService;
    _defaultGenerationServer = settingsData.defaultGenerationServer;
    _outputDirectory = settingsData.outputDirectory;
    _a1111Mode = settingsData.a1111Mode;
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

  // Helper method to normalize API URL by removing trailing slashes
  String _normalizeApiUrl(String url) {
    // Remove all trailing slashes
    while (url.endsWith('/') && url.length > 1) {
      url = url.substring(0, url.length - 1);
    }
    return url;
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
  A1111Mode get a1111Mode => _a1111Mode;
  
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
    // Normalize URL to remove trailing slashes
    final normalizedUrl = _normalizeApiUrl(url);
    if (_apiBaseUrl != normalizedUrl) {
      _apiBaseUrl = normalizedUrl;
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

  void setA1111Mode(A1111Mode mode) {
    if (_a1111Mode != mode) {
      _a1111Mode = mode;
      notifyListeners();
      _saveSettings();
    }
  }

  // A1111 install controls
  Future<void> startA1111Install({String? urlOverride}) async {
    if (a1111Status == InstallerStatus.downloading || a1111Status == InstallerStatus.extracting) {
      return;
    }

    a1111Status = InstallerStatus.downloading;
    a1111Progress = 0;
    a1111Received = 0;
    a1111Total = null;
    a1111Error = null;
    notifyListeners();

    final url = urlOverride ?? ImageGenerationConstants.a1111ZipUrl;
    final packagesDir = Directory('packages');
    _a1111CancelToken = CancelToken();

    try {
      await _installer.downloadAndInstall(
        url: url,
        baseDir: packagesDir,
        cancelToken: _a1111CancelToken,
        onProgress: (progress) {
          final oldStatus = a1111Status;
          
          // Update state silently (no notifyListeners during download progress)
          a1111Status = progress.status;
          a1111Progress = progress.fraction;
          a1111Received = progress.receivedBytes;
          a1111Total = progress.totalBytes;
          a1111Error = progress.message;
          
          // Only notify on actual status changes (downloading -> extracting -> completed/error)
          // Settings screen will poll for progress updates when active
          if (oldStatus != a1111Status) {
            notifyListeners();
          }
        },
      );

      if (a1111Status == InstallerStatus.completed) {
        setWorkingDirectory(ImageGenerationBackend.automatic1111, 'packages/automatic1111/');
      }
    } catch (e) {
      a1111Status = InstallerStatus.error;
      a1111Error = e.toString();
      notifyListeners();
    } finally {
      _a1111CancelToken = null;
    }
  }

  void cancelA1111Install() {
    _a1111CancelToken?.cancel('User cancelled');
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
        a1111Mode: _a1111Mode,
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
        _apiBaseUrl = data.apiBaseUrl.endsWith('/') && data.apiBaseUrl.length > 1
            ? data.apiBaseUrl.substring(0, data.apiBaseUrl.length - 1)
            : data.apiBaseUrl,
        _useApiService = data.useApiService,
        _defaultGenerationServer = data.defaultGenerationServer,
        _outputDirectory = data.outputDirectory,
        _a1111Mode = data.a1111Mode,
        _customCommands = Map.from(data.customCommands),
        _customWorkingDirectories = Map.from(data.customWorkingDirectories),
        _customEndpoints = Map.from(data.customEndpoints),
        _customHealthCheckEndpoints = Map.from(data.customHealthCheckEndpoints);
} 