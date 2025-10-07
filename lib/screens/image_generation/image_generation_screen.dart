import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../models/image_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import '../../services/comfyui_service.dart';
import 'dart:io';

import 'widgets/image_detail_dialog.dart';

class ImageGenerationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ImageGenerationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ImageGenerationScreen> createState() => _ImageGenerationScreenState();
}

class _ImageGenerationScreenState extends State<ImageGenerationScreen> {
  final TextEditingController _positivePromptController =
      TextEditingController();
  final TextEditingController _negativePromptController =
      TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _stepsController =
      TextEditingController(text: '20');
  final TextEditingController _cfgController =
      TextEditingController(text: '7.5');
  final TextEditingController _widthController =
      TextEditingController(text: '512');
  final TextEditingController _heightController =
      TextEditingController(text: '512');
  final TextEditingController _batchCountController =
      TextEditingController(text: '1');

  String _selectedSampler = 'Euler a';
  String _selectedScheduler = "Automatic";
  String _selectedModelFallbackValue = 'No models found';
  String _selectedModel = 'No models found';

  // Asset selection state
  ImageAsset? _selectedAsset;
  List<ImageAsset> _availableAssets = [];
  List<ImageGeneration> _selectedAssetGenerations = [];
  bool _loadingGenerations = false;

  // Seed lock state
  bool _isSeedLocked = false;

  // Batch generation state
  int _currentBatchIndex = 0;
  int _totalBatchCount = 0;
  bool _isBatchGenerating = false;

  // Providers
  late ImageGenerationProvider imageGenerationProvider;

