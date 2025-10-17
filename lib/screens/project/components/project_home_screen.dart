import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/projects_api_service.dart';
import '../../game_design_assistant/models/project_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../constants.dart';

class ProjectHomeScreen extends StatefulWidget {
  final String projectId;

  const ProjectHomeScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<ProjectHomeScreen> createState() => _ProjectHomeScreenState();
}

class _ProjectHomeScreenState extends State<ProjectHomeScreen> {
  late ProjectsApiService _apiService;
  Project? _project;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  final TextEditingController _introductionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiService = ProjectsApiService(
      settingsProvider: context.read<SettingsProvider>(),
      authProvider: context.read<AuthProvider>(),
    );
    _loadProject();
  }

  Future<void> _loadProject() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final projectId = int.tryParse(widget.projectId);
      if (projectId == null) {
        throw Exception('Invalid project ID: ${widget.projectId}');
      }

      final project = await _apiService.getProjectById(projectId);

      if (!mounted) return;
      setState(() {
        _project = project;
        _introductionController.text = project.gameIntroduction ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openGameIntroductionEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameIntroductionEditorScreen(
          project: _project!,
          onSave: (updatedIntroduction) async {
            try {
              setState(() => _isSaving = true);

              await _apiService.updateProject(
                projectId: widget.projectId,
                gameIntroduction:
                    updatedIntroduction.isEmpty ? null : updatedIntroduction,
              );

              if (!mounted) return;
              setState(() {
                _project = _project?.copyWith(
                  gameIntroduction:
                      updatedIntroduction.isEmpty ? null : updatedIntroduction,
                );
                _introductionController.text = updatedIntroduction;
                _isSaving = false;
              });

              _showSnackBar('Game introduction updated successfully');
            } catch (e) {
              if (!mounted) return;
              setState(() => _isSaving = false);
              _showSnackBar('Failed to update introduction: ${e.toString()}');
            }
          },
        ),
      ),
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
            // Header
            Row(
              children: [
                Text(
                  "Project Home",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _loadProject,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                  ),
              ],
            ),
            const SizedBox(height: defaultPadding),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading project',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProject,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildProjectDetails();
  }

  Widget _buildProjectDetails() {
    if (_project == null) return const SizedBox();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 32,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _project!.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              'Project ID: ${_project!.id}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _project!.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: defaultPadding),

          // Metadata Cards
          Row(
            children: [
              Expanded(
                child: _buildMetadataCard(
                  'Created',
                  _formatDateTime(_project!.createdAt),
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: _buildMetadataCard(
                  'Last Updated',
                  _project!.updatedAt != null
                      ? _formatDateTime(_project!.updatedAt!)
                      : 'Never',
                  Icons.update,
                ),
              ),
            ],
          ),

          const SizedBox(height: defaultPadding),

          Row(
            children: [
              Expanded(
                child: _buildMetadataCard(
                  'User ID',
                  _project!.userId?.toString() ?? 'Unknown',
                  Icons.person,
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: _buildMetadataCard(
                  'Knowledge Base',
                  _project!.hasKnowledgeBase ? 'Available' : 'Not Set Up',
                  _project!.hasKnowledgeBase
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      _project!.hasKnowledgeBase ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),

          // Dataset ID if available
          if (_project!.difyDatasetId != null) ...[
            const SizedBox(height: defaultPadding),
            _buildMetadataCard(
              'Dataset ID',
              _project!.difyDatasetId!,
              Icons.dataset,
            ),
          ],

          const SizedBox(height: defaultPadding),

          // Game Introduction Card (moved to bottom)
          _buildGameIntroductionCard(),
        ],
      ),
    );
  }

  Widget _buildGameIntroductionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 24,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Game Introduction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Tooltip(
                  message: 'Edit in full screen',
                  child: IconButton(
                    onPressed: _openGameIntroductionEditor,
                    icon: const Icon(Icons.edit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openGameIntroductionEditor,
              child: Container(
                width: double.infinity,
                height: 240, // Fixed height for ~10 lines
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800.withOpacity(0.3)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _project?.gameIntroduction?.isNotEmpty == true
                        ? _project!.gameIntroduction!
                        : 'No game introduction provided. Click here to add one.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _project?.gameIntroduction?.isNotEmpty == true
                              ? null
                              : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          fontStyle:
                              _project?.gameIntroduction?.isNotEmpty == true
                                  ? null
                                  : FontStyle.italic,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: color ?? primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _introductionController.dispose();
    super.dispose();
  }
}

class GameIntroductionEditorScreen extends StatefulWidget {
  final Project project;
  final Function(String) onSave;

  const GameIntroductionEditorScreen({
    Key? key,
    required this.project,
    required this.onSave,
  }) : super(key: key);

  @override
  State<GameIntroductionEditorScreen> createState() =>
      _GameIntroductionEditorScreenState();
}

class _GameIntroductionEditorScreenState
    extends State<GameIntroductionEditorScreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.project.gameIntroduction ?? '');
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasChanges =
        _controller.text != (widget.project.gameIntroduction ?? '');
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Game Introduction'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: _hasChanges ? _save : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _hasChanges ? primaryColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project info
              Row(
                children: [
                  Icon(Icons.folder_open, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade900.withOpacity(0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.shade700
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade300
                          : Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Write a detailed introduction about your game. This will be used for feedback analysis and other features.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText:
                        'Enter a detailed introduction about your game...\n\nDescribe the gameplay, story, features, target audience, and any other relevant information.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade400,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900.withOpacity(0.2)
                        : Theme.of(context).cardColor.withOpacity(0.04),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

              const SizedBox(height: 16),

              // Character count and actions
              Row(
                children: [
                  Text(
                    '${_controller.text.length} characters',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                  ),
                  const Spacer(),
                  if (_hasChanges) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _controller.text =
                              widget.project.gameIntroduction ?? '';
                        });
                      },
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }
}
