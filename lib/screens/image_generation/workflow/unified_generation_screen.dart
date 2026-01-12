import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../models/image_generation_models.dart';
import '../../../models/workflow_models.dart';
import '../../../providers/workflow_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../responsive.dart';
import '../shared_widgets/prompts_input_widget.dart';
import '../widgets/recent_images_panel_widget.dart';
import 'workflow_browser_screen.dart';

/// Screen 3: Unified Generation Screen
/// Main generation interface with workflow-based approach
class UnifiedGenerationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ImageAsset selectedAsset;
  final Workflow selectedWorkflow;
  final String? userDescription;

  const UnifiedGenerationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.selectedAsset,
    required this.selectedWorkflow,
    this.userDescription,
  }) : super(key: key);

  @override
  State<UnifiedGenerationScreen> createState() => _UnifiedGenerationScreenState();
}

class _UnifiedGenerationScreenState extends State<UnifiedGenerationScreen> {
  final TextEditingController _positivePromptController = TextEditingController();
  final TextEditingController _negativePromptController = TextEditingController();
  final TextEditingController _batchCountController = TextEditingController(text: '1');
  
  String? _selectedAspectRatio;
  bool _isPromptGenerating = false;
  bool _removeBackground = false;
  // bool _showAdvanced = false; // Commented out for future use
  List<ImageGeneration> _selectedAssetGenerations = [];
  bool _loadingGenerations = false;
  
  Timer? _generationPollTimer;
  
