import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/image_generation_models.dart';
import '../../../providers/workflow_provider.dart';
import 'workflow_browser_screen.dart';

/// Screen 2a: Chat Interface
/// User describes what they want and we recommend workflows
class ChatWorkflowScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ImageAsset selectedAsset;

  const ChatWorkflowScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.selectedAsset,
  }) : super(key: key);

  @override
  State<ChatWorkflowScreen> createState() => _ChatWorkflowScreenState();
}

class _ChatWorkflowScreenState extends State<ChatWorkflowScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what you want to create'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final workflowProvider = Provider.of<WorkflowProvider>(context, listen: false);
      
      // Call workflow recommendation API
      await workflowProvider.recommendWorkflows(
        description,
        additionalInfo: {
          'asset_name': widget.selectedAsset.name,
          'asset_description': widget.selectedAsset.description,
          'asset_tags': widget.selectedAsset.tags,
        },
        count: 3,
      );

      if (!mounted) return;

      if (workflowProvider.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get recommendations: ${workflowProvider.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Navigate to workflow browser with recommendations
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WorkflowBrowserScreen(
            projectId: widget.projectId,
            projectName: widget.projectName,
            selectedAsset: widget.selectedAsset,
            recommendedWorkflows: workflowProvider.recommendedWorkflows,
            isFromChat: true,
            userDescription: description,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Generation'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Info Header
            _buildAssetInfoHeader(),
            const SizedBox(height: 32),
            
            // Instructions
            Text(
              'Describe what you want',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us what kind of image you want to create. We\'ll recommend the best workflows for you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            
            // Description Input
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Example: A green shield icon that increases max HP, fantasy style, fits roguelike UI',
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
            const SizedBox(height: 32),
            
            // Action Buttons
              Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
                    onPressed: _isLoading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0078D4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}

