import 'package:flutter/material.dart';
import '../models/image_generation_models.dart';
import '../services/comfyui_service.dart';
import '../services/comfyui_service_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/app_constants.dart';
import 'dart:io';

class ImageGenerationProvider extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final AIImageGenerationServiceManager _serviceManager = AIImageGenerationServiceManager.instance;
  
  List<GeneratedImage> _images = [];
  bool _isGenerating = false;
  bool _isStartingService = false;
  GenerationRequest? _currentRequest;
  
  ImageGenerationProvider(this._settingsProvider);

  List<GeneratedImage> get images => _images;
  bool get isGenerating => _isGenerating;
  GenerationRequest? get currentRequest => _currentRequest;
  
  // AI Service status getters
  AIServiceStatus get serviceStatus => _serviceManager.getStatus() ?? AIServiceStatus.stopped;
  bool get isServiceRunning => serviceStatus == AIServiceStatus.running;
  bool get isServiceStarting => _isStartingService || serviceStatus == AIServiceStatus.starting;
  bool get isServiceStopping => serviceStatus == AIServiceStatus.stopping;
  bool get hasServiceError => serviceStatus == AIServiceStatus.error;
  
  String get currentBackendName => _settingsProvider.defaultGenerationServer.displayName;
  
  Stream<AIServiceStatus> get serviceStatusStream {
    final service = _serviceManager.getService(_settingsProvider);
    return service.statusStream;
  }
  
  Stream<String> get serviceLogStream {
    final service = _serviceManager.getService(_settingsProvider);
    return service.logStream;
  }
  
  List<String> get serviceLogs {
    final service = _serviceManager.getService(_settingsProvider);
    return service.logs;
  }

  /// Start the AI image generation service
  Future<bool> startAIService() async {
    // Prevent double-clicking
    if (_isStartingService || isServiceRunning) {
      return isServiceRunning;
    }
    
    _isStartingService = true;
    notifyListeners();
    
    try {
      // First, kill any dangling processes that might be occupying the port
      await killDanglingService();
      
      final success = await _serviceManager.startService(_settingsProvider);
      return success;
    } finally {
      _isStartingService = false;
      notifyListeners();
    }
  }

  /// Stop the AI image generation service
  Future<void> stopAIService() async {
    notifyListeners();
    await _serviceManager.stopService();
    notifyListeners();
  }

  /// Clear service logs
  void clearServiceLogs() {
    _serviceManager.clearLogs();
    notifyListeners();
  }

  /// Kill dangling processes that might be occupying AI service ports
  Future<bool> killDanglingService() async {
    try {
      // Get the expected port based on current backend
      int port = _settingsProvider.defaultGenerationServer == ImageGenerationBackend.automatic1111 
          ? 7860 // Automatic1111 default port
          : 8188; // ComfyUI default port
      
      // Windows-specific command to find and kill processes using the port
      if (Platform.isWindows) {
        // First, find processes using the port
        final findResult = await Process.run(
          'netstat',
          ['-ano', '-p', 'TCP'],
          runInShell: true,
        );
        
        if (findResult.exitCode == 0) {
          final lines = findResult.stdout.toString().split('\n');
          final List<String> pidsToKill = [];
          
          for (final line in lines) {
            if (line.contains(':$port ') && line.contains('LISTENING')) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.length >= 5) {
                final pid = parts.last.trim();
                if (pid.isNotEmpty && pid != '0') {
                  pidsToKill.add(pid);
                }
              }
            }
          }
          
          if (pidsToKill.isEmpty) {
            return true;
          }
          
          // Kill the processes
          bool allKilled = true;
          for (final pid in pidsToKill) {
            final killResult = await Process.run(
              'taskkill',
              ['/F', '/PID', pid],
              runInShell: true,
            );
            
            if (killResult.exitCode != 0) {
              allKilled = false;
            }
          }
          
          return allKilled;
        } else {
          return false;
        }
      } else {
        // For non-Windows platforms, use different approach
        final result = await Process.run(
          'lsof',
          ['-t', '-i:$port'],
          runInShell: true,
        );
        
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          final pids = result.stdout.toString().trim().split('\n');
          bool allKilled = true;
          
          for (final pid in pids) {
            if (pid.trim().isNotEmpty) {
              final killResult = await Process.run('kill', ['-9', pid.trim()]);
              
              if (killResult.exitCode != 0) {
                allKilled = false;
              }
            }
          }
          
          return allKilled;
        } else {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if service is healthy
  Future<bool> isServiceHealthy() async {
    return await _serviceManager.isServiceHealthy();
  }

  Future<void> generateImage(GenerationRequest request) async {
    if (_isGenerating) return;

    _isGenerating = true;
    _currentRequest = request;
    notifyListeners();

    try {
      if (!isServiceRunning) {
        throw Exception('${currentBackendName} service is not running. Please start the service first.');
      }

      // Create a new generated image entry
      final generatedImage = GeneratedImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        prompt: request.positivePrompt,
        negativePrompt: request.negativePrompt,
        width: request.width,
        height: request.height,
        steps: request.steps,
        cfgScale: request.cfgScale,
        seed: request.seed,
        model: request.model,
        sampler: request.sampler,
        createdAt: DateTime.now(),
        status: GenerationStatus.generating,
        imagePath: null,
      );

      _images.insert(0, generatedImage);
      notifyListeners();

      // TODO: Implement actual image generation with the AI service
      // For now, simulate the generation process
      await Future.delayed(const Duration(seconds: 3));
      
      // Update the image status to completed
      final index = _images.indexWhere((img) => img.id == generatedImage.id);
      if (index != -1) {
        _images[index] = generatedImage.copyWith(
          status: GenerationStatus.completed,
          imagePath: 'assets/images/logo.png', // Placeholder for now
        );
      }

    } catch (e) {
      // Handle generation error
      if (_images.isNotEmpty && _currentRequest != null) {
        final index = 0;
        _images[index] = _images[index].copyWith(
          status: GenerationStatus.failed,
          error: e.toString(),
        );
      }
      rethrow;
    } finally {
      _isGenerating = false;
      _currentRequest = null;
      notifyListeners();
    }
  }

  void removeImage(String imageId) {
    _images.removeWhere((image) => image.id == imageId);
    notifyListeners();
  }

  void clearAllImages() {
    _images.clear();
    notifyListeners();
  }

  void refreshImages() {
    // Placeholder for refreshing images from storage
    notifyListeners();
  }
} 