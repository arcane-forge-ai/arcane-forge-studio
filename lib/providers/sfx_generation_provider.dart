import 'package:flutter/material.dart';
import '../models/sfx_generation_models.dart';
import '../services/sfx_generation_services.dart';
import '../providers/settings_provider.dart';

class SfxGenerationProvider extends ChangeNotifier {
  final SfxAssetService _assetService;
  final SettingsProvider _settingsProvider;

  // Asset management
  List<SfxAsset> _assets = [];
  bool _isLoadingAssets = false;
  String? _assetsError;

  // Generation state
  bool _isGenerating = false;
  SfxGenerationRequest? _currentRequest;
  String? _generationError;

  // UI state
  SfxAsset? _selectedAsset;

  SfxGenerationProvider(this._assetService, this._settingsProvider);

  // Getters
  List<SfxAsset> get assets => _assets;
  bool get isLoadingAssets => _isLoadingAssets;
  String? get assetsError => _assetsError;
  bool get isGenerating => _isGenerating;
  SfxGenerationRequest? get currentRequest => _currentRequest;
  String? get generationError => _generationError;
  SfxAsset? get selectedAsset => _selectedAsset;

  // Asset Management
  Future<void> refreshAssets({String? projectId}) async {
    if (projectId == null) return;
    
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

  Future<SfxAsset?> getAsset(String assetId) async {
    try {
      return await _assetService.getSfxAsset(assetId);
    } catch (e) {
      return null;
    }
  }

  Future<SfxAsset> createAsset(String projectId, String name, String description) async {
    try {
      final asset = await _assetService.createSfxAsset(projectId, name, description);
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

  // Asset Selection
  void selectAsset(SfxAsset? asset) {
    _selectedAsset = asset;
    notifyListeners();
  }

  // Generation Management
  Future<void> generateSfx(SfxGenerationRequest request, {
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
      final generation = await _assetService.addSfxGeneration(
        assetId, 
        request, 
        status: GenerationStatus.generating,
      );
      
      // Refresh assets to get updated asset with new generation
      await refreshAssets(projectId: projectId);

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

  Future<void> setFavoriteSfxGeneration(String assetId, String generationId) async {
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
        
        _assets[assetIndex] = updatedAsset.copyWith(generations: updatedGenerations);
        
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
    return getAllGenerations()
        .where((gen) => gen.isFavorite)
        .toList();
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

  @override
  void dispose() {
    clearAssets();
    super.dispose();
  }
} 