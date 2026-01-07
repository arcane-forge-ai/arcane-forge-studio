import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import '../../../providers/image_generation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/image_generation_models.dart';
import '../../game_design_assistant/services/chat_api_service.dart';
import '../../game_design_assistant/models/api_models.dart';
import '../../../utils/error_handler.dart';

class ChatPanelWidget extends StatefulWidget {
  final String projectId;
  final String projectName;
  final ImageAsset? selectedAsset;
  final String selectedModel;
  final TextEditingController positivePromptController;
  final TextEditingController negativePromptController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController stepsController;
  final TextEditingController cfgController;
  final TextEditingController seedController;
  final TextEditingController batchCountController;
  final String selectedSampler;
  final String selectedScheduler;
  final bool isSeedLocked;
  final VoidCallback onClose;

  const ChatPanelWidget({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.selectedAsset,
    required this.selectedModel,
    required this.positivePromptController,
    required this.negativePromptController,
    required this.widthController,
    required this.heightController,
    required this.stepsController,
    required this.cfgController,
    required this.seedController,
    required this.batchCountController,
    required this.selectedSampler,
    required this.selectedScheduler,
    required this.isSeedLocked,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ChatPanelWidget> createState() => ChatPanelWidgetState();
}

class ChatPanelWidgetState extends State<ChatPanelWidget> {
  final _chatController = ChatMessagesController();
  late final ChatApiService _chatApiService;
  final _uuid = const Uuid();
  String? _currentChatSessionId;
  bool _isChatGenerating = false;
  final ScrollController _chatScrollController = ScrollController();

  // Chat users
  final _currentUser = ChatUser(
    id: 'user123',
    firstName: 'You',
    avatar: 'https://ui-avatars.com/api/?name=User&background=6366f1&color=fff',
  );

  final _aiUser = ChatUser(
    id: 'ai_assistant',
    firstName: 'AI Assistant',
    avatar: 'https://ui-avatars.com/api/?name=AI&background=10b981&color=fff',
  );

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatApiService = ChatApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    _chatController.setScrollController(_chatScrollController);
    _startNewChatSession();
  }

  void _startNewChatSession() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final assetName = widget.selectedAsset?.name ?? 'image-gen';
    final sessionId = '$assetName-$timestamp';

    setState(() {
      _currentChatSessionId = sessionId;
      _chatController.clearMessages();
    });

    final greetingMessage = ChatMessage(
      text: 'Hello! I\'m here to help you with your image generation. What are you looking for? Any comments on existing generations and setup?',
      user: _aiUser,
      createdAt: DateTime.now(),
      isMarkdown: true,
    );
    _chatController.addMessage(greetingMessage);
  }

  void askForModelRecommendation() {
    if (widget.selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an asset first to get model recommendations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);

    List<String> availableModels;
    List<String> availableLoras;

    if (provider.currentBackendName == 'Automatic1111' &&
        provider.isA1111ServerReachable &&
        provider.a1111Checkpoints.isNotEmpty) {
      availableModels = provider.a1111Checkpoints.map((c) => c.title).toList();
    } else {
      availableModels = provider.availableModels;
    }

    if (provider.currentBackendName == 'Automatic1111' &&
        provider.isA1111ServerReachable &&
        provider.a1111Loras.isNotEmpty) {
      availableLoras = provider.a1111Loras.map((l) => l.name).toList();
    } else {
      availableLoras = provider.availableLoras;
    }

    final assetInfo = '''
I need help choosing the best model and LoRAs for my image generation.

Asset Details:
- Name: ${widget.selectedAsset!.name}
- Description: ${widget.selectedAsset!.description.isNotEmpty ? widget.selectedAsset!.description : 'No description provided'}

Current Setup:
- Selected Model: ${widget.selectedModel}
- Dimensions: ${widget.widthController.text}x${widget.heightController.text}
- Current Positive Prompt: ${widget.positivePromptController.text.isNotEmpty ? widget.positivePromptController.text : 'None yet'}

Available Models:
${availableModels.isNotEmpty ? availableModels.map((m) => '- $m').join('\n') : '- No models available'}

Available LoRAs:
${availableLoras.isNotEmpty ? availableLoras.map((l) => '- $l').join('\n') : '- No LoRAs available'}

Please recommend:
1. Which model from the available list would work best for this asset?
2. What LoRAs from the available list would enhance the generation?
3. If none of the available models or LoRAs are suitable, suggest a model or LoRA that would be suitable for this asset.
4. Any prompt suggestions to improve the results?
''';

    final userMessage = ChatMessage(
      text: assetInfo,
      user: _currentUser,
      createdAt: DateTime.now(),
    );

    _sendChatMessage(userMessage);
  }

