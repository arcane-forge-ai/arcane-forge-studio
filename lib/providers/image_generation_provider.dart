import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/image_generation_models.dart';
import '../models/extracted_asset_models.dart';
import '../services/comfyui_service.dart';
import '../services/comfyui_service_manager.dart';
import '../services/image_generation_services.dart';
import '../services/api_client.dart';
import '../services/a1111_online_service.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';
import '../utils/subscription_exceptions.dart';
import '../widgets/create_assets_from_doc_dialog.dart';
import 'dart:io' show Directory, File, Platform, Process;

class ImageGenerationProvider extends ChangeNotifier implements AssetCreationProvider {
  final SettingsProvider _settingsProvider;
  final AuthProvider? _authProvider;
  final AIImageGenerationServiceManager _serviceManager = AIImageGenerationServiceManager.instance;
  final A1111ImageGenerationService _a1111Service;
  late final ImageAssetService _assetService;
  
  // Callback for quota refresh (set by external provider)
  Function()? _quotaRefreshCallback;
  
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
  
  // A1111 specific state
  List<A1111Checkpoint> _a1111Checkpoints = [];
  List<A1111Checkpoint> get a1111Checkpoints => _a1111Checkpoints;
  List<A1111Lora> _a1111Loras = [];
  List<A1111Lora> get a1111Loras => _a1111Loras;
  String? _currentA1111Checkpoint;
  String? get currentA1111Checkpoint => _currentA1111Checkpoint;
  bool _isLoadingA1111Models = false;
  bool get isLoadingA1111Models => _isLoadingA1111Models;
  bool _isA1111ServerReachable = false;
  bool get isA1111ServerReachable => _isA1111ServerReachable;
  
  ImageGenerationProvider(
    this._settingsProvider, {
    AuthProvider? authProvider,
  }) : _authProvider = authProvider,
       _a1111Service = A1111ImageGenerationService(
         _settingsProvider,
         onlineService: A1111OnlineService(
           apiClient: ApiClient(
             settingsProvider: _settingsProvider,
             authProvider: authProvider,
           ),
         ),
       ) {
    // Initialize the asset service using the factory
    // Read API settings from SettingsProvider for dynamic updates
    _assetService = ImageAssetServiceFactory.create(
      useApiService: !_settingsProvider.useMockMode, // Use API when NOT in mock mode
      settingsProvider: _settingsProvider, // Pass provider for dynamic URL reading
      authProvider: _authProvider,
    );
    
    // Test API connection if using API service
    if (!_settingsProvider.useMockMode && _assetService is ApiImageAssetService) {
      _testApiConnection();
    }
  }
  
  /// Set callback for quota refresh (called from external subscription provider)
  void setQuotaRefreshCallback(Function() callback) {
    _quotaRefreshCallback = callback;
  }
  
  bool _isApiConnected = false;
  bool get isApiConnected => _isApiConnected;
  
  /// Test API connection status
  Future<void> _testApiConnection() async {
      if (_assetService is ApiImageAssetService) {
        try {
          _isApiConnected = await _assetService.testConnection();
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
        return await _assetService.getProjectStats(_currentProjectId!);
      } catch (e) {
        debugPrint('Failed to get project stats: $e');
        return null;
      }
    }
    return null;
  }

