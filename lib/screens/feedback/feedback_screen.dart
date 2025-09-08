import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/feedback_provider.dart';
import '../../models/feedback_models.dart' as feedback_models;
import 'feedback_analyze_screen.dart';
import 'package:intl/intl.dart';
import '../../services/projects_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class FeedbackScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const FeedbackScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedFeedbackIds = {};
  bool _selectAll = false;
  late ProjectsApiService _projectsApiService;
  bool _isLoadingProject = true;
  String? _projectError;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApiService();
    // Don't call _loadProjectAndFeedbacks here since provider isn't available yet
    // It will be called from the build method when provider is ready
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

  Future<void> _loadProjectAndFeedbacks(FeedbackProvider? provider) async {
    setState(() {
      _isLoadingProject = true;
      _projectError = null;
    });

    try {
      final project =
          await _projectsApiService.getProjectById(int.parse(widget.projectId));

      final feedbackProvider =
          provider ?? Provider.of<FeedbackProvider>(context, listen: false);
      feedbackProvider.setFeedbackUrl(project.gameFeedbackUrl);

      setState(() {
        _isLoadingProject = false;
      });

      // Load feedbacks after setting the URL
      await feedbackProvider.loadFeedbacks();
    } catch (e) {
      setState(() {
        _isLoadingProject = false;
        _projectError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FeedbackProvider(),
      builder: (context, child) {
        return Consumer<FeedbackProvider>(
          builder: (context, provider, child) {
            // Initialize project data when provider is created (only once)
            if (_isLoadingProject && !_hasInitialized) {
              _hasInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadProjectAndFeedbacks(provider);
              });
            }

            return Scaffold(
              backgroundColor: const Color(0xFF1E1E1E),
              body: Column(
                children: [
                  _buildHeader(context, provider),
                  Expanded(
                    child: _buildContent(context, provider),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, FeedbackProvider provider) {
    final stats = provider.feedbacks.isNotEmpty
        ? provider.getFeedbackStats()
        : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.feedback_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Feedbacks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _hasInitialized = false;
                  });
                  _loadProjectAndFeedbacks(provider);
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Feedbacks',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              if (stats.isNotEmpty) ...[
                _buildStatCard(
                    'Total', stats['total'].toString(), Icons.feedback),
                const SizedBox(width: 12),
                _buildStatCard('This Week', stats['this_week'].toString(),
                    Icons.date_range),
                const SizedBox(width: 12),
                _buildStatCard(
                    'With Email', stats['with_email'].toString(), Icons.email),
              ],
              const Spacer(),

              // Search field
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search feedbacks...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF404040)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF404040)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0078D4)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF404040),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, FeedbackProvider provider) {
    // Show loading state while loading project
    if (_isLoadingProject) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0078D4)),
            SizedBox(height: 16),
            Text(
              'Loading project configuration...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    // Show project error
    if (_projectError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load project configuration',
                style: TextStyle(color: Colors.red, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    _projectError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasInitialized = false;
                  });
                  _loadProjectAndFeedbacks(null);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show message when no feedback URL is configured
    if (!provider.hasFeedbackUrl) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No Feedback URL Configured',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please set the feedback URL in Release Info to view feedbacks for this project.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to Release Info screen (ScreenType.versions)
                Navigator.of(context).pop(); // Go back to project dashboard
                // The user can then navigate to Release Info manually
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Release Info'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0078D4),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Show loading state while loading feedbacks
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0078D4)),
      );
    }

    // Show feedback loading error
    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load feedbacks',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.refreshFeedbacks(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final feedbacks = _searchQuery.isEmpty
        ? provider.feedbacks
        : provider.searchFeedbacks(_searchQuery);

    if (feedbacks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feedback_outlined, color: Colors.white54, size: 48),
            SizedBox(height: 16),
            Text(
              'No feedbacks found',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action bar
        _buildActionBar(context, provider),

        // Feedbacks table
        Expanded(
          child: _buildFeedbacksTable(feedbacks),
        ),

        // Analyze sessions section
        if (provider.analyzeSessions.isNotEmpty)
          _buildAnalyzeSessionsSection(provider),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, FeedbackProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (value) {
              setState(() {
                _selectAll = value ?? false;
                if (_selectAll) {
                  _selectedFeedbackIds.addAll(
                    provider.feedbacks.map((f) => f.id),
                  );
                } else {
                  _selectedFeedbackIds.clear();
                }
              });
            },
            activeColor: const Color(0xFF0078D4),
          ),
          Text(
            'Select All (${_selectedFeedbackIds.length} selected)',
            style: const TextStyle(color: Colors.white),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _selectedFeedbackIds.isNotEmpty
                ? () => _startAnalyzeSession(
                    context, provider, feedback_models.AnalyzeMode.freeDiscuss)
                : null,
            icon: const Icon(Icons.chat),
            label: const Text('Free Discuss'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _selectedFeedbackIds.isNotEmpty
                ? () => _startAnalyzeSession(context, provider,
                    feedback_models.AnalyzeMode.improvementDoc)
                : null,
            icon: const Icon(Icons.analytics),
            label: const Text('Generate Improvement Doc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbacksTable(List<feedback_models.Feedback> feedbacks) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF404040),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 40), // Checkbox space
                Expanded(
                    flex: 1,
                    child: Text('Date',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 4,
                    child: Text('Message',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1,
                    child: Text('Email',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1,
                    child: Text('Notify',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Table body
          Expanded(
            child: ListView.builder(
              itemCount: feedbacks.length,
              itemBuilder: (context, index) {
                final feedback = feedbacks[index];
                final isSelected = _selectedFeedbackIds.contains(feedback.id);

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            _selectedFeedbackIds.add(feedback.id);
                          } else {
                            _selectedFeedbackIds.remove(feedback.id);
                          }
                          _selectAll =
                              _selectedFeedbackIds.length == feedbacks.length;
                        });
                      },
                      activeColor: const Color(0xFF0078D4),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            DateFormat('MMM dd, yyyy')
                                .format(feedback.createdAt),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            feedback.message.length > 100
                                ? '${feedback.message.substring(0, 100)}...'
                                : feedback.message,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            feedback.email ?? 'No email',
                            style: TextStyle(
                              color: feedback.email != null
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Icon(
                            feedback.wantNotify
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: feedback.wantNotify
                                ? const Color(0xFF4CAF50)
                                : Colors.white38,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showFeedbackDetails(context, feedback),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeSessionsSection(FeedbackProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Past Analyze Sessions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...provider.analyzeSessions
              .map((session) => _buildAnalyzeSessionItem(session)),
        ],
      ),
    );
  }

  Widget _buildAnalyzeSessionItem(feedback_models.AnalyzeSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF404040),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            session.mode == feedback_models.AnalyzeMode.freeDiscuss
                ? Icons.chat
                : Icons.analytics,
            color: session.mode == feedback_models.AnalyzeMode.freeDiscuss
                ? const Color(0xFF0078D4)
                : const Color(0xFF4CAF50),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${session.feedbackIds.length} feedbacks • ${DateFormat('MMM dd, yyyy HH:mm').format(session.createdAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openAnalyzeSession(session),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDetails(
      BuildContext context, feedback_models.Feedback feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'Feedback Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(feedback.createdAt)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              if (feedback.email != null) ...[
                Text(
                  'Email: ${feedback.email}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Wants notification: ${feedback.wantNotify ? 'Yes' : 'No'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF404040),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  feedback.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startAnalyzeSession(BuildContext context, FeedbackProvider provider,
      feedback_models.AnalyzeMode mode) {
    final selectedFeedbacks =
        provider.getFeedbacksByIds(_selectedFeedbackIds.toList());

    final session = provider.createAnalyzeSession(
      projectId: widget.projectId,
      mode: mode,
      title: mode == feedback_models.AnalyzeMode.freeDiscuss
          ? 'Free Discussion - ${DateFormat('MMM dd, HH:mm').format(DateTime.now())}'
          : 'Improvement Analysis - ${DateFormat('MMM dd, HH:mm').format(DateTime.now())}',
      feedbackIds: _selectedFeedbackIds.toList(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeedbackAnalyzeScreen(
          session: session,
          feedbacks: selectedFeedbacks,
          projectId: widget.projectId,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  void _openAnalyzeSession(feedback_models.AnalyzeSession session) {
    final provider = Provider.of<FeedbackProvider>(context, listen: false);
    final feedbacks = provider.getFeedbacksByIds(session.feedbackIds);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeedbackAnalyzeScreen(
          session: session,
          feedbacks: feedbacks,
          projectId: widget.projectId,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
