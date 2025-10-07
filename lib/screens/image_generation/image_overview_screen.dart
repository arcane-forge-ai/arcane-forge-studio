import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/image_generation_provider.dart';
import '../../models/image_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import '../../widgets/create_assets_from_doc_dialog.dart';
import 'widgets/asset_detail_screen.dart';

class ImageOverviewScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ImageOverviewScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ImageOverviewScreen> createState() => _ImageOverviewScreenState();
}

class _ImageOverviewScreenState extends State<ImageOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _initializeProjectContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  void _initializeProjectContext() async {
    final imageProvider =
        Provider.of<ImageGenerationProvider>(context, listen: false);
    await imageProvider.setCurrentProject(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageGenerationProvider>(
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

  Widget _buildHeader(BuildContext context, ImageGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: Theme.of(context).colorScheme.onSurface,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Image Assets',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      BuildContext context, ImageGenerationProvider provider) {
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
          onPressed: () => _showCreateAssetsFromDocDialog(context, provider),
          icon: const Icon(Icons.auto_fix_high, color: Colors.white),
          label: const Text(
            'Create Assets from Doc',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A86B),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            Provider.of<MenuAppController>(context, listen: false)
                .changeScreen(ScreenType.imageGenerationGeneration);
          },
          icon: const Icon(Icons.auto_awesome, color: Colors.white70),
          label: const Text(
            'Generate Images',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Search assets by name or description...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _filterType,
        dropdownColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200,
        underline: Container(),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All Assets')),
          DropdownMenuItem(value: 'HasGenerations', child: Text('With Images')),
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

  Widget _buildRefreshButton(ImageGenerationProvider provider) {
    return IconButton(
      onPressed: () => provider.refreshAssets(),
      icon: Icon(
        Icons.refresh,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      tooltip: 'Refresh Assets',
    );
  }

  Widget _buildContent(BuildContext context, ImageGenerationProvider provider) {
    final filteredAssets = _filterAssets(provider.assets);

    if (filteredAssets.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    return _buildAssetGrid(filteredAssets, provider);
  }

  List<ImageAsset> _filterAssets(List<ImageAsset> assets) {
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
      BuildContext context, ImageGenerationProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.folder_outlined,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No image assets yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first image asset to organize your generations',
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
      List<ImageAsset> assets, ImageGenerationProvider provider) {
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

  Widget _buildAssetCard(ImageAsset asset, ImageGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
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
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200,
                ),
                child: _buildAssetThumbnailWithFuture(asset, provider),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asset.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildGenerationCount(asset.generations.length),
                        const Spacer(),
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

  Widget _buildAssetThumbnailWithFuture(ImageAsset asset, ImageGenerationProvider provider) {
    if (asset.favoriteGenerationId != null) {
      return FutureBuilder<ImageGeneration?>(
        future: provider.getGeneration(asset.favoriteGenerationId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingThumbnail();
          } else if (snapshot.hasError) {
            return _buildEmptyThumbnail(asset);
          } else {
            return _buildAssetThumbnail(asset, snapshot.data);
          }
        },
      );
    } else {
      // No favorite generation, use fallback logic
      return _buildAssetThumbnail(asset, null);
    }
  }

  Widget _buildAssetThumbnail(ImageAsset asset, ImageGeneration? generation) {
    if (generation != null &&
        generation.imagePath.isNotEmpty &&
        File(generation.imagePath).existsSync()) {
      return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: _buildGenerationImage(generation, asset),
            ),
            if (generation.isFavorite)
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
    } else {
      return _buildEmptyThumbnail(asset);
    }
  }
  
  Widget _buildGenerationImage(ImageGeneration generation, ImageAsset asset) {
    // Prefer online URL, fallback to local file
    final bool hasOnlineUrl = generation.imageUrl != null && generation.imageUrl!.isNotEmpty;
    final bool hasLocalFile = generation.imagePath.isNotEmpty && File(generation.imagePath).existsSync();
    
    if (hasOnlineUrl) {
      return Image.network(
        generation.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local file if network fails
          if (hasLocalFile) {
            return Image.file(
              File(generation.imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildEmptyThumbnail(asset);
              },
            );
          }
          return _buildEmptyThumbnail(asset);
        },
      );
    } else if (hasLocalFile) {
      return Image.file(
        File(generation.imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildEmptyThumbnail(asset);
        },
      );
    } else {
      return _buildEmptyThumbnail(asset);
    }
  }

  Widget _buildLoadingThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white54,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyThumbnail(ImageAsset asset) {
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
                Icons.folder_outlined,
                color: Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Images',
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
      icon = Icons.folder_outlined;
    } else if (count < 5) {
      color = Colors.blue;
      icon = Icons.image;
    } else {
      color = Colors.green;
      icon = Icons.collections;
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

  void _showAssetDetail(ImageAsset asset, ImageGenerationProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AssetDetailScreen(asset: asset),
      ),
    );
  }

  void _showAssetContextMenu(
      ImageAsset asset, ImageGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Asset Actions',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              title: Text(
                'View Details',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showAssetDetail(asset, provider);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              title: Text(
                'Edit Asset',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showEditAssetDialog(asset, provider);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              title: Text(
                'Generate Images',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToGeneration(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Asset',
                style: TextStyle(color: Colors.red),
              ),
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
      BuildContext context, ImageGenerationProvider provider) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Create New Asset',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Asset Name',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                hintText: 'e.g., Main Character Portrait',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                hintText: 'Describe what this asset represents...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
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
                await provider.createAsset(name, description);
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

  void _showEditAssetDialog(
      ImageAsset asset, ImageGenerationProvider provider) {
    final nameController = TextEditingController(text: asset.name);
    final descriptionController =
        TextEditingController(text: asset.description);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Edit Asset',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Asset Name',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
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

  void _navigateToGeneration(ImageAsset asset) {
    // TODO: In Step 4, we'll implement asset selection in the generation screen
    Provider.of<MenuAppController>(context, listen: false)
        .changeScreen(ScreenType.imageGenerationGeneration);
  }

  void _confirmDeleteAsset(ImageAsset asset, ImageGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Delete Asset',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete "${asset.name}"? This will also delete all ${asset.generations.length} generated images for this asset.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
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
      BuildContext context, ImageGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Clear All Assets',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete all image assets? This action cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
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

  void _showCreateAssetsFromDocDialog(
      BuildContext context, ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => CreateAssetsFromDocDialog(
        projectId: widget.projectId,
        provider: provider,
        assetType: 'image',
        onAssetsCreated: () {
          provider.refreshAssets();
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

