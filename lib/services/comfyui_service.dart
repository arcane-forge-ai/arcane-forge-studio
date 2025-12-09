import 'dart:async';

import '../utils/app_constants.dart';

/// Status of the AI image generation service
enum AIServiceStatus {
  stopped,
  starting,
  running,
  stopping,
  error
}

/// Abstract interface for AI image generation services
abstract class AIImageGenerationService {
  /// Current status of the service
  AIServiceStatus get status;

  /// Stream of status changes
  Stream<AIServiceStatus> get statusStream;

  /// Stream of log entries
  Stream<String> get logStream;

  /// Current logs as a list
  List<String> get logs;

  /// Backend type this service manages
  ImageGenerationBackend get backend;

  /// Start the AI service with the given configuration
  Future<bool> start({
    required String command,
    required String workingDirectory,
    required String apiEndpoint,
    String? healthCheckEndpoint,
  });

  /// Stop the AI service
  Future<void> stop();

  /// Check if the service is healthy (API responding)
  Future<bool> isHealthy();

  /// Clear all logs
  void clearLogs();

  /// Dispose resources
  void dispose();
}

export 'comfyui_service_desktop.dart'
    if (dart.library.html) 'comfyui_service_web.dart';
