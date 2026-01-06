import 'dart:async';
import '../models/sfx_generation_models.dart';
import '../models/extracted_asset_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import 'api_client.dart';

// Service interfaces
abstract class SfxAssetService {
  Future<List<SfxAsset>> getProjectSfxAssets(String projectId);
  Future<SfxAsset> getSfxAsset(String assetId);
  Future<SfxAsset> createSfxAsset(String projectId, String name, String description);
  Future<SfxAsset> updateSfxAsset(SfxAsset asset);
  Future<void> deleteSfxAsset(String assetId);
  Future<SfxGeneration> addSfxGeneration(String assetId, SfxGenerationRequest request, {GenerationStatus status = GenerationStatus.pending});
  Future<SfxGeneration> getSfxGeneration(String generationId);
  Future<void> setFavoriteSfxGeneration(String assetId, String generationId);
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo);
}

/// Service factory to create the appropriate SFX asset service
class SfxAssetServiceFactory {
  static SfxAssetService create({
    String? apiBaseUrl,
    bool useApiService = false,
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    if (useApiService && settingsProvider != null) {
      return ApiSfxAssetService(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      );
    } else if (useApiService && apiBaseUrl != null) {
      // Fallback for backward compatibility
      return ApiSfxAssetService(baseUrl: apiBaseUrl);
    }
    return MockSfxAssetService();
  }
}

// API implementation using FastAPI backend
class ApiSfxAssetService implements SfxAssetService {
  late final ApiClient _apiClient;
  
