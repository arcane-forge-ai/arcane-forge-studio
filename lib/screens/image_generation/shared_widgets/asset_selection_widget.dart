import 'package:flutter/material.dart';
import '../../../models/image_generation_models.dart';

/// Reusable widget for asset selection
/// Extracted from parameters_panel_widget.dart for use across workflow screens
class AssetSelectionWidget extends StatelessWidget {
  final ImageAsset? selectedAsset;
  final List<ImageAsset> availableAssets;
  final Function(ImageAsset?) onAssetChanged;
  final VoidCallback onCreateAsset;
  final VoidCallback? onViewAssetMetadata;
  final bool showMetadataButton;

  const AssetSelectionWidget({
    Key? key,
    required this.selectedAsset,
    required this.availableAssets,
    required this.onAssetChanged,
    required this.onCreateAsset,
    this.onViewAssetMetadata,
    this.showMetadataButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Target Asset',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateAsset,
              icon: const Icon(Icons.add, color: Colors.blue, size: 16),
              label: const Text(
                'New Asset',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            if (selectedAsset != null && showMetadataButton && onViewAssetMetadata != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onViewAssetMetadata,
                icon: const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                tooltip: 'View Asset Metadata',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Color(0xFF404040)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A3A3A)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedAsset == null
                  ? Colors.red.withOpacity(0.5)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF404040)
                      : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ImageAsset?>(
              value: selectedAsset,
              hint: Text(
                'Select an asset...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade200,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: [
                const DropdownMenuItem<ImageAsset?>(
                  value: null,
                  child: Text(
                    'Select an asset...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ...availableAssets.map((asset) {
                  return DropdownMenuItem<ImageAsset?>(
                    value: asset,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          asset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (asset.description.isNotEmpty)
                          Text(
                            asset.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: onAssetChanged,
            ),
          ),
        ),
        if (selectedAsset != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: Colors.blue.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAsset!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (selectedAsset!.description.isNotEmpty)
                        Text(
                          selectedAsset!.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selectedAsset!.generations.length} images',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selectedAsset == null) ...[
          const SizedBox(height: 4),
          const Text(
            'Please select an asset to organize your generated images',
            style: TextStyle(
              color: Colors.red,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

