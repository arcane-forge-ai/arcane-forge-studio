import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../models/image_generation_models.dart';

class ImageDetailDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 800;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: isLargeScreen ? screenSize.width * 0.9 : screenSize.width,
        height: isLargeScreen ? screenSize.height * 0.9 : screenSize.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: isLargeScreen ? _buildLargeScreenLayout(context) : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context),
        // Main content
        Expanded(
          child: Row(
            children: [
              // Left side - Image
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: _buildImageView(),
                ),
              ),
              // Right side - Details
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: _buildDetailsPanel(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Header with action buttons
        _buildDialogHeader(context),
        // Top - Image
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: _buildImageView(),
          ),
        ),
        // Bottom - Details
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: _buildDetailsPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
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
            onPressed: onFavoriteToggle,
            icon: Icon(
              generation.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: generation.isFavorite ? Colors.red : Colors.white54,
            ),
            tooltip: generation.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
          ),
          // Download button
          IconButton(
            onPressed: generation.status == GenerationStatus.completed 
                ? (onDownload ?? () => _downloadImage(context))
                : null,
            icon: const Icon(Icons.download, color: Colors.white54),
            tooltip: 'Download image',
          ),
          // Delete button
          IconButton(
            onPressed: onDelete ?? () => _deleteGeneration(context),
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

  Widget _buildImageView() {
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
              if (generation.imagePath.isNotEmpty) {
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
        : generation.imagePath.isNotEmpty
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

  Widget _buildDetailsPanel() {
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
          
          // Basic Info
          _buildDetailSection('Basic Information', [
            _buildDetailItem('Created', _formatDateTime(generation.createdAt)),
            _buildDetailItem('Status', generation.status.name.toUpperCase()),
            _buildDetailItem('Favorite', generation.isFavorite ? 'Yes' : 'No'),
            if (asset != null) _buildDetailItem('Asset', asset!.name),
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
            _buildDetailItem('Model', generation.parameters['model'] ?? 'Unknown'),
            _buildDetailItem('Dimensions', '${generation.parameters['width']}x${generation.parameters['height']}'),
            _buildDetailItem('Steps', generation.parameters['steps']?.toString() ?? 'Unknown'),
            _buildDetailItem('CFG Scale', generation.parameters['cfg_scale']?.toString() ?? 'Unknown'),
            _buildDetailItem('Sampler', generation.parameters['sampler'] ?? 'Unknown'),
            _buildDetailItem('Seed', generation.parameters['seed']?.toString() ?? 'Unknown'),
          ]),
          
          const SizedBox(height: 20),
          
          // Prompts
          _buildDetailSection('Prompts', [
            _buildTextDetailItem('Positive Prompt', generation.parameters['positive_prompt'] ?? 'No prompt'),
            if (generation.parameters['negative_prompt'] != null && generation.parameters['negative_prompt'].toString().isNotEmpty)
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


  void _downloadImage(BuildContext context) {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality will be implemented soon'),
        backgroundColor: Colors.blue,
      ),
    );
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