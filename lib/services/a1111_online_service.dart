import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/image_generation_models.dart';
import 'api_client.dart';

/// Result from online image generation containing image bytes and generation info
class OnlineGenerationResult {
  final Uint8List imageData;
  final String generationId;
  final String? imageUrl;
  
  OnlineGenerationResult({
    required this.imageData,
    required this.generationId,
    this.imageUrl,
  });
}

/// Service for handling online A1111 operations via backend API
class A1111OnlineService {
  final ApiClient _apiClient;
  
  A1111OnlineService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get available A1111 models from backend API
  /// Endpoint: GET /api/v1/image-generation/models?provider=a1111&model_type={type}
  /// 
  /// [modelType] can be 'checkpoint', 'lora', 'embedding', 'vae', or 'controlnet'
  Future<List<A1111Model>> getAvailableModels({String? modelType}) async {
    try {
      final queryParams = <String, dynamic>{'provider': 'a1111'};
      if (modelType != null && modelType.isNotEmpty) {
        queryParams['model_type'] = modelType;
      }
      
      final response = await _apiClient.get(
        '/image-generation/models',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> modelsJson = response.data['models'] ?? response.data;
        return modelsJson.map((json) => A1111Model.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching A1111 models: $e');
      rethrow;
    }
  }
  
  /// Get available A1111 LoRAs from backend API
  /// Endpoint: GET /api/v1/image-generation/models?provider=a1111&model_type=lora
  Future<List<A1111Model>> getAvailableLoras() async {
    return getAvailableModels(modelType: 'lora');
  }

  /// Submit an image generation job to the backend (async).
  /// Endpoint: POST /api/v1/assets/{asset_id}/generations
  ///
  /// Returns the created generation id. The caller is expected to poll
  /// `/generations/{id}` (or refresh the asset) to observe status changes.
  Future<String> submitGeneration(GenerationRequest request) async {
    try {
      if (request.assetId == null || request.assetId!.isEmpty) {
        throw Exception('Asset ID is required for online generation');
      }

      // Build the request body according to OpenAPI spec ImageGenerationCreateRequest
      // Put A1111-specific parameters in generation_config
      final generationConfig = <String, dynamic>{
        'width': request.width,
        'height': request.height,
        'steps': request.steps,
        'cfg_scale': request.cfgScale,
        'sampler_name': request.sampler, // Backend expects sampler_name
        'scheduler': request.scheduler,
      };

      if (request.negativePrompt.isNotEmpty) {
        generationConfig['negative_prompt'] = request.negativePrompt;
      }

      if (request.seed >= 0) {
        generationConfig['seed'] = request.seed;
      }

      if (request.loras.isNotEmpty) {
        generationConfig['loras'] = request.loras;
      }

      final requestBody = <String, dynamic>{
        'prompt': request.positivePrompt,
        'model': request.model,
        'generation_config': generationConfig,
      };

      final response = await _apiClient.post(
        '/assets/${request.assetId}/generations',
        data: requestBody,
        options: Options(
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = response.data;
        final generationId = data['id'];

        if (generationId == null) {
          throw Exception('Generation response missing id');
        }

        return generationId.toString();
      }

      throw Exception('Unexpected status code: ${response.statusCode}');
    } catch (e) {
      print('Error submitting online generation: $e');
      rethrow;
    }
  }

  /// Generate an image using the online A1111 backend (blocking).
  /// Endpoint: POST /api/v1/assets/{asset_id}/generations
  ///
  /// Returns OnlineGenerationResult containing image bytes and generation ID.
  /// Prefer [submitGeneration] for async UX.
  Future<OnlineGenerationResult> generateImageOnline(GenerationRequest request) async {
    try {
      if (request.assetId == null || request.assetId!.isEmpty) {
        throw Exception('Asset ID is required for online generation');
      }

      // Build the request body according to OpenAPI spec ImageGenerationCreateRequest
      // Put A1111-specific parameters in generation_config
      final generationConfig = <String, dynamic>{
        'width': request.width,
        'height': request.height,
        'steps': request.steps,
        'cfg_scale': request.cfgScale,
        'sampler_name': request.sampler, // Backend expects sampler_name
        'scheduler': request.scheduler,
      };
      
      if (request.negativePrompt.isNotEmpty) {
        generationConfig['negative_prompt'] = request.negativePrompt;
      }
      
      if (request.seed >= 0) {
        generationConfig['seed'] = request.seed;
      }
      
      if (request.loras.isNotEmpty) {
        generationConfig['loras'] = request.loras;
      }
      
      final requestBody = <String, dynamic>{
        'prompt': request.positivePrompt,
        'model': request.model,
        'generation_config': generationConfig,
      };

      // Post to create generation
      final response = await _apiClient.post(
        '/assets/${request.assetId}/generations',
        data: requestBody,
        options: Options(
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = response.data;
        final generationId = data['id'];
        
        if (generationId == null) {
          throw Exception('Generation response missing id');
        }
        
        // Poll for completion and get image
        return await _pollForGenerationWithResult(generationId);
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating image online: $e');
      rethrow;
    }
  }

  /// Legacy method for backward compatibility - returns only image bytes
  Future<Uint8List> generateImage(GenerationRequest request) async {
    final result = await generateImageOnline(request);
    return result.imageData;
  }

  /// Poll for generation status and download when complete - returns full result
  Future<OnlineGenerationResult> _pollForGenerationWithResult(String generationId) async {
    const maxAttempts = 60; // 5 minutes max (5s interval)
    const pollInterval = Duration(seconds: 5);
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _apiClient.get(
          '/generations/$generationId',
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final status = data['status'] ?? '';
          
          if (status == 'completed') {
            // Generation complete - fetch the image
            final imageUrl = data['image_url'];
            if (imageUrl != null) {
              // Download the image
              final imageResponse = await _apiClient.dio.get(
                imageUrl,
                options: Options(responseType: ResponseType.bytes),
              );
              return OnlineGenerationResult(
                imageData: Uint8List.fromList(imageResponse.data),
                generationId: generationId,
                imageUrl: imageUrl,
              );
            } else {
              throw Exception('Generation completed but no image URL provided');
            }
          } else if (status == 'failed' || status == 'error') {
            final error = data['error_message'] ?? data['error'] ?? 'Generation failed';
            throw Exception(error);
          }
          
          // Still generating, wait and retry
          await Future.delayed(pollInterval);
        } else {
          throw Exception('Failed to check generation status: ${response.statusCode}');
        }
      } catch (e) {
        if (attempt == maxAttempts - 1) {
          throw Exception('Polling timeout: $e');
        }
        // Wait before retrying on error
        await Future.delayed(pollInterval);
      }
    }

    throw Exception('Generation timed out after ${maxAttempts * pollInterval.inSeconds} seconds');
  }

  /// Check if the backend API is reachable
  Future<bool> isServerReachable() async {
    try {
      final response = await _apiClient.get(
        '/health',
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
}

