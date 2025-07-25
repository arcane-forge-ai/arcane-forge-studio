import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../models/image_generation_models.dart';

class ImageDetailDialog extends StatelessWidget {
  final ImageGeneration generation;
  final ImageAsset? asset;
  final VoidCallback? onFavoriteToggle;

  const ImageDetailDialog({
    super.key,
    required this.generation,
    this.asset,
    this.onFavoriteToggle,
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
        child: isLargeScreen ? _buildLargeScreenLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
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
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
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
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Image.file(
            File(generation.imagePath),
            width: width.toDouble(),
            height: height.toDouble(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
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
            },
          ),
        ),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context) {
    final details = StringBuffer();
    details.writeln('Generation Details:');
    details.writeln('Created: ${_formatDateTime(generation.createdAt)}');
    details.writeln('Status: ${generation.status.name.toUpperCase()}');
    details.writeln('Favorite: ${generation.isFavorite ? 'Yes' : 'No'}');
    if (asset != null) details.writeln('Asset: ${asset!.name}');
    details.writeln();
    details.writeln('Generation Parameters:');
    details.writeln('Model: ${generation.parameters['model'] ?? 'Unknown'}');
    details.writeln('Dimensions: ${generation.parameters['width']}x${generation.parameters['height']}');
    details.writeln('Steps: ${generation.parameters['steps'] ?? 'Unknown'}');
    details.writeln('CFG Scale: ${generation.parameters['cfg_scale'] ?? 'Unknown'}');
    details.writeln('Sampler: ${generation.parameters['sampler'] ?? 'Unknown'}');
    details.writeln('Seed: ${generation.parameters['seed'] ?? 'Unknown'}');
    details.writeln();
    details.writeln('Positive Prompt: ${generation.parameters['positive_prompt'] ?? 'No prompt'}');
    if (generation.parameters['negative_prompt'] != null && generation.parameters['negative_prompt'].toString().isNotEmpty) {
      details.writeln('Negative Prompt: ${generation.parameters['negative_prompt']}');
    }
    
    Clipboard.setData(ClipboardData(text: details.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generation details copied to clipboard!')),
    );
  }
} 