  // Background removal prompt suggestions
  static const List<String> _backgroundPromptSuggestions = [
    'simple background',
    'clear background',
    'white background',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize aspect ratio from workflow's default
    _selectedAspectRatio = widget.selectedWorkflow.defaultVersion?.defaultAspectRatio ?? '16:9';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSelectedAssetGenerations();
      _startGenerationPolling();
    });
  }

  @override
  void dispose() {
    _generationPollTimer?.cancel();
    _positivePromptController.dispose();
    _negativePromptController.dispose();
    _batchCountController.dispose();
    super.dispose();
  }

  Future<void> _refreshSelectedAssetGenerations() async {
    setState(() {
      _loadingGenerations = true;
    });

    try {
      final imageGenProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
      final generations = await imageGenProvider.getAssetGenerations(widget.selectedAsset.id);
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

  bool _hasInFlightGenerations() {
    return _selectedAssetGenerations.any((g) =>
        g.status == GenerationStatus.pending || g.status == GenerationStatus.generating);
  }

  void _startGenerationPolling() {
    _generationPollTimer?.cancel();
    _generationPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;

      if (!_hasInFlightGenerations()) return;

      try {
        await _refreshSelectedAssetGenerations();
      } catch (_) {
        // Ignore polling errors
      }
    });
  }

  Future<void> _generatePrompt() async {
    setState(() {
      _isPromptGenerating = true;
    });

    try {
      final imageGenProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
      
      final assetInfo = {
        'id': widget.selectedAsset.id,
        'name': widget.selectedAsset.name,
        'description': widget.selectedAsset.description,
      };

      final generatorInfo = {
        'workflow': widget.selectedWorkflow.name,
        'workflow_description': widget.selectedWorkflow.description,
        'aspect_ratio': _selectedAspectRatio ?? widget.selectedWorkflow.defaultVersion?.defaultAspectRatio,
        if (widget.userDescription != null && widget.userDescription!.isNotEmpty)
          'user_request': widget.userDescription,
      };

      final prompt = await imageGenProvider.generateAutoPrompt(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate prompt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPromptGenerating = false;
        });
      }
    }
  }

  Future<void> _generateImage() async {
    if (_positivePromptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a positive prompt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if background prompts should be suggested when remove_background is enabled
    if (_removeBackground) {
      final shouldContinue = await _checkAndSuggestBackgroundPrompts();
      if (!shouldContinue) {
        return; // User cancelled
      }
    }

    final workflowProvider = Provider.of<WorkflowProvider>(context, listen: false);
    
    try {
      // Build config overrides from user input
      final configOverrides = <String, dynamic>{
        'aspect_ratio': _selectedAspectRatio ?? widget.selectedWorkflow.defaultVersion?.defaultAspectRatio ?? '16:9',
        'batch_count': int.tryParse(_batchCountController.text) ?? 1,
        'remove_background': _removeBackground,
        if (_negativePromptController.text.isNotEmpty)
          'negative_prompt': _negativePromptController.text,
      };

      // Execute workflow
      final generation = await workflowProvider.executeWorkflow(
        assetId: widget.selectedAsset.id,
        prompt: _positivePromptController.text,
        version: widget.selectedWorkflow.defaultVersion?.version,
        configOverrides: configOverrides,
      );

      if (!mounted) return;

      if (generation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image generation started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshSelectedAssetGenerations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate image: ${workflowProvider.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeWorkflow() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WorkflowBrowserScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          selectedAsset: widget.selectedAsset,
          recommendedWorkflows: const [],
          isFromChat: false,
          userDescription: widget.userDescription,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: const Color(0xFF2A2A2A),
      child: Row(
        children: [
          // Asset info - limited to 1/3 width
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.selectedAsset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.selectedAsset.description.isNotEmpty)
                          Text(
                            widget.selectedAsset.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Spacer for future content
          const Expanded(flex: 2, child: SizedBox()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Generation'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      body: Column(
        children: [
          // Header with asset selection
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFF404040)),
          Expanded(
            child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1: Info Panel
        Expanded(
          flex: 3,
          child: _buildInfoPanel(),
        ),
        Container(width: 1, color: const Color(0xFF404040)),
        
        // Column 2: Generation Panel
        Expanded(
          flex: 4,
          child: _buildGenerationPanel(),
        ),
        Container(width: 1, color: const Color(0xFF404040)),
        
        // Column 3: Recent Generations
        Expanded(
          flex: 4,
          child: RecentImagesPanelWidget(
            selectedAsset: widget.selectedAsset,
            selectedAssetGenerations: _selectedAssetGenerations,
            loadingGenerations: _loadingGenerations,
            onRefresh: _refreshSelectedAssetGenerations,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildInfoPanel(),
          const Divider(color: Color(0xFF404040)),
          _buildGenerationPanel(),
          const Divider(color: Color(0xFF404040)),
          SizedBox(
            height: 400,
            child: RecentImagesPanelWidget(
              selectedAsset: widget.selectedAsset,
              selectedAssetGenerations: _selectedAssetGenerations,
              loadingGenerations: _loadingGenerations,
              onRefresh: _refreshSelectedAssetGenerations,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Asset Info Section
          Text(
            'Asset Info',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedAsset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.selectedAsset.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.selectedAsset.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // User Description if from AI recommendation
          if (widget.userDescription != null && widget.userDescription!.isNotEmpty) ...[
            Text(
              'Your Request',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0078D4).withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.userDescription!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Workflow Section
          Row(
            children: [
              Text(
                'Selected Workflow',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _changeWorkflow,
                child: const Text(
                  'CHANGE',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Workflow Card - styled like browser screen
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0078D4), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sample Image or Placeholder
                if (widget.selectedWorkflow.sampleImages.isNotEmpty) ...[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.selectedWorkflow.sampleImages.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Workflow Name
                Text(
                  widget.selectedWorkflow.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // Description
                if (widget.selectedWorkflow.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.selectedWorkflow.description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
                
                // Tags
                if (widget.selectedWorkflow.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.selectedWorkflow.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF404040),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationPanel() {
    return Consumer<WorkflowProvider>(
      builder: (context, workflowProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prompt',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Prompts Input
              PromptsInputWidget(
                positivePromptController: _positivePromptController,
                negativePromptController: _negativePromptController,
                isPromptGenerating: _isPromptGenerating,
                onGeneratePrompt: _generatePrompt,
              ),
              const SizedBox(height: 24),
              
              // Aspect Ratio Control
              _buildAspectRatioDropdown(),
              const SizedBox(height: 20),
              
              // Batch Count
              _buildNumberField('Batch Count', _batchCountController),
              const SizedBox(height: 20),
              
              // Remove Background Toggle
              _buildRemoveBackgroundToggle(),
              
              // Advanced Section (commented out for future use)
              // const SizedBox(height: 24),
              // InkWell(
              //   onTap: () {
              //     setState(() {
              //       _showAdvanced = !_showAdvanced;
              //     });
              //   },
              //   child: Row(
              //     children: [
              //       Icon(
              //         _showAdvanced ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              //         color: Colors.white70,
              //       ),
              //       const SizedBox(width: 8),
              //       const Text(
              //         'Advanced',
              //         style: TextStyle(
              //           color: Colors.white70,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // if (_showAdvanced) ...[
              //   const SizedBox(height: 16),
              //   // Future advanced options here
              // ],
              
              const SizedBox(height: 30),
              
              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: workflowProvider.isExecuting ? null : _generateImage,
                  icon: workflowProvider.isExecuting
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
                    workflowProvider.isExecuting ? 'Generating...' : 'Generate',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF3A3A3A),
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
              borderSide: const BorderSide(color: Color(0xFF0078D4)),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _checkAndSuggestBackgroundPrompts() async {
    final currentPrompt = _positivePromptController.text.toLowerCase();
    
    // Find missing suggestions
    final missingSuggestions = _backgroundPromptSuggestions
        .where((suggestion) => !currentPrompt.contains(suggestion.toLowerCase()))
        .toList();
    
    // If all suggestions are present or none are missing, continue
    if (missingSuggestions.isEmpty) {
      return true;
    }
    
    // Show dialog asking if user wants to add missing suggestions
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text(
              'Prompt Suggestion',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background removal works best with these prompts:',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...missingSuggestions.map((suggestion) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    suggestion,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            const Text(
              'Would you like to add them to your prompt?',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'No, Continue',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Add missing suggestions to prompt
              final updatedPrompt = _positivePromptController.text.trim();
              final additions = missingSuggestions.join(', ');
              _positivePromptController.text = '$updatedPrompt, $additions';
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
            ),
            child: const Text(
              'Yes, Add Them',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    // If dialog was dismissed, treat as "no" but continue
    return result ?? true;
  }

  Widget _buildRemoveBackgroundToggle() {
    return Row(
      children: [
        Checkbox(
          value: _removeBackground,
          onChanged: (value) {
            setState(() {
              _removeBackground = value ?? false;
            });
          },
          activeColor: const Color(0xFF0078D4),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Remove Background',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Generate both original and background-removed versions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRatioDropdown() {
    final aspectRatios = widget.selectedWorkflow.defaultVersion?.supportedAspectRatios ?? ['16:9'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspect Ratio',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedAspectRatio ?? aspectRatios.first,
          dropdownColor: const Color(0xFF3A3A3A),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF3A3A3A),
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
              borderSide: const BorderSide(color: Color(0xFF0078D4)),
            ),
          ),
          items: aspectRatios.map((ratio) {
            return DropdownMenuItem(
              value: ratio,
              child: Text(ratio),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedAspectRatio = value;
            });
          },
        ),
      ],
    );
  }
}

