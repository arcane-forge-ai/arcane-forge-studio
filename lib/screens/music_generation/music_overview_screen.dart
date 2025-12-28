import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/music_generation_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/music_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import '../../services/file_download_service.dart';
import '../../widgets/quota_status_widget.dart';
import 'widgets/music_asset_detail_screen.dart';
import 'dart:io' show File;

class MusicOverviewScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const MusicOverviewScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<MusicOverviewScreen> createState() => _MusicOverviewScreenState();
}

class _MusicOverviewScreenState extends State<MusicOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'All';
  final Set<String> _downloadingAssetIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProjectContext();
    });
  }

  void _initializeProjectContext() async {
    final musicProvider =
        Provider.of<MusicGenerationProvider>(context, listen: false);
    await musicProvider.refreshAssets(projectId: widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicGenerationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Column(
            children: [
              _buildHeader(context, provider),
              Expanded(
                child: _buildContent(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MusicGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Music Assets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              QuotaStatusWidget.compact('music_generation'),
              const Spacer(),
              _buildActionButtons(context, provider),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSearchField(),
              ),
              const SizedBox(width: 16),
              _buildFilterDropdown(),
              const SizedBox(width: 16),
              _buildRefreshButton(provider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, MusicGenerationProvider provider) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showCreateAssetDialog(context, provider),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Create Asset',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0078D4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            Provider.of<MenuAppController>(context, listen: false)
                .changeScreen(ScreenType.musicGenerationGeneration);
          },
          icon: const Icon(Icons.music_note, color: Colors.white70),
          label: const Text(
            'Generate Music',
            style: TextStyle(color: Colors.white70),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF404040),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        if (provider.assets.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _showClearAllDialog(context, provider),
            icon: const Icon(Icons.clear_all, color: Colors.white70),
            label: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white70),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search assets by name or description...',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF3A3A3A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _filterType,
        dropdownColor: const Color(0xFF3A3A3A),
        underline: Container(),
        style: const TextStyle(color: Colors.white),
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All Assets')),
          DropdownMenuItem(value: 'HasGenerations', child: Text('With Music')),
          DropdownMenuItem(value: 'Favorites', child: Text('Has Favorite')),
          DropdownMenuItem(value: 'Empty', child: Text('Empty Assets')),
          DropdownMenuItem(value: 'Recent', child: Text('Recent')),
        ],
        onChanged: (value) {
          setState(() {
            _filterType = value ?? 'All';
          });
        },
      ),
    );
  }

  Widget _buildRefreshButton(MusicGenerationProvider provider) {
    return IconButton(
      onPressed: () => provider.refreshAssets(projectId: widget.projectId),
      icon: const Icon(Icons.refresh, color: Colors.white54),
      tooltip: 'Refresh Assets',
    );
  }

  Widget _buildContent(BuildContext context, MusicGenerationProvider provider) {
    final filteredAssets = _filterAssets(provider.assets);

    if (filteredAssets.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    return _buildAssetGrid(filteredAssets, provider);
  }

  List<MusicAsset> _filterAssets(List<MusicAsset> assets) {
    var filtered = assets;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((asset) {
        return asset.name.toLowerCase().contains(_searchQuery) ||
            asset.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply status filter
    switch (_filterType) {
      case 'HasGenerations':
        filtered =
            filtered.where((asset) => asset.generations.isNotEmpty).toList();
        break;
      case 'Favorites':
        filtered = filtered
            .where((asset) =>
                asset.favoriteGenerationId != null ||
                asset.generations.any((gen) => gen.isFavorite))
            .toList();
        break;
      case 'Empty':
        filtered =
            filtered.where((asset) => asset.generations.isEmpty).toList();
        break;
      case 'Recent':
        filtered = filtered
            .where((asset) =>
                DateTime.now().difference(asset.createdAt).inDays < 7)
            .toList();
        break;
      case 'All':
      default:
        // No additional filtering
        break;
    }

    return filtered;
  }

  Widget _buildEmptyState(
      BuildContext context, MusicGenerationProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No music assets yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first music asset to organize your generations',
            style: TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateAssetDialog(context, provider),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Create First Asset',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetGrid(
      List<MusicAsset> assets, MusicGenerationProvider provider) {
    final crossAxisCount = Responsive.isMobile(context)
        ? 2
        : Responsive.isTablet(context)
            ? 3
            : 4;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: assets.length,
        itemBuilder: (context, index) {
          return _buildAssetCard(assets[index], provider);
        },
      ),
    );
  }

  Widget _buildAssetCard(MusicAsset asset, MusicGenerationProvider provider) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF404040), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAssetDetail(asset, provider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  color: Color(0xFF3A3A3A),
                ),
                child: _buildAssetThumbnail(asset),
              ),
            ),
            // Asset Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asset.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildGenerationCount(asset.totalGenerations),
                        const Spacer(),
                        _buildFavoriteDownloadAction(context, asset),
                        Text(
                          _formatDate(asset.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showAssetContextMenu(asset, provider),
                          child: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetThumbnail(MusicAsset asset) {
    if (asset.favoriteGenerationId != null) {
      final favoriteGeneration = asset.generations
          .where((gen) => gen.id == asset.favoriteGenerationId)
          .firstOrNull;
      
      if (favoriteGeneration != null &&
          favoriteGeneration.audioPath != null &&
          favoriteGeneration.audioPath!.isNotEmpty &&
          !kIsWeb &&
          File(favoriteGeneration.audioPath!).existsSync()) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withOpacity(0.6),
                      Colors.pink.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    if (favoriteGeneration.duration != null)
                      Text(
                        '${_formatDuration(favoriteGeneration.duration!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (favoriteGeneration.isFavorite)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
            ],
          ),
        );
      }
    }
    
    return _buildEmptyThumbnail(asset);
  }

  Widget _buildEmptyThumbnail(MusicAsset asset) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Music',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to generate',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationCount(int count) {
    Color color;
    IconData icon;

    if (count == 0) {
      color = Colors.grey;
      icon = Icons.music_note;
    } else if (count < 3) {
      color = Colors.orange;
      icon = Icons.music_note;
    } else {
      color = Colors.pink;
      icon = Icons.queue_music;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFavoriteDownloadAction(
      BuildContext context, MusicAsset asset) {
    if (asset.favoriteGenerationId == null) {
      return const SizedBox.shrink();
    }

    if (_downloadingAssetIds.contains(asset.id)) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () => _downloadFavoriteGeneration(context, asset),
      icon: const Icon(
        Icons.download,
        color: Colors.white70,
        size: 18,
      ),
      tooltip: 'Download favorite music',
    );
  }

  Future<void> _downloadFavoriteGeneration(
      BuildContext context, MusicAsset asset) async {
    final favoriteGenerationId = asset.favoriteGenerationId;
    if (favoriteGenerationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No favorite generation selected for this asset'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _setFavoriteDownloadState(asset.id, true);
    try {
      final provider =
          Provider.of<MusicGenerationProvider>(context, listen: false);
      final favoriteGeneration =
          await provider.getGeneration(favoriteGenerationId);

      if (favoriteGeneration == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load favorite generation details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final audioUrl = favoriteGeneration.audioUrl;

      if (audioUrl == null || audioUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorite generation has no download URL'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final defaultFileName =
          _generateDefaultFileName(asset, favoriteGeneration);

      await FileDownloadService.downloadFile(
        url: audioUrl,
        defaultFileName: defaultFileName,
        config: const FileDownloadConfig(
          dialogTitle: 'Save Music File',
          allowedExtensions: ['mp3', 'wav', 'ogg', 'aac', 'm4a'],
          errorPrefix: 'Error downloading music',
          downloadingSnackbarColor: Colors.orange,
          showOverwriteConfirmation: true,
        ),
        context: context,
        mounted: () => mounted,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download music: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setFavoriteDownloadState(asset.id, false);
    }
  }

  void _setFavoriteDownloadState(String assetId, bool isDownloading) {
    if (!mounted) return;
    setState(() {
      if (isDownloading) {
        _downloadingAssetIds.add(assetId);
      } else {
        _downloadingAssetIds.remove(assetId);
      }
    });
  }

  String _generateDefaultFileName(
      MusicAsset asset, MusicGeneration favoriteGeneration) {
    String baseName = 'music';

    if (asset.name.isNotEmpty) {
      baseName =
          asset.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    } else if (favoriteGeneration.parameters['prompt'] != null) {
      final prompt = favoriteGeneration.parameters['prompt'].toString();
      if (prompt.isNotEmpty) {
        final words = prompt.split(' ').take(3).join('_');
        baseName =
            words.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final format = favoriteGeneration.format ?? 'mp3';

    return '${baseName}_$timestamp.$format';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  void _showAssetDetail(MusicAsset asset, MusicGenerationProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MusicAssetDetailScreen(asset: asset),
      ),
    );
  }

  void _showAssetContextMenu(MusicAsset asset, MusicGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Asset Actions',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white54),
              title: const Text('View Details',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _showAssetDetail(asset, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white54),
              title: const Text('Edit Asset',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _showEditAssetDialog(asset, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.white54),
              title: const Text('Generate Music',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToGeneration(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Asset',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteAsset(asset, provider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAssetDialog(
      BuildContext context, MusicGenerationProvider provider) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Create New Music Asset',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Asset Name',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., Battle Theme',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF3A3A3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Describe what this music represents...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF3A3A3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asset name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await provider.createAsset(
                  widget.projectId,
                  name,
                  description,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asset created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to create asset: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
            ),
            child: const Text(
              'Create',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAssetDialog(MusicAsset asset, MusicGenerationProvider provider) {
    final nameController = TextEditingController(text: asset.name);
    final descriptionController =
        TextEditingController(text: asset.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Edit Music Asset',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Asset Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF3A3A3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF3A3A3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asset name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final updatedAsset = asset.copyWith(
                  name: name,
                  description: description,
                );
                await provider.updateAsset(updatedAsset);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asset updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update asset: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
            ),
            child: const Text(
              'Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToGeneration(MusicAsset asset) {
    Provider.of<MenuAppController>(context, listen: false)
        .changeScreen(ScreenType.musicGenerationGeneration);
  }

  void _confirmDeleteAsset(MusicAsset asset, MusicGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Asset',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${asset.name}"? This will also delete all ${asset.generations.length} generated music files for this asset.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteAsset(asset.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asset deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete asset: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(
      BuildContext context, MusicGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Clear All Assets',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete all music assets? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                for (var asset in List.from(provider.assets)) {
                  await provider.deleteAsset(asset.id);
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All assets cleared successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to clear assets: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
