import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show File;
import '../../../models/image_generation_models.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../services/file_download_service.dart';
import 'package:provider/provider.dart';

class ImageDetailDialog extends StatefulWidget {
  final ImageGeneration generation;
  final ImageAsset? asset;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const ImageDetailDialog({
    super.key,
    required this.generation,
    this.asset,
    this.onFavoriteToggle,
    this.onDownload,
    this.onDelete,
  });

  @override
  State<ImageDetailDialog> createState() => _ImageDetailDialogState();
}

class _ImageDetailDialogState extends State<ImageDetailDialog> {
  ImageGeneration? _currentGeneration;
  bool _isTogglingFavorite = false;
  bool _isLoadingGeneration = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Always fetch fresh data from API when dialog opens
    _refreshGenerationData();
  }

  Future<void> _refreshGenerationData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingGeneration = true;
      _loadError = null;
    });

    try {
      final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
      final updatedGeneration = await provider.getGeneration(widget.generation.id);
      if (updatedGeneration != null && mounted) {
        setState(() {
          _currentGeneration = updatedGeneration;
          _isLoadingGeneration = false;
        });
      } else if (mounted) {
        setState(() {
          _loadError = 'Generation not found';
          _isLoadingGeneration = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load generation: $e';
          _isLoadingGeneration = false;
        });
      }
    }
  }

  Future<void> _handleFavoriteToggle() async {
    if (_isTogglingFavorite || _currentGeneration == null) return;
    
    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
      
      // First, make the API call
      if (_currentGeneration!.isFavorite) {
        await provider.removeGenerationFavorite(_currentGeneration!.id);
      } else {
        await provider.markGenerationAsFavorite(_currentGeneration!.id);
      }
      
      // After API call succeeds, fetch updated generation
      final updatedGeneration = await provider.getGeneration(_currentGeneration!.id);
      if (updatedGeneration != null && mounted) {
        setState(() {
          _currentGeneration = updatedGeneration;
          _isTogglingFavorite = false;
        });
      } else if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
      
      // Call the callback if provided (for parent to refresh)
      if (widget.onFavoriteToggle != null) {
        widget.onFavoriteToggle!();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: isLargeScreen ? screenSize.width * 0.9 : screenSize.width,
        height: isLargeScreen ? screenSize.height * 0.9 : screenSize.height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          ),
        ),
        child: _isLoadingGeneration
            ? _buildLoadingState(context)
            : _loadError != null
                ? _buildErrorState(context)
                : (isLargeScreen ? _buildLargeScreenLayout(context) : _buildMobileLayout(context)),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              const Text(
                'Generation Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Loading content
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading generation details...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              const Text(
                'Generation Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Error content
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshGenerationData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    // This method is only called when _currentGeneration is not null
    final generation = _currentGeneration!;
    
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context, generation),
        // Main content
        Expanded(
          child: Row(
            children: [
              // Left side - Image
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: _buildImageView(generation),
                ),
              ),
              // Right side - Details
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2A2A)
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: _buildDetailsPanel(generation),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    // This method is only called when _currentGeneration is not null
    final generation = _currentGeneration!;
    
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context, generation),
        // Top - Image
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: _buildImageView(generation),
          ),
        ),
        // Bottom - Details
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: _buildDetailsPanel(generation),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogHeader(BuildContext context, ImageGeneration generation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Generation Details',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Copy Generation ID button
          Tooltip(
            message: 'Copy Generation ID',
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: generation.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generation ID copied to clipboard'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF404040)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      generation.id.length > 8 
                          ? '${generation.id.substring(0, 8)}...' 
                          : generation.id,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Favorite button
          IconButton(
            onPressed: _isTogglingFavorite ? null : _handleFavoriteToggle,
            icon: _isTogglingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  )
                : Icon(
                    generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: generation.isFavorite ? Colors.red : Colors.white54,
                  ),
            tooltip: generation.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
          ),
          // Download button
          IconButton(
            onPressed: generation.status == GenerationStatus.completed 
                ? (widget.onDownload ?? () => _downloadImage(context, generation))
                : null,
            icon: const Icon(Icons.download, color: Colors.white54),
            tooltip: 'Download image',
          ),
          // Delete button
          IconButton(
            onPressed: widget.onDelete ?? () => _deleteGeneration(context),
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete generation',
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildImageView(ImageGeneration generation) {
    // Get image dimensions
    int width = 512;
    int height = 512;
    if (generation.parameters.containsKey('width')) {
      width = generation.parameters['width'] ?? 512;
    }
    if (generation.parameters.containsKey('height')) {
      height = generation.parameters['height'] ?? 512;
    }
    
    // Use online URL if available, otherwise use local file
    final Widget imageWidget = generation.imageUrl != null && generation.imageUrl!.isNotEmpty
        ? Image.network(
            generation.imageUrl!,
            width: width.toDouble(),
            height: height.toDouble(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to local file if network image fails
              if (!kIsWeb && generation.imagePath.isNotEmpty) {
                return Image.file(
                  File(generation.imagePath),
                  width: width.toDouble(),
                  height: height.toDouble(),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildErrorImage(width, height);
                  },
                );
              }
              return _buildErrorImage(width, height);
            },
          )
        : !kIsWeb && generation.imagePath.isNotEmpty
            ? Image.file(
                File(generation.imagePath),
                width: width.toDouble(),
                height: height.toDouble(),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorImage(width, height);
                },
              )
            : _buildErrorImage(width, height);
    
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: imageWidget,
        ),
      ),
    );
  }
  
  Widget _buildErrorImage(int width, int height) {
    return Container(
      width: width.toDouble(),
      height: height.toDouble(),
      color: Colors.blue.withOpacity(0.2),
      child: const Icon(
        Icons.broken_image,
        color: Colors.blue,
        size: 60,
      ),
    );
  }

  Widget _buildDetailsPanel(ImageGeneration generation) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Generation Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          
          // Error Message (if failed)
          if (generation.status == GenerationStatus.failed)
            ...[
              _buildErrorSection(generation),
              const SizedBox(height: 20),
            ],
          
          // Basic Info
          _buildDetailSection('Basic Information', [
            _buildDetailItem('Created', _formatDateTime(generation.createdAt)),
            _buildDetailItem('Status', generation.status.name.toUpperCase()),
            _buildDetailItem('Favorite', generation.isFavorite ? 'Yes' : 'No'),
            if (widget.asset != null) _buildDetailItem('Asset', widget.asset!.name),
          ]),
          
          const SizedBox(height: 20),
          
          // Technical Details (Debug Info)
          _buildDetailSection('Technical Details', [
            _buildCopyableDetailItem('Generation ID', generation.id),
            _buildCopyableDetailItem('Asset ID', generation.assetId),
            if (generation.imagePath.isNotEmpty)
              _buildCopyableDetailItem('Local Path', generation.imagePath),
            if (generation.imageUrl != null && generation.imageUrl!.isNotEmpty)
              _buildCopyableDetailItem('Image URL', generation.imageUrl!),
          ]),
          
          const SizedBox(height: 20),
          
          // Generation Parameters
          _buildDetailSection('Generation Parameters', [
            _buildDetailItem('Model', generation.parameters['model_name'] ?? generation.parameters['model'] ?? 'Unknown'),
            // if (generation.parameters['provider'] != null)
            //   _buildDetailItem('Provider', generation.parameters['provider']?.toString() ?? 'Unknown'),
            _buildDetailItem('Dimensions', '${generation.parameters['width']}x${generation.parameters['height']}'),
            _buildDetailItem('Steps', generation.parameters['steps']?.toString() ?? 'Unknown'),
            _buildDetailItem('CFG Scale', generation.parameters['cfg_scale']?.toString() ?? 'Unknown'),
            _buildDetailItem('Sampler', generation.parameters['sampler_name'] ?? generation.parameters['sampler'] ?? 'Unknown'),
            _buildDetailItem('Seed', generation.parameters['seed']?.toString() ?? 'Unknown'),
            if (generation.parameters['scheduler'] != null)
              _buildDetailItem('Scheduler', generation.parameters['scheduler']?.toString() ?? 'Unknown'),
          ]),
          
          const SizedBox(height: 20),
          
          // Prompts
          _buildDetailSection('Prompts', [
            _buildTextDetailItem('Positive Prompt', generation.parameters['positive_prompt'] ?? generation.parameters['prompt'] ?? 'No prompt'),
            if ((generation.parameters['negative_prompt'] ?? '').toString().isNotEmpty)
              _buildTextDetailItem('Negative Prompt', generation.parameters['negative_prompt']),
          ]),
          
          // LoRAs if any
          if (generation.parameters['loras'] != null && (generation.parameters['loras'] as List).isNotEmpty)
            ...[
              const SizedBox(height: 20),
              _buildDetailSection('LoRAs', [
                for (final lora in generation.parameters['loras'] as List)
                  _buildDetailItem(lora['name'], 'Strength: ${lora['strength']}'),
              ]),
            ],
        ],
      ),
    );
  }

  Widget _buildErrorSection(ImageGeneration generation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Generation Failed',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(
              generation.errorMessage ?? 'Unknown error. Some mysterious cosmic event has occurred...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _copyToClipboard(value, label),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.copy,
                    size: 14,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }


  Future<void> _downloadImage(BuildContext context, ImageGeneration generation) async {
    final imageUrl = generation.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image URL available for download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final defaultFileName = _generateDefaultFileName(generation);
    
    await FileDownloadService.downloadFile(
      url: imageUrl,
      defaultFileName: defaultFileName,
      config: const FileDownloadConfig(
        dialogTitle: 'Save Image File',
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        errorPrefix: 'Error downloading image',
        downloadingSnackbarColor: Colors.blue,
        showOverwriteConfirmation: true,
      ),
      context: context,
      mounted: () => mounted,
    );
  }

  String _generateDefaultFileName(ImageGeneration generation) {
    // Generate a filename based on the prompt or asset name
    String baseName = 'generated_image';
    
    if (widget.asset != null && widget.asset!.name.isNotEmpty) {
      baseName = widget.asset!.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    } else {
      // Try both 'positive_prompt' and 'prompt' field names
      final prompt = (generation.parameters['positive_prompt'] ?? generation.parameters['prompt'])?.toString();
      if (prompt != null && prompt.isNotEmpty) {
        // Take first few words of prompt and sanitize
        final words = prompt.split(' ').take(3).join('_');
        baseName = words.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      }
    }
    
    // Add timestamp to make filename unique
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Determine file extension from imageUrl or default to png
    String extension = 'png';
    if (generation.imageUrl != null && generation.imageUrl!.isNotEmpty) {
      final url = generation.imageUrl!;
      if (url.contains('.jpg') || url.contains('.jpeg')) {
        extension = 'jpg';
      } else if (url.contains('.webp')) {
        extension = 'webp';
      }
    }
    
    return '${baseName}_$timestamp.$extension';
  }

  void _deleteGeneration(BuildContext context) {
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
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation dialog
              Navigator.of(context).pop(); // Close image detail dialog
              // TODO: Implement actual deletion logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete functionality will be implemented soon'),
                  backgroundColor: Colors.orange,
                ),
              );
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