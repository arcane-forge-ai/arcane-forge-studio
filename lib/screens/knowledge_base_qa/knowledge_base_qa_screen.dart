import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/qa_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/qa_api_service.dart';
import '../../services/projects_api_service.dart';
import '../game_design_assistant/models/project_model.dart';
import 'widgets/public_access_settings_dialog.dart';
import 'widgets/public_knowledge_base_dialog.dart';
import 'responsibility_areas_screen.dart';

/// Knowledge Base QA Screen with dual access mode
/// - Authenticated users: Access from side menu with normal navigation
/// - Unauthenticated users: Access from public URL with "Return to App" button
class KnowledgeBaseQAScreen extends StatefulWidget {
  final String projectId;
  final String? projectName;
  final String? passcode; // For unauthenticated access

  const KnowledgeBaseQAScreen({
    super.key,
    required this.projectId,
    this.projectName,
    this.passcode,
  });

  @override
  State<KnowledgeBaseQAScreen> createState() => _KnowledgeBaseQAScreenState();
}

class _KnowledgeBaseQAScreenState extends State<KnowledgeBaseQAScreen> {
  // Chat controller for managing messages
  final _chatController = ChatMessagesController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  // Services
  late final QAApiService _qaApiService;
  late final ProjectsApiService _projectsApiService;

  // User definitions
  final _currentUser = ChatUser(
    id: 'user123',
    firstName: 'You',
    avatar: 'https://ui-avatars.com/api/?name=User&background=6366f1&color=fff',
  );

  final _aiUser = ChatUser(
    id: 'ai123',
    firstName: 'Knowledge Base Assistant',
    avatar: 'https://ui-avatars.com/api/?name=KB&background=9d4edd&color=fff',
  );

  // State management
  bool _isGenerating = false;
  bool _isAuthenticated = false;
  String? _displayProjectName;
  String? _lastAiResponse;
  Project? _currentProject;

  // Example questions
  late final List<ExampleQuestion> _exampleQuestions;

  @override
  void initState() {
    super.initState();

    // Initialize services
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    _qaApiService = QAApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    
    _projectsApiService = ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );

    // Check authentication status
    _isAuthenticated = authProvider.isAuthenticated;

    // Set project name (use provided or fetch it)
    _displayProjectName = widget.projectName;
    
    // Always fetch full project data to get QA access settings
    _fetchProjectName();

