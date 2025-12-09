import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_constants.dart';
import 'comfyui_service.dart';

/// Web implementation that assumes a remote, managed backend.
class AIImageGenerationServiceImpl implements AIImageGenerationService {
  final ImageGenerationBackend _backend;
  final StreamController<AIServiceStatus> _statusController =
      StreamController<AIServiceStatus>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final List<String> _logs = [];
  String _apiEndpoint = '';
  String _healthCheckEndpoint = '';
  AIServiceStatus _status = AIServiceStatus.running;

  static const int _maxLogEntries = 500;

  AIImageGenerationServiceImpl(this._backend) {
    _addLog('Running in web mode. ${_backend.displayName} backend assumed to be managed in the cloud.');
  }

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
    _apiEndpoint = apiEndpoint;
    _healthCheckEndpoint =
        healthCheckEndpoint ?? ImageGenerationConstants.defaultHealthCheckEndpoints[_backend] ?? '';

    _addLog('Web build detected: skipping local process start. Using hosted ${_backend.displayName} backend.');
    _updateStatus(AIServiceStatus.running);

    if (_apiEndpoint.isEmpty || _healthCheckEndpoint.isEmpty) {
      _addLog('Health monitoring disabled: missing API endpoint or health check path.');
      return true;
    }

    final healthy = await isHealthy();
    if (!healthy) {
      _addLog('Remote backend appears unhealthy.');
      _updateStatus(AIServiceStatus.error);
    }

    return healthy;
  }

  @override
  Future<void> stop() async {
    _addLog('Web build detected: stop is a no-op because the backend is cloud-managed.');
    _updateStatus(AIServiceStatus.stopped);
  }

  @override
  Future<bool> isHealthy() async {
    if (_apiEndpoint.isEmpty || _healthCheckEndpoint.isEmpty) {
      _addLog('Health check skipped - API or health endpoint not configured.');
      return false;
    }

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final url = _apiEndpoint + _healthCheckEndpoint;
      _addLog('Performing remote health check on: $url');
      final response = await dio.get(url);
      final healthy = response.statusCode == 200;
      _addLog('Health check result: ${healthy ? 'HEALTHY' : 'UNHEALTHY'} (status ${response.statusCode})');
      return healthy;
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
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }

    _logController.add(logEntry);
  }
}
