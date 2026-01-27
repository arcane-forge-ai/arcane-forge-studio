import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:universal_io/io.dart';
import '../screens/game_design_assistant/models/project_model.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../models/project_overview_models.dart';
import '../models/member_model.dart';
import 'api_client.dart';

class ProjectsApiService {
  // Get default configuration from environment variables or use mock ID
  static String get defaultUserId =>
      dotenv.env['DEFAULT_USER_ID'] ?? '00000000-0000-0000-0000-000000000000';

  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;

  ProjectsApiService(
      {SettingsProvider? settingsProvider, AuthProvider? authProvider})
      : _settingsProvider = settingsProvider {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? true;

  /// Get API base URL from settings provider, with fallback to environment or default
  String get baseUrl => _apiClient.baseUrl;

  Future<List<Project>> getProjects({String? userId}) async {
    if (_useMockMode) {
      return _mockGetProjects();
    }

    try {
      final response = await _apiClient.get('/projects');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        return jsonList.map((json) => Project.fromApiJson(json)).toList();
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      print('Projects API Error: $e');
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

    final requestBody = {
      'name': name,
      'description': description,
    };

    try {
      final response = await _apiClient.post(
        '/projects',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to create project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Creation API Error: $e');
      rethrow;
    }
  }

  Future<Project> getProjectById(int projectId) async {
    if (_useMockMode) {
      return _mockGetProjectById(projectId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId');

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to load project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Get API Error: $e');
      rethrow;
    }
  }

  Future<ProjectOverviewResponse> getProjectOverview(int projectId) async {
    if (_useMockMode) {
      return _mockGetProjectOverview(projectId);
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/overview');

      if (response.statusCode == 200) {
        return ProjectOverviewResponse.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to load project overview: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Overview API Error: $e');
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

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (gameReleaseUrl != null) body['game_release_url'] = gameReleaseUrl;
    if (gameFeedbackUrl != null) body['game_feedback_url'] = gameFeedbackUrl;
    if (codeMapUrl != null) body['code_map_url'] = codeMapUrl;

    try {
      final response = await _apiClient.put('/projects/$projectId', data: body);
      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to update project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Update API Error: $e');
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
        userId: defaultUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '2',
        name: 'Sci-Fi Space Shooter',
        description:
            'Fast-paced action in the depths of space. Command your ship through asteroid fields and alien encounters.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        userId: defaultUserId,
        hasKnowledgeBase: false,
      ),
      Project(
        id: '3',
        name: 'Puzzle Platformer',
        description:
            'Mind-bending puzzles combined with precise platforming. Each level challenges both your reflexes and intellect.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        userId: defaultUserId,
        hasKnowledgeBase: true,
      ),
      Project(
        id: '4',
        name: 'Strategy Empire Builder',
        description:
            'Build and manage your civilization from ancient times to the modern era. Research technologies and conquer lands.',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        userId: defaultUserId,
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
      userId: defaultUserId,
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
      final response = await _apiClient.put(
        '/projects/$projectId',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        return Project.fromApiJson(response.data);
      } else {
        throw Exception('Failed to update project: ${response.statusCode}');
      }
    } catch (e) {
      print('Project Update API Error: $e');
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
        userId: defaultUserId,
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
      userId: defaultUserId,
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
    File? file,
    Uint8List? bytes,
    String? fileName,
  }) async {
    if (_useMockMode) {
      // In mock mode, simulate a successful upload
      return {
        'content': 'Mock code map content',
        'project_id': projectId,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    try {
      Response response;

      if (bytes != null && fileName != null) {
        response = await _apiClient.uploadFileFromBytes(
          '/projects/$projectId/code_map/upload',
          fileFieldName: 'file',
          bytes: bytes,
          fileName: fileName,
        );
      } else if (file != null) {
        response = await _apiClient.uploadFile(
          '/projects/$projectId/code_map/upload',
          fileFieldName: 'file',
          filePath: file.path,
          fileName: file.path.split('/').last,
        );
      } else {
        throw ArgumentError(
            'Either file bytes or file reference must be provided.');
      }

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to upload code map file: ${response.statusCode}');
      }
    } catch (e) {
      print('Code Map Upload API Error: $e');
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

  // =====================================================
  // Team Collaboration APIs
  // =====================================================

  /// Get all members of a project
  /// Requires: project membership
  Future<List<ProjectMember>> getProjectMembers(String projectId) async {
    if (_useMockMode) {
      return _mockGetProjectMembers();
    }

    try {
      final response = await _apiClient.get('/projects/$projectId/members');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> membersList = data['members'] ?? [];
        return membersList.map((json) => ProjectMember.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load project members: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Project Members API Error: $e');
      rethrow;
    }
  }

  /// Add a member to a project by userId
  /// Requires: project owner
  Future<ProjectMember> addProjectMember(
      String projectId, String userId) async {
    if (_useMockMode) {
      return ProjectMember(
        userId: userId,
        username: 'mock_user',
        isOwner: false,
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/members',
        data: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        return ProjectMember.fromJson(response.data);
      } else {
        throw Exception('Failed to add project member: ${response.statusCode}');
      }
    } catch (e) {
      print('Add Project Member API Error: $e');
      rethrow;
    }
  }

  /// Remove a member from a project
  /// Requires: project owner (cannot remove owner)
  Future<void> removeProjectMember(String projectId, String userId) async {
    if (_useMockMode) {
      return; // Mock success
    }

    try {
      final response =
          await _apiClient.delete('/projects/$projectId/members/$userId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to remove project member: ${response.statusCode}');
      }
    } catch (e) {
      print('Remove Project Member API Error: $e');
      rethrow;
    }
  }

  /// Create an email invite for a project
  /// Requires: project owner
  /// Returns: EmailInviteResponse (status can be 'accepted' if user exists)
  Future<EmailInviteResponse> createEmailInvite(
      String projectId, String email) async {
    if (_useMockMode) {
      return EmailInviteResponse(
        inviteId: 1,
        projectId: int.tryParse(projectId) ?? 0,
        invitedEmail: email,
        status: 'pending',
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/invites/email',
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return EmailInviteResponse.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to create email invite: ${response.statusCode}');
      }
    } catch (e) {
      print('Create Email Invite API Error: $e');
      rethrow;
    }
  }

  /// Get pending email invites for the current user
  /// Returns invites where invited_email matches the authenticated user's email
  Future<List<PendingInvite>> getMyPendingInvites() async {
    if (_useMockMode) {
      return []; // No pending invites in mock mode
    }

    try {
      final response = await _apiClient.get('/projects/invites/email/pending');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> invitesList = data['invites'] ?? [];
        return invitesList.map((json) => PendingInvite.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load pending invites: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Pending Invites API Error: $e');
      rethrow;
    }
  }

  /// Accept a pending email invite
  /// Returns: true if successful
  Future<bool> acceptEmailInvite(int projectId) async {
    if (_useMockMode) {
      return true;
    }

    try {
      final response = await _apiClient.post(
        '/projects/invites/email/accept',
        data: {'project_id': projectId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['success'] == true;
      } else {
        throw Exception('Failed to accept invite: ${response.statusCode}');
      }
    } catch (e) {
      print('Accept Email Invite API Error: $e');
      rethrow;
    }
  }

  /// Get pending invites for a specific project (owner only)
  /// Returns invites created by the owner that are still pending
  Future<List<PendingInvite>> getPendingInvites(String projectId) async {
    if (_useMockMode) {
      return []; // No pending invites in mock mode
    }

    // Note: This endpoint may need to be confirmed with backend
    // Using the same endpoint but filtering by project
    try {
      final response = await _apiClient.get('/projects/$projectId/invites');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> invitesList = data['invites'] ?? [];
        return invitesList
            .map((json) => PendingInvite.fromJson(json))
            .where((invite) => invite.isPending)
            .toList();
      } else {
        throw Exception(
            'Failed to load project invites: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Project Pending Invites API Error: $e');
      rethrow;
    }
  }

  // Mock data for team collaboration
  List<ProjectMember> _mockGetProjectMembers() {
    return [
      ProjectMember(
        userId: defaultUserId,
        username: 'owner_user',
        email: 'owner@example.com',
        isOwner: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      ProjectMember(
        userId: '11111111-1111-1111-1111-111111111111',
        username: 'collaborator1',
        email: 'collab1@example.com',
        isOwner: false,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ];
  }
}
