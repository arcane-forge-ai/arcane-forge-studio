import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'dart:io';

import 'models/chat_message.dart' as app_models;
import 'models/api_models.dart';
import 'providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import 'services/chat_api_service.dart';
import 'services/document_extractor.dart';
import 'services/langchain_message_parser.dart';
import 'widgets/chat_history_sidebar.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_constants.dart' as app_utils;
import '../../services/mutation_design_service.dart';
import '../../services/feedback_discussion_service.dart';
import '../../models/feedback_models.dart' as feedback_models;

/// Game Design Assistant Screen using Flutter Gen AI Chat UI
class GameDesignAssistantScreen extends StatefulWidget {
  const GameDesignAssistantScreen({super.key});

  @override
  State<GameDesignAssistantScreen> createState() => _GameDesignAssistantScreenState();
}

class _GameDesignAssistantScreenState extends State<GameDesignAssistantScreen> {
  // Chat controller for managing messages
  final _chatController = ChatMessagesController();
  
  // Services
  late final ChatApiService _chatApiService;
  final _uuid = const Uuid();
  
  // User definitions
  final _currentUser = ChatUser(
    id: 'user123',
    firstName: 'You',
    avatar: 'https://ui-avatars.com/api/?name=User&background=6366f1&color=fff',
  );

  final _aiUser = ChatUser(
    id: 'ai123',
    firstName: 'Game Design AI',
    avatar: 'https://ui-avatars.com/api/?name=AI&background=10b981&color=fff',
  );

  // State management
  String _streamingMessageId = '';
  bool _isGenerating = false;
  String? _lastAiResponse; // Store last AI response for document extraction
  bool _lastResponseHasDocument = false; // Track if last response has extractable markdown  
  ChatSession? _selectedChatSession; // Currently selected chat session
  String? _currentSessionId; // Track session ID for current conversation
  bool _showChatHistory = true; // Toggle for chat history sidebar
  bool _showToolbar = true; // Toggle for toolbar visibility
  
  // Scroll controller
  final ScrollController _scrollController = ScrollController();
  
  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();
  
  // Callback to refresh chat history from sidebar
  VoidCallback? _refreshChatHistory;

  // Example questions for game design
  late final List<ExampleQuestion> _exampleQuestions;

  @override
  void initState() {
    super.initState();
    // Initialize chat API service with settings provider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _chatApiService = ChatApiService(settingsProvider: settingsProvider);
    
    _initializeExampleQuestions();
    _addWelcomeMessage();
    _chatController.setScrollController(_scrollController);
    
    // Check for pending mutation design data
    _checkForMutationDesignData();
    
    // Check for pending feedback discussion data
    _checkForFeedbackDiscussionData();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _chatApiService.dispose();
    super.dispose();
  }

