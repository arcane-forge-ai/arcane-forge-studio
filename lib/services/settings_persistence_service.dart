import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import 'package:path_provider/path_provider.dart';

/// Service for persisting and loading user settings using SharedPreferences
class SettingsPersistenceService {
  static const String _keyUseMockMode = 'useMockMode';
  static const String _keyIsDarkMode = 'isDarkMode';
  static const String _keyApiBaseUrl = 'apiBaseUrl';
  static const String _keyUseApiService = 'useApiService';
  static const String _keyDefaultGenerationServer = 'defaultGenerationServer';
  static const String _keyOutputDirectory = 'outputDirectory';
  static const String _keyA1111Mode = 'a1111Mode';

  // Image Generation Backend specific settings
  static const String _keyStartCommandPrefix = 'startCommand_';
  static const String _keyWorkingDirectoryPrefix = 'workingDirectory_';
  static const String _keyEndpointPrefix = 'endpoint_';
  static const String _keyHealthCheckEndpointPrefix = 'healthCheckEndpoint_';

  /// Save all current settings to persistent storage
  static Future<void> saveSettings({
    required bool useMockMode,
    required bool isDarkMode,
    required String apiBaseUrl,
    required bool useApiService,
    required ImageGenerationBackend defaultGenerationServer,
    required String outputDirectory,
    required A1111Mode a1111Mode,
    required Map<ImageGenerationBackend, String> customCommands,
    required Map<ImageGenerationBackend, String> customWorkingDirectories,
    required Map<ImageGenerationBackend, String> customEndpoints,
    required Map<ImageGenerationBackend, String> customHealthCheckEndpoints,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Log the SharedPreferences file location
      debugPrint('📁 Saving settings to SharedPreferences');
      debugPrint('   File location: ${prefs.toString()}');

      // Basic settings
      await prefs.setBool(_keyUseMockMode, useMockMode);
      await prefs.setBool(_keyIsDarkMode, isDarkMode);
      await prefs.setString(_keyApiBaseUrl, apiBaseUrl);
      await prefs.setBool(_keyUseApiService, useApiService);
      await prefs.setString(_keyDefaultGenerationServer, defaultGenerationServer.name);
      await prefs.setString(_keyOutputDirectory, outputDirectory);
      await prefs.setString(_keyA1111Mode, a1111Mode.name);

      // Image Generation Backend specific settings
      for (var backend in ImageGenerationBackend.values) {
        await prefs.setString('$_keyStartCommandPrefix${backend.name}', customCommands[backend] ?? '');
        await prefs.setString('$_keyWorkingDirectoryPrefix${backend.name}', customWorkingDirectories[backend] ?? '');
        await prefs.setString('$_keyEndpointPrefix${backend.name}', customEndpoints[backend] ?? '');
        await prefs.setString('$_keyHealthCheckEndpointPrefix${backend.name}', customHealthCheckEndpoints[backend] ?? '');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Load all settings from persistent storage
  static Future<SettingsData> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = await getApplicationSupportDirectory();

      // Log the SharedPreferences file location
      debugPrint('📁 Loading settings from SharedPreferences');
      debugPrint('   File location: ${dir.toString()}');

      // Basic settings with defaults
      final useMockMode = prefs.getBool(_keyUseMockMode) ?? false;
      final isDarkMode = prefs.getBool(_keyIsDarkMode) ?? true;
      final apiBaseUrl = prefs.getString(_keyApiBaseUrl) ?? ApiConfig.defaultBaseUrl;
      final useApiService = prefs.getBool(_keyUseApiService) ?? ApiConfig.useApiService;
      final outputDirectory = prefs.getString(_keyOutputDirectory) ?? AppConstants.defaultOutputDirectory;

      // Default generation server
      final defaultServerName = prefs.getString(_keyDefaultGenerationServer) ?? ImageGenerationConstants.defaultBackend.name;
      final defaultGenerationServer = ImageGenerationBackend.values.firstWhere(
        (backend) => backend.name == defaultServerName,
        orElse: () => ImageGenerationConstants.defaultBackend,
      );

      // A1111 mode
      final a1111ModeName = prefs.getString(_keyA1111Mode) ?? ImageGenerationConstants.defaultA1111Mode.name;
      final a1111Mode = A1111Mode.values.firstWhere(
        (mode) => mode.name == a1111ModeName,
        orElse: () => ImageGenerationConstants.defaultA1111Mode,
      );

      // Image Generation Backend specific settings
      final customCommands = <ImageGenerationBackend, String>{};
      final customWorkingDirectories = <ImageGenerationBackend, String>{};
      final customEndpoints = <ImageGenerationBackend, String>{};
      final customHealthCheckEndpoints = <ImageGenerationBackend, String>{};

      for (var backend in ImageGenerationBackend.values) {
        customCommands[backend] = prefs.getString('$_keyStartCommandPrefix${backend.name}') ?? ImageGenerationConstants.defaultCommands[backend] ?? '';
        customWorkingDirectories[backend] = prefs.getString('$_keyWorkingDirectoryPrefix${backend.name}') ?? ImageGenerationConstants.defaultWorkingDirectories[backend] ?? '';
        customEndpoints[backend] = prefs.getString('$_keyEndpointPrefix${backend.name}') ?? ImageGenerationConstants.defaultEndpoints[backend] ?? '';
        customHealthCheckEndpoints[backend] = prefs.getString('$_keyHealthCheckEndpointPrefix${backend.name}') ?? ImageGenerationConstants.defaultHealthCheckEndpoints[backend] ?? '';
      }

      return SettingsData(
        useMockMode: useMockMode,
        isDarkMode: isDarkMode,
        apiBaseUrl: apiBaseUrl,
        useApiService: useApiService,
        defaultGenerationServer: defaultGenerationServer,
        outputDirectory: outputDirectory,
        a1111Mode: a1111Mode,
        customCommands: customCommands,
        customWorkingDirectories: customWorkingDirectories,
        customEndpoints: customEndpoints,
        customHealthCheckEndpoints: customHealthCheckEndpoints,
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Return default settings if loading fails
      return SettingsData(
        useMockMode: false,
        isDarkMode: true,
        apiBaseUrl: ApiConfig.defaultBaseUrl,
        useApiService: ApiConfig.useApiService,
        defaultGenerationServer: ImageGenerationConstants.defaultBackend,
        outputDirectory: AppConstants.defaultOutputDirectory,
        a1111Mode: ImageGenerationConstants.defaultA1111Mode,
        customCommands: Map.from(ImageGenerationConstants.defaultCommands),
        customWorkingDirectories: Map.from(ImageGenerationConstants.defaultWorkingDirectories),
        customEndpoints: Map.from(ImageGenerationConstants.defaultEndpoints),
        customHealthCheckEndpoints: Map.from(ImageGenerationConstants.defaultHealthCheckEndpoints),
      );
    }
  }

  /// Clear all saved settings (reset to defaults)
  static Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing settings: $e');
    }
  }
}

/// Data class to hold all settings data
class SettingsData {
  final bool useMockMode;
  final bool isDarkMode;
  final String apiBaseUrl;
  final bool useApiService;
  final ImageGenerationBackend defaultGenerationServer;
  final String outputDirectory;
  final A1111Mode a1111Mode;
  final Map<ImageGenerationBackend, String> customCommands;
  final Map<ImageGenerationBackend, String> customWorkingDirectories;
  final Map<ImageGenerationBackend, String> customEndpoints;
  final Map<ImageGenerationBackend, String> customHealthCheckEndpoints;

  const SettingsData({
    required this.useMockMode,
    required this.isDarkMode,
    required this.apiBaseUrl,
    required this.useApiService,
    required this.defaultGenerationServer,
    required this.outputDirectory,
    required this.a1111Mode,
    required this.customCommands,
    required this.customWorkingDirectories,
    required this.customEndpoints,
    required this.customHealthCheckEndpoints,
  });
}
