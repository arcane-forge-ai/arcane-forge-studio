import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/sfx_generation_provider.dart';
import '../../../models/sfx_generation_models.dart';
import '../../../responsive.dart';
import 'audio_detail_dialog.dart';

class SfxAssetDetailScreen extends StatefulWidget {
  final SfxAsset asset;

  const SfxAssetDetailScreen({
    Key? key,
    required this.asset,
  }) : super(key: key);

  @override
  State<SfxAssetDetailScreen> createState() => _SfxAssetDetailScreenState();
}

class _SfxAssetDetailScreenState extends State<SfxAssetDetailScreen> {
  late SfxAsset _currentAsset;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    _refreshAsset();
  }

  Future<void> _refreshAsset() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider =
          Provider.of<SfxGenerationProvider>(context, listen: false);
      final updatedAsset = await provider.getAsset(_currentAsset.id);
      if (updatedAsset != null && mounted) {
        setState(() {
          _currentAsset = updatedAsset;
        });
      }
    } catch (e) {
      // Handle error silently or show snackbar
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(_currentAsset.name),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshAsset,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssetInfo(),
            const SizedBox(height: 32),
            _buildGenerationsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetInfo() {
    return Card(
      color: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.5)),
                  ),
                  child: const Icon(
                    Icons.library_music,
                    color: Colors.blue,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentAsset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_currentAsset.generations.length} generations',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_currentAsset.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentAsset.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  'Created',
                  _formatDate(_currentAsset.createdAt),
                  Icons.calendar_today,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  'Updated',
                  _formatDate(_currentAsset.updatedAt),
                  Icons.update,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Generated Audio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_currentAsset.generations.length} items',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_currentAsset.generations.isEmpty)
          _buildEmptyGenerations()
        else
          _buildGenerationsList(),
      ],
    );
  }

  Widget _buildEmptyGenerations() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.audiotrack,
              color: Colors.white54,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No audio generated yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start generating SFX for this asset',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGenerationsList() {
    // Sort generations by creation date, most recent first
    final sortedGenerations = [..._currentAsset.generations];
    sortedGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (Responsive.isDesktop(context)) {
      return _buildDesktopGrid(sortedGenerations);
    } else {
      return _buildMobileList(sortedGenerations);
    }
  }

  Widget _buildDesktopGrid(List<SfxGeneration> generations) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: generations.length,
      itemBuilder: (context, index) {
        return _buildGenerationCard(generations[index]);
      },
    );
  }

  Widget _buildMobileList(List<SfxGeneration> generations) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: generations.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGenerationListTile(generations[index]),
        );
      },
    );
  }

  Widget _buildGenerationCard(SfxGeneration generation) {
    return Card(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: generation.isFavorite ? Colors.amber : const Color(0xFF404040),
          width: generation.isFavorite ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showGenerationDetails(generation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(generation.status),
                  const Spacer(),
                  InkWell(
                    onTap: () => _toggleFavorite(generation),
                    child: Icon(
                      generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: generation.isFavorite ? Colors.red : Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: generation.status == GenerationStatus.completed
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.audiotrack,
                      color: generation.status == GenerationStatus.completed
                          ? Colors.blue
                          : Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                generation.parameters['prompt']?.toString() ?? 'No prompt',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatGenerationInfo(generation),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationListTile(SfxGeneration generation) {
    return Card(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: generation.isFavorite ? Colors.amber : const Color(0xFF404040),
          width: generation.isFavorite ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(generation.status),
          child: Icon(
            generation.status == GenerationStatus.completed
                ? Icons.audiotrack
                : generation.status == GenerationStatus.generating
                    ? Icons.hourglass_empty
                    : generation.status == GenerationStatus.failed
                        ? Icons.error
                        : Icons.pending,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          generation.parameters['prompt']?.toString() ?? 'No prompt',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatGenerationInfo(generation),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _toggleFavorite(generation),
              child: Icon(
                generation.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: generation.isFavorite ? Colors.red : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.info_outline,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
        onTap: () => _showGenerationDetails(generation),
      ),
    );
  }

  Widget _buildStatusIcon(GenerationStatus status) {
    Color color = _getStatusColor(status);
    IconData icon;

    switch (status) {
      case GenerationStatus.completed:
        icon = Icons.check_circle;
        break;
      case GenerationStatus.generating:
        icon = Icons.hourglass_empty;
        break;
      case GenerationStatus.failed:
        icon = Icons.error;
        break;
      case GenerationStatus.pending:
        icon = Icons.pending;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }

  Color _getStatusColor(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.completed:
        return Colors.green;
      case GenerationStatus.generating:
        return Colors.orange;
      case GenerationStatus.failed:
        return Colors.red;
      case GenerationStatus.pending:
        return Colors.grey;
    }
  }

  String _formatGenerationInfo(SfxGeneration generation) {
    final parts = <String>[];
    if (generation.duration != null) {
      parts.add('${generation.duration!.toStringAsFixed(1)}s');
    }
    parts.add(generation.status.name);
    parts.add(_formatDateTime(generation.createdAt));
    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _toggleFavorite(SfxGeneration generation) async {
    try {
      final provider = Provider.of<SfxGenerationProvider>(context, listen: false);
      await provider.setFavoriteSfxGeneration(
        generation.assetId,
        generation.id,
      );
      
      // Refresh the asset to update the UI
      _refreshAsset();
      
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGenerationDetails(SfxGeneration generation) async {
    await showDialog(
      context: context,
      builder: (context) => AudioDetailDialog(
        generation: generation,
        asset: _currentAsset,
        onFavoriteToggle: () => _toggleFavorite(generation),
      ),
    );

    // Always refresh the asset after dialog closes
    _refreshAsset();
  }
}
