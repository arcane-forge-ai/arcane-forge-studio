import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_constants.dart' as app_utils;
import '../../services/projects_api_service.dart';
import '../game_design_assistant/models/project_model.dart';
import '../project/project_dashboard_screen.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  /// Get fresh ProjectsApiService instance with current settings
  ProjectsApiService _getProjectsApiService() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure we have a valid auth session before making API calls
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        try {
          // Verify and refresh session if needed
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          print('Session refresh check: $e');
          // Continue anyway - the API interceptor will handle it
        }
      }
      
      _projects = await _getProjectsApiService().getProjects();
    } catch (e) {
      print('Error loading projects: $e');
      _errorMessage =
          'Failed to load projects. Please check your connection and try again.';
      _projects = [];
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createNewProject() async {
    // Clear focus to prevent keyboard issues
    FocusScope.of(context).unfocus();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _NewProjectDialog(),
    );

    if (result != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        final newProject = await _getProjectsApiService().createProject(
          name: result['name']!,
          description: result['description']!,
        );

        setState(() {
          _projects.add(newProject);
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Project "${newProject.name}" created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create project: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editProject(Project project) async {
    // Clear focus to prevent keyboard issues
    FocusScope.of(context).unfocus();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _EditProjectDialog(project: project),
    );

    if (result != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        final updatedProject = await _getProjectsApiService().updateProject(
          projectId: project.id,
          name: result['name'],
          description: result['description'],
        );

        setState(() {
          // Update the project in the local list
          final index = _projects.indexWhere((p) => p.id == project.id);
          if (index != -1) {
            _projects[index] = updatedProject;
          }
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${updatedProject.name}" updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update project: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    // Clear focus to prevent keyboard issues
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
            'Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement API delete when available
      // For now, just remove from local list
      setState(() {
        _projects.removeWhere((p) => p.id == project.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Project "${project.name}" deleted (Note: Delete API not implemented yet)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openProject(Project project) {
    // Clear focus to prevent keyboard issues
    FocusScope.of(context).unfocus();

    // Navigate to project dashboard with this project
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProjectDashboardScreen(
          projectId: project.id,
          projectName: project.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Projects',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Manage and organize your game development projects',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _loadProjects,
                            icon: Icon(
                              Icons.refresh,
                              color: colorScheme.primary,
                            ),
                            tooltip: 'Refresh Projects',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Projects Grid
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount:
                              _projects.length + 1, // +1 for "New Project" card
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // "New Project" card
                              return _buildNewProjectCard();
                            } else {
                              // Project card
                              final project = _projects[index - 1];
                              return _buildProjectCard(project);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Projects',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProjects,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewProjectCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: _createNewProject,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Project',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new game project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? Colors.grey[800]! : Colors.white,
                isDark ? Colors.grey[700]! : Colors.grey[50]!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project header with menu
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                      PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editProject(project);
                        } else if (value == 'delete') {
                          _deleteProject(project);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit Project'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Project'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Project description
                Expanded(
                  child: Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 12),

                // Project metadata
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app_utils.DateUtils.formatDate(project.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black38,
                      ),
                    ),
                    const Spacer(),
                    if (project.hasKnowledgeBase)
                      Icon(
                        Icons.library_books,
                        size: 14,
                        color: Colors.green,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _EditProjectDialog extends StatefulWidget {
  final Project project;

  const _EditProjectDialog({required this.project});

  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.project.name);
  late final _descriptionController = TextEditingController(text: widget.project.description);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Project'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'Enter project name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter project description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
              });
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _NewProjectDialog extends StatefulWidget {
  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Project'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'Enter project name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter project description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
