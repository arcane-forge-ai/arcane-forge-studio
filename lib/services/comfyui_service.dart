import 'dart:io';
import 'dart:async';
import 'dart:convert';
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

/// Generic implementation of AI image generation service
class AIImageGenerationServiceImpl implements AIImageGenerationService {
  final ImageGenerationBackend _backend;
  Process? _process;
  AIServiceStatus _status = AIServiceStatus.stopped;
  final StreamController<AIServiceStatus> _statusController = StreamController<AIServiceStatus>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final List<String> _logs = [];
  Timer? _healthCheckTimer;
  String _apiEndpoint = '';
  String _healthCheckEndpoint = '';
  
  static const int _maxLogEntries = 1000;
  static const Duration _healthCheckInterval = Duration(seconds: 10);
  
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
    if (_status == AIServiceStatus.running || _status == AIServiceStatus.starting) {
      _addLog('Service already running or starting');
      return _status == AIServiceStatus.running;
    }
    
    _apiEndpoint = apiEndpoint;
    _healthCheckEndpoint = healthCheckEndpoint ?? ImageGenerationConstants.defaultHealthCheckEndpoints[_backend] ?? '';
    _updateStatus(AIServiceStatus.starting);
    _addLog('Starting ${_backend.displayName} service...');
    
    try {
      // Validate paths exist
      final workingDir = Directory(workingDirectory);
      if (!await workingDir.exists()) {
        _addLog('ERROR: Working directory does not exist: $workingDirectory');
        _updateStatus(AIServiceStatus.error);
        return false;
      }
      
      // Parse command into executable and arguments
      final commandParts = _parseCommand(command);
      if (commandParts.isEmpty) {
        _addLog('ERROR: Invalid command format');
        _updateStatus(AIServiceStatus.error);
        return false;
      }
      
      final executable = commandParts.first;
      final arguments = commandParts.skip(1).toList();
      
      _addLog('Executing: $executable ${arguments.join(' ')}');
      _addLog('Working directory: $workingDirectory');
      
      // Start the process
      _process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      
      if (_process == null) {
        _addLog('ERROR: Failed to start process');
        _updateStatus(AIServiceStatus.error);
        return false;
      }
      
      _addLog('Process started with PID: ${_process!.pid}');
      
      // Listen to stdout and stderr
      _process!.stdout.transform(utf8.decoder).listen(
        (data) => _addLog('[STDOUT] $data'),
        onError: (error) => _addLog('[STDOUT ERROR] $error'),
        onDone: () => _addLog('[STDOUT] Stream closed'),
      );
      
      _process!.stderr.transform(utf8.decoder).listen(
        (data) => _addLog('[STDERR] $data'),
        onError: (error) => _addLog('[STDERR ERROR] $error'),
        onDone: () => _addLog('[STDERR] Stream closed'),
      );
      
      // Listen for process exit
      _process!.exitCode.then((exitCode) {
        _addLog('Process exited with code: $exitCode');
        if (_status != AIServiceStatus.stopping) {
          _updateStatus(AIServiceStatus.error);
        }
        _process = null;
      });
      
      // Wait for API to become available
      _addLog('Waiting for API to become available...');
      final isAvailable = await _waitForApiAvailability();
      
      if (isAvailable) {
        _updateStatus(AIServiceStatus.running);
        _addLog('${_backend.displayName} service started successfully!');
        _startHealthChecking();
        return true;
      } else {
        _addLog('ERROR: API did not become available within timeout');
        await stop();
        return false;
      }
      
    } catch (e) {
      _addLog('ERROR: Exception during startup: $e');
      _updateStatus(AIServiceStatus.error);
      return false;
    }
  }
  
  @override
  Future<void> stop() async {
    if (_status == AIServiceStatus.stopped || _status == AIServiceStatus.stopping) {
      return;
    }
    
    _updateStatus(AIServiceStatus.stopping);
    _addLog('Stopping ${_backend.displayName} service...');
    
    _stopHealthChecking();
    
    if (_process != null) {
      try {
        final pid = _process!.pid;
        _addLog('Attempting to terminate process tree with root PID: $pid');
        
        // On Windows, kill the entire process tree to ensure we get child processes too
        if (Platform.isWindows) {
          try {
            // Use taskkill with /T flag to kill the process tree
            final result = await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
            _addLog('Taskkill result: ${result.stdout}');
            if (result.stderr.isNotEmpty) {
              _addLog('Taskkill stderr: ${result.stderr}');
            }
          } catch (e) {
            _addLog('Taskkill failed: $e');
          }
          
          // Also try to kill any Python processes that might be running our services
          try {
            _addLog('Searching for Python processes running ${_backend.displayName}...');
            final pythonResult = await Process.run('wmic', [
              'process', 'where', 
              'name="python.exe" and commandline like "%${_backend == ImageGenerationBackend.automatic1111 ? 'launch.py' : 'ComfyUI'}%"',
              'get', 'processid,commandline'
            ]);
            
            if (pythonResult.stdout.toString().contains('ProcessId')) {
              _addLog('Found Python processes: ${pythonResult.stdout}');
              
              // Kill any found Python processes
              final killPythonResult = await Process.run('taskkill', [
                '/F', '/IM', 'python.exe', '/FI', 
                'WINDOWTITLE eq *${_backend == ImageGenerationBackend.automatic1111 ? 'launch.py' : 'ComfyUI'}*'
              ]);
              _addLog('Python process kill result: ${killPythonResult.stdout}');
            } else {
              _addLog('No specific Python processes found for ${_backend.displayName}');
            }
          } catch (e) {
            _addLog('Python process search/kill failed: $e');
          }
        } else {
          // Non-Windows: try graceful then force kill
          _process!.kill(ProcessSignal.sigterm);
          try {
            await _process!.exitCode.timeout(const Duration(seconds: 5));
            _addLog('Process terminated gracefully');
          } catch (e) {
            _addLog('Process did not terminate gracefully, forcing kill...');
            _process!.kill(ProcessSignal.sigkill);
            try {
              await _process!.exitCode.timeout(const Duration(seconds: 5));
              _addLog('Process force killed successfully');
            } catch (e) {
              _addLog('Failed to force kill process: $e');
            }
          }
        }
      } catch (e) {
        _addLog('Error stopping process: $e');
      }
      _process = null;
    }
    
    _updateStatus(AIServiceStatus.stopped);
    _addLog('${_backend.displayName} service stopped');
  }
  
    @override
  Future<bool> isHealthy() async {
    // Only skip if health check endpoint is not configured
    if (_healthCheckEndpoint.isEmpty) {
      _addLog('Health check skipped - health check endpoint not configured');
      return false;
    }

    // If API endpoint is not configured, we can't perform health check
    if (_apiEndpoint.isEmpty) {
      _addLog('Health check failed - API endpoint not configured');
      return false;
    }

    _addLog('Performing health check - service status: ${_status.name}, API endpoint: $_apiEndpoint, health endpoint: $_healthCheckEndpoint');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final healthCheckUrl = _apiEndpoint + _healthCheckEndpoint;
      _addLog('Performing health check on: $healthCheckUrl');
      
      final request = await client.getUrl(Uri.parse(healthCheckUrl));
      final response = await request.close().timeout(const Duration(seconds: 5));
      
      final statusCode = response.statusCode;
      _addLog('Health check response: HTTP $statusCode');
      
      // Read response body for debugging
      final responseBody = await response.transform(utf8.decoder).join();
      _addLog('Health check response body: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}...');
      
      client.close();
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
    _stopHealthChecking();
    _statusController.close();
    _logController.close();
    if (_process != null) {
      _process!.kill();
    }
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
  
  List<String> _parseCommand(String command) {
    final parts = <String>[];
    var current = '';
    var inQuotes = false;
    var escapeNext = false;
    
    for (var i = 0; i < command.length; i++) {
      final char = command[i];
      
      if (escapeNext) {
        current += char;
        escapeNext = false;
        continue;
      }
      
      if (char == '\\') {
        escapeNext = true;
        continue;
      }
      
      if (char == '"' || char == "'") {
        inQuotes = !inQuotes;
        continue;
      }
      
      if (char == ' ' && !inQuotes) {
        if (current.isNotEmpty) {
          parts.add(current);
          current = '';
        }
        continue;
      }
      
      current += char;
    }
    
    if (current.isNotEmpty) {
      parts.add(current);
    }
    
    return parts;
  }
  
  Future<bool> _waitForApiAvailability() async {
    const maxAttempts = 30;
    const delayBetweenAttempts = Duration(seconds: 2);
    
    _addLog('Waiting for API to become available - will check ${maxAttempts} times with ${delayBetweenAttempts.inSeconds}s intervals');
    
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _addLog('API availability check (attempt $attempt/$maxAttempts)...');
      
      if (await isHealthy()) {
        _addLog('API is now available!');
        return true;
      }
      
      if (attempt < maxAttempts) {
        _addLog('API not yet available, waiting ${delayBetweenAttempts.inSeconds} seconds before next attempt...');
        await Future.delayed(delayBetweenAttempts);
      }
    }
    
    _addLog('API availability check failed after $maxAttempts attempts');
    return false;
  }
  
  void _startHealthChecking() {
    _stopHealthChecking();
    _addLog('Starting periodic health checks every ${_healthCheckInterval.inSeconds} seconds');
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      final healthy = await isHealthy();
      if (_status == AIServiceStatus.running && !healthy) {
        _addLog('Health check failed - service may be unresponsive');
        _updateStatus(AIServiceStatus.error);
        _stopHealthChecking();
      } else if (_status == AIServiceStatus.starting && healthy) {
        _addLog('Health check passed - service is now healthy!');
        _updateStatus(AIServiceStatus.running);
      }
    });
  }
  
  void _stopHealthChecking() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
} 