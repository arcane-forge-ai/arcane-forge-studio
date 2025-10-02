import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/music_generation_provider.dart';
import '../../models/music_generation_models.dart';
import '../../models/sfx_generation_models.dart'; // For GenerationStatus
import '../../responsive.dart';
import 'widgets/music_detail_dialog.dart';
import '../../controllers/menu_app_controller.dart';

class MusicGenerationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const MusicGenerationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<MusicGenerationScreen> createState() => _MusicGenerationScreenState();
}

class _MusicGenerationScreenState extends State<MusicGenerationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '30');
  final TextEditingController _batchCountController =
      TextEditingController(text: '1');

  // Asset selection state
  MusicAsset? _selectedAsset;
  List<MusicAsset> _availableAssets = [];
  List<MusicGeneration> _selectedAssetGenerations = [];
  bool _loadingGenerations = false;

  // Batch generation state
  int _currentBatchIndex = 0;
  int _totalBatchCount = 0;
  bool _isBatchGenerating = false;

  // Providers
  late MusicGenerationProvider musicGenerationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  void _initializeProvider() {
    // Get the provider from context
    musicGenerationProvider =
        Provider.of<MusicGenerationProvider>(context, listen: false);

    // Load initial data
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (!mounted) return;

    await musicGenerationProvider.refreshAssets(projectId: widget.projectId);
    if (mounted) {
      setState(() {
        _availableAssets = musicGenerationProvider.assets;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _durationController.dispose();
    _batchCountController.dispose();
    super.dispose();
  }

  /// Refresh generations for the currently selected asset
  Future<void> _refreshSelectedAssetGenerations() async {
    if (_selectedAsset == null || !mounted) return;

    setState(() {
      _loadingGenerations = true;
    });

    try {
      final updatedAsset =
          await musicGenerationProvider.getAsset(_selectedAsset!.id);
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
    return Consumer<MusicGenerationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Column(
            children: [
              _buildHeader(context, provider),
              Expanded(
                child: _buildMainContent(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MusicGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.music_note,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Music Generation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.musicGenerationOverview);
            },
            child: const Text(
              'View All Assets',
              style: TextStyle(color: Color(0xFF0078D4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      BuildContext context, MusicGenerationProvider provider) {
    if (Responsive.isMobile(context)) {
      return _buildMobileLayout(provider);
    } else {
      return _buildDesktopLayout(provider);
    }
  }

  Widget _buildDesktopLayout(MusicGenerationProvider provider) {
    return Row(
      children: [
        // Left Panel: Generation Controls
        Expanded(
          flex: 3,
          child: _buildGenerationPanel(),
        ),
        Container(width: 1, color: const Color(0xFF404040)),

        // Right Panel: Recent Generations
        Expanded(
          flex: 4,
          child: _buildRecentGenerationsPanel(provider),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(MusicGenerationProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildGenerationPanel(),
          const Divider(color: Color(0xFF404040)),
          _buildRecentGenerationsPanel(provider),
        ],
      ),
    );
  }

  Widget _buildGenerationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generation Parameters Header
          const Text(
            'Generation Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
              icon: const Icon(Icons.add, color: Colors.purple),
              label:
                  const Text('New Asset', style: TextStyle(color: Colors.purple)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MusicAsset>(
              value: _selectedAsset,
              hint: const Text(
                'Choose an asset...',
                style: TextStyle(color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF2A2A2A),
              isExpanded: true,
              items: _availableAssets.map((asset) {
                return DropdownMenuItem<MusicAsset>(
                  value: asset,
                  child: Text(asset.name),
                );
              }).toList(),
              onChanged: (asset) async {
                setState(() {
                  _selectedAsset = asset;
                  if (asset != null) {
                    _selectedAssetGenerations = asset.generations;
                  }
                });
                
                // Refresh the selected asset to get latest generations
                if (asset != null) {
                  await _refreshSelectedAssetGenerations();
                }
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
          'Describe the music you want to generate',
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'e.g., Epic orchestral battle music with intense drums and brass',
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
                borderSide: const BorderSide(color: Colors.purple),
              ),
            ),
          ),
        ),

        // Duration
        _buildFormSection(
          'Duration (seconds)',
          'Target duration for the generated music (1 - 600 seconds / 10 minutes)',
          TextField(
            controller: _durationController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              hintText: '30',
              hintStyle: const TextStyle(color: Colors.white38),
              suffixText: 'seconds',
              suffixStyle: const TextStyle(color: Colors.white54),
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
                borderSide: const BorderSide(color: Colors.purple),
              ),
            ),
          ),
        ),

        // Batch Count
        _buildFormSection(
          'Batch Generation',
          'Number of music files to generate (1-5)',
          TextField(
            controller: _batchCountController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '1',
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
                borderSide: const BorderSide(color: Colors.purple),
              ),
            ),
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
    final canGenerate = _selectedAsset != null && 
        _promptController.text.trim().isNotEmpty && 
        !_isBatchGenerating;

    final batchCount = int.tryParse(_batchCountController.text) ?? 1;
    
    String buttonText;
    if (_isBatchGenerating && _totalBatchCount > 1) {
      buttonText = 'Generating ${_currentBatchIndex + 1}/$_totalBatchCount...';
    } else if (_isBatchGenerating) {
      buttonText = 'Generating...';
    } else if (batchCount > 1) {
      buttonText = 'Generate $batchCount Music Tracks';
    } else {
      buttonText = 'Generate Music';
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? () => _generateMusic() : null,
        icon: _isBatchGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.music_note),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: canGenerate ? Colors.purple : Colors.grey[800],
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

  Widget _buildRecentGenerationsPanel(MusicGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Generations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.musicGenerationOverview);
                },
                child: const Text(
                  'View All Assets',
                  style: TextStyle(color: Color(0xFF0078D4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildGenerationsList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationsList(MusicGenerationProvider provider) {
    // Show loading indicator if fetching generations
    if (_loadingGenerations) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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

    // Use selected asset generations if an asset is selected, otherwise show all
    final displayGenerations = _selectedAsset != null
        ? _selectedAssetGenerations
        : provider.getAllGenerations();

    // Sort by creation date, most recent first (if not already sorted)
    final sortedGenerations = [...displayGenerations];
    sortedGenerations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (sortedGenerations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_note,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedAsset != null
                  ? 'No music generated for "${_selectedAsset!.name}"'
                  : 'No music generated yet',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedAsset != null
                  ? 'Generate your first music for this asset'
                  : 'Select an asset and generate your first music',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
        final asset = _selectedAsset ??
            provider.assets.firstWhere((a) => a.id == generation.assetId,
                orElse: () => MusicAsset(
                    id: generation.assetId,
                    projectId: '',
                    name: 'Unknown Asset',
                    description: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    generations: []));
        return _buildGenerationTile(generation, asset, provider);
      },
    );
  }

  Widget _buildGenerationTile(MusicGeneration generation, MusicAsset? asset,
      MusicGenerationProvider provider) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGenerationDetails(generation, asset, provider),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildMusicStatusIcon(generation.status),
                  const SizedBox(width: 12),
                  // Show asset info and music visualization
                  if (asset != null)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF404040)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.withOpacity(0.6),
                            Colors.pink.withOpacity(0.4),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (generation.duration != null)
                              Text(
                                _formatDuration(generation.duration!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                          ],
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
                                style: const TextStyle(
                                  color: Colors.white,
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
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicStatusIcon(GenerationStatus status) {
    switch (status) {
      case GenerationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case GenerationStatus.generating:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        );
      case GenerationStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 24);
      case GenerationStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
    }
  }

  String _formatGenerationInfo(MusicGeneration generation) {
    final parts = <String>[];
    if (generation.duration != null) {
      parts.add(_formatDuration(generation.duration!));
    }
    parts.add(generation.status.name);
    parts.add(_formatDateTime(generation.createdAt));
    return parts.join(' • ');
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _generateMusic() async {
    if (_promptController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a prompt');
      return;
    }

    if (_selectedAsset == null) {
      _showErrorDialog('Please select an asset');
      return;
    }

    // Validate duration
    final durationSeconds = int.tryParse(_durationController.text) ?? 30;
    if (durationSeconds < 1 || durationSeconds > 600) {
      _showErrorDialog('Duration must be between 1 and 600 seconds');
      return;
    }

    // Validate batch count
    final batchCount = int.tryParse(_batchCountController.text) ?? 1;
    if (batchCount < 1 || batchCount > 5) {
      _showErrorDialog('Batch count must be between 1 and 5');
      return;
    }

    try {
      // Set batch generation state
      setState(() {
        _isBatchGenerating = true;
        _totalBatchCount = batchCount;
        _currentBatchIndex = 0;
      });

      // Generate music files sequentially
      for (int i = 0; i < batchCount; i++) {
        // Update current batch index
        if (mounted) {
          setState(() {
            _currentBatchIndex = i;
          });
        }

        final request = MusicGenerationRequest(
          prompt: _promptController.text.trim(),
          musicLengthMs: durationSeconds * 1000, // Convert to milliseconds
        );

        // Generate one music track at a time and wait for completion
        await musicGenerationProvider.generateMusic(
          request,
          projectId: widget.projectId,
          assetId: _selectedAsset!.id,
        );

        // Small delay between generations to ensure different timestamps
        if (i < batchCount - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Reset batch generation state
      if (mounted) {
        setState(() {
          _isBatchGenerating = false;
          _totalBatchCount = 0;
          _currentBatchIndex = 0;
        });
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(batchCount > 1 
                ? 'Generated $batchCount music tracks successfully!'
                : 'Music generation started successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the selected asset generations
        await _refreshSelectedAssetGenerations();
      }
    } catch (e) {
      // Reset batch generation state on error
      if (mounted) {
        setState(() {
          _isBatchGenerating = false;
          _totalBatchCount = 0;
          _currentBatchIndex = 0;
        });
      }
      _showErrorDialog('Failed to generate music: ${e.toString()}');
    }
  }

  void _showCreateAssetDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Create New Music Asset',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Asset Name',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g., Battle Theme',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF404040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
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
                hintText: 'Describe this music...',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF404040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  final asset = await musicGenerationProvider.createAsset(
                    widget.projectId,
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                  );

                  Navigator.of(context).pop();

                  setState(() {
                    _availableAssets = musicGenerationProvider.assets;
                    _selectedAsset = asset;
                    _selectedAssetGenerations = asset.generations;
                  });
                } catch (e) {
                  _showErrorDialog('Failed to create asset: ${e.toString()}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
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
            child: const Text('OK', style: TextStyle(color: Colors.purple)),
          ),
        ],
      ),
    );
  }

  void _showGenerationDetails(MusicGeneration generation, MusicAsset? asset,
      MusicGenerationProvider provider) async {
    await showDialog(
      context: context,
      builder: (context) => MusicDetailDialog(
        generation: generation,
        asset: asset,
        onFavoriteToggle: () async {
          await provider.setFavoriteMusicGeneration(
            generation.assetId,
            generation.id,
          );
          // Refresh the selected asset generations to update UI
          await _refreshSelectedAssetGenerations();
        },
      ),
    );

    // Refresh the selected asset generations after dialog closes
    await _refreshSelectedAssetGenerations();
  }
}

