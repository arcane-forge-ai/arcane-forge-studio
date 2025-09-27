import 'package:dio/dio.dart';
import '../models/feedback_analysis_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class FeedbackAnalysisService {
  static String get baseUrl => 'http://localhost:8000';

  final SettingsProvider? _settingsProvider;
  final Dio _dio;

  FeedbackAnalysisService({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  })  : _settingsProvider = settingsProvider,
        _dio = Dio() {
    _dio.options.baseUrl = '$baseUrl/api/v1';
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout =
        const Duration(seconds: 120); // Longer timeout for analysis
  }

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? true;

  /// Create a new feedback analysis
  Future<FeedbackAnalysisResult> createFeedbackAnalysis({
    required int projectId,
    required String gameIntroduction,
    required List<Map<String, dynamic>> feedbacks,
  }) async {
    if (_useMockMode) {
      return _mockCreateFeedbackAnalysis(
          projectId, gameIntroduction, feedbacks);
    }

    final url = '/projects/$projectId/feedback/analysis';
    final requestBody = {
      'game_introduction': gameIntroduction,
      'feedbacks': feedbacks,
    };

    try {
      final response = await _dio.post(url, data: requestBody);

      if (response.statusCode == 200) {
        return FeedbackAnalysisResult.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to create feedback analysis: ${response.statusCode}');
      }
    } catch (e) {
      print('Feedback Analysis API Error: $e');
      print('Request URL: $url');
      print('Request Body: $requestBody');
      rethrow;
    }
  }

  /// Get feedback clusters for a project
  Future<ClusterListResponse> getClusters({
    required int projectId,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_useMockMode) {
      return _mockGetClusters(projectId, runId);
    }

    final url = '/projects/$projectId/feedback/clusters';
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (runId != null) queryParams['run_id'] = runId;

    try {
      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        return ClusterListResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to get clusters: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Clusters API Error: $e');
      rethrow;
    }
  }

  /// Get feedback opportunities for a project
  Future<OpportunityListResponse> getOpportunities({
    required int projectId,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_useMockMode) {
      return _mockGetOpportunities(projectId, runId);
    }

    final url = '/projects/$projectId/feedback/opportunities';
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (runId != null) queryParams['run_id'] = runId;

    try {
      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        return OpportunityListResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to get opportunities: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Opportunities API Error: $e');
      rethrow;
    }
  }

  /// Get mutation briefs for a project
  Future<MutationBriefListResponse> getMutationBriefs({
    required int projectId,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_useMockMode) {
      return _mockGetMutationBriefs(projectId, runId);
    }

    final url = '/projects/$projectId/feedback/mutation-briefs';
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (runId != null) queryParams['run_id'] = runId;

    try {
      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        return MutationBriefListResponse.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to get mutation briefs: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Mutation Briefs API Error: $e');
      rethrow;
    }
  }

  /// Fetch feedbacks from a URL
  Future<List<Map<String, dynamic>>> fetchFeedbacksFromUrl(
      String feedbackUrl) async {
    try {
      final response = await _dio.get(feedbackUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data.containsKey('feedbacks')) {
          return (data['feedbacks'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Invalid feedback data format');
        }
      } else {
        throw Exception('Failed to fetch feedbacks: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch Feedbacks Error: $e');
      print('Feedback URL: $feedbackUrl');
      rethrow;
    }
  }

  /// List existing feedback analysis runs for a project
  Future<FeedbackRunListResponse> listFeedbackAnalysisRuns({
    required int projectId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_useMockMode) {
      return _mockListFeedbackAnalysisRuns(projectId, status, limit, offset);
    }

    final url = '/projects/$projectId/feedback/analysis';
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) queryParams['status'] = status;

    try {
      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        return FeedbackRunListResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to list feedback analysis runs: ${response.statusCode}');
      }
    } catch (e) {
      print('List Feedback Analysis Runs API Error: $e');
      print('Request URL: $url');
      print('Query Params: $queryParams');
      rethrow;
    }
  }

  /// Get detailed feedback analysis run with results
  Future<FeedbackRunDetailResponse> getFeedbackAnalysis({
    required int projectId,
    required String runId,
  }) async {
    if (_useMockMode) {
      return _mockGetFeedbackAnalysis(projectId, runId);
    }

    final url = '/projects/$projectId/feedback/analysis/$runId';

    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return FeedbackRunDetailResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to get feedback analysis: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Feedback Analysis API Error: $e');
      print('Request URL: $url');
      rethrow;
    }
  }

  // Mock data methods for development
  Future<FeedbackAnalysisResult> _mockCreateFeedbackAnalysis(
    int projectId,
    String gameIntroduction,
    List<Map<String, dynamic>> feedbacks,
  ) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 3));

    return FeedbackAnalysisResult(
      runId: 'mock_run_${DateTime.now().millisecondsSinceEpoch}',
      status: 'completed',
      clusters: _mockClusters(),
      opportunities: _mockOpportunities(),
      mutationBriefs: _mockMutationBriefsData(),
    );
  }

  Future<ClusterListResponse> _mockGetClusters(
      int projectId, String? runId) async {
    return ClusterListResponse(
      clusters: _mockClusters(),
      total: 4,
      limit: 50,
      offset: 0,
    );
  }

  Future<OpportunityListResponse> _mockGetOpportunities(
      int projectId, String? runId) async {
    return OpportunityListResponse(
      opportunities: _mockOpportunities(),
      total: 3,
      limit: 50,
      offset: 0,
    );
  }

  Future<MutationBriefListResponse> _mockGetMutationBriefs(
      int projectId, String? runId) async {
    return MutationBriefListResponse(
      mutationBriefs: _mockMutationBriefsData(),
      total: 3,
      limit: 50,
      offset: 0,
    );
  }

  List<FeedbackCluster> _mockClusters() {
    return [
      FeedbackCluster(
        id: 1,
        projectId: 1,
        runId: 'mock_run',
        name: 'UI/UX Issues',
        count: 15,
        negPct: 0.8,
        example: 'The inventory system is confusing and hard to navigate',
        metadata: {'severity': 'high'},
        createdAt: DateTime.now(),
      ),
      FeedbackCluster(
        id: 2,
        projectId: 1,
        runId: 'mock_run',
        name: 'Performance Problems',
        count: 12,
        negPct: 0.9,
        example: 'Game lags during combat scenes',
        metadata: {'severity': 'critical'},
        createdAt: DateTime.now(),
      ),
      FeedbackCluster(
        id: 3,
        projectId: 1,
        runId: 'mock_run',
        name: 'Positive Feedback',
        count: 8,
        negPct: 0.1,
        example: 'Love the art style and music!',
        metadata: {'sentiment': 'positive'},
        createdAt: DateTime.now(),
      ),
      FeedbackCluster(
        id: 4,
        projectId: 1,
        runId: 'mock_run',
        name: 'Gameplay Balance',
        count: 10,
        negPct: 0.7,
        example: 'Some enemies are too difficult early in the game',
        metadata: {'category': 'balance'},
        createdAt: DateTime.now(),
      ),
    ];
  }

  List<FeedbackOpportunity> _mockOpportunities() {
    return [
      FeedbackOpportunity(
        id: 1,
        projectId: 1,
        runId: 'mock_run',
        statement:
            'Redesign inventory system with better categorization and search functionality',
        metadata: {'priority': 'high', 'effort': 'medium'},
        createdAt: DateTime.now(),
      ),
      FeedbackOpportunity(
        id: 2,
        projectId: 1,
        runId: 'mock_run',
        statement:
            'Optimize rendering pipeline to improve performance during combat',
        metadata: {'priority': 'critical', 'effort': 'high'},
        createdAt: DateTime.now(),
      ),
      FeedbackOpportunity(
        id: 3,
        projectId: 1,
        runId: 'mock_run',
        statement: 'Add difficulty settings and enemy scaling options',
        metadata: {'priority': 'medium', 'effort': 'low'},
        createdAt: DateTime.now(),
      ),
    ];
  }

  List<MutationBrief> _mockMutationBriefsData() {
    return [
      MutationBrief(
        id: 1,
        projectId: 1,
        runId: 'mock_run',
        title: 'Enhanced Inventory System',
        rationale:
            'Players consistently struggle with finding and organizing items',
        changes: [
          'Add search bar to inventory',
          'Implement item categories and filters',
          'Add quick-access toolbar',
          'Improve visual hierarchy'
        ],
        impact: 8,
        effort: 6,
        novelty: 'incremental',
        metadata: {'category': 'ui_ux'},
        createdAt: DateTime.now(),
      ),
      MutationBrief(
        id: 2,
        projectId: 1,
        runId: 'mock_run',
        title: 'Performance Optimization Package',
        rationale:
            'Combat performance issues are severely impacting player experience',
        changes: [
          'Implement level-of-detail (LOD) system',
          'Optimize particle effects',
          'Add graphics quality settings',
          'Implement dynamic resolution scaling'
        ],
        impact: 9,
        effort: 8,
        novelty: 'standard',
        metadata: {'category': 'technical'},
        createdAt: DateTime.now(),
      ),
      MutationBrief(
        id: 3,
        projectId: 1,
        runId: 'mock_run',
        title: 'Dynamic Difficulty System',
        rationale:
            'Players have varying skill levels and want personalized challenge',
        changes: [
          'Add adaptive difficulty AI',
          'Implement player skill tracking',
          'Create difficulty presets',
          'Add real-time difficulty adjustment'
        ],
        impact: 7,
        effort: 9,
        novelty: 'innovative',
        metadata: {'category': 'gameplay'},
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Mock method for listing feedback analysis runs
  Future<FeedbackRunListResponse> _mockListFeedbackAnalysisRuns(
      int projectId, String? status, int limit, int offset) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final mockRuns = [
      FeedbackRunSummary(
        id: 'mock_run_1',
        projectId: projectId,
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      FeedbackRunSummary(
        id: 'mock_run_2',
        projectId: projectId,
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      FeedbackRunSummary(
        id: 'mock_run_3',
        projectId: projectId,
        status: 'failed',
        errorMessage: 'Mock error for testing',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ];

    // Filter by status if provided
    final filteredRuns = status != null
        ? mockRuns.where((run) => run.status == status).toList()
        : mockRuns;

    // Apply pagination
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, filteredRuns.length);
    final paginatedRuns = filteredRuns.sublist(startIndex, endIndex);

    return FeedbackRunListResponse(
      runs: paginatedRuns,
      total: filteredRuns.length,
      limit: limit,
      offset: offset,
    );
  }

  /// Mock method for getting detailed feedback analysis
  Future<FeedbackRunDetailResponse> _mockGetFeedbackAnalysis(
      int projectId, String runId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    final mockRun = FeedbackRunFull(
      id: runId,
      projectId: projectId,
      status: 'completed',
      inputGameIntroMd: 'Mock game introduction for testing',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    return FeedbackRunDetailResponse(
      run: mockRun,
      clusters: _mockClusters(),
      opportunities: _mockOpportunities(),
      mutationBriefs: _mockMutationBriefsData(),
    );
  }
}
