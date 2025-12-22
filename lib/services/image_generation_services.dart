import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/services.dart';
import '../models/image_generation_models.dart';
import '../models/extracted_asset_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import '../utils/app_constants.dart';
import 'api_client.dart';
import 'a1111_online_service.dart';

// Service interfaces
abstract class ImageAssetService {
  Future<List<ImageAsset>> getProjectAssets(String projectId);
  Future<ImageAsset> getAsset(String assetId);
  Future<ImageAsset> createAsset(String projectId, String name, String description);
  Future<ImageAsset> updateAsset(ImageAsset asset);
  Future<void> deleteAsset(String assetId);
  Future<void> deleteGeneration(String generationId);
  Future<ImageGeneration> addGeneration(String assetId, Map<String, dynamic> parameters, {GenerationStatus status = GenerationStatus.pending});
  Future<ImageGeneration> updateGeneration(ImageGeneration generation);
  Future<ImageGeneration> getGeneration(String generationId);
  Future<Map<String, dynamic>> uploadGenerationImage(String generationId, Uint8List imageData, String filename);
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo);
}

abstract class ModelService {
  Future<List<AIModel>> getAvailableModels();
  Future<List<AIModel>> getCheckpointModels();
  Future<List<AIModel>> getLoraModels();
  Future<void> refreshModels();
}

/// Service factory to create the appropriate asset service
class ImageAssetServiceFactory {
  static ImageAssetService create({
    String? apiBaseUrl,
    bool useApiService = false,
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    if (useApiService && settingsProvider != null) {
      return ApiImageAssetService(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      );
    } else if (useApiService && apiBaseUrl != null) {
      // Fallback for backward compatibility
      return ApiImageAssetService(baseUrl: apiBaseUrl);
    }
    return MockImageAssetService();
  }
}

// API implementation using FastAPI backend
class ApiImageAssetService implements ImageAssetService {
  late final ApiClient _apiClient;
  
