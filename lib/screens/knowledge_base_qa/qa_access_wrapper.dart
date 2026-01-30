import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/projects_api_service.dart';
import '../game_design_assistant/models/project_model.dart';
import 'knowledge_base_qa_screen.dart';
import 'qa_not_available_screen.dart';
import 'widgets/passcode_prompt_dialog.dart';

/// Wrapper widget that handles access control for Q&A screen
/// - Authenticated users: Direct access
/// - Unauthenticated users: Check public access and prompt for passcode
class QAAccessWrapper extends StatefulWidget {
  final String projectId;

  const QAAccessWrapper({
    super.key,
    required this.projectId,
  });

  @override
  State<QAAccessWrapper> createState() => _QAAccessWrapperState();
}

class _QAAccessWrapperState extends State<QAAccessWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  Project? _project;
  String? _errorMessage;
  String? _verifiedPasscode;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isAuthenticated = authProvider.isAuthenticated;
    });

    // If authenticated, show screen directly
    if (_isAuthenticated) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // If not authenticated, fetch project to check public access
    await _fetchProject();
  }

  Future<void> _fetchProject() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final projectsService = ProjectsApiService(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      );

      final project = await projectsService.getProjectById(int.parse(widget.projectId));
      
      setState(() {
        _project = project;
        _isLoading = false;
      });

      // If public access is enabled, show passcode prompt
      if (project.qaExternalAccessEnabled) {
        if (mounted) {
          _showPasscodePrompt();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load project: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _showPasscodePrompt() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasscodePromptDialog(
        projectId: widget.projectId,
        onSubmit: (passcode) async {
          // Validate the entered passcode against the project's stored passcode
          if (_project?.qaAccessPasscode == null) {
            throw Exception('Access code is not configured for this project');
          }
          
          if (passcode != _project!.qaAccessPasscode) {
            throw Exception('Invalid access code');
          }
          
          // Passcode is valid, store it and close dialog
          setState(() {
            _verifiedPasscode = passcode;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _checkAccess();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Authenticated user - show screen directly
    if (_isAuthenticated) {
      return KnowledgeBaseQAScreen(
        projectId: widget.projectId,
      );
    }

    // Unauthenticated user
    if (_project == null || !_project!.qaExternalAccessEnabled) {
      // Public access not enabled
      return const QANotAvailableScreen();
    }

    // Public access enabled and passcode verified
    if (_verifiedPasscode != null) {
      return KnowledgeBaseQAScreen(
        projectId: widget.projectId,
        projectName: _project!.name,
        passcode: _verifiedPasscode,
      );
    }

    // Should not reach here as passcode prompt is shown automatically
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
