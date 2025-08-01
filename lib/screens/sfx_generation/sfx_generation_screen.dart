import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sfx_generation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/sfx_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import '../../services/sfx_generation_services.dart';
import 'widgets/audio_detail_dialog.dart';

class SfxGenerationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const SfxGenerationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<SfxGenerationScreen> createState() => _SfxGenerationScreenState();
}

class _SfxGenerationScreenState extends State<SfxGenerationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _negativePromptController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '2.0');
  
  double _promptInfluence = 0.5;

  // Asset selection state
  SfxAsset? _selectedAsset;
  List<SfxAsset> _availableAssets = [];
  List<SfxGeneration> _selectedAssetGenerations = [];
  bool _loadingGenerations = false;

  // Providers
  late SfxGenerationProvider sfxGenerationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  void _initializeProvider() {
    // Get the provider from context
    sfxGenerationProvider = Provider.of<SfxGenerationProvider>(context, listen: false);
    
    // Load initial data
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (!mounted) return;
    
    await sfxGenerationProvider.refreshAssets(projectId: widget.projectId);
    if (mounted) {
      setState(() {
        _availableAssets = sfxGenerationProvider.assets;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  /// Refresh generations for the currently selected asset
  Future<void> _refreshSelectedAssetGenerations() async {
    if (_selectedAsset == null || !mounted) return;

    setState(() {
      _loadingGenerations = true;
    });

    try {
      final updatedAsset = await sfxGenerationProvider.getAsset(_selectedAsset!.id);
      if (updatedAsset != null && mounted) {
        setState(() {
          _selectedAssetGenerations = updatedAsset.generations;
          _selectedAsset = updatedAsset;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to refresh generations: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingGenerations = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SfxGenerationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel - Generation Controls
              if (Responsive.isDesktop(context))
                Expanded(
                  flex: 2,
                  child: _buildGenerationPanel(),
                ),
              
              // Right Panel - Assets and Recent Generations
              Expanded(
                flex: Responsive.isDesktop(context) ? 3 : 1,
                child: _buildAssetsPanel(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenerationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          right: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'SFX Generation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Asset Selection
          _buildAssetSelection(),
          const SizedBox(height: 20),

          // Generation Form
          Expanded(
            child: SingleChildScrollView(
              child: _buildGenerationForm(),
            ),
          ),

          // Generate Button
          const SizedBox(height: 20),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildAssetSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Select Asset',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showCreateAssetDialog,
              icon: const Icon(Icons.add, color: Colors.blue),
              label: const Text('New Asset', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SfxAsset>(
              value: _selectedAsset,
              hint: const Text(
                'Choose an asset...',
                style: TextStyle(color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF2A2A2A),
              items: _availableAssets.map((asset) {
                return DropdownMenuItem<SfxAsset>(
                  value: asset,
                  child: Text(asset.name),
                );
              }).toList(),
              onChanged: (asset) {
                setState(() {
                  _selectedAsset = asset;
                  if (asset != null) {
                    _selectedAssetGenerations = asset.generations;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt
        _buildFormSection(
          'Prompt',
          'Describe the sound you want to generate',
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Laser shooting sound, slowly fading away as the laser travels',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ),

        // Negative Prompt
        _buildFormSection(
          'Negative Prompt (Optional)',
          'Describe what you want to avoid',
          TextField(
            controller: _negativePromptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g., background noise, music, voices',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ),

        // Duration
        _buildFormSection(
          'Duration (seconds)',
          'Target duration for the generated audio (0.1 - 30.0)',
          TextField(
            controller: _durationController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '2.0',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF404040)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ),

        // Prompt Influence
        _buildFormSection(
          'Prompt Influence',
          'How closely to follow the prompt (0.0 = loose, 1.0 = strict)',
          Column(
            children: [
              Slider(
                value: _promptInfluence,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(_promptInfluence * 100).round()}%',
                activeColor: Colors.blue,
                inactiveColor: Colors.white24,
                onChanged: (value) {
                  setState(() {
                    _promptInfluence = value;
                  });
                },
              ),
              Text(
                '${(_promptInfluence * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(String title, String description, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _selectedAsset != null && _promptController.text.trim().isNotEmpty
            ? () => _generateSfx()
            : null,
        icon: const Icon(Icons.audiotrack),
        label: const Text('Generate SFX'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[800],
          disabledForegroundColor: Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'SFX Assets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadAssets,
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: 'Refresh Assets',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected Asset Generations
          if (_selectedAsset != null) ...[
            Text(
              'Recent Generations for "${_selectedAsset!.name}"',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 1,
              child: _buildGenerationsList(),
            ),
            const SizedBox(height: 20),
          ],

          // All Assets List
          const Text(
            'All Assets',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: _selectedAsset != null ? 1 : 2,
            child: _buildAssetsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationsList() {
    if (_loadingGenerations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedAssetGenerations.isEmpty) {
      return const Center(
        child: Text(
          'No generations yet.\nGenerate your first SFX!',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _selectedAssetGenerations.length,
      itemBuilder: (context, index) {
        final generation = _selectedAssetGenerations[index];
        return _buildGenerationTile(generation);
      },
    );
  }

  Widget _buildGenerationTile(SfxGeneration generation) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
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
          generation.parameters['prompt'] ?? 'No prompt',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatGenerationSubtitle(generation),
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (generation.isFavorite)
              const Icon(Icons.favorite, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Icon(
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

  Widget _buildAssetsList() {
    if (sfxGenerationProvider.isLoadingAssets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.audiotrack,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'No SFX assets yet.\nCreate your first asset!',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateAssetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Asset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _availableAssets.length,
      itemBuilder: (context, index) {
        final asset = _availableAssets[index];
        return _buildAssetTile(asset);
      },
    );
  }

  Widget _buildAssetTile(SfxAsset asset) {
    return Card(
      color: _selectedAsset?.id == asset.id 
          ? const Color(0xFF3A3A3A) 
          : const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: const Icon(Icons.audiotrack, color: Colors.white),
        ),
        title: Text(
          asset.name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          asset.description.isNotEmpty 
              ? asset.description 
              : '${asset.totalGenerations} generations',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${asset.totalGenerations}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        onTap: () {
          setState(() {
            _selectedAsset = asset;
            _selectedAssetGenerations = asset.generations;
          });
        },
      ),
    );
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

  String _formatGenerationSubtitle(SfxGeneration generation) {
    final parts = <String>[];
    if (generation.duration != null) {
      parts.add('${generation.duration!.toStringAsFixed(1)}s');
    }
    parts.add(generation.status.name);
    parts.add(_formatDateTime(generation.createdAt));
    return parts.join(' • ');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _generateSfx() async {
    if (_promptController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a prompt');
      return;
    }

    if (_selectedAsset == null) {
      _showErrorDialog('Please select an asset');
      return;
    }

    try {
      final request = SfxGenerationRequest(
        prompt: _promptController.text.trim(),
        negativePrompt: _negativePromptController.text.trim().isNotEmpty
            ? _negativePromptController.text.trim()
            : null,
        durationSeconds: double.tryParse(_durationController.text) ?? 2.0,
        promptInfluence: _promptInfluence,
      );

      await sfxGenerationProvider.generateSfx(
        request,
        projectId: widget.projectId,
        assetId: _selectedAsset!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SFX generation started successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the selected asset generations
        await _refreshSelectedAssetGenerations();
      }
    } catch (e) {
      _showErrorDialog('Failed to generate SFX: ${e.toString()}');
    }
  }

  void _showGenerationDetails(SfxGeneration generation) {
    showDialog(
      context: context,
      builder: (context) => AudioDetailDialog(
        generation: generation,
        asset: _selectedAsset,
        onFavoriteToggle: () async {
          try {
            await sfxGenerationProvider.setFavoriteSfxGeneration(
              generation.assetId,
              generation.id,
            );
            Navigator.of(context).pop();
            await _refreshSelectedAssetGenerations();
          } catch (e) {
            _showErrorDialog('Failed to toggle favorite: ${e.toString()}');
          }
        },
      ),
    );
  }

  void _showCreateAssetDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Create New SFX Asset', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Asset Name',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g., Laser Sounds',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF404040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Describe this asset...',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF404040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  final asset = await sfxGenerationProvider.createAsset(
                    widget.projectId,
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                  );
                  
                  Navigator.of(context).pop();
                  
                  setState(() {
                    _availableAssets = sfxGenerationProvider.assets;
                    _selectedAsset = asset;
                    _selectedAssetGenerations = asset.generations;
                  });
                } catch (e) {
                  _showErrorDialog('Failed to create asset: ${e.toString()}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
} 