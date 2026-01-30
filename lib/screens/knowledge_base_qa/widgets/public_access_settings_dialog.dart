import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/projects_api_service.dart';
import '../../../screens/game_design_assistant/models/project_model.dart';

class PublicAccessSettingsDialog extends StatefulWidget {
  final String projectId;
  final Project? currentProject;

  const PublicAccessSettingsDialog({
    super.key,
    required this.projectId,
    this.currentProject,
  });

  @override
  State<PublicAccessSettingsDialog> createState() =>
      _PublicAccessSettingsDialogState();
}

class _PublicAccessSettingsDialogState
    extends State<PublicAccessSettingsDialog> {
  late bool _isEnabled;
  late TextEditingController _passcodeController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePasscode = true;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.currentProject?.qaExternalAccessEnabled ?? false;
    _passcodeController = TextEditingController(
      text: widget.currentProject?.qaAccessPasscode ?? '',
    );
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_isEnabled && _passcodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Passcode is required when public access is enabled';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final projectsService = ProjectsApiService(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      );

      await projectsService.updateQAPublicAccess(
        projectId: widget.projectId,
        isEnabled: _isEnabled,
        passcode: _isEnabled ? _passcodeController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Public Q&A Access'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allow external users to access this project\'s Q&A with a passcode.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Enable Public Access'),
              value: _isEnabled,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _isEnabled = value;
                        if (!value) {
                          _errorMessage = null;
                        }
                      });
                    },
              contentPadding: EdgeInsets.zero,
            ),
            if (_isEnabled) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passcodeController,
                obscureText: _obscurePasscode,
                decoration: InputDecoration(
                  labelText: 'Access Passcode',
                  hintText: 'Enter a passcode',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePasscode ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePasscode = !_obscurePasscode;
                      });
                    },
                  ),
                  helperText: 'Share this passcode with external users',
                ),
                enabled: !_isLoading,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSettings,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
