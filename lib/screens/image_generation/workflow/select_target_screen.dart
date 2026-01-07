import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../responsive.dart';
import '../shared_widgets/asset_selection_widget.dart';
import '../utils/dialog_helpers.dart';
import 'chat_workflow_screen.dart';
import 'workflow_browser_screen.dart';

/// Screen 1: Target Asset + How to Start
/// User selects an asset and chooses between chat or browsing workflows
class SelectTargetScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ImageAsset? preSelectedAsset;

  const SelectTargetScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
    this.preSelectedAsset,
  }) : super(key: key);

  @override
  State<SelectTargetScreen> createState() => _SelectTargetScreenState();
}

class _SelectTargetScreenState extends State<SelectTargetScreen> {
  ImageAsset? _selectedAsset;
  List<ImageAsset> _availableAssets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.preSelectedAsset;
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
    await provider.setCurrentProject(widget.projectId);
    await provider.refreshAssets();
    
    if (mounted) {
      setState(() {
        _availableAssets = provider.assets;
        _isLoading = false;
      });
    }
  }

  void _onAssetChanged(ImageAsset? asset) {
    setState(() {
      _selectedAsset = asset;
    });
  }

  void _onCreateAsset() {
    DialogHelpers.showCreateAssetDialog(context, (newAsset) {
      _loadAssets();
      setState(() {
        _selectedAsset = newAsset;
      });
    });
  }

  void _onViewAssetMetadata() {
    if (_selectedAsset != null) {
      DialogHelpers.showAssetMetadataDialog(context, _selectedAsset!);
    }
  }

  void _navigateToChat() {
    if (_selectedAsset == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatWorkflowScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          selectedAsset: _selectedAsset!,
        ),
      ),
    );
  }

  void _navigateToBrowser() {
    if (_selectedAsset == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkflowBrowserScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          selectedAsset: _selectedAsset!,
          recommendedWorkflows: const [],
          isFromChat: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAssetSelected = _selectedAsset != null;
    final bool isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Generation'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asset Selection Section - limited to 1/3 width
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: AssetSelectionWidget(
                          selectedAsset: _selectedAsset,
                          availableAssets: _availableAssets,
                          onAssetChanged: _onAssetChanged,
                          onCreateAsset: _onCreateAsset,
                          onViewAssetMetadata: _onViewAssetMetadata,
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Divider
                  const Divider(color: Color(0xFF404040)),
                  const SizedBox(height: 32),
                  
                  // How to Start Section
                  Text(
                    'How would you like to start?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Method Selection Cards
                  if (isMobile)
                    Column(
                      children: [
                        _buildMethodCard(
                          context: context,
                          title: 'Describe in Chat',
                          description: 'Tell the AI what you want.\nWe\'ll infer the workflow.',
                          icon: Icons.chat_bubble_outline,
                          iconColor: Colors.blue,
                          enabled: hasAssetSelected,
                          onTap: _navigateToChat,
                        ),
                        const SizedBox(height: 16),
                        _buildMethodCard(
                          context: context,
                          title: 'Browse Workflow Library',
                          description: 'Pick a predefined workflow\n(icons, sprites, UI, etc.)',
                          icon: Icons.collections_bookmark_outlined,
                          iconColor: Colors.purple,
                          enabled: hasAssetSelected,
                          onTap: _navigateToBrowser,
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMethodCard(
                            context: context,
                            title: 'Describe in Chat',
                            description: 'Tell the AI what you want.\nWe\'ll infer the workflow.',
                            icon: Icons.chat_bubble_outline,
                            iconColor: Colors.blue,
                            enabled: hasAssetSelected,
                            onTap: _navigateToChat,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildMethodCard(
                            context: context,
                            title: 'Browse Workflow Library',
                            description: 'Pick a predefined workflow\n(icons, sprites, UI, etc.)',
                            icon: Icons.collections_bookmark_outlined,
                            iconColor: Colors.purple,
                            enabled: hasAssetSelected,
                            onTap: _navigateToBrowser,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? const Color(0xFF404040) : const Color(0xFF303030),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: enabled ? iconColor : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: enabled ? onTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enabled ? iconColor : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    title.contains('Chat') ? 'Use Chat' : 'Browse Workflows',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