  ApiImageAssetService({
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
  Future<List<ImageAsset>> getProjectAssets(String projectId) async {
    try {
      final response = await _apiClient.get(
        '/$projectId/assets',
        queryParameters: {
          'limit': 200, // Get all assets
          'sort_by': 'created_at',
          'sort_order': 'desc',
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return assetsData.map((assetJson) => _parseImageAsset(assetJson)).toList();
    } catch (e) {
      throw Exception('Failed to get project assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get project assets with advanced filtering
  Future<Map<String, dynamic>> getProjectAssetsWithFilters(
    String projectId, {
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
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (search != null) queryParams['search'] = search;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');
      if (hasGenerations != null) queryParams['has_generations'] = hasGenerations;
      if (createdAfter != null) queryParams['created_after'] = createdAfter.toIso8601String();
      if (createdBefore != null) queryParams['created_before'] = createdBefore.toIso8601String();

      final response = await _apiClient.get(
        '/$projectId/assets',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final assetsData = data['assets'] as List<dynamic>;
      
      return {
        'assets': assetsData.map((assetJson) => _parseImageAsset(assetJson)).toList(),
        'total': data['total'],
        'has_more': data['has_more'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get filtered project assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<ImageAsset> getAsset(String assetId) async {
    try {
      final response = await _apiClient.get(
        '/assets/$assetId',
        queryParameters: {'include_generations': true},
      );
      
      return _parseImageAsset(response.data);
    } catch (e) {
      throw Exception('Failed to get asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get asset generations with filtering
  Future<Map<String, dynamic>> getAssetGenerations(
    String assetId, {
    int limit = 20,
    int offset = 0,
    String? status,
    bool? isFavorite,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };

      if (status != null) queryParams['status'] = status;
      if (isFavorite != null) queryParams['is_favorite'] = isFavorite;

      final response = await _apiClient.get(
        '/assets/$assetId/generations',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final generationsData = data['generations'] as List<dynamic>;
      
      return {
        'generations': generationsData.map((genJson) => _parseImageGeneration(genJson)).toList(),
        'total': data['total'],
        'limit': data['limit'],
        'offset': data['offset'],
      };
    } catch (e) {
      throw Exception('Failed to get asset generations: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<ImageAsset> createAsset(String projectId, String name, String description) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/assets',
        data: {
          'name': name,
          'description': description,
          'tags': <String>[],
          'metadata': <String, dynamic>{},
        },
      );
      
      return _parseImageAsset(response.data);
    } catch (e) {
      throw Exception('Failed to create asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Create multiple assets at once
  Future<Map<String, dynamic>> createBulkAssets(
    String projectId,
    List<Map<String, dynamic>> assetsData,
  ) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/assets/bulk',
        data: {'assets': assetsData},
      );
      
      final data = response.data as Map<String, dynamic>;
      final createdData = data['created'] as List<dynamic>;
      final failedData = data['failed'] as List<dynamic>;
      
      return {
        'created': createdData.map((assetJson) => _parseImageAsset(assetJson)).toList(),
        'failed': failedData,
      };
    } catch (e) {
      throw Exception('Failed to create bulk assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<ImageAsset> updateAsset(ImageAsset asset) async {
    try {
      final response = await _apiClient.put(
        '/assets/${asset.id}',
        data: {
          'name': asset.name,
          'description': asset.description,
          'tags': <String>[], // Add tags support when available in models
          'metadata': <String, dynamic>{},
        },
      );
      
      return _parseImageAsset(response.data);
    } catch (e) {
      throw Exception('Failed to update asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    try {
      await _apiClient.delete(
        '/assets/$assetId',
        queryParameters: {'force': true},
      );
    } catch (e) {
      throw Exception('Failed to delete asset: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Delete multiple assets at once
  Future<Map<String, dynamic>> deleteBulkAssets(
    String projectId,
    List<String> assetIds, {
    bool force = false,
  }) async {
    try {
      final response = await _apiClient.delete(
        '/$projectId/assets/bulk',
        data: {
          'asset_ids': assetIds,
          'force': force,
        },
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to delete bulk assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<void> deleteGeneration(String generationId) async {
    try {
      await _apiClient.delete('/generations/$generationId');
    } catch (e) {
      throw Exception('Failed to delete generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get a specific generation by ID
  Future<ImageGeneration> getGeneration(String generationId) async {
    try {
      final response = await _apiClient.get('/generations/$generationId');
      return _parseImageGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to get generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<ImageGeneration> addGeneration(String assetId, Map<String, dynamic> parameters, {GenerationStatus status = GenerationStatus.pending}) async {
    try {
      final response = await _apiClient.post(
        '/assets/$assetId/generations',
        data: {
          'parameters': parameters,
          'status': status.name,
        },
      );
      
      return _parseImageGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to add generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<ImageGeneration> updateGeneration(ImageGeneration generation) async {
    try {
      final response = await _apiClient.put(
        '/generations/${generation.id}',
        data: {
          'status': generation.status.name,
          'is_favorite': generation.isFavorite,
          'image_path': generation.imagePath,
          'metadata': <String, dynamic>{},
        },
      );
      
      return _parseImageGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to update generation: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Mark a generation as favorite
  Future<ImageGeneration> markGenerationFavorite(String generationId) async {
    try {
      final response = await _apiClient.post('/generations/$generationId/favorite');
      return _parseImageGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to mark generation as favorite: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Remove favorite status from a generation
  Future<ImageGeneration> removeGenerationFavorite(String generationId) async {
    try {
      final response = await _apiClient.delete('/generations/$generationId/favorite');
      return _parseImageGeneration(response.data);
    } catch (e) {
      throw Exception('Failed to remove generation favorite: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Upload an image file for a generation
  Future<Map<String, dynamic>> uploadGenerationImage(String generationId, Uint8List imageData, String filename) async {
    try {
      // Create multipart file with proper content type
      final multipartFile = MultipartFile.fromBytes(
        imageData,
        filename: filename,
        contentType: MediaType('image', 'png'),
      );
      
      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      // Don't manually set Content-Type header - let Dio handle it automatically with proper boundary
      final response = await _apiClient.post(
        '/generations/$generationId/upload',
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to upload generation image: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  @override
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/assets/generate-prompt',
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
      throw Exception('Failed to generate image prompt: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Complete generation workflow: create generation, upload image, update status
  Future<ImageGeneration> completeGenerationWorkflow(
    String assetId,
    Map<String, dynamic> parameters,
    Uint8List imageData,
    String filename,
  ) async {
    try {
      // 1. Create generation (server generates ID)
      final generation = await addGeneration(assetId, parameters, status: GenerationStatus.generating);
      
      // 2. Upload image
      final uploadResult = await uploadGenerationImage(generation.id, imageData, filename);
      
      // 3. Update generation with completed status and image path
      final updatedGeneration = await updateGeneration(
        generation.copyWith(
          status: GenerationStatus.completed,
          imagePath: uploadResult['image_path'],
        ),
      );
      
      return updatedGeneration;
    } catch (e) {
      throw Exception('Failed to complete generation workflow: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get project statistics
  Future<Map<String, dynamic>> getProjectStats(String projectId) async {
    try {
      final response = await _apiClient.get('/$projectId/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get project stats: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get project tags
  Future<List<Map<String, dynamic>>> getProjectTags(String projectId) async {
    try {
      final response = await _apiClient.get('/$projectId/tags');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['tags']);
    } catch (e) {
      throw Exception('Failed to get project tags: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get image URL for serving
  String getImageUrl(String imageId) {
    return '/files/images/$imageId';
  }

  /// Get asset thumbnail URL
  String getAssetThumbnailUrl(String assetId, {String size = 'medium'}) {
    return '/assets/$assetId/thumbnail?size=$size';
  }

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final response = await _apiClient.get('$_baseUrl/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Extract assets from document content
  Future<List<ExtractedAsset>> extractAssetsFromContent(String projectId, String content) async {
    try {
      final response = await _apiClient.post(
        '/$projectId/assets/extract',
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
        final asset = ExtractedAsset.fromJson(assetJson);
        
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
      throw Exception('Failed to extract assets from content: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Batch create assets from extracted data
  Future<List<ImageAsset>> batchCreateAssets(String projectId, List<ExtractedAsset> extractedAssets) async {
    try {
      final assetsData = extractedAssets.map((asset) => {
        'name': asset.name,
        'description': asset.description,
        'tags': asset.tags,
        'metadata': asset.metadata,
      }).toList();

      final response = await _apiClient.post(
        '/$projectId/assets/batch-create',
        data: {
          'assets': assetsData,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final createdAssetsData = data['created'] as List<dynamic>;

      return createdAssetsData.map((assetJson) => _parseImageAsset(assetJson)).toList();
    } catch (e) {
      throw Exception('Failed to batch create assets: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Parse API response to ImageAsset model
  ImageAsset _parseImageAsset(Map<String, dynamic> json) {
    final generations = <ImageGeneration>[];
    
    if (json['generations'] != null) {
      final generationsData = json['generations'] as List<dynamic>;
      generations.addAll(
        generationsData.map((genJson) => _parseImageGeneration(genJson)),
      );
    }

    // Parse total_generations if available (when generations list is not included)
    int? totalGenerations;
    if (json['total_generations'] != null) {
      totalGenerations = json['total_generations'] as int;
    }

    // Parse tags
    List<String> tags = [];
    if (json['tags'] != null) {
      tags = List<String>.from(json['tags'] as List<dynamic>);
    }

    // Parse metadata
    Map<String, dynamic> metadata = {};
    if (json['metadata'] != null) {
      metadata = Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>);
    }

    return ImageAsset(
      id: json['id'] as String,
      projectId: json['project_id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      generations: generations,
      thumbnail: json['thumbnail'] as String?,
      favoriteGenerationId: json['favorite_generation_id'] as String?,
      totalGenerations: totalGenerations,
      tags: tags,
      metadata: metadata,
    );
  }

  /// Parse API response to ImageGeneration model
  ImageGeneration _parseImageGeneration(Map<String, dynamic> json) {
    return ImageGeneration(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      imagePath: json['image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      parameters: Map<String, dynamic>.from(json['parameters'] as Map? ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _parseGenerationStatus(json['status'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
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

// Mock implementations
class MockImageAssetService implements ImageAssetService {
  static final List<ImageAsset> _mockAssets = [];
  static final Random _random = Random();

  @override
  Future<List<ImageAsset>> getProjectAssets(String projectId) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 300));
    
    if (_mockAssets.isEmpty) {
      _generateMockAssets(projectId);
    }
    
    return _mockAssets.where((asset) => asset.projectId == projectId).toList();
  }

  @override
  Future<ImageAsset> getAsset(String assetId) async {
    await Future.delayed(Duration(milliseconds: 200));
    return _mockAssets.firstWhere((asset) => asset.id == assetId);
  }

  @override
  Future<ImageAsset> createAsset(String projectId, String name, String description) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    final asset = ImageAsset(
      id: 'asset_${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      generations: [],
    );
    
    _mockAssets.add(asset);
    return asset;
  }

  @override
  Future<ImageAsset> updateAsset(ImageAsset asset) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    final index = _mockAssets.indexWhere((a) => a.id == asset.id);
    if (index != -1) {
      _mockAssets[index] = asset;
    }
    
    return asset;
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    await Future.delayed(Duration(milliseconds: 300));
    _mockAssets.removeWhere((asset) => asset.id == assetId);
  }

  @override
  Future<void> deleteGeneration(String generationId) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    for (var asset in _mockAssets) {
      asset.generations.removeWhere((gen) => gen.id == generationId);
    }
  }

  @override
  Future<ImageGeneration> addGeneration(String assetId, Map<String, dynamic> parameters, {GenerationStatus status = GenerationStatus.pending}) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    // Create a new generation with server-generated ID
    final generation = ImageGeneration(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}', // Mock server-generated ID
      assetId: assetId,
      imagePath: '', // Will be set when image is uploaded
      parameters: parameters,
      createdAt: DateTime.now(),
      status: status,
      isFavorite: false,
    );
    
    final assetIndex = _mockAssets.indexWhere((a) => a.id == assetId);
    if (assetIndex != -1) {
      final asset = _mockAssets[assetIndex];
      final updatedGenerations = [...asset.generations, generation];
      
      _mockAssets[assetIndex] = asset.copyWith(
        generations: updatedGenerations,
        thumbnail: asset.thumbnail ?? generation.imagePath,
      );
    }
    
    return generation;
  }

  @override
  Future<ImageGeneration> getGeneration(String generationId) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    // Find the asset that contains the generation
    for (var asset in _mockAssets) {
      for (var generation in asset.generations) {
        if (generation.id == generationId) {
          return generation;
        }
      }
    }
    
    // If generation not found, throw an exception
    throw Exception('Generation not found: $generationId');
  }

  @override
  Future<ImageGeneration> updateGeneration(ImageGeneration generation) async {
    await Future.delayed(Duration(milliseconds: 300));
    
    for (var asset in _mockAssets) {
      final genIndex = asset.generations.indexWhere((g) => g.id == generation.id);
      if (genIndex != -1) {
        asset.generations[genIndex] = generation;
        
        // Update favorite generation ID if this generation is marked as favorite
        if (generation.isFavorite) {
          final updatedAsset = asset.copyWith(favoriteGenerationId: generation.id);
          final assetIndex = _mockAssets.indexWhere((a) => a.id == asset.id);
          _mockAssets[assetIndex] = updatedAsset;
        }
        
        break;
      }
    }
    
    return generation;
  }

  @override
  Future<Map<String, dynamic>> uploadGenerationImage(String generationId, Uint8List imageData, String filename) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    // Mock implementation - just return a mock response
    return {
      'image_path': 'mock/$generationId/$filename',
      'image_url': 'https://mock-storage.example.com/$generationId/$filename',
      'file_size': imageData.length,
      'format': 'png',
    };
  }

  @override
  Future<String> generateAutoPrompt(String projectId, Map<String, dynamic> assetInfo, Map<String, dynamic> generatorInfo) async {
    await Future.delayed(Duration(milliseconds: 300));
    final name = (assetInfo['name'] ?? 'game asset').toString();
    final model = (generatorInfo['model'] ?? generatorInfo['checkpoint'] ?? 'a quality model').toString();
    final width = generatorInfo['width'] ?? 512;
    final height = generatorInfo['height'] ?? 512;
    return 'Highly detailed concept art of ' 
      '$name, cinematic lighting, intricate details, sharp focus, ' 
      'rendered with $model, ${width}x$height, masterpiece, trending on artstation.';
  }

  void _generateMockAssets(String projectId) {
    final mockAssets = [
      'Main Character Portrait',
      'Castle Background',
      'Magic Sword',
      'Forest Environment',
      'Dragon Concept',
      'UI Icons',
      'Loading Screen',
      'Title Screen Logo',
    ];

    final descriptions = [
      'Epic fantasy warrior character design',
      'Medieval castle with mountains in background',
      'Glowing magical sword with intricate details',
      'Mystical forest with ancient trees',
      'Fierce dragon with fire breathing',
      'Game UI elements and buttons',
      'Loading screen with animated elements',
      'Main title logo with fantasy theme',
    ];

    for (int i = 0; i < mockAssets.length; i++) {
      final asset = ImageAsset(
        id: 'asset_$i',
        projectId: projectId,
        name: mockAssets[i],
        description: descriptions[i],
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
        generations: _generateMockGenerations('asset_$i'),
      );
      
      _mockAssets.add(asset);
    }
  }

  List<ImageGeneration> _generateMockGenerations(String assetId) {
    final count = _random.nextInt(4) + 1; // 1-4 generations
    return List.generate(count, (index) {
      return ImageGeneration(
        id: 'gen_${assetId}_$index',
        assetId: assetId,
        imagePath: 'mock_image_$index.png',
        parameters: {
          'model': 'Realistic_Vision_V5.1',
          'positive_prompt': 'Epic fantasy artwork, highly detailed, masterpiece',
          'negative_prompt': 'low quality, blurry, distorted',
          'width': 512,
          'height': 768,
          'steps': 30,
          'cfg_scale': 7.5,
          'sampler': 'euler_a',
          'seed': _random.nextInt(1000000),
          'loras': [],
        },
        createdAt: DateTime.now().subtract(Duration(hours: _random.nextInt(48))),
        status: GenerationStatus.completed,
        isFavorite: index == 0, // First generation is favorite
      );
    });
  }
}



class MockModelService implements ModelService {
  static final List<AIModel> _mockModels = [];

  @override
  Future<List<AIModel>> getAvailableModels() async {
    await Future.delayed(Duration(milliseconds: 300));
    
    if (_mockModels.isEmpty) {
      _generateMockModels();
    }
    
    return List.from(_mockModels);
  }

  @override
  Future<List<AIModel>> getCheckpointModels() async {
    final models = await getAvailableModels();
    return models.where((model) => model.type == 'checkpoint').toList();
  }

  @override
  Future<List<AIModel>> getLoraModels() async {
    final models = await getAvailableModels();
    return models.where((model) => model.type == 'lora').toList();
  }

  @override
  Future<void> refreshModels() async {
    await Future.delayed(Duration(seconds: 1));
    _mockModels.clear();
    _generateMockModels();
  }

  void _generateMockModels() {
    // Mock checkpoint models
    final checkpoints = [
      'Realistic_Vision_V5.1',
      'DreamShaper_v7',
      'Anything_v5',
      'Epic_Realism_v5',
      'Deliberate_v2',
    ];

    for (final name in checkpoints) {
      _mockModels.add(AIModel(
        id: 'checkpoint_${name.toLowerCase()}',
        name: name,
        type: 'checkpoint',
        path: 'models/checkpoints/$name.safetensors',
        description: 'High-quality checkpoint model for $name',
        lastModified: DateTime.now().subtract(Duration(days: Random().nextInt(30))),
      ));
    }

    // Mock LoRA models
    final loras = [
      'Detail_Tweaker_LoRA',
      'Lighting_LoRA',
      'Fantasy_Style_LoRA',
      'Concept_Art_LoRA',
      'Realism_Helper_LoRA',
    ];

    for (final name in loras) {
      _mockModels.add(AIModel(
        id: 'lora_${name.toLowerCase()}',
        name: name,
        type: 'lora',
        path: 'models/loras/$name.safetensors',
        description: 'Enhancement LoRA for $name',
        lastModified: DateTime.now().subtract(Duration(days: Random().nextInt(30))),
      ));
    }
  }
} 

class A1111ImageGenerationService {
  final SettingsProvider _settingsProvider;
  final Dio _dio;
  final A1111OnlineService? _onlineService;
  
  A1111ImageGenerationService(
    this._settingsProvider, {
    A1111OnlineService? onlineService,
  })  : _dio = Dio(),
        _onlineService = onlineService {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }
  
  /// Check if currently in online mode
  bool get _isOnlineMode => _settingsProvider.a1111Mode == A1111Mode.online;
  
  /// Generate image using online mode - returns full result with generation ID
  Future<OnlineGenerationResult> generateImageOnline(GenerationRequest request) async {
    if (_onlineService == null) {
      throw Exception('Online service not initialized');
    }
    return await _onlineService.generateImageOnline(request);
  }

  /// Submit generation in online mode (async) and return the created generation id.
  Future<String> submitGenerationOnline(GenerationRequest request) async {
    if (_onlineService == null) {
      throw Exception('Online service not initialized');
    }
    return await _onlineService.submitGeneration(request);
  }
  
  /// Generate image using A1111 API with checkpoint switching
  Future<Uint8List> generateImage(GenerationRequest request) async {
    // Online mode: delegate to online service
    if (_isOnlineMode) {
      if (_onlineService == null) {
        throw Exception('Online service not initialized');
      }
      return await _onlineService.generateImage(request);
    }
    
    // Local mode: use direct API calls
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    // Check and switch checkpoint if needed
    await _ensureCorrectCheckpoint(request.model);

    // Load the request template
    final payload = await _loadRequestTemplate();
    
    // Update the payload with our request parameters
    _updatePayload(payload, request);

    print(jsonEncode(payload));
    
    // Make the API call
    final url = '$apiEndpoint/sdapi/v1/txt2img';
    
    try {
      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('API request failed with status ${response.statusCode}');
      }
      
      final responseData = response.data;
      if (responseData['images'] == null || responseData['images'].isEmpty) {
        throw Exception('No images returned from API');
      }
      
      // Decode the Base64 image
      final base64Image = responseData['images'][0];
      final imageData = base64Decode(base64Image);
      
      return imageData;
    } catch (e) {
      if (e is DioException) {
        throw Exception('API request failed: ${e.message}');
      }
      rethrow;
    }
  }

  /// Get available A1111 checkpoints
  Future<List<A1111Checkpoint>> getAvailableCheckpoints() async {
    // Online mode: get models from backend API with model_type filter
    if (_isOnlineMode) {
      if (_onlineService == null) {
        throw Exception('Online service not initialized');
      }
      // Get checkpoints with model_type=checkpoint filter
      final models = await _onlineService.getAvailableModels(modelType: 'checkpoint');
      
      // Check for duplicate display names
      final displayNameCounts = <String, int>{};
      for (final model in models) {
        final displayName = model.displayName ?? model.name;
        displayNameCounts[displayName] = (displayNameCounts[displayName] ?? 0) + 1;
      }
      
      return models.map((model) {
        final displayName = model.displayName ?? model.name;
        // Use filename if duplicate display name found
        final shouldUseFilename = displayNameCounts[displayName]! > 1;
        
        return A1111Checkpoint(
          title: shouldUseFilename ? model.name : displayName,
          modelName: model.name,
          filename: model.name,
          hash: null,
          sha256: null,
          config: null,
        );
      }).toList();
    }
    
    // Local mode: get from local API
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    final url = '$apiEndpoint/sdapi/v1/sd-models';
    
    try {
      final response = await _dio.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get checkpoints: ${response.statusCode}');
      }
      
      final List<dynamic> data = response.data;
      final checkpoints = data.map((json) => A1111Checkpoint.fromJson(json)).toList();
      
      // Check for duplicate titles
      final titleCounts = <String, int>{};
      for (final checkpoint in checkpoints) {
        titleCounts[checkpoint.title] = (titleCounts[checkpoint.title] ?? 0) + 1;
      }
      
      // If duplicates found, recreate checkpoints with filename as title
      if (titleCounts.values.any((count) => count > 1)) {
        return checkpoints.map((checkpoint) {
          final shouldUseFilename = titleCounts[checkpoint.title]! > 1;
          if (shouldUseFilename) {
            return A1111Checkpoint(
              title: checkpoint.filename,
              modelName: checkpoint.modelName,
              filename: checkpoint.filename,
              hash: checkpoint.hash,
              sha256: checkpoint.sha256,
              config: checkpoint.config,
            );
          }
          return checkpoint;
        }).toList();
      }
      
      return checkpoints;
    } catch (e) {
      if (e is DioException) {
        throw Exception('Failed to get checkpoints: ${e.message}');
      }
      rethrow;
    }
  }

  /// Get available A1111 LoRAs
  Future<List<A1111Lora>> getAvailableLoras() async {
    // Online mode: get LoRAs from backend API with model_type filter
    if (_isOnlineMode) {
      if (_onlineService == null) {
        throw Exception('Online service not initialized');
      }
      try {
        // Get loras with model_type=lora filter
        final models = await _onlineService.getAvailableLoras();
        
        // Check for duplicate display names
        final displayNameCounts = <String, int>{};
        for (final model in models) {
          final displayName = model.displayName ?? model.name;
          displayNameCounts[displayName] = (displayNameCounts[displayName] ?? 0) + 1;
        }
        
        return models.map((model) {
          final displayName = model.displayName ?? model.name;
          // Use filename if duplicate display name found
          final shouldUseFilename = displayNameCounts[displayName]! > 1;
          
          return A1111Lora(
            name: shouldUseFilename ? model.name : displayName,
            alias: shouldUseFilename ? model.name : displayName,
            path: model.name,
            metadata: model.metadata,
          );
        }).toList();
      } catch (e) {
        print('Error fetching online LoRAs: $e');
        // Return empty list if online API call fails
        return [];
      }
    }
    
    // Local mode: get from local API
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    final url = '$apiEndpoint/sdapi/v1/loras';
    
    try {
      final response = await _dio.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get LoRAs: ${response.statusCode}');
      }
      
      final List<dynamic> data = response.data;
      final loras = data.map((json) => A1111Lora.fromJson(json)).toList();
      
      // Check for duplicate names (display names)
      final nameCounts = <String, int>{};
      for (final lora in loras) {
        final displayName = lora.alias ?? lora.name;
        nameCounts[displayName] = (nameCounts[displayName] ?? 0) + 1;
      }
      
      // If duplicates found, recreate LoRAs with path as name
      if (nameCounts.values.any((count) => count > 1)) {
        return loras.map((lora) {
          final displayName = lora.alias ?? lora.name;
          final shouldUsePath = nameCounts[displayName]! > 1;
          if (shouldUsePath) {
            return A1111Lora(
              name: lora.path,
              alias: lora.path,
              path: lora.path,
              metadata: lora.metadata,
            );
          }
          return lora;
        }).toList();
      }
      
      return loras;
    } catch (e) {
      if (e is DioException) {
        throw Exception('Failed to get LoRAs: ${e.message}');
      }
      rethrow;
    }
  }

  /// Get current A1111 options (including current checkpoint)
  Future<Map<String, dynamic>> getCurrentOptions() async {
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    final url = '$apiEndpoint/sdapi/v1/options';
    
    try {
      final response = await _dio.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get current options: ${response.statusCode}');
      }
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException) {
        throw Exception('Failed to get current options: ${e.message}');
      }
      rethrow;
    }
  }

  /// Get current checkpoint title
  /// Not available in online mode - returns null
  Future<String?> getCurrentCheckpoint() async {
    // Online mode: current checkpoint not available
    if (_isOnlineMode) {
      return null;
    }
    
    try {
      final options = await getCurrentOptions();
      return options['sd_model_checkpoint'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Switch A1111 checkpoint
  Future<void> switchCheckpoint(String checkpointTitle) async {
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    final url = '$apiEndpoint/sdapi/v1/options';
    final payload = {
      'sd_model_checkpoint': checkpointTitle,
    };
    
    try {
      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to switch checkpoint: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Failed to switch checkpoint: ${e.message}');
      }
      rethrow;
    }
  }

  /// Check if server is reachable
  Future<bool> isServerReachable() async {
    // Online mode: check backend API health
    if (_isOnlineMode) {
      if (_onlineService == null) {
        return false;
      }
      return await _onlineService.isServerReachable();
    }
    
    // Local mode: check local A1111 endpoint
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      return false;
    }
    
    try {
      final response = await _dio.get(
        '$apiEndpoint/sdapi/v1/options',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Ensure the correct checkpoint is loaded before generation
  Future<void> _ensureCorrectCheckpoint(String selectedCheckpointTitle) async {
    try {
      final currentCheckpoint = await getCurrentCheckpoint();
      
      if (currentCheckpoint != selectedCheckpointTitle) {
        await switchCheckpoint(selectedCheckpointTitle);
      }
    } catch (e) {
      final currentCheckpoint = await getCurrentCheckpoint();
      throw Exception(
        'Failed to switch checkpoint to "$selectedCheckpointTitle". '
        'Current checkpoint: "${currentCheckpoint ?? "Unknown"}". '
        'Error: ${e.toString()}'
      );
    }
  }
  
  /// Load the request template from the JSON file
  Future<Map<String, dynamic>> _loadRequestTemplate() async {
    try {
      // Load the asset using rootBundle
      final jsonString = await rootBundle.loadString('assets/requests/a1111_request.json');
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load request template: ${ErrorHandler.getErrorMessage(e)}');
    }
  }
  
  /// Update the payload with our generation parameters
  void _updatePayload(Map<String, dynamic> payload, GenerationRequest request) {
    // Update main parameters
    payload['prompt'] = request.positivePrompt;
    payload['negative_prompt'] = request.negativePrompt;
    payload['width'] = request.width;
    payload['height'] = request.height;
    payload['steps'] = request.steps;
    payload['cfg_scale'] = request.cfgScale;
    payload['seed'] = request.seed;
    payload['sampler_name'] = request.sampler;
    payload['scheduler'] = request.scheduler;
    
    // Update alwayson_scripts parameters
    final alwaysonScripts = payload['alwayson_scripts'] as Map<String, dynamic>;
    
    // Update Dynamic Thresholding (CFG Scale Fix) - 2nd value in args array
    if (alwaysonScripts.containsKey('Dynamic Thresholding (CFG Scale Fix)')) {
      final dynamicThresholding = alwaysonScripts['Dynamic Thresholding (CFG Scale Fix)'];
      final args = dynamicThresholding['args'] as List;
      if (args.length > 1) {
        args[1] = request.cfgScale;
      }
    }
    
    // Update Sampler - contains 3 args: steps, sampler, and scheduler
    if (alwaysonScripts.containsKey('Sampler')) {
      final sampler = alwaysonScripts['Sampler'];
      final args = sampler['args'] as List;
      if (args.length >= 3) {
        args[0] = request.steps;
        args[1] = request.sampler;
        args[2] = request.scheduler;
      }
    }
    
    // Update Seed - 1st value in args array
    if (alwaysonScripts.containsKey('Seed')) {
      final seed = alwaysonScripts['Seed'];
      final args = seed['args'] as List;
      if (args.isNotEmpty) {
        args[0] = request.seed;
      }
    }
  }
} 