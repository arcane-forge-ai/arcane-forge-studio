import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                              child: Text(
                                widget.isFromChat
                                    ? 'No workflows recommended. Try a different description.'
                                    : 'No workflows available.',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile ? 1 : (Responsive.isTablet(context) ? 2 : 4),
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: isMobile ? 1.5 : 0.85,
                              ),
                              itemCount: workflows.length,
                              itemBuilder: (context, index) {
                                final workflow = workflows[index];
                                final isSelected = _selectedWorkflow?.id == workflow.id;
                                return _buildWorkflowCard(workflow, isSelected);
                              },
                            ),
                    ),
                    
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
            // Sample Image or Placeholder
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: workflow.sampleImages.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          workflow.sampleImages.first,
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
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
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
            const Spacer(),
            
            // Tags
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

