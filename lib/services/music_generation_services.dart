import 'dart:async';
import '../models/music_generation_models.dart';
import '../models/sfx_generation_models.dart'; // For GenerationStatus
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import 'api_client.dart';

// Service interfaces
abstract class MusicAssetService {
  Future<List<MusicAsset>> getProjectMusicAssets(String projectId);
  Future<MusicAsset> getMusicAsset(String assetId);
  Future<MusicAsset> createMusicAsset(String projectId, String name, String description);
  Future<MusicAsset> updateMusicAsset(MusicAsset asset);
  Future<void> deleteMusicAsset(String assetId);
  Future<MusicGeneration> addMusicGeneration(String assetId, MusicGenerationRequest request, {GenerationStatus status = GenerationStatus.pending});
  Future<MusicGeneration> getMusicGeneration(String generationId);
  Future<void> setFavoriteMusicGeneration(String assetId, String generationId);
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo);
}

/// Service factory to create the appropriate Music asset service
class MusicAssetServiceFactory {
  static MusicAssetService create({
    String? apiBaseUrl,
    bool useApiService = false,
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    if (useApiService && settingsProvider != null) {
      return ApiMusicAssetService(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      );
    } else if (useApiService && apiBaseUrl != null) {
      // Fallback for backward compatibility
      return ApiMusicAssetService(baseUrl: apiBaseUrl);
    }
    return MockMusicAssetService();
  }
}

// API implementation using FastAPI backend
class ApiMusicAssetService implements MusicAssetService {
  late final ApiClient _apiClient;
  
