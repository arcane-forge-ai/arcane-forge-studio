import 'package:flutter/material.dart';
import '../models/music_generation_models.dart';
import '../models/sfx_generation_models.dart'; // For GenerationStatus
import '../models/extracted_asset_models.dart';
import '../services/music_generation_services.dart';
import '../widgets/create_assets_from_doc_dialog.dart';

class MusicGenerationProvider extends ChangeNotifier implements AssetCreationProvider {
  final MusicAssetService _assetService;

  // Asset management
  List<MusicAsset> _assets = [];
  bool _isLoadingAssets = false;
  String? _assetsError;

  // Generation state
  bool _isGenerating = false;
  MusicGenerationRequest? _currentRequest;
  String? _generationError;

  // UI state
  MusicAsset? _selectedAsset;

  MusicGenerationProvider(this._assetService);

  // Getters
  List<MusicAsset> get assets => _assets;
  bool get isLoadingAssets => _isLoadingAssets;
  String? get assetsError => _assetsError;
  bool get isGenerating => _isGenerating;
  MusicGenerationRequest? get currentRequest => _currentRequest;
  String? get generationError => _generationError;
  MusicAsset? get selectedAsset => _selectedAsset;

  // Asset Management
  @override
  Future<void> refreshAssets({String? projectId}) async {
    if (projectId == null) return;

    _isLoadingAssets = true;
    _assetsError = null;
    notifyListeners();

    try {
      _assets = await _assetService.getProjectMusicAssets(projectId);
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
    await refreshAssets(projectId: projectId);
  }

  Future<MusicAsset?> getAsset(String assetId) async {
    try {
      return await _assetService.getMusicAsset(assetId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh a single asset from the service and update cache
  Future<void> _refreshSingleAsset(String assetId) async {
    try {
      final asset = await _assetService.getMusicAsset(assetId);
      
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
      print('Error refreshing single music asset $assetId: $e');
    }
  }

  Future<MusicAsset> createAsset(
      String projectId, String name, String description) async {
    try {
      final asset =
          await _assetService.createMusicAsset(projectId, name, description);
      _assets.insert(0, asset); // Add to beginning of list
      notifyListeners();
      return asset;
    } catch (e) {
      throw Exception('Failed to create music asset: $e');
    }
  }

  Future<void> updateAsset(MusicAsset asset) async {
    try {
      final updatedAsset = await _assetService.updateMusicAsset(asset);
      final index = _assets.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _assets[index] = updatedAsset;
        if (_selectedAsset?.id == asset.id) {
          _selectedAsset = updatedAsset;
        }
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update music asset: $e');
    }
  }

  Future<void> deleteAsset(String assetId) async {
    try {
      await _assetService.deleteMusicAsset(assetId);
      _assets.removeWhere((asset) => asset.id == assetId);
      if (_selectedAsset?.id == assetId) {
        _selectedAsset = null;
      }
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete music asset: $e');
    }
  }

  /// Generate an optimized prompt for music generation
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
  void selectAsset(MusicAsset? asset) {
    _selectedAsset = asset;
    notifyListeners();
  }

  // Generation Management
  Future<void> generateMusic(
    MusicGenerationRequest request, {
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
      await _assetService.addMusicGeneration(
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

  Future<void> setFavoriteMusicGeneration(
      String assetId, String generationId) async {
    try {
      await _assetService.setFavoriteMusicGeneration(assetId, generationId);

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
      throw Exception('Failed to set favorite music generation: $e');
    }
  }

  // Utility methods for UI
  List<MusicAsset> getAssetsWithGenerations() {
    return _assets.where((asset) => asset.generations.isNotEmpty).toList();
  }

  List<MusicAsset> getAssetsWithoutGenerations() {
    return _assets.where((asset) => asset.generations.isEmpty).toList();
  }

  int getTotalGenerationsCount() {
    return _assets.fold(0, (sum, asset) => sum + asset.totalGenerations);
  }

  List<MusicGeneration> getAllGenerations() {
    final allGenerations = <MusicGeneration>[];
    for (final asset in _assets) {
      allGenerations.addAll(asset.generations);
    }
    // Sort by creation date, newest first
    allGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allGenerations;
  }

  List<MusicGeneration> getCompletedGenerations() {
    return getAllGenerations()
        .where((gen) => gen.status == GenerationStatus.completed)
        .toList();
  }

  List<MusicGeneration> getFavoriteGenerations() {
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

  /// Extract assets from document content - Music assets don't have extraction endpoint yet
  /// So we return empty list for now
  @override
  Future<List<ExtractedAsset>> extractAssetsFromContent(String content) async {
    // Music assets don't have a specific extraction API yet
    // Return empty list for now
    return [];
  }

  /// Batch create assets from extracted asset data
  @override
  Future<void> batchCreateAssets(String projectId, List<ExtractedAsset> extractedAssets) async {
    // Simple implementation: create assets one by one
    for (final extracted in extractedAssets) {
      try {
        await createAsset(projectId, extracted.name, extracted.description ?? '');
      } catch (e) {
        debugPrint('Failed to create music asset ${extracted.name}: $e');
      }
    }
  }

  @override
  void dispose() {
    clearAssets();
    super.dispose();
  }
}

