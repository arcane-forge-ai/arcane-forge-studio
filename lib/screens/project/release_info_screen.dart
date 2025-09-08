import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../services/projects_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class ReleaseInfoScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ReleaseInfoScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ReleaseInfoScreen> createState() => _ReleaseInfoScreenState();
}

class _ReleaseInfoScreenState extends State<ReleaseInfoScreen> {
  final TextEditingController _gameLinkController = TextEditingController();
  final TextEditingController _feedbackLinkController = TextEditingController();

  bool _isEditingGameLink = false;
  bool _isEditingFeedbackLink = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  late ProjectsApiService _projectsApiService;

  @override
  void initState() {
    super.initState();
    _initializeApiService();
    _loadProject();
  }

  void _initializeApiService() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _projectsApiService = ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  Future<void> _loadProject() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final project =
          await _projectsApiService.getProjectById(int.parse(widget.projectId));

      setState(() {
        _gameLinkController.text = project.gameReleaseUrl ?? '';
        _feedbackLinkController.text = project.gameFeedbackUrl ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _saveGameLink() async {
    final link = _gameLinkController.text.trim();
    if (link.isNotEmpty && !_isValidUrl(link)) {
      _showSnackBar('Please enter a valid URL for Game Link');
      return;
    }
    await _updateProject(gameReleaseUrl: link.isEmpty ? null : link);
    setState(() => _isEditingGameLink = false);
  }

  Future<void> _saveFeedbackLink() async {
    final link = _feedbackLinkController.text.trim();
    if (link.isNotEmpty && !_isValidUrl(link)) {
      _showSnackBar('Please enter a valid URL for Feedback Link');
      return;
    }
    await _updateProject(gameFeedbackUrl: link.isEmpty ? null : link);
    setState(() => _isEditingFeedbackLink = false);
  }

  Future<void> _updateProject(
      {String? gameReleaseUrl, String? gameFeedbackUrl}) async {
    try {
      setState(() => _isSaving = true);

      await _projectsApiService.updateProject(
        projectId: widget.projectId,
        gameReleaseUrl: gameReleaseUrl,
        gameFeedbackUrl: gameFeedbackUrl,
      );

      setState(() {
        _isSaving = false;
      });

      _showSnackBar('Release info updated successfully');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to update release info: ${e.toString()}');
    }
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.hasAuthority;
  }

  Future<void> _openUrl(String value) async {
    final link = value.trim();
    if (!_isValidUrl(link)) {
      _showSnackBar('Invalid URL');
      return;
    }
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Could not open the link');
    }
  }

  Future<void> _copyToClipboard(String value, {String label = 'Link'}) async {
    if (value.trim().isEmpty) {
      _showSnackBar('$label is empty');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value.trim()));
    _showSnackBar('$label copied to clipboard');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 28, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Release Info',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadProject,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load release info',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadProject, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLinkCard(
                        title: 'Game Link',
                        icon: Icons.videogame_asset,
                        controller: _gameLinkController,
                        isEditing: _isEditingGameLink,
                        onToggleEdit: () {
                          if (_isEditingGameLink) {
                            _saveGameLink();
                          } else {
                            setState(() => _isEditingGameLink = true);
                          }
                        },
                        onOpen: () => _openUrl(_gameLinkController.text),
                        onCopy: () => _copyToClipboard(_gameLinkController.text,
                            label: 'Game link'),
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildLinkCard(
                        title: 'Feedback Link',
                        icon: Icons.feedback_outlined,
                        controller: _feedbackLinkController,
                        isEditing: _isEditingFeedbackLink,
                        onToggleEdit: () {
                          if (_isEditingFeedbackLink) {
                            _saveFeedbackLink();
                          } else {
                            setState(() => _isEditingFeedbackLink = true);
                          }
                        },
                        onOpen: () => _openUrl(_feedbackLinkController.text),
                        onCopy: () => _copyToClipboard(
                            _feedbackLinkController.text,
                            label: 'Feedback link'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onToggleEdit,
    required VoidCallback onOpen,
    required VoidCallback onCopy,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Tooltip(
                  message: isEditing ? 'Save' : 'Edit',
                  child: IconButton(
                    onPressed: _isSaving ? null : onToggleEdit,
                    icon: Icon(isEditing ? Icons.check : Icons.edit),
                  ),
                ),
                Tooltip(
                  message: 'Open Link',
                  child: IconButton(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
                Tooltip(
                  message: 'Copy to clipboard',
                  child: IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              readOnly: !isEditing,
              onTap: !isEditing && controller.text.isNotEmpty
                  ? () => _openUrl(controller.text)
                  : null,
              decoration: InputDecoration(
                hintText: 'https://example.com/...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey.shade400,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor.withOpacity(0.04),
                suffixIcon: isEditing
                    ? IconButton(
                        tooltip: 'Save',
                        icon: const Icon(Icons.check),
                        onPressed: _isSaving ? null : onToggleEdit,
                      )
                    : null,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!isEditing && controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _isValidUrl(controller.text)
                          ? Icons.verified
                          : Icons.error_outline,
                      size: 16,
                      color: _isValidUrl(controller.text)
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isValidUrl(controller.text)
                          ? 'Valid URL'
                          : 'Invalid URL',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameLinkController.dispose();
    _feedbackLinkController.dispose();
    super.dispose();
  }
}