  ApiSfxAssetService({
    String? baseUrl,
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }
  
  /// Get the current base URL from ApiClient
  String get _baseUrl => _apiClient.baseUrl;

  @override
  Future<List<SfxAsset>> getProjectSfxAssets(String projectId) async {
    try {
      final response = await _apiClient.get(
        '/$projectId/sfx-assets',
        queryParameters: {
          'limit': 200, // Get all assets
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return assetsData.map((assetJson) => _parseSfxAsset(assetJson)).toList();
    } catch (e) {
      throw Exception('Failed to get project SFX assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get project SFX assets with advanced filtering
  Future<Map<String, dynamic>> getProjectSfxAssetsWithFilters(
    String projectId, {
    int limit = 50,
    int offset = 0,
    String? search,
    List<String>? tags,
    bool? hasGenerations,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };

      if (search != null) queryParams['search'] = search;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');
      if (hasGenerations != null) queryParams['has_generations'] = hasGenerations;

      final response = await _apiClient.get(
        '/$projectId/sfx-assets',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return {
        'assets': assetsData.map((assetJson) => _parseSfxAsset(assetJson)).toList(),
        'total': data['total'],
        'has_more': data['has_more'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get filtered project SFX assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<SfxAsset> getSfxAsset(String assetId) async {
    try {
      final response = await _apiClient.get('/sfx-assets/$assetId');
      return _parseSfxAsset(response.data);
    } catch (e) {
      throw Exception('Failed to get SFX asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get SFX asset generations with filtering
  Future<Map<String, dynamic>> getSfxAssetGenerations(
    String assetId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };

      final response = await _apiClient.get(
        '/sfx-assets/$assetId/generations',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final generationsData = data['generations'] as List<dynamic>;
      
      return {
        'generations': generationsData.map((genJson) => _parseSfxGeneration(genJson)).toList(),
        'total': data['total'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get SFX asset generations: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<SfxAsset> createSfxAsset(String projectId, String name, String description) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/sfx-assets',
        data: {
          'name': name,
          'description': description,
          'tags': <String>[],
          'metadata': <String, dynamic>{},
        },
      );
      
      return _parseSfxAsset(response.data);
    } catch (e) {
      throw Exception('Failed to create SFX asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<SfxAsset> updateSfxAsset(SfxAsset asset) async {
    try {
      final response = await _apiClient.put(
        '/sfx-assets/${asset.id}',
        data: {
          'name': asset.name,
          'description': asset.description,
          'tags': asset.tags,
          'metadata': asset.metadata,
        },
      );
      
      return _parseSfxAsset(response.data);
    } catch (e) {
      throw Exception('Failed to update SFX asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> deleteSfxAsset(String assetId) async {
    try {
      await _apiClient.delete('/sfx-assets/$assetId');
    } catch (e) {
      throw Exception('Failed to delete SFX asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<SfxGeneration> addSfxGeneration(String assetId, SfxGenerationRequest request, {GenerationStatus status = GenerationStatus.pending}) async {
    try {
      final response = await _apiClient.post(
        '/sfx-assets/$assetId/generations',
        data: request.toJson(),
      );
      
      return _parseSfxGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to create SFX generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<SfxGeneration> getSfxGeneration(String generationId) async {
    try {
      final response = await _apiClient.get('/sfx-generations/$generationId');
      return _parseSfxGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to get SFX generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> setFavoriteSfxGeneration(String assetId, String generationId) async {
    try {
      await _apiClient.put('/sfx-assets/$assetId/favorite/$generationId');
    } catch (e) {
      throw Exception('Failed to set favorite SFX generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/sfx-assets/generate-prompt',
        data: {
          'asset_info': assetInfo,
          'generator_info': generatorInfo,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final prompt = data['prompt'] as String?;
      if (prompt == null || prompt.isEmpty) {
        throw Exception('Empty prompt received from server');
      }
      return prompt;
    } catch (e) {
      throw Exception('Failed to generate SFX prompt: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final response = await _apiClient.dio.get('$_baseUrl/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Parse API response to SfxAsset model
  SfxAsset _parseSfxAsset(Map<String, dynamic> json) {
    final generations = <SfxGeneration>[];
    
    if (json['generations'] != null) {
      final generationsData = json['generations'] as List<dynamic>;
      generations.addAll(
        generationsData.map((genJson) => _parseSfxGeneration(genJson)),
      );
    }

    return SfxAsset(
      id: json['id'] as String,
      projectId: json['project_id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      generations: generations,
      favoriteGenerationId: json['favorite_generation_id'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      fileSize: json['file_size'] as int?,
      totalGenerations: json['total_generations'] as int? ?? 0,
    );
  }

  /// Parse API response to SfxGeneration model
  SfxGeneration _parseSfxGeneration(Map<String, dynamic> json) {
    return SfxGeneration(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      audioPath: json['audio_path'] as String?,
      audioUrl: json['audio_url'] as String?,
      parameters: Map<String, dynamic>.from(json['parameters'] as Map? ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _parseGenerationStatus(json['status'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      fileSize: json['file_size'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
      format: json['format'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      queuedAt: json['queued_at'] != null ? DateTime.parse(json['queued_at'] as String) : null,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Extract assets from document content using API
  Future<List<ExtractedAsset>> extractAssetsFromContent(String projectId, String content) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/sfx-assets/extract',
        data: {
          'file_content': content,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;

      return assetsData.map((assetJson) {
        // Create a copy of the original JSON for metadata
        final originalJson = Map<String, dynamic>.from(assetJson);
        
        // Create the asset with original JSON in metadata
        final asset = _parseExtractedAsset(assetJson);
        
        // Merge original JSON with existing metadata (original JSON takes precedence)
        final updatedMetadata = Map<String, dynamic>.from(asset.metadata);
        updatedMetadata.addAll(originalJson);
        
        return ExtractedAsset(
          name: asset.name,
          description: asset.description,
          tags: asset.tags,
          metadata: updatedMetadata,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to extract SFX assets from content: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Batch create assets from extracted asset data
  Future<List<SfxAsset>> batchCreateAssets(String projectId, List<ExtractedAsset> extractedAssets) async {
    try {
      // Convert ExtractedAsset to SfxAssetCreateRequest format
      final assetsData = extractedAssets.map((asset) => {
        'name': asset.name,
        'description': asset.description ?? '',
        'tags': asset.tags,
        'metadata': asset.metadata,
      }).toList();

      final response = await _apiClient.post(
        '/$projectId/sfx-assets/batch-create',
        data: {
          'assets': assetsData,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final createdData = data['created'] as List<dynamic>;
      
      return createdData.map((assetJson) => _parseSfxAsset(assetJson)).toList();
    } catch (e) {
      throw Exception('Failed to batch create SFX assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Parse ExtractedAsset from JSON
  ExtractedAsset _parseExtractedAsset(Map<String, dynamic> json) {
    return ExtractedAsset(
      name: json['name'] as String,
      description: json['description'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Parse status string to GenerationStatus enum
  GenerationStatus _parseGenerationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return GenerationStatus.pending;
      case 'queued':
        return GenerationStatus.queued;
      case 'generating':
        return GenerationStatus.generating;
      case 'completed':
        return GenerationStatus.completed;
      case 'failed':
        return GenerationStatus.failed;
      default:
        return GenerationStatus.pending;
    }
  }
}

// Mock implementation for testing/development
class MockSfxAssetService implements SfxAssetService {
  static final List<SfxAsset> _mockAssets = [];
  
  @override
  Future<List<SfxAsset>> getProjectSfxAssets(String projectId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_mockAssets.isEmpty) {
      _generateMockAssets(projectId);
    }
    
    return _mockAssets.where((asset) => asset.projectId == projectId).toList();
  }

  @override
  Future<SfxAsset> getSfxAsset(String assetId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockAssets.firstWhere((asset) => asset.id == assetId);
  }

  @override
  Future<SfxAsset> createSfxAsset(String projectId, String name, String description) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final asset = SfxAsset(
      id: 'sfx_asset_${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      generations: [],
    );
    
    _mockAssets.add(asset);
    return asset;
  }

  @override
  Future<SfxAsset> updateSfxAsset(SfxAsset asset) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final index = _mockAssets.indexWhere((a) => a.id == asset.id);
    if (index != -1) {
      _mockAssets[index] = asset;
    }
    
    return asset;
  }

  @override
  Future<void> deleteSfxAsset(String assetId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockAssets.removeWhere((asset) => asset.id == assetId);
  }

  @override
  Future<SfxGeneration> addSfxGeneration(String assetId, SfxGenerationRequest request, {GenerationStatus status = GenerationStatus.pending}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final generation = SfxGeneration(
      id: 'sfx_gen_${DateTime.now().millisecondsSinceEpoch}',
      assetId: assetId,
      parameters: request.toParameters(),
      createdAt: DateTime.now(),
      status: status,
      duration: request.durationSeconds ?? 2.0,
    );
    
    final assetIndex = _mockAssets.indexWhere((a) => a.id == assetId);
    if (assetIndex != -1) {
      final asset = _mockAssets[assetIndex];
      final updatedGenerations = [...asset.generations, generation];
      
      _mockAssets[assetIndex] = asset.copyWith(
        generations: updatedGenerations,
        totalGenerations: updatedGenerations.length,
      );
    }
    
    return generation;
  }

  @override
  Future<SfxGeneration> getSfxGeneration(String generationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    for (var asset in _mockAssets) {
      for (var generation in asset.generations) {
        if (generation.id == generationId) {
          return generation;
        }
      }
    }
    
    throw Exception('SFX generation not found: $generationId');
  }

  @override
  Future<void> setFavoriteSfxGeneration(String assetId, String generationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final assetIndex = _mockAssets.indexWhere((a) => a.id == assetId);
    if (assetIndex != -1) {
      final asset = _mockAssets[assetIndex];
      _mockAssets[assetIndex] = asset.copyWith(favoriteGenerationId: generationId);
      
      // Update generation's favorite status
      final updatedGenerations = asset.generations.map((gen) {
        return gen.copyWith(isFavorite: gen.id == generationId);
      }).toList();
      
      _mockAssets[assetIndex] = _mockAssets[assetIndex].copyWith(generations: updatedGenerations);
    }
  }

  @override
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final name = (assetInfo['name'] ?? 'sound effect').toString();
    final duration = (generatorInfo['duration_seconds'] ?? 2.0).toString();
    final influence = ((generatorInfo['prompt_influence'] ?? 0.5) as num).toDouble();
    final influencePct = (influence * 100).round();
    return 'A clean, production-ready $name, $duration s, minimal background noise, $influencePct% adherence to description, crisp transients, natural decay, game-ready.';
  }

  void _generateMockAssets(String projectId) {
    _mockAssets.addAll([
      SfxAsset(
        id: 'sfx_1',
        projectId: projectId,
        name: 'Laser Sounds',
        description: 'Various laser sound effects for weapons',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        generations: [
          SfxGeneration(
            id: 'sfx_gen_1',
            assetId: 'sfx_1',
            parameters: {
              'prompt': 'Laser shooting sound, slowly fading away as the laser travels',
              'duration_seconds': 2.0,
              'model': 'elevenlabs',
            },
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            status: GenerationStatus.completed,
            duration: 2.0,
          ),
        ],
        tags: ['weapon', 'laser', 'sci-fi'],
        totalGenerations: 1,
      ),
      SfxAsset(
        id: 'sfx_2',
        projectId: projectId,
        name: 'Ambient Sounds',
        description: 'Background ambient sounds for levels',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        generations: [],
        tags: ['ambient', 'background'],
        totalGenerations: 0,
      ),
    ]);
  }
} 