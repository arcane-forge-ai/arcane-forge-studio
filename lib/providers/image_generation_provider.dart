import 'package:flutter/material.dart';
import '../models/image_generation_models.dart';
import '../services/comfyui_service.dart';
import '../services/comfyui_service_manager.dart';
import '../services/image_generation_services.dart';
import '../providers/settings_provider.dart';
import '../utils/app_constants.dart';
import 'dart:io';

class ImageGenerationProvider extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final AIImageGenerationServiceManager _serviceManager = AIImageGenerationServiceManager.instance;
  final A1111ImageGenerationService _a1111Service;
  late final ImageAssetService _assetService;
  
  // Asset-based state instead of flat image list
  List<ImageAsset> _assets = [];
  String? _currentProjectId;
  bool _isGenerating = false;
  bool _isStartingService = false;
  GenerationRequest? _currentRequest;
  List<String> _availableModels = [];
  List<String> get availableModels => _availableModels;
  List<String> _availableLoras = [];
  List<String> get availableLoras => _availableLoras;
  
  ImageGenerationProvider(
    this._settingsProvider, {
    String? apiBaseUrl,
    bool useApiService = false,
  }) : _a1111Service = A1111ImageGenerationService(_settingsProvider) {
    // Initialize the asset service using the factory
    _assetService = ImageAssetServiceFactory.create(
      apiBaseUrl: apiBaseUrl,
      useApiService: useApiService,
    );
    
    // Test API connection if using API service
    if (useApiService && apiBaseUrl != null && _assetService is ApiImageAssetService) {
      _testApiConnection();
    }
  }
  
  bool _isApiConnected = false;
  bool get isApiConnected => _isApiConnected;
  
  /// Test API connection status
  Future<void> _testApiConnection() async {
    if (_assetService is ApiImageAssetService) {
      try {
        _isApiConnected = await (_assetService as ApiImageAssetService).testConnection();
      } catch (e) {
        _isApiConnected = false;
      }
      notifyListeners();
    }
  }
  
  /// Public method to test API connection
  Future<bool> testApiConnection() async {
    await _testApiConnection();
    return _isApiConnected;
  }

  // Asset-based getters
  List<ImageAsset> get assets => _assets;
  String? get currentProjectId => _currentProjectId;
  bool get isGenerating => _isGenerating;
  GenerationRequest? get currentRequest => _currentRequest;
  
  // Get all generations from all assets (for backward compatibility)
  List<ImageGeneration> get allGenerations {
    return _assets.expand((asset) => asset.generations).toList();
  }
  
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
  
  /// Clear service logs
  void clearServiceLogs() {
    _serviceManager.clearLogs();
    notifyListeners();
  }
  
  /// Check if service is healthy
  Future<bool> isServiceHealthy() async {
    return await _serviceManager.isServiceHealthy();
  }
  
  /// Get project statistics (API only)
  Future<Map<String, dynamic>?> getProjectStats() async {
    if (_currentProjectId == null) return null;
    
    if (_assetService is ApiImageAssetService) {
      try {
        return await (_assetService as ApiImageAssetService).getProjectStats(_currentProjectId!);
      } catch (e) {
        debugPrint('Failed to get project stats: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Get project tags (API only)
  Future<List<Map<String, dynamic>>?> getProjectTags() async {
    if (_currentProjectId == null) return null;
    
    if (_assetService is ApiImageAssetService) {
      try {
        return await (_assetService as ApiImageAssetService).getProjectTags(_currentProjectId!);
      } catch (e) {
        debugPrint('Failed to get project tags: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Get filtered assets (API only)
  Future<Map<String, dynamic>?> getFilteredAssets({
    int limit = 50,
    int offset = 0,
    String? search,
    List<String>? tags,
    bool? hasGenerations,
    DateTime? createdAfter,
    DateTime? createdBefore,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    if (_currentProjectId == null) return null;
    
    if (_assetService is ApiImageAssetService) {
      try {
        return await (_assetService as ApiImageAssetService).getProjectAssetsWithFilters(
          _currentProjectId!,
          limit: limit,
          offset: offset,
          search: search,
          tags: tags,
          hasGenerations: hasGenerations,
          createdAfter: createdAfter,
          createdBefore: createdBefore,
          sortBy: sortBy,
          sortOrder: sortOrder,
        );
      } catch (e) {
        debugPrint('Failed to get filtered assets: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Delete multiple assets (API only)
  Future<Map<String, dynamic>?> deleteBulkAssets(List<String> assetIds, {bool force = false}) async {
    if (_currentProjectId == null) return null;
    
    if (_assetService is ApiImageAssetService) {
      try {
        final result = await (_assetService as ApiImageAssetService).deleteBulkAssets(
          _currentProjectId!,
          assetIds,
          force: force,
        );
        
        // Refresh assets after bulk delete
        await refreshAssets();
        
        return result;
      } catch (e) {
        debugPrint('Failed to delete bulk assets: $e');
        return null;
      }
    }
    return null;
  }
  
  /// Mark generation as favorite (API enhanced)
  Future<void> markGenerationAsFavorite(String generationId) async {
    if (_assetService is ApiImageAssetService) {
      try {
        await (_assetService as ApiImageAssetService).markGenerationFavorite(generationId);
        await refreshAssets(); // Refresh to get updated data
      } catch (e) {
        debugPrint('Failed to mark generation as favorite: $e');
        // Fallback to regular update method
        await _markGenerationFavoriteLocal(generationId);
      }
    } else {
      await _markGenerationFavoriteLocal(generationId);
    }
  }
  
  /// Remove generation favorite status (API enhanced)
  Future<void> removeGenerationFavorite(String generationId) async {
    if (_assetService is ApiImageAssetService) {
      try {
        await (_assetService as ApiImageAssetService).removeGenerationFavorite(generationId);
        await refreshAssets(); // Refresh to get updated data
      } catch (e) {
        debugPrint('Failed to remove generation favorite: $e');
        // Fallback to regular update method
        await _removeGenerationFavoriteLocal(generationId);
      }
    } else {
      await _removeGenerationFavoriteLocal(generationId);
    }
  }
  
  /// Local fallback for marking generation as favorite
  Future<void> _markGenerationFavoriteLocal(String generationId) async {
    try {
      // Find and update the generation
      for (var asset in _assets) {
        final genIndex = asset.generations.indexWhere((g) => g.id == generationId);
        if (genIndex != -1) {
          final updatedGeneration = asset.generations[genIndex].copyWith(isFavorite: true);
          await _assetService.updateGeneration(updatedGeneration);
          break;
        }
      }
      await refreshAssets();
    } catch (e) {
      debugPrint('Failed to mark generation as favorite locally: $e');
    }
  }
  
  /// Local fallback for removing generation favorite status
  Future<void> _removeGenerationFavoriteLocal(String generationId) async {
    try {
      // Find and update the generation
      for (var asset in _assets) {
        final genIndex = asset.generations.indexWhere((g) => g.id == generationId);
        if (genIndex != -1) {
          final updatedGeneration = asset.generations[genIndex].copyWith(isFavorite: false);
          await _assetService.updateGeneration(updatedGeneration);
          break;
        }
      }
      await refreshAssets();
    } catch (e) {
      debugPrint('Failed to remove generation favorite locally: $e');
    }
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

  // Project context management
  Future<void> setCurrentProject(String projectId) async {
    if (_currentProjectId == projectId) return;
    
    _currentProjectId = projectId;
    await refreshAssets();
  }

  // Asset management methods
  Future<void> refreshAssets() async {
    if (_currentProjectId == null) {
      _assets = [];
      notifyListeners();
      return;
    }

    try {
      _assets = await _assetService.getProjectAssets(_currentProjectId!);
      notifyListeners();
    } catch (e) {
      print('Error refreshing assets: $e');
      _assets = [];
      notifyListeners();
    }
  }

  Future<ImageAsset> createAsset(String name, String description) async {
    if (_currentProjectId == null) {
      throw Exception('No project selected');
    }

    try {
      final asset = await _assetService.createAsset(_currentProjectId!, name, description);
      _assets.insert(0, asset);
      notifyListeners();
      return asset;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAsset(String assetId) async {
    try {
      await _assetService.deleteAsset(assetId);
      _assets.removeWhere((asset) => asset.id == assetId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAsset(ImageAsset asset) async {
    try {
      final updatedAsset = await _assetService.updateAsset(asset);
      final index = _assets.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _assets[index] = updatedAsset;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGeneration(String generationId) async {
    try {
      await _assetService.deleteGeneration(generationId);
      
      // Remove generation from local state
      for (var asset in _assets) {
        asset.generations.removeWhere((gen) => gen.id == generationId);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setFavoriteGeneration(String assetId, String generationId) async {
    try {
      final assetIndex = _assets.indexWhere((a) => a.id == assetId);
      if (assetIndex == -1) return;

      final asset = _assets[assetIndex];
      
      // Clear existing favorite
      for (var gen in asset.generations) {
        if (gen.isFavorite) {
          final updatedGen = gen.copyWith(isFavorite: false);
          await _assetService.updateGeneration(updatedGen);
        }
      }
      
      // Set new favorite
      final genIndex = asset.generations.indexWhere((g) => g.id == generationId);
      if (genIndex != -1) {
        final generation = asset.generations[genIndex];
        final updatedGeneration = generation.copyWith(isFavorite: true);
        await _assetService.updateGeneration(updatedGeneration);
        
        // Update local state
        asset.generations[genIndex] = updatedGeneration;
        _assets[assetIndex] = asset.copyWith(favoriteGenerationId: generationId);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get asset from cache (fast but may be stale)
  ImageAsset? getAssetFromCache(String assetId) {
    try {
      return _assets.firstWhere((asset) => asset.id == assetId);
    } catch (e) {
      return null;
    }
  }

  /// Get fresh asset data from service (slower but always up-to-date)
  Future<ImageAsset?> getAsset(String assetId) async {
    try {
      final asset = await _assetService.getAsset(assetId);
      
      // Update cache with fresh data
      final index = _assets.indexWhere((a) => a.id == assetId);
      if (index != -1) {
        _assets[index] = asset;
      } else {
        _assets.add(asset);
      }
      
      notifyListeners();
      return asset;
    } catch (e) {
      print('Error fetching asset $assetId: $e');
      // Fallback to cache if service fails
      return getAssetFromCache(assetId);
    }
  }

  /// Get fresh generations for a specific asset from service
  Future<List<ImageGeneration>> getAssetGenerations(String assetId, {int limit = 50}) async {
    try {
      if (_assetService is ApiImageAssetService) {
        final result = await (_assetService as ApiImageAssetService).getAssetGenerations(
          assetId,
          limit: limit,
        );
        return result['generations'] as List<ImageGeneration>;
      } else {
        // For mock service, get from cached asset
        final asset = getAssetFromCache(assetId);
        if (asset != null) {
          final sortedGenerations = [...asset.generations];
          sortedGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sortedGenerations.take(limit).toList();
        }
        return [];
      }
    } catch (e) {
      print('Error fetching generations for asset $assetId: $e');
      // Fallback to cached data
      final asset = getAssetFromCache(assetId);
      if (asset != null) {
        final sortedGenerations = [...asset.generations];
        sortedGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sortedGenerations.take(limit).toList();
      }
      return [];
    }
  }

  // Get Generation with Generation Id
  Future<ImageGeneration?> getGeneration(String generationId) async {
    try {
      final generation = await _assetService.getGeneration(generationId);
      return generation;
    } catch (e) {
      rethrow;
    }
  }

  // Service management methods (unchanged)
  Future<void> startService() async {
    if (_isStartingService || isServiceRunning) return;

    _isStartingService = true;
    notifyListeners();

    try {
      await _serviceManager.startService(_settingsProvider);
    } catch (e) {
      rethrow;
    } finally {
      _isStartingService = false;
      notifyListeners();
    }
  }

  Future<void> stopService() async {
    if (!isServiceRunning) return;

    try {
      await _serviceManager.stopService();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> generateImage(GenerationRequest request, {required String projectName, required String projectId, required String assetId}) async {
    if (_isGenerating) return;

    _isGenerating = true;
    _currentRequest = request;
    notifyListeners();

    try {
      if (!isServiceRunning) {
        throw Exception('${currentBackendName} service is not running. Please start the service first.');
      }

      // Find the target asset
      final asset = await getAsset(assetId);
      if (asset == null) {
        throw Exception('Asset not found: $assetId');
      }

      // Add generation to asset (server will generate the ID)
      final generation = await _assetService.addGeneration(
        assetId, 
        request.toParameters(), 
        status: GenerationStatus.generating,
      );
      await refreshAssets(); // Refresh to get updated asset

      // Generate the image using the A1111 service
      final imageData = await _a1111Service.generateImage(request);

      // Build output path: $output_directory/$project_name_with_id/assets/$asset_name/$server_generation_id.png
      final outputDir = _settingsProvider.outputDirectory.isNotEmpty
        ? _settingsProvider.outputDirectory
        : 'output';
      final safeProjectName = projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final safeAssetName = asset.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final projectFolder = '${safeProjectName}_${projectId}';
      final assetDir = Directory('$outputDir/$projectFolder/assets/$safeAssetName');
      if (!assetDir.existsSync()) {
        assetDir.createSync(recursive: true);
      }
      // Use the server-generated ID for the filename
      final imageFile = File('${assetDir.path}/${generation.id}.png');
      await imageFile.writeAsBytes(imageData);

      // Update the generation with completed status and image path
      final updatedGeneration = generation.copyWith(
        status: GenerationStatus.completed,
        imagePath: imageFile.path,
      );
      
      await _assetService.updateGeneration(updatedGeneration);
      await refreshAssets(); // Refresh to get updated asset

    } catch (e) {
      // Handle generation error - find and update the generation
      if (_currentRequest != null) {
        try {
          final asset = await getAsset(assetId);
          if (asset != null && asset.generations.isNotEmpty) {
            final failedGeneration = asset.generations.first;
            final updatedGeneration = failedGeneration.copyWith(
              status: GenerationStatus.failed,
            );
            await _assetService.updateGeneration(updatedGeneration);
            await refreshAssets();
          }
        } catch (updateError) {
          print('Error updating failed generation: $updateError');
        }
      }
      rethrow;
    } finally {
      _isGenerating = false;
      _currentRequest = null;
      notifyListeners();
    }
  }

  // Legacy methods for backward compatibility (will be removed in Step 6)
  @Deprecated('Use assets instead')
  List<GeneratedImage> get images {
    // Convert generations to GeneratedImage for backward compatibility
    return allGenerations.map((gen) {
      final params = GenerationParameters(gen.parameters);
      return GeneratedImage(
        id: gen.id,
        prompt: params.positivePrompt,
        negativePrompt: params.negativePrompt,
        width: params.width,
        height: params.height,
        steps: params.steps,
        cfgScale: params.cfgScale,
        seed: params.seed,
        model: params.model,
        sampler: params.sampler,
        scheduler: params['scheduler'] ?? 'normal',
        createdAt: gen.createdAt,
        status: gen.status,
        imagePath: gen.imagePath,
      );
    }).toList();
  }

  @Deprecated('Use deleteGeneration instead')
  void removeImage(String imageId) {
    deleteGeneration(imageId);
  }

  @Deprecated('Use asset-based operations instead')
  void clearAllImages() {
    // Clear all assets for current project
    if (_currentProjectId != null) {
      for (var asset in List.from(_assets)) {
        deleteAsset(asset.id);
      }
    }
  }

  @Deprecated('Use refreshAssets instead')
  void refreshImages() {
    refreshAssets();
  }

  /// Refresh the list of available models from the working directory
  Future<void> refreshAvailableModels() async {
    final backend = _settingsProvider.defaultGenerationServer;
    final workingDir = _settingsProvider.getWorkingDirectory(backend);
    final modelDir = Directory(
      '$workingDir/models/Stable-diffusion',
    );
    if (await modelDir.exists()) {
      final files = modelDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.safetensors') || f.path.endsWith('.ckpt'))
          .map((f) {
            final fileName = f.uri.pathSegments.last;
            // Remove file extension by splitting and taking all parts except the last
            final parts = fileName.split('.');
            return parts.take(parts.length - 1).join('.');
          })
          .toList();
      _availableModels = files;
    } else {
      _availableModels = [];
    }
    notifyListeners();
  }

  /// Refresh the list of available loras from the working directory
  Future<void> refreshAvailableLoras() async {
    final backend = _settingsProvider.defaultGenerationServer;
    final workingDir = _settingsProvider.getWorkingDirectory(backend);
    final modelDir = Directory(
      '$workingDir/models/Lora',
    );
    if (await modelDir.exists()) {
      final files = modelDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.safetensors') || f.path.endsWith('.ckpt'))
          .map((f) {
            final fileName = f.uri.pathSegments.last;
            // Remove file extension by splitting and taking all parts except the last
            final parts = fileName.split('.');
            return parts.take(parts.length - 1).join('.');
          })
          .toList();
      _availableLoras = files;
    } else {
      _availableLoras = [];
    }
    notifyListeners();
  }
} 