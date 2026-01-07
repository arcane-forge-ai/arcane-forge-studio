import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/image_generation_provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../controllers/menu_app_controller.dart';
import 'image_detail_dialog.dart';

class RecentImagesPanelWidget extends StatelessWidget {
  final ImageAsset? selectedAsset;
  final List<ImageGeneration> selectedAssetGenerations;
  final bool loadingGenerations;
  final VoidCallback? onRefresh;

  const RecentImagesPanelWidget({
    Key? key,
    required this.selectedAsset,
    required this.selectedAssetGenerations,
    required this.loadingGenerations,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                'Recent Generations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  onPressed: loadingGenerations ? null : onRefresh,
                  icon: Icon(
                    Icons.refresh,
                    color: loadingGenerations ? Colors.white38 : const Color(0xFF0078D4),
                  ),
                  tooltip: 'Refresh generations',
                ),
              TextButton(
                onPressed: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.imageGenerationOverview);
                },
                child: const Text(
                  'View All Assets',
                  style: TextStyle(color: Color(0xFF0078D4)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildGenerationsList(context),
        ),
      ],
    );
  }

  Widget _buildGenerationsList(BuildContext context) {
    if (loadingGenerations) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Loading generations...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        final displayGenerations = selectedAsset != null
            ? selectedAssetGenerations
            : provider.allGenerations;

        final sortedGenerations = [...displayGenerations];
        sortedGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (sortedGenerations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  selectedAsset != null
                      ? 'No images generated for "${selectedAsset!.name}"'
                      : 'No images generated yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedAsset != null
                      ? 'Generate your first image for this asset'
                      : 'Select an asset and generate your first image',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sortedGenerations.length,
          itemBuilder: (context, index) {
            final generation = sortedGenerations[index];
            final asset = selectedAsset ?? provider.getAssetFromCache(generation.assetId);
            return _buildGenerationTile(context, generation, asset, provider);
          },
        );
      },
    );
  }

  Widget _buildGenerationTile(
    BuildContext context,
    ImageGeneration generation,
    ImageAsset? asset,
    ImageGenerationProvider provider,
  ) {
    return InkWell(
      onTap: () async {
        final freshAsset = await provider.getAsset(generation.assetId);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => ImageDetailDialog(
              generation: generation,
              asset: freshAsset,
              onFavoriteToggle: freshAsset != null
                  ? () => provider.setFavoriteGeneration(freshAsset.id, generation.id)
                  : null,
            ),
          );
        }
      },
      child: Card(
        color: const Color(0xFF2A2A2A),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildImageStatusIcon(generation.status),
                  const SizedBox(width: 12),
                  if (asset != null)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF404040)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: generation.status == GenerationStatus.completed
                            ? _buildGenerationThumbnailImage(generation)
                            : Container(
                                color: const Color(0xFF3A3A3A),
                                child: const Icon(
                                  Icons.folder_outlined,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                asset?.name ?? 'Unknown Asset',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageStatusIcon(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case GenerationStatus.generating:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case GenerationStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 24);
      case GenerationStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
    }
  }

  Widget _buildGenerationThumbnailImage(ImageGeneration generation) {
    final bool hasOnlineUrl = generation.imageUrl != null && generation.imageUrl!.isNotEmpty;
    final bool hasLocalFile = !kIsWeb && generation.imagePath.isNotEmpty;

    if (hasOnlineUrl) {
      return Image.network(
        generation.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (hasLocalFile) {
            return Image.file(
              File(generation.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF3A3A3A),
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 24,
                  ),
                );
              },
            );
          }
          return Container(
            color: const Color(0xFF3A3A3A),
            child: const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 24,
            ),
          );
        },
      );
    } else if (hasLocalFile) {
      return Image.file(
        File(generation.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF3A3A3A),
            child: const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 24,
            ),
          );
        },
      );
    } else {
      return Container(
        color: const Color(0xFF3A3A3A),
        child: const Icon(
          Icons.folder_outlined,
          color: Colors.white54,
          size: 24,
        ),
      );
    }
  }

  String _formatGenerationInfo(ImageGeneration generation) {
    final params = GenerationParameters(generation.parameters);
    return '${params.width}x${params.height} • ${params.steps} steps';
  }
}

