import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../models/image_generation_models.dart';
import '../providers/settings_provider.dart';

// Service interfaces
abstract class ImageAssetService {
  Future<List<ImageAsset>> getProjectAssets(String projectId);
  Future<ImageAsset> getAsset(String assetId);
  Future<ImageAsset> createAsset(String projectId, String name, String description);
  Future<ImageAsset> updateAsset(ImageAsset asset);
  Future<void> deleteAsset(String assetId);
  Future<void> deleteGeneration(String generationId);
  Future<ImageGeneration> addGeneration(String assetId, ImageGeneration generation);
  Future<ImageGeneration> updateGeneration(ImageGeneration generation);
}

abstract class ModelService {
  Future<List<AIModel>> getAvailableModels();
  Future<List<AIModel>> getCheckpointModels();
  Future<List<AIModel>> getLoraModels();
  Future<void> refreshModels();
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
  Future<ImageGeneration> addGeneration(String assetId, ImageGeneration generation) async {
    await Future.delayed(Duration(milliseconds: 300));
    
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
  
  A1111ImageGenerationService(this._settingsProvider) : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }
  
  /// Generate image using A1111 API
  Future<Uint8List> generateImage(GenerationRequest request) async {
    final backend = _settingsProvider.defaultGenerationServer;
    final apiEndpoint = _settingsProvider.getEndpoint(backend);
    
    if (apiEndpoint.isEmpty) {
      throw Exception('API endpoint not configured for ${backend.displayName}');
    }
    
    // Load the request template
    final payload = await _loadRequestTemplate();
    
    // Update the payload with our request parameters
    _updatePayload(payload, request);
    
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
  
  /// Load the request template from the JSON file
  Future<Map<String, dynamic>> _loadRequestTemplate() async {
    try {
      // Load the asset using rootBundle
      final jsonString = await rootBundle.loadString('assets/requests/a1111_request.json');
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load request template: $e');
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