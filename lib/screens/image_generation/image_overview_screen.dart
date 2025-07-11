import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/image_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import 'widgets/image_detail_dialog.dart';

class ImageOverviewScreen extends StatefulWidget {
  const ImageOverviewScreen({Key? key}) : super(key: key);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImageGenerationProvider>().refreshImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
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
                Icons.grid_view,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Generated Images',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
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

  Widget _buildActionButtons(BuildContext context, ImageGenerationProvider provider) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Provider.of<MenuAppController>(context, listen: false)
                .changeScreen(ScreenType.imageGenerationGeneration);
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Generate Images',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0078D4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        if (provider.images.isNotEmpty)
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
        hintText: 'Search images by prompt...',
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
          DropdownMenuItem(value: 'All', child: Text('All Images')),
          DropdownMenuItem(value: 'Completed', child: Text('Completed')),
          DropdownMenuItem(value: 'Failed', child: Text('Failed')),
          DropdownMenuItem(value: 'Generating', child: Text('Generating')),
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
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
      onPressed: () => provider.refreshImages(),
      icon: const Icon(Icons.refresh, color: Colors.white54),
      tooltip: 'Refresh Images',
    );
  }

  Widget _buildContent(BuildContext context, ImageGenerationProvider provider) {
    final filteredImages = _filterImages(provider.images);

    if (filteredImages.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    return _buildImageGrid(filteredImages, provider);
  }

  List<GeneratedImage> _filterImages(List<GeneratedImage> images) {
    var filtered = images;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((image) {
        return image.prompt.toLowerCase().contains(_searchQuery) ||
               (image.negativePrompt?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

         // Apply status filter
     if (_filterType != 'All') {
       GenerationStatus status;
       switch (_filterType) {
         case 'Completed':
           status = GenerationStatus.completed;
           break;
         case 'Failed':
           status = GenerationStatus.failed;
           break;
         case 'Generating':
           status = GenerationStatus.generating;
           break;
         case 'Pending':
           status = GenerationStatus.pending;
           break;
         default:
           return filtered;
       }
       filtered = filtered.where((image) => image.status == status).toList();
     }

    return filtered;
  }

  Widget _buildEmptyState(BuildContext context, ImageGenerationProvider provider) {
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
            'No images generated yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first AI-generated image',
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.imageGenerationGeneration);
            },
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text(
              'Generate First Image',
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

  Widget _buildImageGrid(List<GeneratedImage> images, ImageGenerationProvider provider) {
    final crossAxisCount = Responsive.isMobile(context) ? 2 : 
                           Responsive.isTablet(context) ? 3 : 4;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return _buildImageCard(images[index], provider);
        },
      ),
    );
  }

  Widget _buildImageCard(GeneratedImage image, ImageGenerationProvider provider) {
    return Card(
      color: const Color(0xFF2A2A2A),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF404040), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showImageDetail(image, provider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  color: Color(0xFF3A3A3A),
                ),
                child: _buildImageThumbnail(image),
              ),
            ),
            // Image Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image.prompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatImageInfo(image),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildStatusIndicator(image.status),
                        const Spacer(),
                        Text(
                          _formatDate(image.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showImageContextMenu(image, provider),
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

     Widget _buildImageThumbnail(GeneratedImage image) {
     if (image.status == GenerationStatus.completed && image.imagePath != null) {
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
                   color: Colors.green.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.green.withOpacity(0.5)),
                 ),
                 child: const Icon(
                   Icons.image,
                   color: Colors.green,
                   size: 30,
                 ),
               ),
               const SizedBox(height: 8),
               const Text(
                 'Image Generated',
                 style: TextStyle(
                   color: Colors.green,
                   fontSize: 12,
                   fontWeight: FontWeight.w500,
                 ),
               ),
               const SizedBox(height: 4),
               const Text(
                 'Tap to view',
                 style: TextStyle(
                   color: Colors.white54,
                   fontSize: 10,
                 ),
               ),
             ],
           ),
         ),
       );
     } else if (image.status == GenerationStatus.generating) {
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
                   color: Colors.blue.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.blue.withOpacity(0.5)),
                 ),
                 child: const CircularProgressIndicator(
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                   strokeWidth: 2,
                 ),
               ),
               const SizedBox(height: 8),
               const Text(
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
     } else if (image.status == GenerationStatus.pending) {
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
                   color: Colors.orange.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.orange.withOpacity(0.5)),
                 ),
                 child: const Icon(
                   Icons.schedule,
                   color: Colors.orange,
                   size: 30,
                 ),
               ),
               const SizedBox(height: 8),
               const Text(
                 'Queued',
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
     } else {
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
                   color: Colors.red.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.red.withOpacity(0.5)),
                 ),
                 child: const Icon(
                   Icons.error,
                   color: Colors.red,
                   size: 30,
                 ),
               ),
               const SizedBox(height: 8),
               const Text(
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
        Icon(icon, color: color, size: 14),
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

  String _formatImageInfo(GeneratedImage image) {
    return '${image.width}x${image.height} • ${image.steps} steps • ${image.model ?? 'Unknown'}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showImageDetail(GeneratedImage image, ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Image Details',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prompt:',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              image.prompt,
              style: const TextStyle(color: Colors.white70),
            ),
            if (image.negativePrompt?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Negative Prompt:',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                image.negativePrompt!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Parameters:',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${image.width}x${image.height}, ${image.steps} steps, CFG: ${image.cfgScale}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Model: ${image.model ?? 'Unknown'}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (image.error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Error:',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                image.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
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
    );
  }

  void _showImageContextMenu(GeneratedImage image, ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Image Actions',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white54),
              title: const Text('View Details', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _showImageDetail(image, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.white54),
              title: const Text('Generate Similar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _generateSimilar(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Image', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteImage(image, provider);
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

  void _generateSimilar(GeneratedImage image) {
    // Navigate to generation screen and populate fields
    final menuController = Provider.of<MenuAppController>(context, listen: false);
    menuController.changeScreen(ScreenType.imageGenerationGeneration);
    
    // TODO: Pre-populate the generation form with this image's parameters
    // This would require extending the provider interface to support parameter setting
  }

  void _confirmDeleteImage(GeneratedImage image, ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Image',
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
              Navigator.of(context).pop();
              provider.removeImage(image.id);
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

  void _showClearAllDialog(BuildContext context, ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Clear All Images',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete all generated images? This action cannot be undone.',
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
              Navigator.of(context).pop();
              provider.clearAllImages();
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