  ApiMusicAssetService({
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
  Future<List<MusicAsset>> getProjectMusicAssets(String projectId) async {
    try {
      final response = await _apiClient.get(
        '/$projectId/music-assets',
        queryParameters: {
          'limit': 200, // Get all assets
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return assetsData.map((assetJson) => _parseMusicAsset(assetJson)).toList();
    } catch (e) {
      throw Exception('Failed to get project music assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get project music assets with advanced filtering
  Future<Map<String, dynamic>> getProjectMusicAssetsWithFilters(
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
        '/$projectId/music-assets',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return {
        'assets': assetsData.map((assetJson) => _parseMusicAsset(assetJson)).toList(),
        'total': data['total'],
        'has_more': data['has_more'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get filtered project music assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<MusicAsset> getMusicAsset(String assetId) async {
    try {
      final response = await _apiClient.get('/music-assets/$assetId');
      return _parseMusicAsset(response.data);
    } catch (e) {
      throw Exception('Failed to get music asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get music asset generations with filtering
  Future<Map<String, dynamic>> getMusicAssetGenerations(
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
        '/music-assets/$assetId/generations',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final generationsData = data['generations'] as List<dynamic>;
      
      return {
        'generations': generationsData.map((genJson) => _parseMusicGeneration(genJson)).toList(),
        'total': data['total'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get music asset generations: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<MusicAsset> createMusicAsset(String projectId, String name, String description) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/music-assets',
        data: {
          'name': name,
          'description': description,
          'tags': <String>[],
          'metadata': <String, dynamic>{},
        },
      );
      
      return _parseMusicAsset(response.data);
    } catch (e) {
      throw Exception('Failed to create music asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<MusicAsset> updateMusicAsset(MusicAsset asset) async {
    try {
      final response = await _apiClient.put(
        '/music-assets/${asset.id}',
        data: {
          'name': asset.name,
          'description': asset.description,
          'tags': asset.tags,
          'metadata': asset.metadata,
        },
      );
      
      return _parseMusicAsset(response.data);
    } catch (e) {
      throw Exception('Failed to update music asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> deleteMusicAsset(String assetId) async {
    try {
      await _apiClient.delete('/music-assets/$assetId');
    } catch (e) {
      throw Exception('Failed to delete music asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<MusicGeneration> addMusicGeneration(String assetId, MusicGenerationRequest request, {GenerationStatus status = GenerationStatus.pending}) async {
    try {
      final response = await _apiClient.post(
        '/music-assets/$assetId/generations',
        data: request.toJson(),
      );
      
      return _parseMusicGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to create music generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<MusicGeneration> getMusicGeneration(String generationId) async {
    try {
      final response = await _apiClient.get('/music-generations/$generationId');
      return _parseMusicGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to get music generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> setFavoriteMusicGeneration(String assetId, String generationId) async {
    try {
      await _apiClient.put('/music-assets/$assetId/favorite/$generationId');
    } catch (e) {
      throw Exception('Failed to set favorite music generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/music-assets/generate-prompt',
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
      throw Exception('Failed to generate music prompt: ${ErrorHandler.getErrorMessage(e)}');
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

  /// Parse API response to MusicAsset model
  MusicAsset _parseMusicAsset(Map<String, dynamic> json) {
    final generations = <MusicGeneration>[];
    
    if (json['generations'] != null) {
      final generationsData = json['generations'] as List<dynamic>;
      generations.addAll(
        generationsData.map((genJson) => _parseMusicGeneration(genJson)),
      );
    }

    return MusicAsset(
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

  /// Parse API response to MusicGeneration model
  MusicGeneration _parseMusicGeneration(Map<String, dynamic> json) {
    return MusicGeneration(
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
    );
  }

  /// Parse status string to GenerationStatus enum
  GenerationStatus _parseGenerationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return GenerationStatus.pending;
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
class MockMusicAssetService implements MusicAssetService {
  static final List<MusicAsset> _mockAssets = [];
  
  @override
  Future<List<MusicAsset>> getProjectMusicAssets(String projectId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_mockAssets.isEmpty) {
      _generateMockAssets(projectId);
    }
    
    return _mockAssets.where((asset) => asset.projectId == projectId).toList();
  }

  @override
  Future<MusicAsset> getMusicAsset(String assetId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockAssets.firstWhere((asset) => asset.id == assetId);
  }

  @override
  Future<MusicAsset> createMusicAsset(String projectId, String name, String description) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final asset = MusicAsset(
      id: 'music_asset_${DateTime.now().millisecondsSinceEpoch}',
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
  Future<MusicAsset> updateMusicAsset(MusicAsset asset) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final index = _mockAssets.indexWhere((a) => a.id == asset.id);
    if (index != -1) {
      _mockAssets[index] = asset;
    }
    
    return asset;
  }

  @override
  Future<void> deleteMusicAsset(String assetId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockAssets.removeWhere((asset) => asset.id == assetId);
  }

  @override
  Future<MusicGeneration> addMusicGeneration(String assetId, MusicGenerationRequest request, {GenerationStatus status = GenerationStatus.pending}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final generation = MusicGeneration(
      id: 'music_gen_${DateTime.now().millisecondsSinceEpoch}',
      assetId: assetId,
      parameters: request.toParameters(),
      createdAt: DateTime.now(),
      status: status,
      duration: request.musicLengthMs / 1000.0, // Convert ms to seconds
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
  Future<MusicGeneration> getMusicGeneration(String generationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    for (var asset in _mockAssets) {
      for (var generation in asset.generations) {
        if (generation.id == generationId) {
          return generation;
        }
      }
    }
    
    throw Exception('Music generation not found: $generationId');
  }

  @override
  Future<void> setFavoriteMusicGeneration(String assetId, String generationId) async {
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
    final name = (assetInfo['name'] ?? 'music track').toString();
    final lengthMs = generatorInfo['music_length_ms'] ?? 30000;
    return 'An engaging, cohesive composition for $name, evolving themes, clear structure, rich instrumentation, suitable for ${lengthMs ~/ 1000}s duration, professionally mixed and mastered.';
  }

  void _generateMockAssets(String projectId) {
    _mockAssets.addAll([
      MusicAsset(
        id: 'music_1',
        projectId: projectId,
        name: 'Menu Theme',
        description: 'Background music for main menu',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        generations: [
          MusicGeneration(
            id: 'music_gen_1',
            assetId: 'music_1',
            parameters: {
              'prompt': 'Peaceful, ambient menu music with soft piano',
              'music_length_ms': 60000,
            },
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            status: GenerationStatus.completed,
            duration: 60.0,
          ),
        ],
        tags: ['menu', 'ambient', 'piano'],
        totalGenerations: 1,
      ),
      MusicAsset(
        id: 'music_2',
        projectId: projectId,
        name: 'Battle Theme',
        description: 'Energetic music for combat scenes',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        generations: [],
        tags: ['battle', 'energetic'],
        totalGenerations: 0,
      ),
    ]);
  }
}