  /// Refresh generations for the currently selected asset
  Future<void> _refreshSelectedAssetGenerations() async {
    if (_selectedAsset == null) return;
    
    setState(() {
      _loadingGenerations = true;
    });
    
    try {
      final generations = await imageGenerationProvider.getAssetGenerations(_selectedAsset!.id);
      if (mounted) {
        setState(() {
          _selectedAssetGenerations = generations;
          _loadingGenerations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAssetGenerations = [];
          _loadingGenerations = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();

    // Check if AI service is already running when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      imageGenerationProvider =
          Provider.of<ImageGenerationProvider>(context, listen: false);
      _initializeProviders(imageGenerationProvider);
    });
  }

  void _initializeProviders(
      ImageGenerationProvider imageGenerationProvider) async {
    // Initialize project context
    await imageGenerationProvider.setCurrentProject(widget.projectId);

    // Load available assets
    _refreshAssets(imageGenerationProvider);

    // Check service health
    try {
      if (imageGenerationProvider.isServiceRunning && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI service is already running and healthy!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Silently ignore errors during initial health check
    }

    // Refresh model list on load
    imageGenerationProvider.refreshAvailableModels().then((_) {
      if (mounted && imageGenerationProvider.availableModels.isNotEmpty) {
        setState(() {
          _selectedModel = imageGenerationProvider.availableModels.first;
        });
      }
    });
    imageGenerationProvider.refreshAvailableLoras().then((_) {
      if (mounted && imageGenerationProvider.availableLoras.isEmpty) {
        setState(() {});
      }
    });
    
    // Refresh A1111 models and current checkpoint if service is running
    if (imageGenerationProvider.isServiceRunning && 
        imageGenerationProvider.currentBackendName == 'Automatic1111') {
      imageGenerationProvider.refreshA1111Models().then((_) {
        if (mounted && imageGenerationProvider.a1111Checkpoints.isNotEmpty) {
          setState(() {
            // Set first checkpoint as selected if none is selected
            if (_selectedModel == _selectedModelFallbackValue) {
              _selectedModel = imageGenerationProvider.a1111Checkpoints.first.title;
            }
          });
        }
      });
    }
  }

  void _refreshAssets(ImageGenerationProvider provider) async {
    try {
      await provider.refreshAssets();
      if (mounted) {
        setState(() {
          _availableAssets = provider.assets;
        });
      }
    } catch (e) {
      print('Error refreshing assets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageGenerationProvider>(
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

  Widget _buildHeader(BuildContext context, ImageGenerationProvider provider) {
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
          Icon(
            Icons.auto_awesome,
            color: Theme.of(context).colorScheme.onSurface,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'AI Image Generation',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildAIServiceStatusIndicator(provider),
          const SizedBox(width: 16),
          _buildAIServiceControls(provider),
        ],
      ),
    );
  }

  Widget _buildAIServiceStatusIndicator(ImageGenerationProvider provider) {
    final status = provider.serviceStatus;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case AIServiceStatus.running:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Running';
        break;
      case AIServiceStatus.starting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Starting...';
        break;
      case AIServiceStatus.stopping:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Stopping...';
        break;
      case AIServiceStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Error';
        break;
      case AIServiceStatus.stopped:
        statusColor = Colors.red;
        statusIcon = Icons.stop_circle;
        statusText = 'Stopped';
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${provider.currentBackendName}: $statusText',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
            ),
            // Show current checkpoint for A1111 when running
            if (status == AIServiceStatus.running && 
                provider.currentBackendName == 'Automatic1111' && 
                provider.currentA1111Checkpoint != null)
              Text(
                'Checkpoint: ${_getCheckpointDisplayName(provider.currentA1111Checkpoint!)}',
                style: TextStyle(
                  color: statusColor.withOpacity(0.8), 
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Extract display name from checkpoint title (remove hash if present)
  String _getCheckpointDisplayName(String checkpointTitle) {
    // Remove hash from title like "model.safetensors [abc123]" -> "model.safetensors"
    final hashMatch = RegExp(r'\s*\[[a-fA-F0-9]+\]$').firstMatch(checkpointTitle);
    if (hashMatch != null) {
      return checkpointTitle.substring(0, hashMatch.start);
    }
    return checkpointTitle;
  }

  Widget _buildAIServiceControls(ImageGenerationProvider provider) {
    return Row(
      children: [
        if (!provider.isServiceRunning)
          ElevatedButton.icon(
            onPressed: provider.isServiceStarting
                ? null
                : () => provider.startService(),
            icon: provider.isServiceStarting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(
              provider.isServiceStarting ? 'Starting...' : 'Start AI Service',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        if (provider.isServiceRunning)
          ElevatedButton.icon(
            onPressed: provider.isServiceStopping
                ? null
                : () => provider.stopService(),
            icon: provider.isServiceStopping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.stop, color: Colors.white),
            label: Text(
              provider.isServiceStopping ? 'Stopping...' : 'Stop AI Service',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showServiceLogs(provider),
          icon: const Icon(Icons.article, color: Colors.white54),
          tooltip: 'Show Service Logs',
        ),
      ],
    );
  }

  Widget _buildMainContent(
      BuildContext context, ImageGenerationProvider provider) {
    if (Responsive.isMobile(context)) {
      return _buildMobileLayout(provider);
    } else {
      return _buildDesktopLayout(provider);
    }
  }

  Widget _buildDesktopLayout(ImageGenerationProvider provider) {
    return Row(
      children: [
        // Left Panel: Parameters
        Expanded(
          flex: 3,
          child: _buildParametersPanel(provider),
        ),
        Container(width: 1, color: const Color(0xFF404040)),

        // Middle Panel: Prompts
        Expanded(
          flex: 4,
          child: _buildPromptsPanel(provider),
        ),
        Container(width: 1, color: const Color(0xFF404040)),

        // Right Panel: Recent Images
        Expanded(
          flex: 4,
          child: _buildRecentImagesPanel(provider),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ImageGenerationProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildParametersPanel(provider),
          const Divider(color: Color(0xFF404040)),
          _buildPromptsPanel(provider),
          const Divider(color: Color(0xFF404040)),
          _buildRecentImagesPanel(provider),
        ],
      ),
    );
  }

  Widget _buildParametersPanel(ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generation Parameters',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Asset Selection
          _buildAssetSelection(),
          const SizedBox(height: 20),

          // Model Selection
          _buildModelSelection(),
          const SizedBox(height: 20),

          // Dimensions
          _buildDimensionsSection(),
          const SizedBox(height: 20),

          // Sampler
          _buildQualitySection(),
          const SizedBox(height: 20),

          // Seed
          _buildSeedSection(),
          const SizedBox(height: 20),

          // Batch Count
          _buildBatchSection(),
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
              onPressed: _showCreateAssetDialog,
              icon: const Icon(Icons.add, color: Colors.blue, size: 16),
              label: const Text(
                'New Asset',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
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
              color: _selectedAsset == null
                  ? Colors.red.withOpacity(0.5)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF404040)
                      : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ImageAsset?>(
              value: _selectedAsset,
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
                ..._availableAssets.map((asset) {
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
                              onChanged: (ImageAsset? value) async {
                  setState(() {
                    _selectedAsset = value;
                  });
                  
                  // Refresh generations for the newly selected asset
                  await _refreshSelectedAssetGenerations();
                },
            ),
          ),
        ),
        if (_selectedAsset != null) ...[
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
                        _selectedAsset!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedAsset!.description.isNotEmpty)
                        Text(
                          _selectedAsset!.description,
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
                  '${_selectedAsset!.generations.length} images',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_selectedAsset == null) ...[
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

  Widget _buildModelSelection() {
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        // Use A1111 checkpoints if available and server is reachable
        List<String> models;
        bool useA1111Models = provider.currentBackendName == 'Automatic1111' && 
                              provider.isA1111ServerReachable && 
                              provider.a1111Checkpoints.isNotEmpty;
        
        if (useA1111Models) {
          models = provider.a1111Checkpoints.map((c) => c.title).toList();
          // Set first checkpoint as selected if none is selected or fallback
          if (_selectedModel == _selectedModelFallbackValue || 
              !models.contains(_selectedModel)) {
            _selectedModel = models.first;
          }
        } else {
          models = provider.availableModels;
          if (models.isNotEmpty && _selectedModel == _selectedModelFallbackValue) {
            _selectedModel = models.first;
          }
        }

        // LoRA handling - use A1111 LoRAs if available
        List<String> loras;
        String loraDropdownLabel;
        bool useA1111Loras = provider.currentBackendName == 'Automatic1111' && 
                             provider.isA1111ServerReachable && 
                             provider.a1111Loras.isNotEmpty;
        
        if (useA1111Loras) {
          loras = provider.a1111Loras.map((l) => l.name).toList();
          loraDropdownLabel = 'Click on a LoRA to add to prompt';
        } else {
          loras = provider.availableLoras;
          loraDropdownLabel = loras.isEmpty ? 'No LoRAs found' : 'Click on a LoRA to add to prompt';
        }

        return Column(
          children: [
            // Checkpoint selection with refresh button
            Row(
              children: [
                Expanded(
                  child: _buildDropdownWithLabel(
                    "Model",
                    _selectedModel,
                    models.isNotEmpty ? models : [_selectedModel],
                    (value) {
                      if (value != null && value != _selectedModel) {
                        setState(() {
                          _selectedModel = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh button for models
                IconButton(
                  onPressed: provider.isLoadingA1111Models ? null : () async {
                    if (provider.currentBackendName == 'Automatic1111') {
                      await provider.refreshA1111Models();
                    } else {
                      await provider.refreshAvailableModels();
                    }
                  },
                  icon: provider.isLoadingA1111Models
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white54),
                  tooltip: 'Refresh Models',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // LoRA selection with refresh button
            Row(
              children: [
                Expanded(
                  child: _buildDropdownWithLabel(
                    "LoRA",
                    loraDropdownLabel,
                    [loraDropdownLabel] + loras,
                    ((value) {
                      // Add to positive prompt
                      if (value != null && value != loraDropdownLabel && value.isNotEmpty) {
                        final loraTag = '<lora:$value:1>';
                        final currentText = _positivePromptController.text;
                        if (!currentText.contains(loraTag)) {
                          String separator = '';
                          if (currentText.isNotEmpty) {
                            if (!currentText.trim().endsWith(',')) {
                              separator = ', ';
                            } else {
                              separator = ' ';
                            }
                          }
                          setState(() {
                            _positivePromptController.text =
                                currentText + separator + loraTag;
                          });
                        }
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh button for LoRAs
                IconButton(
                  onPressed: provider.isLoadingA1111Models ? null : () async {
                    if (provider.currentBackendName == 'Automatic1111') {
                      await provider.refreshA1111Models();
                    } else {
                      await provider.refreshAvailableLoras();
                    }
                  },
                  icon: provider.isLoadingA1111Models
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white54),
                  tooltip: 'Refresh LoRAs',
                ),
              ],
            ),
            // Show server status warning if A1111 server is not reachable
            if (provider.currentBackendName == 'Automatic1111' && !provider.isA1111ServerReachable)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A1111 server not reachable. Using local model list.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDimensionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dimensions',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberField('Width', _widthController),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberField('Height', _heightController),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdownWithLabel(
                "Sampler",
                _selectedSampler,
                [
                  'Euler a',
                  'Euler',
                  'heun',
                  'dpm_2',
                  'dpm_2_a',
                  'lms',
                  'ddim',
                  'plms',
                ],
                (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSampler = value;
                    });
                  }
                },
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildDropdownWithLabel(
                "Scheduler",
                _selectedScheduler,
                [
                  'Automatic',
                  'euler_a',
                  'heun',
                  'dpm_2',
                  'dpm_2_a',
                  'lms',
                  'ddim',
                  'plms',
                ],
                (value) {
                  if (value != null) {
                    setState(() {
                      _selectedScheduler = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildNumberField('Steps', _stepsController)),
            SizedBox(width: 8),
            Expanded(child: _buildNumberField('CFG Scale', _cfgController)),
          ],
        )
      ],
    );
  }

  Widget _buildSeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seed',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _seedController.text =
                      DateTime.now().millisecondsSinceEpoch.toString();
                });
              },
              child: const Text(
                'Random',
                style: TextStyle(color: Color(0xFF0078D4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Seed'),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _seedController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Seed',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0078D4)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                setState(() {
                  _isSeedLocked = !_isSeedLocked;
                });
              },
              icon: Icon(
                _isSeedLocked ? Icons.lock : Icons.lock_open,
                color: _isSeedLocked ? Colors.amber : Colors.white54,
              ),
              tooltip: _isSeedLocked ? 'Unlock seed (auto-randomize)' : 'Lock seed (keep current)',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Batch Generation',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Count'),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _batchCountController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Number of images to generate',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0078D4)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Each image will use a different random seed',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWithItems(
      String label, String value, List<String> items, ValueChanged onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
      underline: Container(),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      items: items
          .map((sampler) => DropdownMenuItem<String>(
                value: sampler,
                child: Text(sampler),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownWithLabel(
      String label, String value, List<String> items, ValueChanged onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          label,
          // style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF404040)
                    : Colors.grey.shade400,
              ),
            ),
            child: _buildDropdownWithItems(label, value, items, onChanged),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Row(
      children: [
        Text(label),
        SizedBox(width: 12),
        Expanded(
            child: TextField(
                controller: controller,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0078D4)),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildPromptsPanel(ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prompts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Positive Prompt
          _buildPromptField(
            'Positive Prompt',
            _positivePromptController,
            'Describe what you want to see in the image...',
          ),
          const SizedBox(height: 20),

          // Negative Prompt
          _buildPromptField(
            'Negative Prompt',
            _negativePromptController,
            'Describe what you don\'t want to see in the image...',
          ),
          const SizedBox(height: 30),

          // Generate Button
          _buildGenerateButton(provider),
        ],
      ),
    );
  }

  Widget _buildPromptField(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A3A3A)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF404040)
                    : Colors.grey.shade400,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF404040)
                    : Colors.grey.shade400,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0078D4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(ImageGenerationProvider provider) {
    final canGenerate = provider.isServiceRunning &&
        !provider.isGenerating &&
        !_isBatchGenerating &&
        _positivePromptController.text.trim().isNotEmpty;

    final batchCount = int.tryParse(_batchCountController.text) ?? 1;
    
    String buttonText;
    if (_isBatchGenerating && _totalBatchCount > 1) {
      buttonText = 'Generating ${_currentBatchIndex + 1}/$_totalBatchCount...';
    } else if (provider.isGenerating || _isBatchGenerating) {
      buttonText = 'Generating...';
    } else if (batchCount > 1) {
      buttonText = 'Generate $batchCount Images';
    } else {
      buttonText = 'Generate Image';
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? () => _generateImage(provider) : null,
        icon: (provider.isGenerating || _isBatchGenerating)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canGenerate ? const Color(0xFF0078D4) : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentImagesPanel(ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Generations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
          const SizedBox(height: 20),
          Expanded(
            child: _buildGenerationsList(provider),
          ),
        ],
      ),
    );
  }

    Widget _buildGenerationsList(ImageGenerationProvider provider) {
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
        : provider.allGenerations;
    
    // Sort by creation date, most recent first (if not already sorted)
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
            _selectedAsset != null 
                ? 'No images generated for "${_selectedAsset!.name}"'
                : 'No images generated yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedAsset != null
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
        final asset = _selectedAsset ?? provider.getAssetFromCache(generation.assetId);
        return _buildGenerationTile(generation, asset, provider);
      },
    );
  }

  Widget _buildGenerationTile(ImageGeneration generation, ImageAsset? asset,
      ImageGenerationProvider provider) {
    return InkWell(
      onTap: () async {
        // Get fresh asset data for the dialog
        final freshAsset = await provider.getAsset(generation.assetId);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => ImageDetailDialog(
              generation: generation,
              asset: freshAsset,
              onFavoriteToggle: freshAsset != null
                  ? () => provider.setFavoriteGeneration(
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
                  _buildImageStatusIcon(generation.status),
                  const SizedBox(width: 12),
                  // Show asset info and thumbnail
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
                        child:
                            generation.status == GenerationStatus.completed
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
                              child:                         Text(
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
    // Prefer online URL, fallback to local file
    final bool hasOnlineUrl = generation.imageUrl != null && generation.imageUrl!.isNotEmpty;
    final bool hasLocalFile = generation.imagePath.isNotEmpty;
    
    if (hasOnlineUrl) {
      return Image.network(
        generation.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local file if network fails
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

  void _generateImage(ImageGenerationProvider provider) async {
    if (_positivePromptController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a positive prompt');
      return;
    }

    // Check if asset is selected
    if (_selectedAsset == null) {
      _showErrorDialog('Please select an asset before generating images.');
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

      // Use project name and id from widget parameters
      final projectName = widget.projectName;
      final projectId = widget.projectId;

      // Generate base seed for batch generation
      int baseSeed;
      if (_isSeedLocked && _seedController.text.isNotEmpty) {
        baseSeed = int.tryParse(_seedController.text) ?? DateTime.now().millisecondsSinceEpoch;
      } else {
        baseSeed = DateTime.now().millisecondsSinceEpoch;
        // Update the seed field to show the base seed
        setState(() {
          _seedController.text = baseSeed.toString();
        });
      }

      // Generate images sequentially for A1111 single-threaded service
      for (int i = 0; i < batchCount; i++) {
        // Update current batch index
        if (mounted) {
          setState(() {
            _currentBatchIndex = i;
          });
        }
        // Use different seed for each generation (unless locked to a specific seed)
        int currentSeed;
        if (_isSeedLocked) {
          currentSeed = baseSeed;
        } else {
          // Generate a new random seed for each iteration
          currentSeed = DateTime.now().millisecondsSinceEpoch + i * 1000;
          // Update the seed field to show the current seed being used
          if (mounted) {
            setState(() {
              _seedController.text = currentSeed.toString();
            });
          }
        }
        
        final request = GenerationRequest(
          positivePrompt: _positivePromptController.text.trim(),
          negativePrompt: _negativePromptController.text.trim(),
          width: int.tryParse(_widthController.text) ?? 512,
          height: int.tryParse(_heightController.text) ?? 512,
          sampler: _selectedSampler,
          scheduler: _selectedScheduler,
          steps: int.tryParse(_stepsController.text) ?? 20,
          cfgScale: double.tryParse(_cfgController.text) ?? 7.5,
          seed: currentSeed,
          model: _selectedModel,
        );

        // Generate one image at a time and wait for completion
        await provider.generateImage(request,
            projectName: projectName,
            projectId: projectId,
            assetId: _selectedAsset!.id);
            
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
                ? 'Generated $batchCount images successfully!'
                : 'Image generation completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the recent images panel if this asset is selected
        if (_selectedAsset != null) {
          _refreshSelectedAssetGenerations();
        }
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
      _showErrorDialog('Failed to generate image(s): ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Error',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
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

  void _showCreateAssetDialog() {
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

                // Refresh assets and select the new one
                _refreshAssets(provider);
                setState(() {
                  _selectedAsset = newAsset;
                });

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

  void _showServiceLogs(ImageGenerationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<String>(
        stream: provider.serviceLogStream,
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
                  onPressed: () => _killDanglingService(provider),
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
                  onPressed: () => _copyLogsToClipboard(provider.serviceLogs),
                  child: const Text(
                    'Copy Logs',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 800, // Fixed width
              height: 600, // Increased height
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

  void _killDanglingService(ImageGenerationProvider provider) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Killing dangling processes...'),
          backgroundColor: Colors.orange,
        ),
      );

      final success = await provider.killDanglingService();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dangling processes killed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to kill some processes'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error killing dangling processes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyLogsToClipboard(List<String> logs) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No logs to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final logsText = logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy logs: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  @override
  void dispose() {
    _positivePromptController.dispose();
    _negativePromptController.dispose();
    _seedController.dispose();
    _stepsController.dispose();
    _cfgController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _batchCountController.dispose();
    super.dispose();
  }
}
