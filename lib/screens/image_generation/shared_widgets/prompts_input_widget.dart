import 'package:flutter/material.dart';

/// Reusable widget for prompt input fields
/// Simplified version extracted from prompts_panel_widget.dart for use in workflow screens
class PromptsInputWidget extends StatelessWidget {
  final TextEditingController positivePromptController;
  final TextEditingController negativePromptController;
  final bool isPromptGenerating;
  final VoidCallback? onGeneratePrompt;
  final bool showAiButton;
  final String? positivePromptLabel;
  final String? negativePromptLabel;
  final String? positivePromptHint;
  final String? negativePromptHint;

  const PromptsInputWidget({
    Key? key,
    required this.positivePromptController,
    required this.negativePromptController,
    this.isPromptGenerating = false,
    this.onGeneratePrompt,
    this.showAiButton = true,
    this.positivePromptLabel = 'Positive Prompt',
    this.negativePromptLabel = 'Negative Prompt',
    this.positivePromptHint = 'Describe what you want to see in the image...',
    this.negativePromptHint = 'Describe what you don\'t want to see in the image...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAiButton && onGeneratePrompt != null) ...[
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
                  : const Icon(Icons.bolt, color: Colors.white, size: 18),
              label: Text(
                isPromptGenerating ? 'Generating...' : 'Generate Prompt AI',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0078D4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildPromptField(
          context,
          positivePromptLabel!,
          positivePromptController,
          positivePromptHint!,
        ),
        const SizedBox(height: 20),
        _buildPromptField(
          context,
          negativePromptLabel!,
          negativePromptController,
          negativePromptHint!,
        ),
      ],
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
}

