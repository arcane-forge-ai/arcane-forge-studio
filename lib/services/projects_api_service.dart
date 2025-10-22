import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../screens/game_design_assistant/models/project_model.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';
import '../models/project_overview_models.dart';

class ProjectsApiService {
  // Get default configuration from environment variables or constants
  static String get defaultUserId =>
      dotenv.env['DEFAULT_USER_ID'] ?? AppConstants.visitorUserId;

  final SettingsProvider? _settingsProvider;
  final AuthProvider? _authProvider;
  final Dio _dio;

  ProjectsApiService(
      {SettingsProvider? settingsProvider, AuthProvider? authProvider})
      : _settingsProvider = settingsProvider,
        _authProvider = authProvider,
        _dio = Dio();

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? true;
  
  /// Get API base URL from settings provider, with fallback to environment or default
  String get baseUrl => 
      _settingsProvider?.apiBaseUrl ?? 
      dotenv.env['API_BASE_URL'] ?? 
      ApiConfig.defaultBaseUrl;

  Future<List<Project>> getProjects({String? userId}) async {
    if (_useMockMode) {
      return _mockGetProjects();
    }

    final userIdToUse = userId ?? _authProvider?.userId ?? defaultUserId;
    final url = '$baseUrl/api/v1/projects';
    final queryParams = {'user_id': userIdToUse};

    try {
      final response = await _dio.get(
        url,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        return jsonList.map((json) => Project.fromApiJson(json)).toList();
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      print('Projects API Error: $e');
      print('Request URL: $url');
      print('Query Parameters: $queryParams');
      print('Headers: ${_dio.options.headers}');
      // Re-throw the exception to let the UI handle it properly
      rethrow;
    }
  }

  Future<Project> createProject({
    required String name,
    required String description,
    String? userId,
  }) async {
    if (_useMockMode) {
      return _mockCreateProject(name: name, description: description);
    }

    final userIdToUse = userId ?? _authProvider?.userId ?? defaultUserId;
    final url = '$baseUrl/api/v1/projects';
    final queryParams = {'user_id': userIdToUse};
    final requestBody = {
      'name': name,
      'description': description,
    };

    try {
      final response = await _dio.post(
        url,
        queryParameters: queryParams,
        data: requestBody,
      );

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to create project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Creation API Error: $e');
      print('Request URL: $url');
      print('Query Parameters: $queryParams');
      print('Request Body: $requestBody');
      print('Headers: ${_dio.options.headers}');
      // Re-throw the exception to let the UI handle it properly
      rethrow;
    }
  }

  Future<Project> getProjectById(int projectId) async {
    if (_useMockMode) {
      return _mockGetProjectById(projectId);
    }

    final url = '$baseUrl/api/v1/projects/$projectId';

    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to load project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Get API Error: $e');
      print('Request URL: $url');
      print('Headers: ${_dio.options.headers}');
      // Re-throw the exception to let the UI handle it properly
      rethrow;
    }
  }