  Future<void> _sendChatMessage(ChatMessage message) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _chatController.addMessage(message);

    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);

    List<String> availableModels;
    List<String> availableLoras;

    if (provider.currentBackendName == 'Automatic1111' &&
        provider.isA1111ServerReachable &&
        provider.a1111Checkpoints.isNotEmpty) {
      availableModels = provider.a1111Checkpoints.map((c) => c.title).toList();
    } else {
      availableModels = provider.availableModels;
    }

    if (provider.currentBackendName == 'Automatic1111' &&
        provider.isA1111ServerReachable &&
        provider.a1111Loras.isNotEmpty) {
      availableLoras = provider.a1111Loras.map((l) => l.name).toList();
    } else {
      availableLoras = provider.availableLoras;
    }

    final contextData = {
      'asset': {
        'name': widget.selectedAsset?.name ?? 'None selected',
        'description': widget.selectedAsset?.description ?? '',
      },
      'backend': provider.currentBackendName,
      'model': widget.selectedModel,
      'available_models': availableModels.isNotEmpty ? availableModels : ['No models available'],
      'available_loras': availableLoras.isNotEmpty ? availableLoras : ['No LoRAs available'],
      'dimensions': {
        'width': widget.widthController.text,
        'height': widget.heightController.text,
      },
      'quality_settings': {
        'sampler': widget.selectedSampler,
        'scheduler': widget.selectedScheduler,
        'steps': widget.stepsController.text,
        'cfg_scale': widget.cfgController.text,
      },
      'seed': {
        'value': widget.seedController.text,
        'locked': widget.isSeedLocked,
      },
      'batch_count': widget.batchCountController.text,
      'prompts': {
        'positive': widget.positivePromptController.text,
        'negative': widget.negativePromptController.text,
      },
    };

    final contextString = '''

Current Image Generation Setup:
${const JsonEncoder.withIndent('  ').convert(contextData)}''';

    final fullMessage = message.text + contextString;

    int? projectId = int.tryParse(widget.projectId);
    String? userId;
    final authUserId = authProvider.userId;
    if (authUserId.isNotEmpty) {
      userId = authUserId;
    }

    final messageId = _uuid.v4();

    final aiMessage = ChatMessage(
      text: '',
      user: _aiUser,
      createdAt: DateTime.now(),
      customProperties: {'id': messageId},
    );

    _chatController.addMessage(aiMessage);

    setState(() {
      _isChatGenerating = true;
    });

    try {
      final request = ChatRequest(
        message: fullMessage,
        projectId: projectId,
        userId: userId,
        sessionId: _currentChatSessionId,
        title: _currentChatSessionId,
      );

      final response = await _chatApiService.sendChatMessage(request);
      String fullResponse = response.content;

      final updatedMessage = aiMessage.copyWith(text: fullResponse, isMarkdown: true);
      _chatController.updateMessage(updatedMessage);
    } catch (e) {
      print('Chat Error: $e');
      if (e is DioException) {
        print('DioException details:');
        print('  - Status code: ${e.response?.statusCode}');
        print('  - Response data: ${e.response?.data}');
      }

      final errorMessage = 'Sorry, I encountered an error: ${ErrorHandler.getErrorMessage(e)}';
      final updatedMessage = aiMessage.copyWith(text: errorMessage);
      _chatController.updateMessage(updatedMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${ErrorHandler.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChatGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Chat Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (widget.selectedAsset != null)
                        Text(
                          'Asset: ${widget.selectedAsset!.name}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _startNewChatSession,
                  icon: const Icon(Icons.add_comment, size: 16, color: Colors.white),
                  label: const Text(
                    'New Discussion',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close Chat Panel',
                ),
              ],
            ),
          ),
          Expanded(
            child: AiChatWidget(
              currentUser: _currentUser,
              aiUser: _aiUser,
              controller: _chatController,
              onSendMessage: _sendChatMessage,
              scrollController: _chatScrollController,
              messageOptions: MessageOptions(
                bubbleStyle: BubbleStyle(
                  userBubbleColor: isDark
                      ? Colors.deepOrange[800]!
                      : Colors.deepOrange[700]!,
                  aiBubbleColor: colorScheme.surfaceContainerHighest,
                  userNameColor: Colors.white,
                  aiNameColor: colorScheme.onSurface,
                  userBubbleTopLeftRadius: 16,
                  userBubbleTopRightRadius: 4,
                  aiBubbleTopLeftRadius: 4,
                  aiBubbleTopRightRadius: 16,
                  bottomLeftRadius: 16,
                  bottomRightRadius: 16,
                ),
                showUserName: true,
                showTime: true,
                timeFormat: (dateTime) =>
                    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
              ),
              loadingConfig: LoadingConfig(
                isLoading: _isChatGenerating,
                typingIndicatorColor: colorScheme.primary,
              ),
              inputOptions: InputOptions(
                decoration: InputDecoration(
                  hintText: 'Ask about your image generation...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                sendButtonIcon: Icons.send_rounded,
                sendButtonColor: colorScheme.primary,
              ),
              enableAnimation: true,
              enableMarkdownStreaming: true,
              streamingDuration: const Duration(milliseconds: 30),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatApiService.dispose();
    super.dispose();
  }
}

