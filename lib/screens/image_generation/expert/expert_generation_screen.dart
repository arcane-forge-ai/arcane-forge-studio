import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../responsive.dart';
import '../../../utils/error_handler.dart';
import 'dart:async';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_constants.dart';

import '../widgets/header_widget.dart';
import '../widgets/parameters_panel_widget.dart';
import '../widgets/prompts_panel_widget.dart';
import '../widgets/recent_images_panel_widget.dart';
import '../widgets/chat_panel_widget.dart';
import '../utils/dialog_helpers.dart';

/// Expert Mode Image Generation Screen
/// Provides direct access to all generation parameters and models
/// For advanced users who want full control over the generation process
class ExpertGenerationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ExpertGenerationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ExpertGenerationScreen> createState() => _ExpertGenerationScreenState();
}

class _ExpertGenerationScreenState extends State<ExpertGenerationScreen> {
  final TextEditingController _positivePromptController = TextEditingController();
  final TextEditingController _negativePromptController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController(text: '20');
  final TextEditingController _cfgController = TextEditingController(text: '7.5');
  final TextEditingController _widthController = TextEditingController(text: '512');
  final TextEditingController _heightController = TextEditingController(text: '512');
  final TextEditingController _batchCountController = TextEditingController(text: '1');

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
  bool _isPromptGenerating = false;

  // Chat state
  bool _showChatPanel = false;
  final GlobalKey<ChatPanelWidgetState> _chatPanelKey = GlobalKey<ChatPanelWidgetState>();

  // Providers
  late ImageGenerationProvider imageGenerationProvider;

  Timer? _generationPollTimer;