    _initializeExampleQuestions();
    _addWelcomeMessage();
    _chatController.setScrollController(_scrollController);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeExampleQuestions() {
    _exampleQuestions = [
      ExampleQuestion(
        question: "What are the project requirements?",
        config: ExampleQuestionConfig(
          iconData: Icons.description,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.1),
                Colors.purple.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      ExampleQuestion(
        question: "Who should I contact about UI design?",
        config: ExampleQuestionConfig(
          iconData: Icons.contact_mail,
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
        question: "Where can I find the style guide?",
        config: ExampleQuestionConfig(
          iconData: Icons.style,
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
        question: "What's the project timeline?",
        config: ExampleQuestionConfig(
          iconData: Icons.schedule,
          containerDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.withOpacity(0.1),
                Colors.indigo.withOpacity(0.1)
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
    final welcomeMessage = ChatMessage(
      text: _isAuthenticated
          ? 'Hello! I\'m your Knowledge Base Assistant. Ask me anything about this project.'
          : 'Welcome! I\'m here to answer questions about this project. Feel free to ask me anything.',
      user: _aiUser,
      createdAt: DateTime.now(),
    );
    _chatController.addMessage(welcomeMessage);
  }

  Future<void> _fetchProjectName() async {
    try {
      final project = await _projectsApiService.getProjectById(int.parse(widget.projectId));
      setState(() {
        // Use fetched name if we don't have one, otherwise keep the provided name
        _displayProjectName = _displayProjectName ?? project.name;
        _currentProject = project;
      });
    } catch (e) {
      print('Error fetching project name: $e');
      setState(() {
        _displayProjectName = _displayProjectName ?? 'Project ${widget.projectId}';
      });
    }
  }

  Future<void> _sendMessage(ChatMessage message) async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    // Add user message to chat
    _chatController.addMessage(message);

    // Create AI message placeholder
    final aiMessage = ChatMessage(
      text: '',
      user: _aiUser,
      createdAt: DateTime.now(),
    );
    _chatController.addMessage(aiMessage);

    try {
      // Prepare request
      final request = QARequest(
        question: message.text,
        userRole: _isAuthenticated ? 'internal' : 'vendor',
      );

      // Call QA API (with or without passcode)
      final QAResponse response;
      if (_isAuthenticated) {
        response = await _qaApiService.askQuestion(widget.projectId, request);
      } else {
        // Use passcode for unauthenticated access
        response = await _qaApiService.askQuestionWithPasscode(
          widget.projectId,
          request,
          widget.passcode!,
        );
      }

      // Store the response
      _lastAiResponse = response.answer;

      // Build the full response text with metadata
      String responseText = response.answer;
      
      // Add confidence badge
      responseText += '\n\n**Confidence:** ${response.confidence}';
      
      // Add references
      if (response.references.isNotEmpty) {
        responseText += '\n\n**References:**';
        for (final ref in response.references) {
          // Add reference type icon
          String typeIcon = '';
          switch (ref.type) {
            case 'document':
              typeIcon = '📄';
              break;
            case 'link':
              typeIcon = '🔗';
              break;
            case 'contact':
              typeIcon = '👤';
              break;
            case 'folder':
              typeIcon = '📁';
              break;
            default:
              typeIcon = '📋';
          }
          
          responseText += '\n- $typeIcon ${ref.title}';
          if (ref.source != null) {
            responseText += ' (${ref.source})';
          }
        }
        
        // Add helpful note for vendors about viewing documents
        if (!_isAuthenticated && response.references.any((ref) => ref.type == 'document')) {
          responseText += '\n\n💡 *Tip: Click the "Browse Documents" button above to view these files.*';
        }
      }
      
      // Add escalation info
      if (response.escalation != null) {
        responseText += '\n\n**Contact:** ${response.escalation!.contactName}';
        if (response.escalation!.contactMethod != null) {
          responseText += '\n**Method:** ${response.escalation!.contactMethod}';
        }
        responseText += '\n**Reason:** ${response.escalation!.reason}';
      }

      // Update the AI message with the response
      final updatedMessage = aiMessage.copyWith(
        text: responseText,
        isMarkdown: true,
      );
      _chatController.updateMessage(updatedMessage);
    } catch (e) {
      print('Error asking question: $e');
      final errorMessage = aiMessage.copyWith(
        text: 'Sorry, I encountered an error while processing your question. Please try again.',
      );
      _chatController.updateMessage(errorMessage);
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }


  void _openResponsibilityAreas() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResponsibilityAreasScreen(
          projectId: widget.projectId,
          projectName: _displayProjectName,
        ),
      ),
    );
  }

  Future<void> _openPublicAccessSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PublicAccessSettingsDialog(
        projectId: widget.projectId,
        currentProject: _currentProject,
      ),
    );

    if (result == true) {
      // Refresh project data after successful update
      await _fetchProjectName();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Public access settings updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPublicKnowledgeBase({String? highlightDocumentId}) {
    if (widget.passcode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to access knowledge base: No passcode available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PublicKnowledgeBaseDialog(
        projectId: widget.projectId,
        passcode: widget.passcode!,
        highlightDocumentId: highlightDocumentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayProjectName ?? 'Loading...'),
        actions: [
          if (_isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                onPressed: _openResponsibilityAreas,
                icon: const Icon(Icons.people_outline),
                tooltip: 'Manage Responsibility Areas',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 16.0),
              child: IconButton(
                onPressed: _openPublicAccessSettings,
                icon: const Icon(Icons.public),
                tooltip: 'Public Access Settings',
              ),
            ),
          ],
          if (!_isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                onPressed: _showPublicKnowledgeBase,
                icon: const Icon(Icons.library_books),
                tooltip: 'Browse Documents',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text('Return to Arcane Forge'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: AiChatWidget(
            currentUser: _currentUser,
            aiUser: _aiUser,
            controller: _chatController,
            onSendMessage: _sendMessage,
            scrollController: _scrollController,
            messageOptions: MessageOptions(
              showUserName: true,
              showTime: true,
              bubbleStyle: BubbleStyle(
                userBubbleColor: theme.primaryColor,
                aiBubbleColor: theme.colorScheme.surface,
                userNameColor: Colors.white,
                aiNameColor: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                userBubbleTopLeftRadius: 16,
                userBubbleTopRightRadius: 4,
                aiBubbleTopLeftRadius: 4,
                aiBubbleTopRightRadius: 16,
                bottomLeftRadius: 16,
                bottomRightRadius: 16,
              ),
            ),
            loadingConfig: LoadingConfig(
              isLoading: _isGenerating,
              typingIndicatorColor: theme.primaryColor,
            ),
            exampleQuestions: _exampleQuestions,
            inputOptions: InputOptions(
              decoration: InputDecoration(
                hintText: 'Ask a question about the project...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              sendButtonIcon: Icons.send_rounded,
              sendButtonColor: theme.primaryColor,
            ),
            enableMarkdownStreaming: true,
          ),
        ),
      ),
    );
  }
}
