import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../models/image_generation_models.dart';
import '../../responsive.dart';
import '../../controllers/menu_app_controller.dart';
import '../../services/comfyui_service.dart';

class ImageGenerationScreen extends StatefulWidget {
  final String projectId;

  const ImageGenerationScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<ImageGenerationScreen> createState() => _ImageGenerationScreenState();
}

class _ImageGenerationScreenState extends State<ImageGenerationScreen> {
  final TextEditingController _positivePromptController = TextEditingController();
  final TextEditingController _negativePromptController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController(text: '20');
  final TextEditingController _cfgController = TextEditingController(text: '7.5');
  final TextEditingController _widthController = TextEditingController(text: '512');
  final TextEditingController _heightController = TextEditingController(text: '512');
  
  String _selectedSampler = 'euler';
  String _selectedModel = 'sd_xl_base_1.0.safetensors';
  
  @override
  void initState() {
    super.initState();
    _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Check if AI service is already running when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServiceHealthOnLoad();
    });
  }

  void _checkServiceHealthOnLoad() async {
    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
    try {
      final isHealthy = await provider.isServiceHealthy();
      if (isHealthy && mounted) {
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
      // This is expected when no service is running
    }
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
                child: _buildMainContent(context, provider),
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
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'AI Image Generation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
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
      default:
        statusColor = Colors.red;
        statusIcon = Icons.stop_circle;
        statusText = 'Stopped';
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Text(
          '${provider.currentBackendName}: $statusText',
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAIServiceControls(ImageGenerationProvider provider) {
    return Row(
      children: [
        if (!provider.isServiceRunning)
          ElevatedButton.icon(
            onPressed: provider.isServiceStarting ? null : () => provider.startAIService(),
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
            onPressed: provider.isServiceStopping ? null : () => provider.stopAIService(),
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

  Widget _buildMainContent(BuildContext context, ImageGenerationProvider provider) {
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
          const Text(
            'Generation Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Model Selection
          _buildModelSelection(),
          const SizedBox(height: 20),
          
          // Dimensions
          _buildDimensionsSection(),
          const SizedBox(height: 20),
          
          // Steps and CFG
          _buildStepsCfgSection(),
          const SizedBox(height: 20),
          
          // Sampler
          _buildSamplerSection(),
          const SizedBox(height: 20),
          
          // Seed
          _buildSeedSection(),
        ],
      ),
    );
  }

  Widget _buildModelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButton<String>(
            value: _selectedModel,
            isExpanded: true,
            dropdownColor: const Color(0xFF3A3A3A),
            underline: Container(),
            style: const TextStyle(color: Colors.white),
            items: [
              'sd_xl_base_1.0.safetensors',
              'sd_xl_turbo_1.0.safetensors',
              'sd_v1-5-pruned-emaonly.safetensors',
              'sd_v2-1_768-ema-pruned.safetensors',
            ].map((model) => DropdownMenuItem<String>(
              value: model,
              child: Text(model),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedModel = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimensions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildStepsCfgSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberField('Steps', _stepsController),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberField('CFG Scale', _cfgController),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSamplerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sampler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButton<String>(
            value: _selectedSampler,
            isExpanded: true,
            dropdownColor: const Color(0xFF3A3A3A),
            underline: Container(),
            style: const TextStyle(color: Colors.white),
            items: [
              'euler',
              'euler_a',
              'heun',
              'dpm_2',
              'dpm_2_a',
              'lms',
              'ddim',
              'plms',
            ].map((sampler) => DropdownMenuItem<String>(
              value: sampler,
              child: Text(sampler),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedSampler = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Seed',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _seedController.text = DateTime.now().millisecondsSinceEpoch.toString();
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
        _buildNumberField('Seed', _seedController),
      ],
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextField(
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
    );
  }

  Widget _buildPromptsPanel(ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prompts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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

  Widget _buildPromptField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
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

  Widget _buildGenerateButton(ImageGenerationProvider provider) {
    final canGenerate = provider.isServiceRunning && 
                       !provider.isGenerating && 
                       _positivePromptController.text.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? () => _generateImage(provider) : null,
        icon: provider.isGenerating 
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
          provider.isGenerating ? 'Generating...' : 'Generate Image',
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
              const Text(
                'Recent Images',
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
                      .changeScreen(ScreenType.imageGenerationOverview);
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF0078D4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: _buildImagesList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesList(ImageGenerationProvider provider) {
    if (provider.images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: Colors.white54,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No images generated yet',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.images.length,
      itemBuilder: (context, index) {
        final image = provider.images[index];
        return _buildImageTile(image, provider);
      },
    );
  }

  Widget _buildImageTile(GeneratedImage image, ImageGenerationProvider provider) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildImageStatusIcon(image.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.prompt,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${image.width}x${image.height} • ${image.steps} steps',
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
            if (image.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${image.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
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

  void _generateImage(ImageGenerationProvider provider) async {
    if (_positivePromptController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a positive prompt');
      return;
    }

    try {
      final request = GenerationRequest(
        positivePrompt: _positivePromptController.text.trim(),
        negativePrompt: _negativePromptController.text.trim(),
        width: int.tryParse(_widthController.text) ?? 512,
        height: int.tryParse(_heightController.text) ?? 512,
        steps: int.tryParse(_stepsController.text) ?? 20,
        cfgScale: double.tryParse(_cfgController.text) ?? 7.5,
        seed: int.tryParse(_seedController.text) ?? 
              DateTime.now().millisecondsSinceEpoch,
        model: _selectedModel,
        sampler: _selectedSampler,
      );

      await provider.generateImage(request);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image generation started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to generate image: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
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
    super.dispose();
  }
} 