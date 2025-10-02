import '../services/comfyui_service.dart';
import '../providers/settings_provider.dart';
import '../utils/app_constants.dart';

/// Singleton service manager for AI image generation services
class AIImageGenerationServiceManager {
  static AIImageGenerationServiceManager? _instance;
  static AIImageGenerationServiceManager get instance => _instance ??= AIImageGenerationServiceManager._();
  
  AIImageGenerationServiceManager._();
  
  AIImageGenerationService? _currentService;
  ImageGenerationBackend? _currentBackend;
  
  /// Get the current service instance, creating it if necessary
  AIImageGenerationService getService(SettingsProvider settings) {
    final selectedBackend = settings.defaultGenerationServer;
    
    // If backend changed or no service exists, create new one
    if (_currentService == null || _currentBackend != selectedBackend) {
      _disposeCurrentService();
      _currentService = AIImageGenerationServiceImpl(selectedBackend);
      _currentBackend = selectedBackend;
    }
    
    return _currentService!;
  }
  
  /// Start the AI service using settings configuration
  Future<bool> startService(SettingsProvider settings) async {
    final service = getService(settings);
    final backend = settings.defaultGenerationServer;
    
    return await service.start(
      command: settings.getStartCommand(backend),
      workingDirectory: settings.getWorkingDirectory(backend),
      apiEndpoint: settings.getEndpoint(backend),
      healthCheckEndpoint: settings.getHealthCheckEndpoint(backend),
    );
  }
  
  /// Stop the current service
  Future<void> stopService() async {
    if (_currentService != null) {
      await _currentService!.stop();
    }
  }
  
  /// Check if current service is healthy
  Future<bool> isServiceHealthy() async {
    if (_currentService == null) return false;
    return await _currentService!.isHealthy();
  }
  
  /// Clear logs from current service
  void clearLogs() {
    _currentService?.clearLogs();
  }
  
  /// Get current service status
  AIServiceStatus? getStatus() {
    return _currentService?.status;
  }
  
  /// Get current service backend
  ImageGenerationBackend? getCurrentBackend() {
    return _currentBackend;
  }
  
  /// Dispose all resources (call on app shutdown)
  void dispose() {
    _disposeCurrentService();
  }
  
  void _disposeCurrentService() {
    _currentService?.dispose();
    _currentService = null;
    _currentBackend = null;
  }
} 