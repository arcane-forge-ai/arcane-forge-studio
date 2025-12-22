import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

/// Web stub implementation of AI image generation service
/// Local process management is not supported on web platform
class AIImageGenerationServiceImpl implements AIImageGenerationService {
  final ImageGenerationBackend _backend;
  AIServiceStatus _status = AIServiceStatus.stopped;
  final StreamController<AIServiceStatus> _statusController = StreamController<AIServiceStatus>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final List<String> _logs = [];
  String _apiEndpoint = '';
  String _healthCheckEndpoint = '';
  
  static const int _maxLogEntries = 1000;
  
  AIImageGenerationServiceImpl(this._backend);
  
  @override
  AIServiceStatus get status => _status;
  
  @override
  Stream<AIServiceStatus> get statusStream => _statusController.stream;
  
  @override
  Stream<String> get logStream => _logController.stream;
  
  @override
  List<String> get logs => List.unmodifiable(_logs);
  
  @override
  ImageGenerationBackend get backend => _backend;
  
  @override
  Future<bool> start({
    required String command,
    required String workingDirectory,
    required String apiEndpoint,
    String? healthCheckEndpoint,
  }) async {
    _addLog('⚠️ Local service management is not supported on web platform');
    throw UnsupportedError(
      'Local ${_backend.displayName} service management is not supported on web. '
      'Please use online mode which connects to a backend API.',
    );
  }
  
  @override
  Future<void> stop() async {
    _addLog('⚠️ Local service management is not supported on web platform');
    throw UnsupportedError(
      'Local ${_backend.displayName} service management is not supported on web. '
      'Please use online mode which connects to a backend API.',
    );
  }
  
  @override
  Future<bool> isHealthy() async {
    if (_healthCheckEndpoint.isEmpty) {
      _addLog('Health check skipped - health check endpoint not configured');
      return false;
    }

    if (_apiEndpoint.isEmpty) {
      _addLog('Health check failed - API endpoint not configured');
      return false;
    }

    _addLog('Performing health check - API endpoint: $_apiEndpoint, health endpoint: $_healthCheckEndpoint');

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);
      
      final healthCheckUrl = _apiEndpoint + _healthCheckEndpoint;
      _addLog('Performing health check on: $healthCheckUrl');
      
      final response = await dio.get(healthCheckUrl);
      
      final statusCode = response.statusCode ?? 0;
      _addLog('Health check response: HTTP $statusCode');
      
      final isHealthy = statusCode == 200;
      _addLog('Health check result: ${isHealthy ? 'HEALTHY' : 'UNHEALTHY'}');
      return isHealthy;
    } catch (e) {
      _addLog('Health check failed with error: $e');
      return false;
    }
  }
  
  @override
  void clearLogs() {
    _logs.clear();
    _addLog('Logs cleared');
  }
  
  @override
  void dispose() {
    _statusController.close();
    _logController.close();
  }
  
  void _updateStatus(AIServiceStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;
      _addLog('Service status changed: ${oldStatus.name} -> ${newStatus.name}');
      _statusController.add(_status);
    }
  }
  
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    
    _logs.add(logEntry);
    
    // Keep only the last N entries to prevent memory issues
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }
    
    _logController.add(logEntry);
  }
}