  /// Generate an optimized prompt for the current project/image asset
  Future<String> generateAutoPrompt({
    required Map<String, dynamic> assetInfo,
    required Map<String, dynamic> generatorInfo,
  }) async {
    if (_currentProjectId == null) {
      throw Exception('No project selected');
    }
    try {
      return await _assetService.generateAutoPrompt(
        _currentProjectId!,
        assetInfo,
        generatorInfo,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get project tags (API only)
  Future<List<Map<String, dynamic>>?> getProjectTags() async {
    if (_currentProjectId == null) return null;
    
    if (_assetService is ApiImageAssetService) {
      try {
        return await _assetService.getProjectTags(_currentProjectId!);
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
        return await _assetService.getProjectAssetsWithFilters(
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
        final result = await _assetService.deleteBulkAssets(
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
        final updatedGeneration = await _assetService.markGenerationFavorite(generationId);
        await _refreshSingleAsset(updatedGeneration.assetId);
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
        final updatedGeneration = await _assetService.removeGenerationFavorite(generationId);
        await _refreshSingleAsset(updatedGeneration.assetId);
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
          await _refreshSingleAsset(asset.id);
          break;
        }
      }
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
          await _refreshSingleAsset(asset.id);
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to remove generation favorite locally: $e');
    }
  }
  
  /// Kill dangling processes that might be occupying AI service ports
  Future<bool> killDanglingService() async {
    if (kIsWeb) return true;
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
  @override
  Future<void> refreshAssets({String? projectId}) async {
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

  /// Refresh a single asset from the service and update cache
  Future<void> _refreshSingleAsset(String assetId) async {
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
    } catch (e) {
      print('Error refreshing single asset $assetId: $e');
    }
  }

  /// Get fresh generations for a specific asset from service
  Future<List<ImageGeneration>> getAssetGenerations(String assetId, {int limit = 50}) async {
    try {
      if (_assetService is ApiImageAssetService) {
        final result = await _assetService.getAssetGenerations(
          assetId,
          limit: limit,
        );
        return List<ImageGeneration>.from(result['generations'] as List);
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

  Future<void> generateImage(GenerationRequest request, {required String projectName, required String projectId, required String assetId, Function? checkQuota}) async {
    if (_isGenerating) return;

    _isGenerating = true;
    // Ensure request has assetId for online mode (backend endpoint requires it in URL path)
    final requestWithAssetId = GenerationRequest(
      assetId: assetId,
      positivePrompt: request.positivePrompt,
      negativePrompt: request.negativePrompt,
      model: request.model,
      width: request.width,
      height: request.height,
      steps: request.steps,
      cfgScale: request.cfgScale,
      sampler: request.sampler,
      scheduler: request.scheduler,
      seed: request.seed,
      loras: request.loras,
    );

    _currentRequest = requestWithAssetId;
    notifyListeners();

    try {
      // Check quota before generation if callback provided
      if (checkQuota != null) {
        final hasQuota = await checkQuota();
        if (!hasQuota) {
          throw QuotaExceededException('image_generation');
        }
      }
      
      // Skip service running check for online mode
      final isOnlineMode = kIsWeb || (currentBackendName == 'Automatic1111' && 
                           _settingsProvider.a1111Mode == A1111Mode.online);
      
      if (!isOnlineMode && !isServiceRunning) {
        throw Exception('${currentBackendName} service is not running. Please start the service first.');
      }

      // Find the target asset
      final asset = await getAsset(assetId);
      if (asset == null) {
        throw Exception('Asset not found: $assetId');
      }

      if (isOnlineMode) {
        // ONLINE MODE: Submit the job and return immediately.
        // The backend creates the generation via POST /assets/{assetId}/generations.
        await _a1111Service.submitGenerationOnline(requestWithAssetId);

        // Refresh quota after successful submission
        if (_quotaRefreshCallback != null) {
          await _quotaRefreshCallback!();
        }

        // Refresh asset to get the new generation from server (status pending/generating)
        await _refreshSingleAsset(assetId);
      } else {
        // Build output path components (local mode only)
        final outputDir = _settingsProvider.outputDirectory.isNotEmpty
            ? _settingsProvider.outputDirectory
            : 'output';
        final safeProjectName =
            projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final safeAssetName =
            asset.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final projectFolder = '${safeProjectName}_${projectId}';
        final assetDir =
            Directory('$outputDir/$projectFolder/assets/$safeAssetName');
        if (!assetDir.existsSync()) {
          assetDir.createSync(recursive: true);
        }

        // LOCAL MODE: Use the existing flow
        // Add generation to asset (server will generate the ID)
        final generation = await _assetService.addGeneration(
          assetId, 
          request.toParameters(), 
          status: GenerationStatus.generating,
        );
        
        // Refresh quota after successful generation
        if (_quotaRefreshCallback != null) {
          await _quotaRefreshCallback!();
        }
        
        await _refreshSingleAsset(assetId); // Refresh to get updated asset

        // Generate the image using the A1111 service
        final imageData = await _a1111Service.generateImage(requestWithAssetId);

        // Use the server-generated ID for the filename
        final imageFile = File('${assetDir.path}/${generation.id}.png');
        await imageFile.writeAsBytes(imageData);

        // Upload the image to Supabase
        final uploadResult = await _assetService.uploadGenerationImage(
          generation.id,
          imageData,
          '${generation.id}.png',
        );

        // Update the generation with completed status, local path and online URL
        final updatedGeneration = generation.copyWith(
          status: GenerationStatus.completed,
          imagePath: imageFile.path,
          imageUrl: uploadResult['image_url'],
        );
        
        await _assetService.updateGeneration(updatedGeneration);
        await _refreshSingleAsset(assetId); // Refresh to get updated asset
      }

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
            await _refreshSingleAsset(assetId);
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

  /// Refresh the list of available models
  /// In online mode, this is handled by refreshA1111Models()
  /// In local mode, scans the working directory
  Future<void> refreshAvailableModels() async {
    // In online A1111 mode, models are fetched via API in refreshA1111Models()
    // Skip local filesystem scan
    if (kIsWeb || (currentBackendName == 'Automatic1111' && 
        _settingsProvider.a1111Mode == A1111Mode.online)) {
      // Models will be available via a1111Checkpoints after refreshA1111Models()
      _availableModels = [];
      notifyListeners();
      return;
    }
    
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

  /// Refresh the list of available LoRAs
  /// In online mode, this is handled by refreshA1111Models()
  /// In local mode, scans the working directory
  Future<void> refreshAvailableLoras() async {
    // In online A1111 mode, LoRAs are fetched via API in refreshA1111Models()
    // Skip local filesystem scan
    if (kIsWeb || (currentBackendName == 'Automatic1111' && 
        _settingsProvider.a1111Mode == A1111Mode.online)) {
      // LoRAs will be available via a1111Loras after refreshA1111Models()
      _availableLoras = [];
      notifyListeners();
      return;
    }
    
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

  /// Check A1111 server reachability and update state
  Future<void> checkA1111ServerStatus() async {
    try {
      _isA1111ServerReachable = await _a1111Service.isServerReachable();
    } catch (e) {
      _isA1111ServerReachable = false;
    }
    notifyListeners();
  }

  /// Refresh A1111 checkpoints and LoRAs from API
  Future<void> refreshA1111Models() async {
    if (_isLoadingA1111Models) return;
    
    _isLoadingA1111Models = true;
    notifyListeners();
    
    try {
      // Online mode: skip server status check and directly fetch from backend
      if (_settingsProvider.a1111Mode == A1111Mode.online) {
        _isA1111ServerReachable = true; // Backend API is assumed to be available
        
        // Get both checkpoints and LoRAs from backend API with proper filters
        final futures = [
          _a1111Service.getAvailableCheckpoints(),
          _a1111Service.getAvailableLoras(),
        ];
        
        final results = await Future.wait(futures);
        
        _a1111Checkpoints = results[0] as List<A1111Checkpoint>;
        _a1111Loras = results[1] as List<A1111Lora>;
        _currentA1111Checkpoint = null; // No current checkpoint concept in online mode
      } else {
        // Local mode: check server status first
        await checkA1111ServerStatus();
        
        if (!_isA1111ServerReachable) {
          _a1111Checkpoints = [];
          _a1111Loras = [];
          _currentA1111Checkpoint = null;
          return;
        }

        // Get checkpoints, LoRAs, and current checkpoint in parallel
        final futures = [
          _a1111Service.getAvailableCheckpoints(),
          _a1111Service.getAvailableLoras(),
          _a1111Service.getCurrentCheckpoint(),
        ];
        
        final results = await Future.wait(futures);
        
        _a1111Checkpoints = results[0] as List<A1111Checkpoint>;
        _a1111Loras = results[1] as List<A1111Lora>;
        _currentA1111Checkpoint = results[2] as String?;
      }
      
    } catch (e) {
      _isA1111ServerReachable = false;
      _a1111Checkpoints = [];
      _a1111Loras = [];
      _currentA1111Checkpoint = null;
      print('Error refreshing A1111 models: $e');
    } finally {
      _isLoadingA1111Models = false;
      notifyListeners();
    }
  }

  /// Get current A1111 checkpoint (refresh if needed)
  Future<void> refreshCurrentA1111Checkpoint() async {
    try {
      if (!_isA1111ServerReachable) {
        await checkA1111ServerStatus();
      }
      
      if (_isA1111ServerReachable) {
        _currentA1111Checkpoint = await _a1111Service.getCurrentCheckpoint();
        notifyListeners();
      }
    } catch (e) {
      _currentA1111Checkpoint = null;
      notifyListeners();
    }
  }

  /// Extract assets from document content using API
  @override
  Future<List<ExtractedAsset>> extractAssetsFromContent(String content) async {
    if (_currentProjectId == null) {
      throw Exception('No project selected');
    }

    if (_assetService is ApiImageAssetService) {
      try {
        final result = await _assetService.extractAssetsFromContent(
          _currentProjectId!,
          content,
        );
        return result;
      } catch (e) {
        debugPrint('Failed to extract assets from content: $e');
        rethrow;
      }
    } else {
      // Mock implementation for local service
      return _mockExtractAssetsFromContent(content);
    }
  }

  /// Mock implementation for extracting assets from content
  List<ExtractedAsset> _mockExtractAssetsFromContent(String content) {
    // Simple mock implementation - extract potential asset names from content
    final lines = content.split('\n');
    final assets = <ExtractedAsset>[];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length > 3 && trimmed.length < 100) {
        // Simple heuristic: if line looks like it could be an asset name
        if (RegExp(r'^[A-Z][a-zA-Z\s]+$').hasMatch(trimmed)) {
          // Create mock original JSON response
          final originalJson = {
            'name': trimmed,
            'description': 'Auto-extracted from document',
            'tags': ['auto-generated'],
            'metadata': {'source': 'document_extraction'},
            'confidence': 0.8,
            'extraction_method': 'mock_regex',
          };
          
          // Merge original JSON with base metadata
          final mergedMetadata = <String, dynamic>{
            'source': 'document_extraction',
          };
          mergedMetadata.addAll(originalJson);
          
          assets.add(ExtractedAsset(
            name: trimmed,
            description: 'Auto-extracted from document',
            tags: ['auto-generated'],
            metadata: mergedMetadata,
          ));
        }
      }
    }
    
    // Limit to reasonable number of assets
    return assets.take(10).toList();
  }

  /// Batch create assets from extracted asset data
  @override
  Future<void> batchCreateAssets(String projectId, List<ExtractedAsset> extractedAssets) async {
    if (_assetService is ApiImageAssetService) {
      try {
        await _assetService.batchCreateAssets(
          projectId,
          extractedAssets,
        );
        
        // Refresh assets to get the newly created ones
        await refreshAssets();
      } catch (e) {
        debugPrint('Failed to batch create assets: $e');
        rethrow;
      }
    } else {
      // Mock implementation for local service
      for (final extracted in extractedAssets) {
        try {
          await createAsset(extracted.name, extracted.description ?? '');
        } catch (e) {
          debugPrint('Failed to create asset ${extracted.name}: $e');
        }
      }
    }
  }

  /// Legacy method that returns created assets (for backward compatibility)
  Future<List<ImageAsset>> batchCreateAssetsWithReturn(List<ExtractedAsset> extractedAssets) async {
    if (_currentProjectId == null) {
      throw Exception('No project selected');
    }

    if (_assetService is ApiImageAssetService) {
      try {
        final result = await _assetService.batchCreateAssets(
          _currentProjectId!,
          extractedAssets,
        );
        
        // Refresh assets to get the newly created ones
        await refreshAssets();
        
        return result;
      } catch (e) {
        debugPrint('Failed to batch create assets: $e');
        rethrow;
      }
    } else {
      // Mock implementation for local service
      final createdAssets = <ImageAsset>[];
      
      for (final extracted in extractedAssets) {
        try {
          final asset = await createAsset(extracted.name, extracted.description ?? '');
          createdAssets.add(asset);
        } catch (e) {
          debugPrint('Failed to create asset ${extracted.name}: $e');
        }
      }
      
      return createdAssets;
    }
  }
} 