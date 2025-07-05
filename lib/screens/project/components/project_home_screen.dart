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
      
      setState(() {
        _project = project;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
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
                  _project!.hasKnowledgeBase ? Icons.check_circle : Icons.cancel,
                  color: _project!.hasKnowledgeBase ? Colors.green : Colors.orange,
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
        ],
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
                    color: Colors.grey[600],
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
} 