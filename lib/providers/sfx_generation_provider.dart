import 'package:flutter/material.dart';
import '../models/sfx_generation_models.dart';
import '../models/extracted_asset_models.dart';
import '../services/sfx_generation_services.dart';
import '../widgets/create_assets_from_doc_dialog.dart';

class SfxGenerationProvider extends ChangeNotifier implements AssetCreationProvider {
  final SfxAssetService _assetService;

  // Asset management
  List<SfxAsset> _assets = [];
  bool _isLoadingAssets = false;
  String? _assetsError;
  String? _currentProjectId;

  // Generation state
  bool _isGenerating = false;
  SfxGenerationRequest? _currentRequest;
  String? _generationError;

  // UI state
  SfxAsset? _selectedAsset;

  SfxGenerationProvider(this._assetService);

  // Getters
  List<SfxAsset> get assets => _assets;
  bool get isLoadingAssets => _isLoadingAssets;
  String? get assetsError => _assetsError;
  bool get isGenerating => _isGenerating;
  SfxGenerationRequest? get currentRequest => _currentRequest;
  String? get generationError => _generationError;
  SfxAsset? get selectedAsset => _selectedAsset;

  // Asset Management
  @override
  Future<void> refreshAssets({String? projectId}) async {
    if (projectId == null) return;
    
    // Store the current project ID for API calls
    _currentProjectId = projectId;

    _isLoadingAssets = true;
    _assetsError = null;
    notifyListeners();

    try {
      _assets = await _assetService.getProjectSfxAssets(projectId);
      _assetsError = null;
    } catch (e) {
      _assetsError = e.toString();
      _assets = [];
    } finally {
      _isLoadingAssets = false;
      notifyListeners();
    }
  }

  /// Set the current project context for API calls
  Future<void> setCurrentProject(String projectId) async {
    _currentProjectId = projectId;
    await refreshAssets(projectId: projectId);
  }

