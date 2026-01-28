import '../models/evaluate_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'api_client.dart';

class EvaluateApiService {
  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;

  EvaluateApiService({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) : _settingsProvider = settingsProvider {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? true;

  /// Start a new evaluation for a project
  Future<EvaluateResponse> startEvaluation(int projectId,
      {Map<String, dynamic>? metadataOverrides}) async {
    if (_useMockMode) {
      return _mockStartEvaluation(projectId);
    }

    final requestBody = {
      if (metadataOverrides != null) 'metadata_overrides': metadataOverrides,
    };

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/evaluate',
        data: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EvaluateResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to start evaluation: ${response.statusCode}');
      }
    } catch (e) {
      print('Evaluate API Error (start): $e');
      rethrow;
    }
  }

  /// Get evaluation history for a project
  Future<EvaluateHistoryResponse> getEvaluationHistory(int projectId,
      {int limit = 20, int offset = 0}) async {
    if (_useMockMode) {
      return _mockGetEvaluationHistory(projectId);
    }

    try {
      final response = await _apiClient.get(
        '/projects/$projectId/evaluate/history',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        print('History response data type: ${response.data.runtimeType}');
        print('History response data: ${response.data}');
        return EvaluateHistoryResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to get evaluation history: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Evaluate API Error (history): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get the latest evaluation for a project
  Future<EvaluateResponse> getLatestEvaluation(int projectId) async {
    if (_useMockMode) {
      return _mockGetLatestEvaluation(projectId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/evaluate/latest');

      if (response.statusCode == 200) {
        return EvaluateResponse.fromJson(response.data);
      } else if (response.statusCode == 404) {
        throw Exception('No evaluations found for this project');
      } else {
        throw Exception('Failed to get latest evaluation: ${response.statusCode}');
      }
    } catch (e) {
      print('Evaluate API Error (latest): $e');
      rethrow;
    }
  }

  /// Get a specific evaluation by ID
  Future<EvaluateResponse> getEvaluationById(int projectId, int evaluationId) async {
    if (_useMockMode) {
      return _mockGetEvaluationById(projectId, evaluationId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/evaluate/$evaluationId');

      if (response.statusCode == 200) {
        return EvaluateResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to get evaluation: ${response.statusCode}');
      }
    } catch (e) {
      print('Evaluate API Error (get by id): $e');
      rethrow;
    }
  }

  // =====================================================
  // Mock Data Implementation
  // =====================================================

  Future<EvaluateResponse> _mockStartEvaluation(int projectId) async {
    await Future.delayed(const Duration(seconds: 1));
    return EvaluateResponse(
      id: 123,
      projectId: projectId,
      status: 'pending',
      createdAt: DateTime.now(),
    );
  }

  EvaluateHistoryResponse _mockGetEvaluationHistory(int projectId) {
    return EvaluateHistoryResponse(
      projectId: projectId,
      evaluations: [
        _mockGetLatestEvaluation(projectId),
        EvaluateResponse(
          id: 122,
          projectId: projectId,
          status: 'completed',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          completedAt: DateTime.now().subtract(const Duration(days: 7, minutes: 2)),
          result: _mockResult('green'),
        ),
      ],
    );
  }

  EvaluateResponse _mockGetLatestEvaluation(int projectId) {
    return EvaluateResponse(
      id: 123,
      projectId: projectId,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      completedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 58)),
      result: _mockResult('yellow'),
    );
  }

  EvaluateResponse _mockGetEvaluationById(int projectId, int evaluationId) {
    // Return a processing state if it's the one we just "started"
    if (evaluationId == 123) {
      return EvaluateResponse(
        id: 123,
        projectId: projectId,
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        completedAt: DateTime.now(),
        result: _mockResult('yellow'),
      );
    }

    return EvaluateResponse(
      id: evaluationId,
      projectId: projectId,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      completedAt: DateTime.now().subtract(const Duration(days: 1, minutes: 2)),
      result: _mockResult('red'),
    );
  }

  EvaluateResult _mockResult(String status) {
    return EvaluateResult(
      gaps: [
        KnowledgeGap(
          id: 'gap-1',
          title: 'Missing Combat Mechanics',
          severity: 'high',
          kbEvidence: ['No combat system documentation found in knowledge base.'],
          currentState: 'Combat mechanics are not defined.',
          whatToDecide: 'The core combat loop is not defined in the knowledge base.',
          whyItMatters: 'Define damage types, weapon scaling, and player movement during combat.',
        ),
        KnowledgeGap(
          id: 'gap-2',
          title: 'Vague Economy Balance',
          severity: 'medium',
          kbEvidence: ['Economy section exists but lacks specific numbers.'],
          currentState: 'Economy balance is described in general terms.',
          whatToDecide: 'In-game currency acquisition rates vs item costs are unclear.',
          whyItMatters: 'Add a spreadsheet or detailed table of expected player gold per hour.',
        ),
      ],
      risks: [
        RiskAssessment(
          category: 'Retention',
          risk: 'Lack of long-term progression goals may lead to player churn after 10 hours.',
          severity: 'high',
          mitigation: 'Implement a talent tree or prestige system.',
        ),
        RiskAssessment(
          category: 'Technical',
          risk: 'Multiplayer networking architecture not specified.',
          severity: 'medium',
          mitigation: 'Document the choice between client-server or P2P.',
        ),
      ],
      marketAnalysis: MarketAnalysis(
        differentiation: MarketDifferentiation(
          unique: ['Craftable skills system', 'Accessible yet deep ARPG mechanics'],
          genericOrExpected: ['Character progression', 'Loot system'],
          unclearOrUnproven: ['Monetization strategy'],
        ),
        comparableGames: [
          ComparableGame(
            title: 'Path of Exile',
            confidence: 'high',
            similarityReason: 'Similar ARPG structure with deep customization.',
          ),
          ComparableGame(
            title: 'Diablo IV',
            confidence: 'medium',
            similarityReason: 'Shared genre and target audience.',
          ),
          ComparableGame(
            title: 'Last Epoch',
            confidence: 'high',
            similarityReason: 'Focus on character build depth and progression.',
          ),
        ],
      ),
      greenlight: GreenlightDecision(
        status: status,
        blockers: status == 'red' 
            ? ['Missing core combat mechanics', 'Unclear economy balance']
            : [],
        reasoningList: [
          status == 'green' 
              ? 'The design is comprehensive and addresses key player motivations.' 
              : status == 'yellow' 
                  ? 'The project has strong potential but needs more detail in core systems.' 
                  : 'Significant design gaps exist that make production risky.',
        ],
        toReachNextStatus: [
          'Detail the skill crafting system.',
          'Define the first 5 enemy archetypes.',
          'Create a prototype for the movement mechanics.',
        ],
      ),
    );
  }
}

