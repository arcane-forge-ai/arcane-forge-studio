import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sfx_generation_provider.dart';
import '../../models/sfx_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
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
  final TextEditingController _negativePromptController =
      TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '2.0');
  final TextEditingController _batchCountController =
      TextEditingController(text: '1');

  double _promptInfluence = 0.5;

  // Asset selection state
  SfxAsset? _selectedAsset;
  List<SfxAsset> _availableAssets = [];
  List<SfxGeneration> _selectedAssetGenerations = [];
  bool _loadingGenerations = false;

  // Batch generation state
  int _currentBatchIndex = 0;
  int _totalBatchCount = 0;
  bool _isBatchGenerating = false;
  bool _isPromptGenerating = false;

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
    sfxGenerationProvider =
        Provider.of<SfxGenerationProvider>(context, listen: false);

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
          await sfxGenerationProvider.getAsset(_selectedAsset!.id);
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

  Widget _buildHeader(BuildContext context, SfxGenerationProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.audiotrack,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'SFX Generation',
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
                  .changeScreen(ScreenType.sfxGenerationOverview);
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
      BuildContext context, SfxGenerationProvider provider) {
    if (Responsive.isMobile(context)) {
      return _buildMobileLayout(provider);
    } else {
      return _buildDesktopLayout(provider);
    }
  }

  Widget _buildDesktopLayout(SfxGenerationProvider provider) {
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

  Widget _buildMobileLayout(SfxGenerationProvider provider) {
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
              icon: const Icon(Icons.add, color: Colors.blue),
              label:
                  const Text('New Asset', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
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
            ),
            if (_selectedAsset != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showAssetMetadataDialog(_selectedAsset!),
                icon: const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                tooltip: 'View Asset Metadata',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF404040)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGenerationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _isPromptGenerating ? null : _generateAutoPrompt,
            icon: _isPromptGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.bolt, color: Colors.white),
            label: Text(
              _isPromptGenerating ? 'Generating prompt...' : 'Generate Prompt with AI',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Prompt
        _buildFormSection(
          'Prompt',
          'Describe the sound you want to generate',
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g., Laser shooting sound, slowly fading away as the laser travels',
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

        // Batch Count
        _buildFormSection(
          'Batch Generation',
          'Number of audio files to generate (1-10)',
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
                borderSide: const BorderSide(color: Colors.blue),
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
      buttonText = 'Generate $batchCount SFX';
    } else {
      buttonText = 'Generate SFX';
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? () => _generateSfx() : null,
        icon: _isBatchGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.audiotrack),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: canGenerate ? Colors.blue : Colors.grey[800],
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

  Widget _buildRecentGenerationsPanel(SfxGenerationProvider provider) {
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
                      .changeScreen(ScreenType.sfxGenerationOverview);
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

  Widget _buildGenerationsList(SfxGenerationProvider provider) {
    // Show loading indicator if fetching generations
    if (_loadingGenerations) {
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
              Icons.audiotrack,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedAsset != null
                  ? 'No audio generated for "${_selectedAsset!.name}"'
                  : 'No audio generated yet',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedAsset != null
                  ? 'Generate your first audio for this asset'
                  : 'Select an asset and generate your first audio',
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
                orElse: () => SfxAsset(
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

  Widget _buildGenerationTile(SfxGeneration generation, SfxAsset? asset,
      SfxGenerationProvider provider) {
    return InkWell(
      onTap: () async {
        // Get fresh asset data for the dialog
        final freshAsset = asset ?? await provider.getAsset(generation.assetId);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AudioDetailDialog(
              generation: generation,
              asset: freshAsset,
              onFavoriteToggle: freshAsset != null
                  ? () => provider.setFavoriteSfxGeneration(
                      freshAsset.id, generation.id)
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
                  _buildAudioStatusIcon(generation.status),
                  const SizedBox(width: 12),
                  // Show asset info and audio visualization
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
                            Colors.blue.withOpacity(0.6),
                            Colors.orange.withOpacity(0.4),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.audiotrack,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (generation.duration != null)
                              Text(
                                '${generation.duration!.toStringAsFixed(1)}s',
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioStatusIcon(GenerationStatus status) {
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

  String _formatGenerationInfo(SfxGeneration generation) {
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

    // Validate batch count
    final batchCount = int.tryParse(_batchCountController.text) ?? 1;
    if (batchCount < 1 || batchCount > 10) {
      _showErrorDialog('Batch count must be between 1 and 10');
      return;
    }

    try {
      // Set batch generation state
      setState(() {
        _isBatchGenerating = true;
        _totalBatchCount = batchCount;
        _currentBatchIndex = 0;
      });

      // Generate SFX files sequentially
      for (int i = 0; i < batchCount; i++) {
        // Update current batch index
        if (mounted) {
          setState(() {
            _currentBatchIndex = i;
          });
        }

        final request = SfxGenerationRequest(
          prompt: _promptController.text.trim(),
          negativePrompt: _negativePromptController.text.trim().isNotEmpty
              ? _negativePromptController.text.trim()
              : null,
          durationSeconds: double.tryParse(_durationController.text) ?? 2.0,
          promptInfluence: _promptInfluence,
        );

        // Generate one SFX at a time and wait for completion
        await sfxGenerationProvider.generateSfx(
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
                ? 'Generated $batchCount SFX files successfully!'
                : 'SFX generation started successfully!'),
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
      _showErrorDialog('Failed to generate SFX: ${e.toString()}');
    }
  }

  Future<void> _generateAutoPrompt() async {
    if (_selectedAsset == null) {
      _showErrorDialog('Please select an asset before generating a prompt');
      return;
    }

    setState(() {
      _isPromptGenerating = true;
    });

    try {
      final assetInfo = {
        'id': _selectedAsset!.id,
        'name': _selectedAsset!.name,
        'description': _selectedAsset!.description,
      };

      final duration = double.tryParse(_durationController.text) ?? 2.0;
      final generatorInfo = {
        'name': 'elevenlabs',
        'duration_seconds': duration,
        'prompt_influence': _promptInfluence,
        'negative_prompt': _negativePromptController.text.trim().isEmpty ? null : _negativePromptController.text.trim(),
      };

      final prompt = await sfxGenerationProvider.generateAutoPrompt(
        projectId: widget.projectId,
        assetInfo: assetInfo,
        generatorInfo: generatorInfo,
      );

      if (mounted) {
        setState(() {
          _promptController.text = prompt;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt generated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to generate prompt: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPromptGenerating = false;
        });
      }
    }
  }

  void _showAssetMetadataDialog(SfxAsset asset) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Asset Metadata',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection('Basic Information', [
                        _buildMetadataRow('Name', asset.name),
                        _buildMetadataRow('Description', asset.description.isEmpty ? 'No description' : asset.description),
                        _buildMetadataRow('Asset ID', asset.id),
                        _buildMetadataRow('Project ID', asset.projectId),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      _buildMetadataSection('Statistics', [
                        _buildMetadataRow('Total Generations', asset.totalGenerations.toString()),
                        _buildMetadataRow('Active Generations', asset.generations.length.toString()),
                        if (asset.favoriteGenerationId != null)
                          _buildMetadataRow('Favorite Generation ID', asset.favoriteGenerationId!),
                        if (asset.fileSize != null)
                          _buildMetadataRow('File Size', '${(asset.fileSize! / 1024).toStringAsFixed(2)} KB'),
                      ]),
                      
                      const SizedBox(height: 20),
                      
                      _buildMetadataSection('Timestamps', [
                        _buildMetadataRow('Created At', _formatDetailedDateTime(asset.createdAt)),
                        _buildMetadataRow('Updated At', _formatDetailedDateTime(asset.updatedAt)),
                      ]),
                      
                      if (asset.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildMetadataSection('Tags', [
                          _buildMetadataRow('Tags', asset.tags.join(', ')),
                        ]),
                      ],
                      
                      if (asset.metadata.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildMetadataSection('Custom Metadata', 
                          asset.metadata.entries.map((entry) => 
                            _buildMetadataRow(entry.key, entry.value.toString())
                          ).toList()
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

  Widget _buildMetadataSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: Column(
            children: rows,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value, label),
            icon: const Icon(Icons.copy, color: Colors.blue, size: 16),
            tooltip: 'Copy $label',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDetailedDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _showCreateAssetDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Create New SFX Asset',
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
