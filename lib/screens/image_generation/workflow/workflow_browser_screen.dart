import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/image_generation_models.dart';
import '../../../models/workflow_models.dart';
import '../../../providers/workflow_provider.dart';
import '../../../responsive.dart';
import 'unified_generation_screen.dart';

/// Screen 2b: Workflow Browser
/// Shows available workflows (all or recommended) for user to select
class WorkflowBrowserScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ImageAsset selectedAsset;
  final List<Workflow> recommendedWorkflows;
  final bool isFromChat;
  final String? userDescription;

  const WorkflowBrowserScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.selectedAsset,
    required this.recommendedWorkflows,
    required this.isFromChat,
    this.userDescription,
  }) : super(key: key);

  @override
  State<WorkflowBrowserScreen> createState() => _WorkflowBrowserScreenState();
}

class _WorkflowBrowserScreenState extends State<WorkflowBrowserScreen> {
  Workflow? _selectedWorkflow;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isFromChat) {
      // Defer loading until after the first frame to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadWorkflows();
      });
    }
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workflowProvider = Provider.of<WorkflowProvider>(context, listen: false);
      await workflowProvider.loadWorkflows(activeOnly: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load workflows: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onWorkflowSelected(Workflow workflow) {
    setState(() {
      _selectedWorkflow = workflow;
    });
  }

  void _onContinue() {
    if (_selectedWorkflow == null) return;

    final workflowProvider = Provider.of<WorkflowProvider>(context, listen: false);
    workflowProvider.selectWorkflow(_selectedWorkflow);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedGenerationScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          selectedAsset: widget.selectedAsset,
          selectedWorkflow: _selectedWorkflow!,
          userDescription: widget.userDescription,
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<WorkflowProvider>(
              builder: (context, workflowProvider, child) {
                final workflows = widget.isFromChat
                    ? widget.recommendedWorkflows
                    : workflowProvider.workflows;

                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAssetInfoHeader(),
                          const SizedBox(height: 24),
                          Text(
                            widget.isFromChat ? 'Recommended workflows' : 'Choose a workflow',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.isFromChat)
                            const SizedBox(height: 8),
                          if (widget.isFromChat)
                            Text(
                              'Based on your description, here are the workflows we recommend:',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Workflows Grid
                    Expanded(
                      child: workflows.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.isFromChat
                                        ? 'No workflows recommended. Try a different description.'
                                        : 'No workflows available.',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDiscordHelpCard(),
                                ],
                              ),
                            )
                          : MasonryGridView.count(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              crossAxisCount: isMobile ? 1 : (Responsive.isTablet(context) ? 2 : 4),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              itemCount: workflows.length,
                              itemBuilder: (context, index) {
                                final workflow = workflows[index];
                                final isSelected = _selectedWorkflow?.id == workflow.id;
                                return _buildWorkflowCard(workflow, isSelected);
                              },
                            ),
                    ),
                    
                    // Help Section
                    _buildDiscordHelpCard(),
                    
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        border: Border(
                          top: BorderSide(color: Color(0xFF404040)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFF404040)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedWorkflow != null ? _onContinue : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedWorkflow != null
                                    ? const Color(0xFF0078D4)
                                    : Colors.grey,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _getAspectRatiosText(Workflow workflow) {
    final aspectRatios = workflow.defaultVersion?.supportedAspectRatios ?? [];
    if (aspectRatios.isEmpty) {
      return 'any dimension';
    }
    return aspectRatios.join(', ');
  }

  Widget _buildAssetInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_outlined,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Asset: ${widget.selectedAsset.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.selectedAsset.description.isNotEmpty)
                  Text(
                    widget.selectedAsset.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: 20,
          ),
        ],
      ),
    );
  }

  Future<void> _launchDiscord() async {
    final Uri discordUrl = Uri.parse('https://discord.gg/J4Nb8qRR7q');
    try {
      if (await canLaunchUrl(discordUrl)) {
        await launchUrl(discordUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Discord link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening Discord: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDiscordHelpCard() {
    return InkWell(
      onTap: _launchDiscord,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF5865F2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF5865F2),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Can't find the right workflow?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Reach out to us on Discord and we'll help you find or create one!",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              color: Color(0xFF5865F2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(Workflow workflow, bool isSelected) {
    return InkWell(
      onTap: () => _onWorkflowSelected(workflow),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0078D4) : const Color(0xFF404040),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sample Image Carousel or Placeholder
            _WorkflowImageCarousel(
              sampleImages: workflow.sampleImages,
            ),
            const SizedBox(height: 12),
            
            // Workflow Name
            Text(
              workflow.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            
            // Description
            if (workflow.description != null)
              Text(
                workflow.description!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            
            // Aspect Ratios
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.aspect_ratio,
                  color: Colors.blue,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _getAspectRatiosText(workflow),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Cost Factor
            if (workflow.defaultVersion?.costFactor != null && 
                workflow.defaultVersion!.costFactor! != 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    color: Colors.amber,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Text(
                      '×${workflow.defaultVersion!.costFactor} credits',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Tags
            const SizedBox(height: 8),
            if (workflow.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: workflow.tags.take(3).map((tag) {
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
        ),
      ),
    );
  }
}

/// Widget for displaying sample images carousel in workflow cards
class _WorkflowImageCarousel extends StatefulWidget {
  final List<String> sampleImages;

  const _WorkflowImageCarousel({
    Key? key,
    required this.sampleImages,
  }) : super(key: key);

  @override
  State<_WorkflowImageCarousel> createState() => _WorkflowImageCarouselState();
}

class _WorkflowImageCarouselState extends State<_WorkflowImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < widget.sampleImages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sampleImages.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
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
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Image PageView
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: widget.sampleImages.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    widget.sampleImages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          
          // Navigation buttons - only show if more than one image
          if (widget.sampleImages.length > 1) ...[
            // Previous button
            if (_currentPage > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      iconSize: 24,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: _previousPage,
                    ),
                  ),
                ),
              ),
            
            // Next button
            if (_currentPage < widget.sampleImages.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      iconSize: 24,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: _nextPage,
                    ),
                  ),
                ),
              ),
          ],
          
          // Page indicators (dots) - only show if more than one image
          if (widget.sampleImages.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.sampleImages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

