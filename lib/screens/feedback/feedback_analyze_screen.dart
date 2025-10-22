import 'package:flutter/material.dart';
import '../../models/feedback_models.dart' as feedback_models;
import '../../models/feedback_analysis_models.dart';
import '../../services/feedback_analysis_service.dart';
import '../../services/projects_api_service.dart';
import '../../services/mutation_api_service.dart';
import '../../widgets/mutation_edit_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../controllers/menu_app_controller.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/mutation_design_service.dart';
import 'package:intl/intl.dart';

class FeedbackAnalyzeScreen extends StatefulWidget {
  final feedback_models.AnalyzeSession session;
  final List<feedback_models.Feedback> feedbacks;
  final String projectId;
  final String projectName;
  final String? runId; // Optional: API run ID to load existing results

  const FeedbackAnalyzeScreen({
    Key? key,
    required this.session,
    required this.feedbacks,
    required this.projectId,
    required this.projectName,
    this.runId,
  }) : super(key: key);

  @override
  State<FeedbackAnalyzeScreen> createState() => _FeedbackAnalyzeScreenState();
}

class _FeedbackAnalyzeScreenState extends State<FeedbackAnalyzeScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _hasInitialized = false;
  String? _errorMessage;

  // Analysis results
  FeedbackAnalysisResult? _analysisResult;
  List<FeedbackCluster> _clusters = [];
  List<FeedbackOpportunity> _opportunities = [];
  List<MutationBrief> _mutationBriefs = [];

  // Mutation brief selection
  final Set<int> _selectedMutationBriefIds = {};
  bool _selectAllMutationBriefs = false;

  // Services
  late FeedbackAnalysisService _analysisService;
  late ProjectsApiService _projectsService;
  late MutationApiService _mutationService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnalyzeSession();
    });
  }

  void _initializeServices() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _analysisService = FeedbackAnalysisService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    _projectsService = ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    _mutationService = MutationApiService(
      settingsProvider: settingsProvider,
    );
  }

  void _initializeAnalyzeSession() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    // First, try to load existing analysis if runId is provided
    if (widget.runId != null) {
      await _loadExistingAnalysis();
      return;
    }

    // For improvement doc mode, start analysis immediately
    if (widget.session.mode == feedback_models.AnalyzeMode.improvementDoc) {
      await _generateImprovementDocument();
    }
  }

  Future<void> _loadExistingAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final projectId = int.parse(widget.projectId);
      final runDetails = await _analysisService.getFeedbackAnalysis(
        projectId: projectId,
        runId: widget.runId!,
      );

      setState(() {
        _clusters = runDetails.clusters;
        _opportunities = runDetails.opportunities;
        _mutationBriefs = runDetails.mutationBriefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading existing analysis: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateImprovementDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Get project details to fetch game introduction
      final projectId = int.parse(widget.projectId);
      final project = await _projectsService.getProjectById(projectId);

      if (project.gameIntroduction == null ||
          project.gameIntroduction!.isEmpty) {
        throw Exception(
            'Game introduction is required but not set in project settings. Please add a game introduction in the Release Info section.');
      }

      // 2. Convert feedbacks to API format
      final feedbacksData = widget.feedbacks
          .map((feedback) => {
                'id': feedback.id,
                'message': feedback.message,
                'created_at': feedback.createdAt.toIso8601String(),
                'game_slug': feedback.gameSlug,
                'email': feedback.email,
                'want_notify': feedback.wantNotify,
              })
          .toList();

      // 3. Call feedback analysis API
      final result = await _analysisService.createFeedbackAnalysis(
        projectId: projectId,
        gameIntroduction: project.gameIntroduction!,
        feedbacks: feedbacksData,
      );

      // 4. Update state with results
      setState(() {
        _analysisResult = result;
        _clusters = result.clusters;
        _opportunities = result.opportunities;
        _mutationBriefs = result.mutationBriefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating improvement document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Improvement Analysis',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              '${widget.feedbacks.length} feedbacks • ${widget.projectName}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _regenerateAnalysis,
              tooltip: 'Regenerate Analysis',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    // Check if we have analysis results (either from new analysis or loaded existing)
    final hasResults = _analysisResult != null || 
                      _clusters.isNotEmpty || 
                      _opportunities.isNotEmpty || 
                      _mutationBriefs.isNotEmpty;

    if (!hasResults) {
      return _buildInitialState();
    }

    return _buildAnalysisResults();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing Feedbacks...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing ${widget.feedbacks.length} feedbacks to generate insights',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'This may take a few moments while we:\n• Cluster similar feedback themes\n• Identify improvement opportunities\n• Generate mutation briefs for next iteration',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Analysis Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _generateImprovementDocument();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.analytics,
            color: Color(0xFF4CAF50),
            size: 64,
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready to Analyze',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Click below to start analyzing ${widget.feedbacks.length} feedbacks',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _generateImprovementDocument,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: const Color(0xFF2A2A2A),
            child: TabBar(
              indicatorColor: const Color(0xFF4CAF50),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: const Icon(Icons.group_work),
                  text: 'Clusters (${_clusters.length})',
                ),
                Tab(
                  icon: const Icon(Icons.lightbulb_outline),
                  text: 'Opportunities (${_opportunities.length})',
                ),
                Tab(
                  icon: const Icon(Icons.science),
                  text: 'Mutations (${_mutationBriefs.length})',
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildClustersTab(),
                _buildOpportunitiesTab(),
                _buildMutationBriefsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClustersTab() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            'Feedback Clusters',
            'Similar themes grouped together',
            Icons.group_work,
          ),
          const SizedBox(height: 16),
          ..._clusters.map((cluster) => _buildClusterCard(cluster)),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesTab() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            'Improvement Opportunities',
            'Actionable insights from player feedback',
            Icons.lightbulb_outline,
          ),
          const SizedBox(height: 16),
          ..._opportunities
              .map((opportunity) => _buildOpportunityCard(opportunity)),
        ],
      ),
    );
  }

  Widget _buildMutationBriefsTab() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Action bar for mutation briefs
          if (_mutationBriefs.isNotEmpty) _buildMutationBriefsActionBar(),
          
          // Mutation briefs list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(
                  'Mutation Briefs',
                  'Next iteration features and changes',
                  Icons.science,
                ),
                const SizedBox(height: 16),
                ..._mutationBriefs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final brief = entry.value;
                  return _buildMutationBriefCard(brief, index);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterCard(FeedbackCluster cluster) {
    final isNegative = (cluster.negPct ?? 0) > 0.5;
    final sentimentColor = isNegative ? Colors.red : Colors.green;
    final sentimentIcon =
        isNegative ? Icons.sentiment_dissatisfied : Icons.sentiment_satisfied;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and metrics
          Row(
            children: [
              Expanded(
                child: Text(
                  cluster.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cluster.count} feedback${cluster.count != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (cluster.negPct != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(sentimentIcon, color: sentimentColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(cluster.negPct! * 100).toInt()}% negative sentiment',
                  style: TextStyle(
                    color: sentimentColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          if (cluster.example != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Example feedback:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${cluster.example}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(FeedbackOpportunity opportunity) {
    final priority = opportunity.metadata['priority'] as String?;
    final effort = opportunity.metadata['effort'] as String?;

    Color priorityColor = Colors.grey;
    if (priority == 'high') priorityColor = Colors.orange;
    if (priority == 'critical') priorityColor = Colors.red;
    if (priority == 'medium') priorityColor = Colors.yellow;
    if (priority == 'low') priorityColor = Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority and effort badges
          Row(
            children: [
              if (priority != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (priority != null && effort != null) const SizedBox(width: 8),
              if (effort != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$effort effort'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Statement
          Text(
            opportunity.statement,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutationBriefsActionBar() {
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
            value: _selectAllMutationBriefs,
            onChanged: (value) {
              setState(() {
                _selectAllMutationBriefs = value ?? false;
                if (_selectAllMutationBriefs) {
                  _selectedMutationBriefIds.addAll(
                    List.generate(_mutationBriefs.length, (index) => index),
                  );
                } else {
                  _selectedMutationBriefIds.clear();
                }
              });
            },
            activeColor: const Color(0xFF0078D4),
          ),
          Text(
            'Select All (${_selectedMutationBriefIds.length} selected)',
            style: const TextStyle(color: Colors.white),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _addNewMutation(),
            icon: const Icon(Icons.add),
            label: const Text('Add New Mutation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _selectedMutationBriefIds.isNotEmpty
                ? () => _startMutationDesign()
                : null,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Start Mutation Design'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutationBriefCard(MutationBrief brief, int index) {
    final isSelected = _selectedMutationBriefIds.contains(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF6B35) : const Color(0xFF404040),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox and title row with actions
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedMutationBriefIds.add(index);
                    } else {
                      _selectedMutationBriefIds.remove(index);
                    }
                    _selectAllMutationBriefs =
                        _selectedMutationBriefIds.length == _mutationBriefs.length;
                  });
                },
                activeColor: const Color(0xFFFF6B35),
              ),
              Expanded(
                child: Text(
                  brief.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editMutation(brief, index),
                    icon: const Icon(Icons.edit, size: 18),
                    color: const Color(0xFF4CAF50),
                    tooltip: 'Edit mutation',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () => _deleteMutation(brief, index),
                    icon: const Icon(Icons.delete, size: 18),
                    color: const Color(0xFFFF5252),
                    tooltip: 'Delete mutation',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (brief.impact != null)
                    _buildMetricChip(
                        'Impact', brief.impact.toString(), Colors.green),
                  if (brief.effort != null) ...[
                    const SizedBox(height: 4),
                    _buildMetricChip(
                        'Effort', brief.effort.toString(), Colors.orange),
                  ],
                ],
              ),
            ],
          ),

          if (brief.novelty != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getNoveltyColor(brief.novelty!).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                brief.novelty!.toUpperCase(),
                style: TextStyle(
                  color: _getNoveltyColor(brief.novelty!),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          if (brief.rationale != null) ...[
            const SizedBox(height: 12),
            Text(
              brief.rationale!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],

          if (brief.changes != null && brief.changes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Proposed Changes:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...brief.changes!.map((change) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: Color(0xFF4CAF50)),
                      ),
                      Expanded(
                        child: Text(
                          change,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getNoveltyColor(String novelty) {
    switch (novelty.toLowerCase()) {
      case 'innovative':
        return Colors.orange;
      case 'standard':
        return Colors.blue;
      case 'incremental':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _regenerateAnalysis() {
    setState(() {
      _analysisResult = null;
      _clusters = [];
      _opportunities = [];
      _mutationBriefs = [];
    });
    _generateImprovementDocument();
  }

  Future<void> _startMutationDesign() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF2A2A2A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text(
                'Preparing mutation design data...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Get selected mutation briefs
      final selectedBriefs = _selectedMutationBriefIds
          .map((index) => _mutationBriefs[index])
          .toList();
      
      // Fetch project data
      final project = await _projectsService.getProjectById(int.parse(widget.projectId));
      
      // Fetch game introduction
      final gameIntroduction = project.gameIntroduction?.isNotEmpty == true 
          ? project.gameIntroduction! 
          : "Not Available at this moment";
      
      // Fetch code map content
      String codeMapContent = "Not Available at this moment";
      if (project.codeMapUrl?.isNotEmpty == true) {
        try {
          final codeMapResponse = await http.get(Uri.parse(project.codeMapUrl!));
          if (codeMapResponse.statusCode == 200) {
            codeMapContent = codeMapResponse.body;
          }
        } catch (e) {
          // Keep default "Not Available at this moment"
        }
      }
      
      // Load mutation design prompt
      String mutationPrompt = "Not Available at this moment";
      try {
        mutationPrompt = await rootBundle.loadString('assets/requests/mutation_design_prompt.md');
      } catch (e) {
        // Keep default "Not Available at this moment"
      }
      
      // Compose mutation brief summaries
      final mutationBriefSummaries = selectedBriefs.map((brief) {
        final changes = brief.changes?.join('\n- ') ?? 'No specific changes listed';
        return """Title: ${brief.title}
Rationale: ${brief.rationale ?? 'No rationale provided'}
Impact: ${brief.impact ?? 'Not specified'}
Effort: ${brief.effort ?? 'Not specified'}
Novelty: ${brief.novelty ?? 'Not specified'}
Changes:
- $changes""";
      }).join('\n\n---\n\n');
      
      // Compose the full message
      final DateTime now = DateTime.now();
      final String sessionTitle = "${DateFormat('yy-MM-dd-HH-mm').format(now)} Mutation Design";
      
      final String composedMessage = """=====Game Introduction=====
$gameIntroduction

=====Code Map=====
$codeMapContent

=====Mutation Brief Summaries=====
$mutationBriefSummaries

$mutationPrompt""";

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Navigate to Game Design Assistant
      if (mounted) {
        final menuController = Provider.of<MenuAppController>(context, listen: false);
        menuController.changeScreen(ScreenType.gameDesignAssistant);
        
        // Store the composed message and session title for the Game Design Assistant to pick up
        MutationDesignService().setMutationDesignData(composedMessage, sessionTitle);
        
        // Navigate back to project dashboard so the menu controller can switch screens
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing mutation design: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Mutation CRUD operations
  Future<void> _addNewMutation() async {
    final runId = widget.runId ?? '';
    if (runId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No analysis run selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => MutationEditDialog(
        runId: runId,
        onSaved: (mutationData) async {
          return await _createMutation(mutationData);
        },
      ),
    );
  }

  Future<void> _editMutation(MutationBrief mutation, int index) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => MutationEditDialog(
        mutation: mutation,
        runId: mutation.runId,
        onSaved: (mutationData) async {
          return await _updateMutation(mutation.id, mutationData);
        },
      ),
    );
  }

  Future<void> _deleteMutation(MutationBrief mutation, int index) async {
    final confirmed = await _showDeleteConfirmationDialog(mutation.title);
    if (confirmed) {
      await _performDeleteMutation(mutation.id);
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String mutationTitle) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Delete Mutation Brief',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$mutationTitle"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _createMutation(Map<String, dynamic> mutationData) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4CAF50),
          ),
        ),
      );

      final changes = mutationData['changes'] as List<String>?;
      
      await _mutationService.createMutation(
        projectId: int.parse(widget.projectId),
        runId: mutationData['runId'],
        title: mutationData['title'],
        rationale: mutationData['rationale'],
        changes: changes,
        impact: mutationData['impact'],
        effort: mutationData['effort'],
        novelty: mutationData['novelty'],
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Refresh the list
      await _loadExistingAnalysis();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mutation brief created successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
      
      return true; // Success
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating mutation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return false; // Failed
    }
  }

  Future<bool> _updateMutation(int mutationId, Map<String, dynamic> mutationData) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4CAF50),
          ),
        ),
      );

      final changes = mutationData['changes'] as List<String>?;
      
      await _mutationService.updateMutation(
        projectId: int.parse(widget.projectId),
        mutationId: mutationId,
        title: mutationData['title'],
        rationale: mutationData['rationale'],
        changes: changes,
        impact: mutationData['impact'],
        effort: mutationData['effort'],
        novelty: mutationData['novelty'],
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Refresh the list
      await _loadExistingAnalysis();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mutation brief updated successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
      
      return true; // Success
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating mutation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return false; // Failed
    }
  }

  Future<void> _performDeleteMutation(int mutationId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF5252),
          ),
        ),
      );

      await _mutationService.deleteMutation(
        projectId: int.parse(widget.projectId),
        mutationId: mutationId,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Refresh the list
      await _loadExistingAnalysis();

      // Clear selection if the deleted mutation was selected
      setState(() {
        _selectedMutationBriefIds.clear();
        _selectAllMutationBriefs = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mutation brief deleted successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting mutation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
