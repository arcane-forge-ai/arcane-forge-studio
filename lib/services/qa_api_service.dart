import 'package:dio/dio.dart';
import '../models/qa_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'api_client.dart';

class QAApiService {
  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;

  QAApiService({
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

  /// Ask a question to the QA assistant
  Future<QAResponse> askQuestion(String projectId, QARequest request) async {
    if (_useMockMode) {
      return _mockAskQuestion(projectId, request);
    }

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/qa',
        data: request.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return QAResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to ask question: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  /// Ask a question with passcode (for unauthenticated access)
  Future<QAResponse> askQuestionWithPasscode(
    String projectId,
    QARequest request,
    String passcode,
  ) async {
    if (_useMockMode) {
      return _mockAskQuestionWithPasscode(projectId, request, passcode);
    }

    try {
      final response = await _apiClient.dio.post(
        '${_apiClient.apiUrl}/projects/$projectId/qa',
        data: request.toJson(),
        options: Options(
          headers: {
            'X-QA-Passcode': passcode,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return QAResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to ask question: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  /// List all responsibility areas for a project
  Future<List<ResponsibilityArea>> listResponsibilityAreas(String projectId) async {
    if (_useMockMode) {
      return _mockListResponsibilityAreas(projectId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/responsibility-areas');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final areas = (data['areas'] as List<dynamic>)
            .map((area) => ResponsibilityArea.fromJson(area as Map<String, dynamic>))
            .toList();
        return areas;
      } else {
        throw Exception('Failed to list responsibility areas: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  /// Create a new responsibility area (Owner only)
  Future<ResponsibilityArea> createResponsibilityArea(
    String projectId,
    ResponsibilityArea area,
  ) async {
    if (_useMockMode) {
      return _mockCreateResponsibilityArea(projectId, area);
    }

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/responsibility-areas',
        data: area.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponsibilityArea.fromJson(response.data);
      } else {
        throw Exception('Failed to create responsibility area: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  /// Update an existing responsibility area
  Future<ResponsibilityArea> updateResponsibilityArea(
    String projectId,
    int areaId,
    ResponsibilityArea area,
  ) async {
    if (_useMockMode) {
      return _mockUpdateResponsibilityArea(projectId, areaId, area);
    }

    try {
      final response = await _apiClient.put(
        '/projects/$projectId/responsibility-areas/$areaId',
        data: area.toJson(),
      );

      if (response.statusCode == 200) {
        return ResponsibilityArea.fromJson(response.data);
      } else {
        throw Exception('Failed to update responsibility area: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  /// Delete a responsibility area
  Future<void> deleteResponsibilityArea(String projectId, int areaId) async {
    if (_useMockMode) {
      return _mockDeleteResponsibilityArea(projectId, areaId);
    }

    try {
      final response = await _apiClient.delete(
        '/projects/$projectId/responsibility-areas/$areaId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete responsibility area: ${response.statusCode}');
      }
    } catch (e) {
      print('QA API Error: $e');
      rethrow;
    }
  }

  // =====================================================
  // Mock Data Implementation
  // =====================================================

  // In-memory mock storage
  static final List<ResponsibilityArea> _mockAreas = [
    ResponsibilityArea(
      id: 1,
      projectId: 1,
      areaName: 'UI/UX Design',
      areaKeywords: const ['ui', 'ux', 'interface', 'design', 'button', 'style'],
      internalContact: 'alice@studio.com',
      externalDisplayName: 'UI Lead',
      contactMethod: 'slack: #ui-questions',
      notes: 'Responsible for all UI/UX decisions',
      createdAt: DateTime(2026, 1, 28, 10, 0),
      updatedAt: DateTime(2026, 1, 28, 10, 0),
    ),
    ResponsibilityArea(
      id: 2,
      projectId: 1,
      areaName: 'Backend Engineering',
      areaKeywords: const ['backend', 'api', 'server', 'database', 'infrastructure'],
      internalContact: 'bob@studio.com',
      externalDisplayName: 'Backend Lead',
      contactMethod: 'email: backend@studio.com',
      notes: 'API and server infrastructure',
      createdAt: DateTime(2026, 1, 28, 11, 0),
      updatedAt: DateTime(2026, 1, 28, 11, 0),
    ),
  ];

  Future<QAResponse> _mockAskQuestion(String projectId, QARequest request) async {
    await Future.delayed(const Duration(seconds: 2));

    final question = request.question.toLowerCase();
    
    // Mock high confidence response with references
    if (question.contains('requirement') || question.contains('specification')) {
      return const QAResponse(
        answer: 'The project requirements include a real-time multiplayer combat system with skill-based progression, '
            'a dynamic economy system, and cross-platform support. The core gameplay loop focuses on skill crafting '
            'and character customization.',
        references: [
          QAReference(
            type: 'document',
            title: 'Project Requirements Document',
            source: 'Project Documentation',
            excerpt: 'Real-time multiplayer combat with skill-based progression...',
          ),
          QAReference(
            type: 'document',
            title: 'Technical Specification',
            source: 'Project Documentation',
            excerpt: 'Cross-platform support for PC, Console, and Mobile...',
          ),
        ],
        confidence: 'high',
        escalation: null,
        needsHumanVerification: false,
      );
    }
    
    // Mock medium confidence response
    if (question.contains('deadline') || question.contains('timeline')) {
      return const QAResponse(
        answer: 'Based on the project documentation, the alpha release is targeted for Q2 2026, '
            'with a beta phase starting in Q3 2026. However, these dates are subject to change based on development progress.',
        references: [
          QAReference(
            type: 'document',
            title: 'Project Roadmap',
            source: 'Project Documentation',
            excerpt: 'Alpha release: Q2 2026, Beta: Q3 2026...',
          ),
        ],
        confidence: 'medium',
        escalation: null,
        needsHumanVerification: true,
      );
    }
    
    // Mock escalation response (unknown/low confidence)
    if (question.contains('ui') || question.contains('design') || question.contains('color') || question.contains('style')) {
      return const QAResponse(
        answer: 'UI design specifications are not fully documented in the knowledge base. '
            'For detailed UI guidelines, you should contact the UI design team.',
        references: [],
        confidence: 'unknown',
        escalation: QAEscalation(
          contactName: 'UI Lead',
          contactMethod: 'slack: #ui-questions',
          area: 'UI Design',
          reason: 'UI specifications and style guidelines are managed by the design team.',
        ),
        needsHumanVerification: true,
      );
    }
    
    // Default mock response
    return const QAResponse(
      answer: 'I found some information about your question in the project documentation. '
          'The project is an action RPG with focus on player creativity and skill combinations. '
          'For more specific details, please refer to the documentation or contact the appropriate team.',
      references: [
        QAReference(
          type: 'document',
          title: 'Game Design Document',
          source: 'Project Documentation',
        ),
      ],
      confidence: 'low',
      escalation: null,
      needsHumanVerification: true,
    );
  }

  Future<List<ResponsibilityArea>> _mockListResponsibilityAreas(String projectId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockAreas);
  }

  Future<ResponsibilityArea> _mockCreateResponsibilityArea(
    String projectId,
    ResponsibilityArea area,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final newId = _mockAreas.isEmpty ? 1 : _mockAreas.map((a) => a.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    final newArea = area.copyWith(
      id: newId,
      projectId: int.tryParse(projectId),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _mockAreas.add(newArea);
    return newArea;
  }

  Future<ResponsibilityArea> _mockUpdateResponsibilityArea(
    String projectId,
    int areaId,
    ResponsibilityArea area,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final index = _mockAreas.indexWhere((a) => a.id == areaId);
    if (index == -1) {
      throw Exception('Responsibility area not found');
    }
    
    final updatedArea = area.copyWith(
      id: areaId,
      projectId: int.tryParse(projectId),
      createdAt: _mockAreas[index].createdAt,
      updatedAt: DateTime.now(),
    );
    
    _mockAreas[index] = updatedArea;
    return updatedArea;
  }

  Future<void> _mockDeleteResponsibilityArea(String projectId, int areaId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final index = _mockAreas.indexWhere((a) => a.id == areaId);
    if (index == -1) {
      throw Exception('Responsibility area not found');
    }
    
    _mockAreas.removeAt(index);
  }

  // Mock passcode for testing
  static const String _mockPasscode = 'test123';

  Future<QAResponse> _mockAskQuestionWithPasscode(
    String projectId,
    QARequest request,
    String passcode,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Validate passcode
    if (passcode != _mockPasscode) {
      throw DioException(
        requestOptions: RequestOptions(path: '/projects/$projectId/qa'),
        response: Response(
          requestOptions: RequestOptions(path: '/projects/$projectId/qa'),
          statusCode: 403,
          data: {'error': 'Invalid passcode'},
        ),
      );
    }

    // If valid, return the same mock response as authenticated
    return _mockAskQuestion(projectId, request);
  }
}