  Future<ProjectOverviewResponse> getProjectOverview(int projectId) async {
    if (_useMockMode) {
      return _mockGetProjectOverview(projectId);
    }

    final url = '$baseUrl/api/v1/projects/$projectId/overview';

    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return ProjectOverviewResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load project overview: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Overview API Error: $e');
      print('Request URL: $url');
      print('Headers: ${_dio.options.headers}');
      rethrow;
    }
  }

  Future<Project> updateProjectById({
    required int projectId,
    String? name,
    String? description,
    String? gameReleaseUrl,
    String? gameFeedbackUrl,
    String? codeMapUrl,
  }) async {
    if (_useMockMode) {
      // Update the mock project and return
      final current = _mockGetProjectById(projectId);
      return current.copyWith(
        name: name,
        description: description,
        gameReleaseUrl: gameReleaseUrl,
        gameFeedbackUrl: gameFeedbackUrl,
        codeMapUrl: codeMapUrl,
      );
    }

    final url = '$baseUrl/api/v1/projects/$projectId';

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (gameReleaseUrl != null) body['game_release_url'] = gameReleaseUrl;
    if (gameFeedbackUrl != null) body['game_feedback_url'] = gameFeedbackUrl;
    if (codeMapUrl != null) body['code_map_url'] = codeMapUrl;

    try {
      final response = await _dio.put(url, data: body);
      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to update project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Update API Error: $e');
      print('Request URL: $url');
      print('Request Body: $body');
      print('Headers: ${_dio.options.headers}');
      rethrow;
    }
  }

  // Mock data methods for development
  List<Project> _mockGetProjects() {
    return [
      Project(
        id: '1',
        name: 'Fantasy RPG Adventure',
        description:
            'A magical world filled with quests, dragons, and epic battles. Build your character and explore vast kingdoms.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '2',
        name: 'Sci-Fi Space Shooter',
        description:
            'Fast-paced action in the depths of space. Command your ship through asteroid fields and alien encounters.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: false,
      ),
      Project(
        id: '3',
        name: 'Puzzle Platformer',
        description:
            'Mind-bending puzzles combined with precise platforming. Each level challenges both your reflexes and intellect.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '4',
        name: 'Strategy Empire Builder',
        description:
            'Build and manage your civilization from ancient times to the modern era. Research technologies and conquer lands.',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: false,
      ),
    ];
  }

  Project _mockCreateProject(
      {required String name, required String description}) {
    // Simulate API delay
    return Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      userId: AppConstants.visitorUserId,
      hasKnowledgeBase: false,
    );
  }

  Future<Project> updateProject({
    required String projectId,
    String? name,
    String? description,
    String? gameReleaseUrl,
    String? gameFeedbackUrl,
    String? gameIntroduction,
    String? codeMapUrl,
  }) async {
    if (_useMockMode) {
      return _mockUpdateProject(
        projectId: projectId,
        name: name,
        description: description,
        gameReleaseUrl: gameReleaseUrl,
        gameFeedbackUrl: gameFeedbackUrl,
        gameIntroduction: gameIntroduction,
        codeMapUrl: codeMapUrl,
      );
    }

    final url = '$baseUrl/api/v1/projects/$projectId';
    final requestBody = <String, dynamic>{};

    if (name != null) requestBody['name'] = name;
    if (description != null) requestBody['description'] = description;
    if (gameReleaseUrl != null)
      requestBody['game_release_url'] = gameReleaseUrl;
    if (gameFeedbackUrl != null)
      requestBody['game_feedback_url'] = gameFeedbackUrl;
    if (gameIntroduction != null)
      requestBody['game_introduction'] = gameIntroduction;
    if (codeMapUrl != null) requestBody['code_map_url'] = codeMapUrl;

    try {
      final response = await _dio.put(
        url,
        data: requestBody,
      );

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to update project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Update API Error: $e');
      print('Request URL: $url');
      print('Request Body: $requestBody');
      print('Headers: ${_dio.options.headers}');
      rethrow;
    }
  }

  Project _mockGetProjectById(int projectId) {
    final projects = _mockGetProjects();
    try {
      return projects.firstWhere((p) => p.id == projectId.toString());
    } catch (e) {
      // Return a default project if not found
      return Project(
        id: projectId.toString(),
        name: 'Sample Project',
        description: 'This is a sample project created in mock mode.',
        createdAt: DateTime.now(),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: false,
      );
    }
  }

  Project _mockUpdateProject({
    required String projectId,
    String? name,
    String? description,
    String? gameReleaseUrl,
    String? gameFeedbackUrl,
    String? gameIntroduction,
    String? codeMapUrl,
  }) {
    // In mock mode, just return a project with updated values
    return Project(
      id: projectId,
      name: name ?? 'Updated Project',
      description: description ?? 'Updated description in mock mode.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
      userId: AppConstants.visitorUserId,
      hasKnowledgeBase: false,
      gameReleaseUrl: gameReleaseUrl,
      gameFeedbackUrl: gameFeedbackUrl,
      gameIntroduction: gameIntroduction,
      codeMapUrl: codeMapUrl,
    );
  }

  /// Upload a code map file for a project
  /// The API endpoint expects a multipart/form-data file upload
  Future<Map<String, dynamic>> uploadCodeMapFile({
    required int projectId,
    required File file,
  }) async {
    if (_useMockMode) {
      // In mock mode, simulate a successful upload
      return {
        'content': 'Mock code map content',
        'project_id': projectId,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    final url = '$baseUrl/api/v1/projects/$projectId/code_map/upload';

    try {
      // Create form data with the file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        url,
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to upload code map file: ${response.statusCode}');
      }
    } catch (e) {
      print('Code Map Upload API Error: $e');
      print('Request URL: $url');
      print('File: ${file.path}');
      rethrow;
    }
  }

  ProjectOverviewResponse _mockGetProjectOverview(int projectId) {
    // Return mock data showing all three status types for testing
    return ProjectOverviewResponse(
      projectId: projectId,
      gameDesign: GameDesignOverview(conversationCount: 5),
      imageAssets: AssetCategoryOverview(
        totalAssets: 15,
        assetsWithGenerations: 14,
        assetsWithFavorite: 14,
      ),
      sfxAssets: AssetCategoryOverview(
        totalAssets: 7,
        assetsWithGenerations: 7,
        assetsWithFavorite: 7,
      ),
      musicAssets: AssetCategoryOverview(
        totalAssets: 0,
        assetsWithGenerations: 0,
        assetsWithFavorite: 0,
      ),
      code: CodeOverview(hasCodeMap: true),
      release: ReleaseOverview(hasGameLink: true),
      analytics: AnalyticsOverview(analysisRunsCount: 3),
      knowledgeBase: KnowledgeBaseOverview(fileCount: 4),
    );
  }
}
