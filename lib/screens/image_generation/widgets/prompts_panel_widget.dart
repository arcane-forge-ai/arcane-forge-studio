import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/image_generation_provider.dart';

class PromptsPanelWidget extends StatelessWidget {
  final TextEditingController positivePromptController;
  final TextEditingController negativePromptController;
  final bool isPromptGenerating;
  final VoidCallback onGeneratePrompt;
  final VoidCallback onGenerateImage;
  final VoidCallback onDiscussWithAI;
  final bool canGenerate;
  final String generateButtonText;

  const PromptsPanelWidget({
    Key? key,
    required this.positivePromptController,
    required this.negativePromptController,
    required this.isPromptGenerating,
    required this.onGeneratePrompt,
    required this.onGenerateImage,
    required this.onDiscussWithAI,
    required this.canGenerate,
    required this.generateButtonText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
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
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isPromptGenerating ? null : onGeneratePrompt,
                icon: isPromptGenerating
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
                  isPromptGenerating ? 'Generating prompt...' : 'Generate Prompt with AI',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPromptField(
              context,
              'Positive Prompt',
              positivePromptController,
              'Describe what you want to see in the image...',
            ),
            const SizedBox(height: 20),
            _buildPromptField(
              context,
              'Negative Prompt',
              negativePromptController,
              'Describe what you don\'t want to see in the image...',
            ),
            const SizedBox(height: 30),
            _buildGenerateButton(context),
            const SizedBox(height: 16),
            _buildDiscussWithAIButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint,
  ) {
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

  Widget _buildGenerateButton(BuildContext context) {
    return Consumer<ImageGenerationProvider>(
      builder: (context, provider, child) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canGenerate ? onGenerateImage : null,
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
              generateButtonText,
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
      },
    );
  }

  Widget _buildDiscussWithAIButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onDiscussWithAI,
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          'Discuss with AI',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

