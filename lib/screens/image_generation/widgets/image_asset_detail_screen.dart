import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../responsive.dart';
import '../../../controllers/menu_app_controller.dart';
import 'image_detail_dialog.dart';
import 'dart:async';
import 'dart:io' show File;

class ImageAssetDetailScreen extends StatefulWidget {
  final ImageAsset asset;

  const ImageAssetDetailScreen({Key? key, required this.asset}) : super(key: key);

  @override
  State<ImageAssetDetailScreen> createState() => _ImageAssetDetailScreenState();
}

class _ImageAssetDetailScreenState extends State<ImageAssetDetailScreen> {
  late ImageAsset _asset;
  bool _isLoading = false;
  Timer? _generationPollTimer;

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _refreshAsset(); // Fetch fresh data on init
    _startGenerationPolling();
  }

  bool _hasInFlightGenerations() {
    return _asset.generations.any((g) =>
        g.status == GenerationStatus.pending ||
        g.status == GenerationStatus.generating);
  }

  void _startGenerationPolling() {
    _generationPollTimer?.cancel();
    _generationPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      if (!_hasInFlightGenerations()) return;
      try {
        await _refreshAsset();
      } catch (_) {
        // Ignore polling errors; user can manually refresh.
      }
    });
  }

  Future<void> _refreshAsset() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
      final updatedAsset = await provider.getAsset(_asset.id);
      if (updatedAsset != null && mounted) {
        setState(() {
          _asset = updatedAsset;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh asset: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generationPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _asset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _asset.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(),
            ],
          ),
          const SizedBox(height: 16),
          _buildAssetStats(),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        IconButton(
          onPressed: _isLoading ? null : _refreshAsset,
          icon: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  ),
                )
              : const Icon(Icons.refresh, color: Colors.white54),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: const Color(0xFF2A2A2A),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditAssetDialog();
                break;
              case 'delete':
                _confirmDeleteAsset();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white54, size: 20),
                  SizedBox(width: 12),
                  Text('Edit Asset', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Delete Asset', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetStats() {
    final totalGenerations = _asset.generations.length;
    final completedGenerations = _asset.generations.where((g) => g.status == GenerationStatus.completed).length;
    final favoriteGeneration = _asset.favoriteGenerationId != null
        ? _asset.generations.where((g) => g.id == _asset.favoriteGenerationId).isNotEmpty
            ? _asset.generations.firstWhere((g) => g.id == _asset.favoriteGenerationId)
            : null
        : null;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildStatItem(
                icon: Icons.image,
                label: 'Total',
                value: '$totalGenerations',
                color: Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Completed',
                value: '$completedGenerations',
                color: Colors.green,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.star,
                label: 'Favorite',
                value: favoriteGeneration != null ? '1' : '0',
                color: Colors.amber,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.calendar_today,
                label: 'Created',
                value: _formatDate(_asset.createdAt),
                color: Colors.white70,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Debug info section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF505050)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Asset ID:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _asset.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(_asset.id, 'Asset ID'),
                icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                tooltip: 'Copy Asset ID',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_asset.generations.isEmpty) {
      return _buildEmptyState();
    }

    return _buildGenerationGrid();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_outlined,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No generations yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate your first image for "${_asset.name}"',
            style: const TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to generation screen
              Navigator.of(context).pop();
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.imageGenerationGeneration);
            },
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text(
              'Generate Images',
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

  Widget _buildGenerationGrid() {
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
        itemCount: _asset.generations.length,
        itemBuilder: (context, index) {
          return _buildGenerationCard(_asset.generations[index]);
        },
      ),
    );
  }

  Widget _buildGenerationCard(ImageGeneration generation) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: generation.isFavorite ? Colors.amber : const Color(0xFF404040),
          width: generation.isFavorite ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGenerationDetail(generation),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generation image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  color: Color(0xFF3A3A3A),
                ),
                child: _buildGenerationThumbnail(generation),
              ),
            ),
            // Generation info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStatusIndicator(generation.status),
                        const Spacer(),
                        if (generation.isFavorite)
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatGenerationInfo(generation),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          _formatDate(generation.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _toggleFavorite(generation),
                          child: Icon(
                            generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: generation.isFavorite ? Colors.red : Colors.white54,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showGenerationContextMenu(generation),
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

  Widget _buildGenerationThumbnail(ImageGeneration generation) {
    if (generation.status == GenerationStatus.completed) {
      // Prefer online URL, fallback to local file
      final bool hasOnlineUrl = generation.imageUrl != null && generation.imageUrl!.isNotEmpty;
      final bool hasLocalFile = !kIsWeb && generation.imagePath.isNotEmpty && File(generation.imagePath).existsSync();
      
      if (hasOnlineUrl || hasLocalFile) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: hasOnlineUrl
                  ? Image.network(
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
                              return _buildErrorThumbnail();
                            },
                          );
                        }
                        return _buildErrorThumbnail();
                      },
                    )
                  : Image.file(
                      File(generation.imagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorThumbnail();
                      },
                    ),
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
        );
      }
    }
    
    if (generation.status == GenerationStatus.generating) {
      return _buildGeneratingThumbnail();
    } else if (generation.status == GenerationStatus.failed) {
      return _buildErrorThumbnail();
    } else {
      return _buildPendingThumbnail();
    }
  }

  Widget _buildGeneratingThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Generating...',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              color: Colors.red,
              size: 30,
            ),
            SizedBox(height: 8),
            Text(
              'Failed',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              color: Colors.orange,
              size: 30,
            ),
            SizedBox(height: 8),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(GenerationStatus status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case GenerationStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Done';
        break;
      case GenerationStatus.generating:
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        text = 'Gen';
        break;
      case GenerationStatus.failed:
        color = Colors.red;
        icon = Icons.error;
        text = 'Error';
        break;
      case GenerationStatus.pending:
        color = Colors.orange;
        icon = Icons.schedule;
        text = 'Queue';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatGenerationInfo(ImageGeneration generation) {
    final params = GenerationParameters(generation.parameters);
    return '${params.width}x${params.height} • ${params.steps} steps';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showGenerationDetail(ImageGeneration generation) async {
    // Get fresh asset data for the dialog
    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
    final freshAsset = await provider.getAsset(_asset.id);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => ImageDetailDialog(
          generation: generation,
          asset: freshAsset ?? _asset,
          onFavoriteToggle: () => _toggleFavorite(generation),
        ),
      );
    }
  }

  void _showGenerationContextMenu(ImageGeneration generation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Generation Actions',
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
                _showGenerationDetail(generation);
              },
            ),
            ListTile(
              leading: Icon(
                generation.isFavorite ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              title: Text(
                generation.isFavorite ? 'Remove Favorite' : 'Mark as Favorite',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _toggleFavorite(generation);
              },
            ),
            if (generation.status == GenerationStatus.completed)
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white54),
                title: const Text('Export Image',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportGeneration(generation);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Generation',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteGeneration(generation);
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

  void _toggleFavorite(ImageGeneration generation) async {
    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
    try {
      if (generation.isFavorite) {
        // Remove from favorites using the DELETE endpoint
        await provider.removeGenerationFavorite(generation.id);
      } else {
        // Mark as favorite using the POST endpoint
        await provider.markGenerationAsFavorite(generation.id);
      }
      
      _refreshAsset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            generation.isFavorite 
                ? 'Removed from favorites' 
                : 'Marked as favorite',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportGeneration(ImageGeneration generation) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality will be implemented soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _confirmDeleteGeneration(ImageGeneration generation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Generation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this generated image?',
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
              final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
              try {
                await provider.deleteGeneration(generation.id);
                Navigator.of(context).pop();
                _refreshAsset();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generation deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete generation: $e'),
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

  void _showEditAssetDialog() {
    final nameController = TextEditingController(text: _asset.name);
    final descriptionController = TextEditingController(text: _asset.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Edit Asset',
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

              final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
              try {
                final updatedAsset = _asset.copyWith(
                  name: name,
                  description: description,
                );
                await provider.updateAsset(updatedAsset);
                Navigator.of(context).pop();
                _refreshAsset();
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

  void _confirmDeleteAsset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Asset',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${_asset.name}"? This will also delete all ${_asset.generations.length} generated images for this asset.',
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
              final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
              try {
                await provider.deleteAsset(_asset.id);
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to overview
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
} 