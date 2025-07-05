import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../screens/game_design_assistant/models/project_model.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';

class ProjectsApiService {
  // Get configuration from environment variables with fallback defaults
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  static String get defaultUserId => dotenv.env['DEFAULT_USER_ID'] ?? AppConstants.visitorUserId;
  
  final SettingsProvider? _settingsProvider;
  final AuthProvider? _authProvider;
  final Dio _dio;

  ProjectsApiService({SettingsProvider? settingsProvider, AuthProvider? authProvider})
      : _settingsProvider = settingsProvider,
        _authProvider = authProvider,
        _dio = Dio();

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? true;

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

  // Mock data methods for development
  List<Project> _mockGetProjects() {
    return [
      Project(
        id: '1',
        name: 'Fantasy RPG Adventure',
        description: 'A magical world filled with quests, dragons, and epic battles. Build your character and explore vast kingdoms.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '2', 
        name: 'Sci-Fi Space Shooter',
        description: 'Fast-paced action in the depths of space. Command your ship through asteroid fields and alien encounters.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: false,
      ),
      Project(
        id: '3',
        name: 'Puzzle Platformer',
        description: 'Mind-bending puzzles combined with precise platforming. Each level challenges both your reflexes and intellect.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '4',
        name: 'Strategy Empire Builder',
        description: 'Build and manage your civilization from ancient times to the modern era. Research technologies and conquer lands.',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        userId: AppConstants.visitorUserId,
        hasKnowledgeBase: false,
      ),
    ];
  }

  Project _mockCreateProject({required String name, required String description}) {
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
} 