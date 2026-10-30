import '../models/resource_comment_models.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/error_handler.dart';
import 'api_client.dart';

abstract class ResourceCommentService {
  Future<ResourceCommentPage> listComments({
    required String projectId,
    required ResourceCommentTarget target,
    int limit = 50,
    int offset = 0,
  });

  Future<ResourceComment> addComment({
    required String projectId,
    required ResourceCommentTarget target,
    required String body,
  });

  Future<ResourceComment> editComment({
    required String projectId,
    required int commentId,
    required String body,
  });

  Future<ResourceComment> deleteComment({
    required String projectId,
    required int commentId,
  });
}

class ApiResourceCommentService implements ResourceCommentService {
  final ApiClient _apiClient;

  ApiResourceCommentService({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
    ApiClient? apiClient,
  }) : _apiClient = apiClient ??
            ApiClient(
              settingsProvider: settingsProvider,
              authProvider: authProvider,
            );

  @override
  Future<ResourceCommentPage> listComments({
    required String projectId,
    required ResourceCommentTarget target,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '/projects/$projectId/comments',
        queryParameters: {
          'resource_type': target.type.wireName,
          if (target.resourceId != null) 'resource_id': target.resourceId,
          'limit': limit,
          'offset': offset,
        },
      );
      return ResourceCommentPage.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(
        'Failed to load comments: ${ErrorHandler.getErrorMessage(error)}',
      );
    }
  }

  @override
  Future<ResourceComment> addComment({
    required String projectId,
    required ResourceCommentTarget target,
    required String body,
  }) async {
    try {
      final response = await _apiClient.post(
        '/projects/$projectId/comments',
        data: {
          'resource_type': target.type.wireName,
          'resource_id': target.resourceId,
          'body': body,
        },
      );
      return ResourceComment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(
        'Failed to add comment: ${ErrorHandler.getErrorMessage(error)}',
      );
    }
  }

  @override
  Future<ResourceComment> editComment({
    required String projectId,
    required int commentId,
    required String body,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/projects/$projectId/comments/$commentId',
        data: {'body': body},
      );
      return ResourceComment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(
        'Failed to edit comment: ${ErrorHandler.getErrorMessage(error)}',
      );
    }
  }

  @override
  Future<ResourceComment> deleteComment({
    required String projectId,
    required int commentId,
  }) async {
    try {
      final response = await _apiClient.delete(
        '/projects/$projectId/comments/$commentId',
      );
      return ResourceComment.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (error) {
      throw Exception(
        'Failed to delete comment: ${ErrorHandler.getErrorMessage(error)}',
      );
    }
  }
}
