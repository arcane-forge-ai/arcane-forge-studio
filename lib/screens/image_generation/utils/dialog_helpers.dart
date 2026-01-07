import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/image_generation_provider.dart';
import '../../../models/image_generation_models.dart';

class DialogHelpers {
  static void showErrorDialog(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Error',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: SelectableText(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF0078D4)),
            ),
          ),
        ],
      ),
    );
  }

  static void showCreateAssetDialog(
    BuildContext context,
    Function(ImageAsset) onAssetCreated,
  ) {
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

              final provider =
                  Provider.of<ImageGenerationProvider>(context, listen: false);
              try {
                final newAsset = await provider.createAsset(name, description);
                Navigator.of(context).pop();
                onAssetCreated(newAsset);

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

  static void showServiceLogs(
    BuildContext context,
    Function() onKillDanglingService,
    Function() onCopyLogs,
  ) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<String>(
        stream: Provider.of<ImageGenerationProvider>(context, listen: false)
            .serviceLogStream,
        builder: (context, snapshot) => Consumer<ImageGenerationProvider>(
          builder: (context, provider, child) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: Row(
              children: [
                Text(
                  '${provider.currentBackendName} Logs',
                  style: const TextStyle(color: Colors.white),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onKillDanglingService,
                  child: const Text(
                    'Kill Dangling Service',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => provider.clearServiceLogs(),
                  child: const Text(
                    'Clear Logs',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onCopyLogs,
                  child: const Text(
                    'Copy Logs',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 800,
              height: 600,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: provider.serviceLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs available',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          provider.serviceLogs.join('\n'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showAssetMetadataDialog(BuildContext context, ImageAsset asset) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Asset Metadata',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection(
                        context,
                        'Basic Information',
                        [
                          _buildMetadataRow(context, 'Name', asset.name),
                          _buildMetadataRow(
                            context,
                            'Description',
                            asset.description.isEmpty
                                ? 'No description'
                                : asset.description,
                          ),
                          _buildMetadataRow(context, 'Asset ID', asset.id),
                          _buildMetadataRow(context, 'Project ID', asset.projectId),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildMetadataSection(
                        context,
                        'Statistics',
                        [
                          _buildMetadataRow(
                            context,
                            'Total Generations',
                            asset.generations.length.toString(),
                          ),
                          if (asset.favoriteGenerationId != null)
                            _buildMetadataRow(
                              context,
                              'Favorite Generation ID',
                              asset.favoriteGenerationId!,
                            ),
                          _buildMetadataRow(
                            context,
                            'Has Thumbnail',
                            asset.thumbnail != null && asset.thumbnail!.isNotEmpty
                                ? 'Yes'
                                : 'No',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildMetadataSection(
                        context,
                        'Timestamps',
                        [
                          _buildMetadataRow(
                            context,
                            'Created At',
                            _formatDetailedDateTime(asset.createdAt),
                          ),
                        ],
                      ),
                      if (asset.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildMetadataSection(
                          context,
                          'Tags',
                          [
                            _buildMetadataRow(context, 'Tags', asset.tags.join(', ')),
                          ],
                        ),
                      ],
                      if (asset.metadata.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildMetadataSection(
                          context,
                          'Custom Metadata',
                          asset.metadata.entries
                              .map((entry) => _buildMetadataRow(
                                    context,
                                    entry.key,
                                    entry.value.toString(),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildMetadataSection(
    BuildContext context,
    String title,
    List<Widget> rows,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: rows,
          ),
        ),
      ],
    );
  }

  static Widget _buildMetadataRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.blue, size: 16),
            tooltip: 'Copy $label',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  static String _formatDetailedDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