  Future<SfxAsset?> getAsset(String assetId) async {
    try {
      return await _assetService.getSfxAsset(assetId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh a single asset from the service and update cache
  Future<void> _refreshSingleAsset(String assetId) async {
    try {
      final asset = await _assetService.getSfxAsset(assetId);
      
      // Update cache with fresh data
      final index = _assets.indexWhere((a) => a.id == assetId);
      if (index != -1) {
        _assets[index] = asset;
      } else {
        _assets.add(asset);
      }
      
      // Update selected asset if it's the one we refreshed
      if (_selectedAsset?.id == assetId) {
        _selectedAsset = asset;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error refreshing single SFX asset $assetId: $e');
    }
  }

  Future<SfxAsset> createAsset(
      String projectId, String name, String description) async {
    try {
      final asset =
          await _assetService.createSfxAsset(projectId, name, description);
      _assets.insert(0, asset); // Add to beginning of list
      notifyListeners();
      return asset;
    } catch (e) {
      throw Exception('Failed to create SFX asset: $e');
    }
  }

  Future<void> updateAsset(SfxAsset asset) async {
    try {
      final updatedAsset = await _assetService.updateSfxAsset(asset);
      final index = _assets.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _assets[index] = updatedAsset;
        if (_selectedAsset?.id == asset.id) {
          _selectedAsset = updatedAsset;
        }
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update SFX asset: $e');
    }
  }

  Future<void> deleteAsset(String assetId) async {
    try {
      await _assetService.deleteSfxAsset(assetId);
      _assets.removeWhere((asset) => asset.id == assetId);
      if (_selectedAsset?.id == assetId) {
        _selectedAsset = null;
      }
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete SFX asset: $e');
    }
  }

  /// Generate an optimized prompt for SFX generation
  Future<String> generateAutoPrompt({
    required String projectId,
    required Map<String, dynamic> assetInfo,
    required Map<String, dynamic> generatorInfo,
  }) async {
    try {
      return await _assetService.generateAutoPrompt(projectId, assetInfo, generatorInfo);
    } catch (e) {
      rethrow;
    }
  }

  // Asset Selection
  void selectAsset(SfxAsset? asset) {
    _selectedAsset = asset;
    notifyListeners();
  }

  // Generation Management
  Future<void> generateSfx(
    SfxGenerationRequest request, {
    required String projectId,
    required String assetId,
  }) async {
    if (_isGenerating) return;

    _isGenerating = true;
    _currentRequest = request;
    _generationError = null;
    notifyListeners();

    try {
      // Find the target asset
      final asset = await getAsset(assetId);
      if (asset == null) {
        throw Exception('Asset not found: $assetId');
      }

      // Add generation to asset (server will generate the ID and handle ElevenLabs)
      await _assetService.addSfxGeneration(
        assetId,
        request,
        status: GenerationStatus.generating,
      );

      // Refresh the specific asset to get updated generation
      await _refreshSingleAsset(assetId);

      // Update selected asset if it's the one we just generated for
      if (_selectedAsset?.id == assetId) {
        _selectedAsset = await getAsset(assetId);
      }
    } catch (e) {
      _generationError = e.toString();
      rethrow;
    } finally {
      _isGenerating = false;
      _currentRequest = null;
      notifyListeners();
    }
  }

  Future<void> setFavoriteSfxGeneration(
      String assetId, String generationId) async {
    try {
      await _assetService.setFavoriteSfxGeneration(assetId, generationId);

      // Update local state
      final assetIndex = _assets.indexWhere((a) => a.id == assetId);
      if (assetIndex != -1) {
        final asset = _assets[assetIndex];

        // Update favorite generation ID
        final updatedAsset = asset.copyWith(favoriteGenerationId: generationId);

        // Update generation's favorite status
        final updatedGenerations = asset.generations.map((gen) {
          return gen.copyWith(isFavorite: gen.id == generationId);
        }).toList();

        _assets[assetIndex] =
            updatedAsset.copyWith(generations: updatedGenerations);

        // Update selected asset if needed
        if (_selectedAsset?.id == assetId) {
          _selectedAsset = _assets[assetIndex];
        }

        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to set favorite SFX generation: $e');
    }
  }

  // Utility methods for UI
  List<SfxAsset> getAssetsWithGenerations() {
    return _assets.where((asset) => asset.generations.isNotEmpty).toList();
  }

  List<SfxAsset> getAssetsWithoutGenerations() {
    return _assets.where((asset) => asset.generations.isEmpty).toList();
  }

  int getTotalGenerationsCount() {
    return _assets.fold(0, (sum, asset) => sum + asset.totalGenerations);
  }

  List<SfxGeneration> getAllGenerations() {
    final allGenerations = <SfxGeneration>[];
    for (final asset in _assets) {
      allGenerations.addAll(asset.generations);
    }
    // Sort by creation date, newest first
    allGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allGenerations;
  }

  List<SfxGeneration> getCompletedGenerations() {
    return getAllGenerations()
        .where((gen) => gen.status == GenerationStatus.completed)
        .toList();
  }

  List<SfxGeneration> getFavoriteGenerations() {
    return getAllGenerations().where((gen) => gen.isFavorite).toList();
  }

  // Clear state
  void clearError() {
    _assetsError = null;
    _generationError = null;
    notifyListeners();
  }

  void clearAssets() {
    _assets.clear();
    _selectedAsset = null;
    notifyListeners();
  }

  /// Extract assets from document content using API
  @override
  Future<List<ExtractedAsset>> extractAssetsFromContent(String content) async {
    if (_assetService is ApiSfxAssetService && _currentProjectId != null) {
      try {
        final result = await _assetService.extractAssetsFromContent(_currentProjectId!, content);
        return result;
      } catch (e) {
        debugPrint('Failed to extract SFX assets from content via API: $e');
        // Fall back to mock implementation if API fails
        return _mockExtractAssetsFromContent(content);
      }
    } else {
      // Mock implementation for local service or when no project ID is set
      return _mockExtractAssetsFromContent(content);
    }
  }

  /// Mock implementation for extracting SFX assets from content
  List<ExtractedAsset> _mockExtractAssetsFromContent(String content) {
    // Simple mock implementation - extract potential SFX asset names from content
    final lines = content.split('\n');
    final assets = <ExtractedAsset>[];
    
    // SFX-specific keywords to look for
    final sfxKeywords = ['sound', 'audio', 'sfx', 'effect', 'noise', 'music', 'voice', 'ambient'];
    
    for (final line in lines) {
      final trimmed = line.trim().toLowerCase();
      if (trimmed.isNotEmpty && trimmed.length > 3 && trimmed.length < 100) {
        // Check if line contains SFX-related keywords
        bool containsSfxKeyword = sfxKeywords.any((keyword) => trimmed.contains(keyword));
        
        if (containsSfxKeyword || RegExp(r'^[A-Z][a-zA-Z\s]+$').hasMatch(line.trim())) {
          final assetName = line.trim();
          
          // Create mock original JSON response
          final originalJson = {
            'name': assetName,
            'description': 'Auto-extracted SFX asset from document',
            'tags': ['auto-generated', 'sfx'],
            'metadata': {'source': 'document_extraction', 'type': 'sfx'},
            'confidence': 0.8,
            'extraction_method': 'mock_regex',
          };
          
          // Merge original JSON with base metadata
          final mergedMetadata = <String, dynamic>{
            'source': 'document_extraction',
            'type': 'sfx',
          };
          mergedMetadata.addAll(originalJson);
          
          assets.add(ExtractedAsset(
            name: assetName,
            description: 'Auto-extracted SFX asset from document',
            tags: ['auto-generated', 'sfx'],
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
    if (_assetService is ApiSfxAssetService) {
      try {
        await _assetService.batchCreateAssets(projectId, extractedAssets);
        // Refresh assets to get the newly created ones
        await refreshAssets(projectId: projectId);
      } catch (e) {
        debugPrint('Failed to batch create SFX assets: $e');
        rethrow;
      }
    } else {
      // Mock implementation for local service
      for (final extracted in extractedAssets) {
        try {
          await createAsset(projectId, extracted.name, extracted.description ?? '');
        } catch (e) {
          debugPrint('Failed to create SFX asset ${extracted.name}: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    clearAssets();
    super.dispose();
  }
}