  void _initializeExampleQuestions() {
    _exampleQuestions = [
      ExampleQuestion(
        question: "Help me design a fantasy RPG game",
        config: ExampleQuestionConfig(
          iconData: Icons.shield,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.1),
                Colors.blue.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      ExampleQuestion(
        question: "Create a game mechanics document",
        config: ExampleQuestionConfig(
          iconData: Icons.settings,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.1),
                Colors.teal.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      ExampleQuestion(
        question: "Design character progression system",
        config: ExampleQuestionConfig(
          iconData: Icons.trending_up,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.1),
                Colors.red.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      ExampleQuestion(
        question: "Help with game balance and difficulty",
        config: ExampleQuestionConfig(
          iconData: Icons.balance,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.deepOrange.withOpacity(0.1),
                Colors.orange.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    ];
  }

  void _addWelcomeMessage() {
    final welcomeMessage = """
# Welcome to Game Design Assistant! 🎮

I'm here to help you create amazing games. I can assist with:

## 🎯 Core Features
- **Game Mechanics Design** - Combat systems, progression, balancing
- **Narrative Design** - Story structure, character development, dialogue
- **Level Design** - Layout principles, pacing, player flow
- **System Architecture** - Technical design documents and specifications

## 📚 Knowledge Base
Upload your game design documents to build a custom knowledge base. I'll reference them when providing guidance.

## 🚀 Getting Started
Ask me anything about game design, or try one of the example questions below!
""";

    _chatController.addMessage(
      ChatMessage(
        text: welcomeMessage,
        user: _aiUser,
        createdAt: DateTime.now(),
        isMarkdown: true,
        customProperties: {'type': 'welcome'},
      ),
    );
  }

  /// Check for pending mutation design data and automatically send it
  void _checkForMutationDesignData() {
    final mutationService = MutationDesignService();
    if (mutationService.hasPendingMutationDesign) {
      // Use a post-frame callback to ensure the UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMutationDesignMessage(
          mutationService.pendingMessage!,
          mutationService.pendingTitle!,
        );
      });
    }
  }

  /// Check for pending feedback discussion data and automatically send it
  void _checkForFeedbackDiscussionData() {
    final discussionService = FeedbackDiscussionService();
    if (discussionService.hasPendingFeedbackDiscussion) {
      // Use a post-frame callback to ensure the UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendFeedbackDiscussionMessage(
          discussionService.pendingTopic!,
          discussionService.pendingFeedbacks!,
          discussionService.pendingProjectId!,
          discussionService.pendingProjectName!,
        );
      });
    }
  }

  /// Send the mutation design message with custom title
  Future<void> _sendMutationDesignMessage(String message, String title) async {
    // Clear the mutation design data since we're using it now
    MutationDesignService().clearMutationDesignData();
    
    // Create and send the user message
    final userMessage = ChatMessage(
      text: message,
      user: _currentUser,
      createdAt: DateTime.now(),
    );
    
    // Send the message with custom title
    await _sendMessageWithTitle(userMessage, title);
  }

  /// Send the feedback discussion message with RAG agent
  Future<void> _sendFeedbackDiscussionMessage(
    String topic,
    List<feedback_models.Feedback> feedbacks,
    String projectId,
    String projectName,
  ) async {
    // Clear the feedback discussion data since we're using it now
    FeedbackDiscussionService().clearFeedbackDiscussionData();
    
    // Format the message using the service
    final discussionService = FeedbackDiscussionService();
    final formattedMessage = discussionService.formatFeedbacksForChat(feedbacks, topic);
    
    // Create and send the user message
    final userMessage = ChatMessage(
      text: formattedMessage,
      user: _currentUser,
      createdAt: DateTime.now(),
    );
    
    // Send the message with custom title
    final sessionTitle = 'Feedback Discussion: $topic';
    await _sendMessageWithTitle(userMessage, sessionTitle);
  }

  /// Send a message with custom session title
  Future<void> _sendMessageWithTitle(ChatMessage message, String customTitle, {String? agentType}) async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // FIRST: Add the user's message to the chat immediately
    _chatController.addMessage(message);
    
    // Get project ID and user ID if available - let API handle defaults if missing
    int? projectId;
    String? userId;
    
    // Only include project ID if we have a valid current project
    if (projectProvider.currentProject?.id != null) {
      projectId = int.tryParse(projectProvider.currentProject!.id!);
    }
    
    // Only include user ID if we have a valid authenticated user
    final authUserId = authProvider.userId;
    if (authUserId.isNotEmpty && authUserId != app_utils.AppConstants.visitorUserId) {
      userId = authUserId;
    }

    // Generate unique ID for the AI message
    final messageId = _uuid.v4();
    
    // Create AI message for the UI
    final aiMessage = ChatMessage(
      text: '', // Start with empty text for streaming
      user: _aiUser,
      createdAt: DateTime.now(),
      customProperties: {'id': messageId},
    );

    // Add empty AI message to chat for the response
    _chatController.addMessage(aiMessage);

    // Update state
    setState(() {
      _streamingMessageId = messageId;
      _isGenerating = true;
    });

    try {
      // Convert flutter_gen_ai_chat_ui message to app message format
      final appMessages = [
        app_models.ChatMessage(
          id: _uuid.v4(),
          role: 'user',
          content: message.text,
          timestamp: message.createdAt,
          projectId: projectProvider.currentProject?.id,
        ),
      ];

      // Create chat request with custom title - API will handle defaults for missing projectId/userId
      final request = ChatRequest(
        message: appMessages.last.content, // Send the latest user message
        projectId: projectId, // Only included if available
        userId: userId, // Only included if available
        knowledgeBaseName: projectProvider.knowledgeBaseName,
        sessionId: _currentSessionId, // Use current session ID for this conversation (may be null for first message)
        title: customTitle, // Custom session title for mutation design
        agentType: agentType, // Agent type (rag for feedback discussions)
        extraConfig: {
          'message_history': appMessages.take(appMessages.length - 1).map((m) => {
            'role': m.role,
            'content': m.content,
            'timestamp': m.timestamp.toIso8601String(),
          }).toList(),
        },
      );

      // Use HTTP request instead of WebSocket streaming (backend doesn't support WebSocket)
      final response = await _chatApiService.sendChatMessage(request);
      String fullResponse = response.content;
      
      // Store the session ID from the response for subsequent messages
      if (response.sessionId.isNotEmpty) {
        setState(() {
          _currentSessionId = response.sessionId;
        });
      }
      
      // Update the message with the complete response
      final updatedMessage = aiMessage.copyWith(text: fullResponse);
      _chatController.updateMessage(updatedMessage);

      // Store the final response and check for extractable documents
      _lastAiResponse = fullResponse;
      final hasDocument = DocumentExtractor.hasExtractableDocument(fullResponse);
      
      // Update state to show/hide save button
      setState(() {
        _lastResponseHasDocument = hasDocument;
      });

      // Refresh the chat history sidebar to show any new sessions created by the API
      _refreshChatHistory?.call();

    } catch (e) {
      // Handle error - similar to the original _sendMessage method
      print('GameDesignAssistant: Error in sendMessageWithTitle: $e');
      print('GameDesignAssistant: Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('GameDesignAssistant: DioException details:');
        print('  - Status code: ${e.response?.statusCode}');
        print('  - Response data: ${e.response?.data}');
        print('  - Request data: ${e.requestOptions.data}');
      }
      
      final errorMessage = 'Sorry, I encountered an error: ${e.toString()}';
      final updatedMessage = aiMessage.copyWith(text: errorMessage);
      _chatController.updateMessage(updatedMessage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // Reset generating state
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _streamingMessageId = '';
        });
      }
    }
  }

  /// Send a message to the chat API
  Future<void> _sendMessage(ChatMessage message) async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // FIRST: Add the user's message to the chat immediately
    _chatController.addMessage(message);
    
    // Get project ID and user ID if available - let API handle defaults if missing
    int? projectId;
    String? userId;
    
    // Only include project ID if we have a valid current project
    if (projectProvider.currentProject?.id != null) {
      projectId = int.tryParse(projectProvider.currentProject!.id!);
    }
    
    // Only include user ID if we have a valid authenticated user
    final authUserId = authProvider.userId;
    if (authUserId.isNotEmpty && authUserId != app_utils.AppConstants.visitorUserId) {
      userId = authUserId;
    }

    // Generate unique ID for the AI message
    final messageId = _uuid.v4();
    
    // Create AI message for the UI
    final aiMessage = ChatMessage(
      text: '', // Start with empty text for streaming
      user: _aiUser,
      createdAt: DateTime.now(),
      customProperties: {'id': messageId},
    );

    // Add empty AI message to chat for the response
    _chatController.addMessage(aiMessage);

    // Update state
    setState(() {
      _streamingMessageId = messageId;
      _isGenerating = true;
    });

    try {
      // Convert flutter_gen_ai_chat_ui message to app message format
      final appMessages = [
        app_models.ChatMessage(
          id: _uuid.v4(),
          role: 'user',
          content: message.text,
          timestamp: message.createdAt,
          projectId: projectProvider.currentProject?.id,
        ),
      ];

      // Create chat request - API will handle defaults for missing projectId/userId
      final request = ChatRequest(
        message: appMessages.last.content, // Send the latest user message
        projectId: projectId, // Only included if available
        userId: userId, // Only included if available
        knowledgeBaseName: projectProvider.knowledgeBaseName,
        sessionId: _currentSessionId, // Use current session ID for this conversation (may be null for first message)
        agentType: 'rag', // Use RAG agent for regular chat messages
        extraConfig: {
          'message_history': appMessages.take(appMessages.length - 1).map((m) => {
            'role': m.role,
            'content': m.content,
            'timestamp': m.timestamp.toIso8601String(),
          }).toList(),
        },
      );

      // Use HTTP request instead of WebSocket streaming (backend doesn't support WebSocket)
      final response = await _chatApiService.sendChatMessage(request);
      String fullResponse = response.content;
      
      // Store the session ID from the response for subsequent messages
      if (response.sessionId.isNotEmpty) {
        setState(() {
          _currentSessionId = response.sessionId;
        });
      }
      
      // Update the message with the complete response
      final updatedMessage = aiMessage.copyWith(text: fullResponse);
      _chatController.updateMessage(updatedMessage);

      // Store the final response and check for extractable documents
      _lastAiResponse = fullResponse;
      final hasDocument = DocumentExtractor.hasExtractableDocument(fullResponse);
      
      // Update state to show/hide save button
      setState(() {
        _lastResponseHasDocument = hasDocument;
      });

      // Refresh the chat history sidebar to show any new sessions created by the API
      _refreshChatHistory?.call();

    } catch (e) {
      // Handle error
      print('GameDesignAssistant: Error in _sendMessage: $e');
      print('GameDesignAssistant: Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('GameDesignAssistant: DioException details:');
        print('  - Status code: ${e.response?.statusCode}');
        print('  - Response data: ${e.response?.data}');
        print('  - Request data: ${e.requestOptions.data}');
      }
      
      final errorMessage = aiMessage.copyWith(
        text: "Sorry, I encountered an error: ${e.toString()}",
      );
      _chatController.updateMessage(errorMessage);
      
      // Reset document state on error
      setState(() {
        _lastResponseHasDocument = false;
        _lastAiResponse = null;
      });
      
      // Show error snackbar for regular send message too
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // Reset streaming state
      if (mounted) {
        setState(() {
          _streamingMessageId = '';
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveDocumentToKnowledgeBase() async {
    if (_lastAiResponse == null) return;

    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    // Show loading state
    setState(() {
      _isGenerating = true;
    });
    
    try {
      // Extract markdown content from AI response
      final markdownContent = DocumentExtractor.extractMarkdownBlock(_lastAiResponse!);
      if (markdownContent == null) {
        throw Exception('No extractable markdown content found');
      }
      
      // Extract title for filename
      final extractedDoc = DocumentExtractor.createExtractedDocument(
        _lastAiResponse!,
        projectProvider.currentProject?.id ?? 'default',
        'saved_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (extractedDoc == null) {
        throw Exception('Failed to create document');
      }
      
      // Create temporary markdown file
      final tempDir = await Directory.systemTemp.createTemp('arcane_forge_docs');
      final cleanFileName = _getFileNameFromMarkdown(markdownContent);
      final fileName = '$cleanFileName.md';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(markdownContent);
      
      // Upload file to backend via API
      final projectIdString = projectProvider.currentProject?.id ?? '1';
      final success = await _chatApiService.uploadFile(
        projectIdString,
        tempFile.path,
        fileName,
      );
      
      if (success) {
        // Also add to local provider for immediate UI update
        projectProvider.addExtractedDocument(extractedDoc);
        
        // Update state to hide save button
        setState(() {
          _lastResponseHasDocument = false;
        });
        
        // Show success notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${extractedDoc.title}" to knowledge base'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: _showKnowledgeBase,
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to upload file to server');
      }
      
      // Clean up temporary file
      try {
        await tempFile.delete();
        await tempDir.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
      
    } catch (e) {
      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Hide loading state
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _uploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
        
        for (final file in result.files) {
          if (file.path != null) {
            // Upload file using the API service
            final success = await _chatApiService.uploadFile(
              projectProvider.currentProject?.id ?? 'default',
              file.path!,
              file.name,
            );
            
            if (success) {
              // Create a simple document entry for uploaded files
              final doc = ExtractedDocument(
                id: _uuid.v4(),
                title: file.name,
                content: "File uploaded: ${file.name}",
                projectId: projectProvider.currentProject?.id ?? 'default',
                extractedAt: DateTime.now(),
                sourceMessageId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
              );
              projectProvider.addExtractedDocument(doc);
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded ${result.files.length} file(s) to knowledge base'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCtrlEnterShortcut() {
    // Request focus to ensure the widget is active
    _focusNode.requestFocus();
    
    // Note: The actual sending will be handled by the AiChatWidget's internal logic
    // when it detects the Ctrl+Enter combination. This callback ensures our focus
    // is maintained and the shortcut is recognized at the application level.
  }

  /// Show session information dialog
  void _showSessionInfo() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text('Session Information'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Session Status', _selectedChatSession != null ? 'Active' : 'No Session'),
                if (_selectedChatSession != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Session ID', _selectedChatSession!.sessionId),
                  _buildInfoRow('Database ID', _selectedChatSession!.id.toString()),
                  _buildInfoRow('Title', _selectedChatSession!.title ?? 'Untitled'),
                  _buildInfoRow('Project ID', _selectedChatSession!.projectId.toString()),
                  _buildInfoRow('User ID', _selectedChatSession!.userId.toString()),
                          _buildInfoRow('Created', app_utils.DateUtils.formatDateTime(_selectedChatSession!.createdAt)),
        _buildInfoRow('Last Updated', app_utils.DateUtils.formatDateTime(_selectedChatSession!.updatedAt)),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Current Session ID', _currentSessionId ?? 'None'),
                  _buildInfoRow('Project', projectProvider.currentProject?.name ?? 'Default Project'),
                  _buildInfoRow('Project ID', projectProvider.currentProject?.id ?? '1'),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Messages in Chat', _chatController.messages.length.toString()),
                _buildInfoRow('Is Generating', _isGenerating ? 'Yes' : 'No'),
                _buildInfoRow('Last Response Has Doc', _lastResponseHasDocument ? 'Yes' : 'No'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (_selectedChatSession != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _copySessionId();
                },
                child: const Text('Copy Session ID'),
              ),
          ],
        );
      },
    );
  }

  /// Helper method to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago (${_formatFullDateTime(dateTime)})';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago (${_formatFullDateTime(dateTime)})';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Format full DateTime
  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Copy session ID to clipboard
  void _copySessionId() {
    if (_selectedChatSession != null) {
      Clipboard.setData(ClipboardData(text: _selectedChatSession!.sessionId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session ID copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Toggle toolbar visibility
  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  /// Extract first title from markdown content for filename
  String _getFileNameFromMarkdown(String markdownContent) {
    // Look for first markdown heading
    final RegExp headingPattern = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true);
    final match = headingPattern.firstMatch(markdownContent);
    
    if (match != null) {
      String title = match.group(1)?.trim() ?? '';
      // Clean up title for filename (remove invalid characters)
      title = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      // Limit length for filename
      if (title.length > 50) {
        title = title.substring(0, 47) + '...';
      }
      return title.isNotEmpty ? title : 'game_design_document';
    }

    // Fallback: use first line or generic name
    final lines = markdownContent.split('\n').where((line) => line.trim().isNotEmpty);
    if (lines.isNotEmpty) {
      String firstLine = lines.first.trim();
      // Remove markdown symbols from first line
      firstLine = firstLine.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      firstLine = firstLine.replaceAll(RegExp(r'^\*+\s*'), '');
      firstLine = firstLine.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      if (firstLine.length > 50) {
        firstLine = firstLine.substring(0, 47) + '...';
      }
      return firstLine.isNotEmpty ? firstLine : 'game_design_document';
    }

    return 'game_design_document';
  }

  /// Start a new conversation by clearing the current state
  /// Session will be created automatically when the first message is sent
  Future<void> _startNewConversation() async {
    try {
      setState(() {
        _currentSessionId = null;
        _selectedChatSession = null;
        _lastAiResponse = null;
        _lastResponseHasDocument = false;
      });
      
      // Clear current chat messages and add welcome message
      _chatController.clearMessages();
      _addWelcomeMessage();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ready for new conversation - session will be created when you send your first message'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting new conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onChatSessionSelected(ChatSession session) async {
    setState(() {
      _selectedChatSession = session;
      _currentSessionId = session.sessionId; // Set current session ID
    });
    
    // Show loading indicator
    setState(() {
      _isGenerating = true;
    });
    
    try {
      // Load chat history for the selected session
      final chatHistory = await _chatApiService.getChatHistory(session.sessionId);
      
      // Parse LangChain messages to our format
      final parsedMessages = LangChainMessageParser.parseMessageList(chatHistory.messages);
      
      // Clear current chat messages
      _chatController.clearMessages();
      
      // Convert to ChatMessage format for the UI
      for (final appMessage in parsedMessages) {
        final chatUser = appMessage.role == 'user' ? _currentUser : _aiUser;
        final chatMessage = ChatMessage(
          text: appMessage.content,
          user: chatUser,
          createdAt: appMessage.timestamp,
          isMarkdown: appMessage.role == 'assistant', // Only AI messages are markdown
          customProperties: {
            'id': appMessage.id,
            'role': appMessage.role,
          },
        );
        
        _chatController.addMessage(chatMessage);
      }
      
      // Check if the last AI message has extractable content
      final lastAiMessage = parsedMessages.lastWhere(
        (msg) => msg.role == 'assistant',
        orElse: () => app_models.ChatMessage(
          id: '',
          role: 'assistant',
          content: '',
          timestamp: DateTime.now(),
        ),
      );
      
      if (lastAiMessage.content.isNotEmpty) {
        final hasExtractableDoc = DocumentExtractor.hasExtractableDocument(lastAiMessage.content);
        setState(() {
          _lastResponseHasDocument = hasExtractableDoc;
          _lastAiResponse = hasExtractableDoc ? lastAiMessage.content : null;
          // Note: Don't automatically show toolbar (_showToolbar remains unchanged)
        });
      } else {
        setState(() {
          _lastResponseHasDocument = false;
          _lastAiResponse = null;
        });
      }
      
      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded: ${session.title ?? 'Untitled Chat'} (${parsedMessages.length} messages)'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chat history: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _toggleChatHistory() {
    setState(() {
      _showChatHistory = !_showChatHistory;
    });
  }

  void _startNewChat() {
    // Use the proper new conversation method (now async)
    _startNewConversation();
  }

  void _showKnowledgeBase() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.library_books),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Knowledge Base',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Documents list
              Expanded(
                child: Consumer<ProjectProvider>(
                  builder: (context, provider, child) {
                    final docs = provider.extractedDocuments;
                    
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No documents in knowledge base',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(Icons.description),
                          ),
                          title: Text(doc.title),
                          subtitle: Text(
                            doc.content.length > 100
                                ? '${doc.content.substring(0, 100)}...'
                                : doc.content,
                          ),
                          onTap: () {
                            // Could show document details
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showChatHistory ? Icons.menu_open : Icons.menu,
                        color: colorScheme.primary,
                      ),
                      onPressed: _toggleChatHistory,
                      tooltip: _showChatHistory ? 'Hide Chat History' : 'Show Chat History',
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.psychology,
                      size: 28,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Game Design Assistant',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Consumer<ProjectProvider>(
                      builder: (context, provider, child) {
                        final docCount = provider.extractedDocuments.length;
                        return Badge(
                          label: Text(docCount.toString()),
                          isLabelVisible: docCount > 0,
                          child: IconButton(
                            icon: const Icon(Icons.library_books),
                            onPressed: _showKnowledgeBase,
                            tooltip: 'Knowledge Base',
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: _uploadFiles,
                      tooltip: 'Upload Files',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment),
                      onPressed: _startNewChat,
                      tooltip: 'New Chat',
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: _showSessionInfo,
                      tooltip: 'Session Info',
                    ),
                    IconButton(
                      icon: Icon(
                        _showToolbar ? Icons.build_circle : Icons.build_circle_outlined,
                        color: colorScheme.primary,
                      ),
                      onPressed: _toggleToolbar,
                      tooltip: _showToolbar ? 'Hide Toolbar' : 'Show Toolbar',
                    ),
                  ],
                ),
              ),
              
              // Main Content with Chat History Sidebar and Chat Interface
              Expanded(
                child: Row(
                  children: [
                    // Chat History Sidebar
                    if (_showChatHistory)
                      ChatHistorySidebar(
                        selectedSession: _selectedChatSession,
                        onSessionSelected: _onChatSessionSelected,
                        chatApiService: _chatApiService,
                        onNewChat: _startNewChat, // Pass the new chat callback
                        onRefreshCallback: (refreshCallback) {
                          _refreshChatHistory = refreshCallback;
                        },
                      ),
                    
                    // Chat Interface with Floating Action Bar
                    Expanded(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(
                                LogicalKeyboardKey.enter,
                                control: true,
                              ): _handleCtrlEnterShortcut,
                            },
                            child: Focus(
                              focusNode: _focusNode,
                              child: Stack(
                                children: [
                                  // Main Chat Widget
                                  AiChatWidget(
                      currentUser: _currentUser,
                      aiUser: _aiUser,
                      controller: _chatController,
                      onSendMessage: _sendMessage,
                      scrollController: _scrollController,

                      // Message styling
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

                      // Loading configuration
                      loadingConfig: LoadingConfig(
                        isLoading: _isGenerating,
                        typingIndicatorColor: colorScheme.primary,
                      ),

                      // Example questions
                      exampleQuestions: _exampleQuestions,
                      persistentExampleQuestions: false,

                      // Width constraint for desktop
                      maxWidth: 900,

                                                // Input customization
                          inputOptions: InputOptions(
                            decoration: InputDecoration(
                              hintText: 'Ask about game design... (Ctrl+Enter to send)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark 
                              ? Colors.grey[800] 
                              : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textStyle: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        sendButtonIcon: Icons.send_rounded,
                        sendButtonColor: colorScheme.primary,
                      ),

                      // Animation settings
                      enableAnimation: true,
                      enableMarkdownStreaming: true,
                      streamingDuration: const Duration(milliseconds: 30),

                      // Pagination configuration
                      paginationConfig: const PaginationConfig(
                        enabled: true,
                        loadingIndicatorOffset: 100,
                      ),
                    ),
                    
                                  // Floating Action Bar (shows when toolbar is enabled)
                                  if (_showToolbar)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 80, // Position above the input bar
                                      child: _buildFloatingActionBar(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar() {
    final bool canSave = _lastResponseHasDocument && !_isGenerating;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5), // 50% transparent background
          borderRadius: BorderRadius.circular(35),
        ),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(25),
          shadowColor: Colors.black.withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: canSave ? [
                  Colors.green[400]!,
                  Colors.green[600]!,
                ] : [
                  Colors.grey[400]!,
                  Colors.grey[600]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InkWell(
              onTap: canSave ? _saveDocumentToKnowledgeBase : null,
              borderRadius: BorderRadius.circular(25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.save_alt_rounded,
                      color: canSave ? Colors.white : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Save File',
                      style: TextStyle(
                        color: canSave ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}