  @override
  void initState() {
    super.initState();
    _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      imageGenerationProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
      _initializeProviders(imageGenerationProvider);
      _startGenerationPolling();
    });
  }

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

  bool _hasInFlightGenerations(ImageGenerationProvider provider) {
    List<ImageGeneration> generationsToCheck;
    if (_selectedAsset != null) {
      generationsToCheck = _selectedAssetGenerations.isNotEmpty
          ? _selectedAssetGenerations
          : (provider.getAssetFromCache(_selectedAsset!.id)?.generations ?? []);
    } else {
      generationsToCheck = provider.allGenerations;
    }

    return generationsToCheck.any((g) =>
        g.status == GenerationStatus.pending || g.status == GenerationStatus.generating);
  }

  void _startGenerationPolling() {
    _generationPollTimer?.cancel();
    _generationPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;

      final provider = Provider.of<ImageGenerationProvider>(context, listen: false);

      if (!_hasInFlightGenerations(provider)) return;

      try {
        if (_selectedAsset != null) {
          await _refreshSelectedAssetGenerations();
        } else {
          await provider.refreshAssets();
        }
      } catch (_) {
        // Ignore polling errors
      }
    });
  }

  void _initializeProviders(ImageGenerationProvider imageGenerationProvider) async {
    await imageGenerationProvider.setCurrentProject(widget.projectId);
    _refreshAssets(imageGenerationProvider);

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

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isOnlineMode = imageGenerationProvider.currentBackendName == 'Automatic1111' &&
        settingsProvider.a1111Mode == A1111Mode.online;

    if (isOnlineMode) {
      imageGenerationProvider.refreshA1111Models().then((_) {
        if (mounted && imageGenerationProvider.a1111Checkpoints.isNotEmpty) {
          setState(() {
            if (_selectedModel == _selectedModelFallbackValue) {
              _selectedModel = imageGenerationProvider.a1111Checkpoints.first.title;
            }
          });
        }
      });
    } else {
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

      if (imageGenerationProvider.isServiceRunning &&
          imageGenerationProvider.currentBackendName == 'Automatic1111') {
        imageGenerationProvider.refreshA1111Models().then((_) {
          if (mounted && imageGenerationProvider.a1111Checkpoints.isNotEmpty) {
            setState(() {
              if (_selectedModel == _selectedModelFallbackValue) {
                _selectedModel = imageGenerationProvider.a1111Checkpoints.first.title;
              }
            });
          }
        });
      }
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
              ImageGenerationHeaderWidget(
                onShowServiceLogs: () => _showServiceLogs(provider),
              ),
              Expanded(
                child: _buildMainContent(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, ImageGenerationProvider provider) {
    if (Responsive.isMobile(context)) {
      return _buildMobileLayout(provider);
    } else {
      return Column(
        children: [
          Expanded(
            child: _buildDesktopLayout(provider),
          ),
          if (_showChatPanel)
            ChatPanelWidget(
              key: _chatPanelKey,
              projectId: widget.projectId,
              projectName: widget.projectName,
              selectedAsset: _selectedAsset,
              selectedModel: _selectedModel,
              positivePromptController: _positivePromptController,
              negativePromptController: _negativePromptController,
              widthController: _widthController,
              heightController: _heightController,
              stepsController: _stepsController,
              cfgController: _cfgController,
              seedController: _seedController,
              batchCountController: _batchCountController,
              selectedSampler: _selectedSampler,
              selectedScheduler: _selectedScheduler,
              isSeedLocked: _isSeedLocked,
              onClose: () {
                setState(() {
                  _showChatPanel = false;
                });
              },
            ),
        ],
      );
    }
  }

  Widget _buildDesktopLayout(ImageGenerationProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: ParametersPanelWidget(
            selectedAsset: _selectedAsset,
            availableAssets: _availableAssets,
            selectedModel: _selectedModel,
            selectedModelFallbackValue: _selectedModelFallbackValue,
            selectedSampler: _selectedSampler,
            selectedScheduler: _selectedScheduler,
            isSeedLocked: _isSeedLocked,
            widthController: _widthController,
            heightController: _heightController,
            stepsController: _stepsController,
            cfgController: _cfgController,
            seedController: _seedController,
            batchCountController: _batchCountController,
            onAssetChanged: (asset) async {
              setState(() {
                _selectedAsset = asset;
              });
              await _refreshSelectedAssetGenerations();
            },
            onModelChanged: (model) {
              setState(() {
                _selectedModel = model;
              });
            },
            onSamplerChanged: (sampler) {
              setState(() {
                _selectedSampler = sampler;
              });
            },
            onSchedulerChanged: (scheduler) {
              setState(() {
                _selectedScheduler = scheduler;
              });
            },
            onSeedLockToggle: () {
              setState(() {
                _isSeedLocked = !_isSeedLocked;
              });
            },
            onRandomizeSeed: () {
              setState(() {
                _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();
              });
            },
            onCreateAsset: () {
              DialogHelpers.showCreateAssetDialog(context, (newAsset) {
                _refreshAssets(provider);
                setState(() {
                  _selectedAsset = newAsset;
                });
              });
            },
            onViewAssetMetadata: () {
              if (_selectedAsset != null) {
                DialogHelpers.showAssetMetadataDialog(context, _selectedAsset!);
              }
            },
            onAskForModelRecommendation: _askAIForModelRecommendation,
          ),
        ),
        Container(width: 1, color: const Color(0xFF404040)),
        Expanded(
          flex: 4,
          child: PromptsPanelWidget(
            positivePromptController: _positivePromptController,
            negativePromptController: _negativePromptController,
            isPromptGenerating: _isPromptGenerating,
            onGeneratePrompt: () => _generateAutoPrompt(provider),
            onGenerateImage: () => _generateImage(provider),
            onDiscussWithAI: _openChatPanel,
            canGenerate: _canGenerate(provider),
            generateButtonText: _getGenerateButtonText(provider),
          ),
        ),
        Container(width: 1, color: const Color(0xFF404040)),
        Expanded(
          flex: 4,
          child: RecentImagesPanelWidget(
            selectedAsset: _selectedAsset,
            selectedAssetGenerations: _selectedAssetGenerations,
            loadingGenerations: _loadingGenerations,
            onRefresh: _refreshSelectedAssetGenerations,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ImageGenerationProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ParametersPanelWidget(
            selectedAsset: _selectedAsset,
            availableAssets: _availableAssets,
            selectedModel: _selectedModel,
            selectedModelFallbackValue: _selectedModelFallbackValue,
            selectedSampler: _selectedSampler,
            selectedScheduler: _selectedScheduler,
            isSeedLocked: _isSeedLocked,
            widthController: _widthController,
            heightController: _heightController,
            stepsController: _stepsController,
            cfgController: _cfgController,
            seedController: _seedController,
            batchCountController: _batchCountController,
            onAssetChanged: (asset) async {
              setState(() {
                _selectedAsset = asset;
              });
              await _refreshSelectedAssetGenerations();
            },
            onModelChanged: (model) {
              setState(() {
                _selectedModel = model;
              });
            },
            onSamplerChanged: (sampler) {
              setState(() {
                _selectedSampler = sampler;
              });
            },
            onSchedulerChanged: (scheduler) {
              setState(() {
                _selectedScheduler = scheduler;
              });
            },
            onSeedLockToggle: () {
              setState(() {
                _isSeedLocked = !_isSeedLocked;
              });
            },
            onRandomizeSeed: () {
              setState(() {
                _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();
              });
            },
            onCreateAsset: () {
              DialogHelpers.showCreateAssetDialog(context, (newAsset) {
                _refreshAssets(provider);
                setState(() {
                  _selectedAsset = newAsset;
                });
              });
            },
            onViewAssetMetadata: () {
              if (_selectedAsset != null) {
                DialogHelpers.showAssetMetadataDialog(context, _selectedAsset!);
              }
            },
            onAskForModelRecommendation: _askAIForModelRecommendation,
          ),
          const Divider(color: Color(0xFF404040)),
          PromptsPanelWidget(
            positivePromptController: _positivePromptController,
            negativePromptController: _negativePromptController,
            isPromptGenerating: _isPromptGenerating,
            onGeneratePrompt: () => _generateAutoPrompt(provider),
            onGenerateImage: () => _generateImage(provider),
            onDiscussWithAI: _openChatPanel,
            canGenerate: _canGenerate(provider),
            generateButtonText: _getGenerateButtonText(provider),
          ),
          const Divider(color: Color(0xFF404040)),
          RecentImagesPanelWidget(
            selectedAsset: _selectedAsset,
            selectedAssetGenerations: _selectedAssetGenerations,
            loadingGenerations: _loadingGenerations,
            onRefresh: _refreshSelectedAssetGenerations,
          ),
        ],
      ),
    );
  }

  bool _canGenerate(ImageGenerationProvider provider) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isOnlineMode = provider.currentBackendName == 'Automatic1111' &&
        settingsProvider.a1111Mode == A1111Mode.online;

    return (isOnlineMode || provider.isServiceRunning) &&
        !provider.isGenerating &&
        !_isBatchGenerating &&
        _positivePromptController.text.trim().isNotEmpty;
  }

  String _getGenerateButtonText(ImageGenerationProvider provider) {
    final batchCount = int.tryParse(_batchCountController.text) ?? 1;

    if (_isBatchGenerating && _totalBatchCount > 1) {
      return 'Generating ${_currentBatchIndex + 1}/$_totalBatchCount...';
    } else if (provider.isGenerating || _isBatchGenerating) {
      return 'Generating...';
    } else if (batchCount > 1) {
      return 'Generate $batchCount Images';
    } else {
      return 'Generate Image';
    }
  }

  Future<void> _generateAutoPrompt(ImageGenerationProvider provider) async {
    if (_selectedAsset == null) {
      DialogHelpers.showErrorDialog(context, 'Please select an asset before generating a prompt.');
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

      final generatorInfo = {
        'name': provider.currentBackendName,
        'model': _selectedModel,
        'width': int.tryParse(_widthController.text) ?? 512,
        'height': int.tryParse(_heightController.text) ?? 512,
        'steps': int.tryParse(_stepsController.text) ?? 20,
        'cfg_scale': double.tryParse(_cfgController.text) ?? 7.5,
        'sampler': _selectedSampler,
        'scheduler': _selectedScheduler,
        'seed': int.tryParse(_seedController.text) ?? -1,
      };

      final prompt = await provider.generateAutoPrompt(
        assetInfo: assetInfo,
        generatorInfo: generatorInfo,
      );

      if (mounted) {
        setState(() {
          _positivePromptController.text = prompt;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt generated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      DialogHelpers.showErrorDialog(context, 'Failed to generate prompt: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPromptGenerating = false;
        });
      }
    }
  }

  void _generateImage(ImageGenerationProvider provider) async {
    if (_positivePromptController.text.trim().isEmpty) {
      DialogHelpers.showErrorDialog(context, 'Please enter a positive prompt');
      return;
    }

    if (_selectedAsset == null) {
      DialogHelpers.showErrorDialog(context, 'Please select an asset before generating images.');
      return;
    }

    final batchCount = int.tryParse(_batchCountController.text) ?? 1;
    if (batchCount < 1 || batchCount > 10) {
      DialogHelpers.showErrorDialog(context, 'Batch count must be between 1 and 10');
      return;
    }

    try {
      setState(() {
        _isBatchGenerating = true;
        _totalBatchCount = batchCount;
        _currentBatchIndex = 0;
      });

      final projectName = widget.projectName;
      final projectId = widget.projectId;

      int baseSeed;
      if (_isSeedLocked && _seedController.text.isNotEmpty) {
        baseSeed = int.tryParse(_seedController.text) ?? DateTime.now().millisecondsSinceEpoch;
      } else {
        baseSeed = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _seedController.text = baseSeed.toString();
        });
      }

      for (int i = 0; i < batchCount; i++) {
        if (mounted) {
          setState(() {
            _currentBatchIndex = i;
          });
        }

        int currentSeed;
        if (_isSeedLocked) {
          currentSeed = baseSeed;
        } else {
          currentSeed = DateTime.now().millisecondsSinceEpoch + i * 1000;
          if (mounted) {
            setState(() {
              _seedController.text = currentSeed.toString();
            });
          }
        }

        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final isA1111Online =
            provider.currentBackendName == 'Automatic1111' &&
            settingsProvider.a1111Mode == A1111Mode.online;

        String modelForRequest = _selectedModel;
        if (isA1111Online) {
          A1111Checkpoint? selectedCheckpoint;
          for (final c in provider.a1111Checkpoints) {
            if (c.title == _selectedModel) {
              selectedCheckpoint = c;
              break;
            }
          }
          if (selectedCheckpoint != null && selectedCheckpoint.modelName.isNotEmpty) {
            modelForRequest = selectedCheckpoint.modelName;
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
          model: modelForRequest,
        );

        await provider.generateImage(
          request,
          projectName: projectName,
          projectId: projectId,
          assetId: _selectedAsset!.id,
        );

        if (i < batchCount - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (mounted) {
        setState(() {
          _isBatchGenerating = false;
          _totalBatchCount = 0;
          _currentBatchIndex = 0;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(batchCount > 1
                ? 'Generated $batchCount images successfully!'
                : 'Image generation completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (_selectedAsset != null) {
          _refreshSelectedAssetGenerations();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBatchGenerating = false;
          _totalBatchCount = 0;
          _currentBatchIndex = 0;
        });
      }
      DialogHelpers.showErrorDialog(
        context,
        'Failed to generate image(s): ${ErrorHandler.getErrorMessage(e)}',
      );
    }
  }

  void _openChatPanel() {
    setState(() {
      _showChatPanel = true;
    });
  }

  void _askAIForModelRecommendation() {
    if (_selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an asset first to get model recommendations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_showChatPanel) {
      setState(() {
        _showChatPanel = true;
      });
    }

    // Give the widget a frame to build before calling the method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPanelKey.currentState?.askForModelRecommendation();
    });
  }

  void _showServiceLogs(ImageGenerationProvider provider) {
    DialogHelpers.showServiceLogs(
      context,
      () => _killDanglingService(provider),
      () => _copyLogsToClipboard(provider.serviceLogs),
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
    _generationPollTimer?.cancel();
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

