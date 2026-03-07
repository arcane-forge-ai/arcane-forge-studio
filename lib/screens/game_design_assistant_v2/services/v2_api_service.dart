import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/api_client.dart';
import '../models/context.dart';
import '../models/message.dart';
import '../models/progress.dart';
import '../models/session.dart';

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);

  @override
  String toString() => message;
}

class V2ApiService {
  final ApiClient _apiClient;

  V2ApiService({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  }) : _apiClient = ApiClient(
          settingsProvider: settingsProvider,
          authProvider: authProvider,
        );

  String get _baseUrl => _apiClient.baseUrl;
  String get _projectBaseUrl => '$_baseUrl/api/v1/projects';
  String get _designBaseUrl => '$_baseUrl/api/v2/design-agent';

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw Exception('Unexpected response format (expected object)');
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is List) return decoded;
    }
    throw Exception('Unexpected response format (expected list)');
  }

  String _extractError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      try {
        if (data is Map) {
          return data['detail']?.toString() ?? data.toString();
        }
        if (data is String && data.isNotEmpty) {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return decoded['detail']?.toString() ?? decoded.toString();
          }
          return decoded.toString();
        }
      } catch (_) {
        if (data != null) return data.toString();
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  bool _is409(Object error) {
    return error is DioException && error.response?.statusCode == 409;
  }

  bool _is404(Object error) {
    return error is DioException && error.response?.statusCode == 404;
  }

  Future<void> _enableProjectV2Runtime(String projectId) async {
    try {
      final response = await _apiClient.dio.put(
        '$_projectBaseUrl/$projectId',
        data: {'agent_runtime': 'v2'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to enable v2 runtime');
      }
    } catch (e) {
      throw Exception(
          'Failed to enable v2 runtime for project $projectId: ${_extractError(e)}');
    }
  }

  Future<List<SessionInfo>> listSessions({required String projectId}) async {
    Future<List<SessionInfo>> doRequest() async {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/projects/$projectId/sessions');
      final jsonList = _asList(response.data);
      return jsonList
          .map((e) => SessionInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    }

    try {
      return await doRequest();
    } catch (e) {
      if (_is409(e)) {
        await _enableProjectV2Runtime(projectId);
        return doRequest();
      }
      throw Exception('Failed to list sessions: ${_extractError(e)}');
    }
  }

  Future<CreateSessionResponse> createSession(
      CreateSessionRequest request) async {
    Future<CreateSessionResponse> doRequest() async {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/${request.projectId}/sessions',
        data: request.toJson(),
      );
      return CreateSessionResponse.fromJson(_asMap(response.data));
    }

    try {
      return await doRequest();
    } catch (e) {
      if (_is409(e)) {
        await _enableProjectV2Runtime(request.projectId);
        return doRequest();
      }
      throw Exception('Failed to create session: ${_extractError(e)}');
    }
  }

  Future<SessionInfo> getSession(String sessionId) async {
    try {
      final response =
          await _apiClient.dio.get('$_designBaseUrl/sessions/$sessionId');
      return SessionInfo.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception('Failed to get session: ${_extractError(e)}');
    }
  }

  Future<List<ChatMessage>> getHistory(String sessionId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/sessions/$sessionId/history');
      final data = _asMap(response.data);
      final messagesJson = data['messages'] as List? ?? const [];
      return messagesJson
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } catch (e) {
      throw Exception('Failed to get history: ${_extractError(e)}');
    }
  }

  Future<GetContextResponse> getContext(String sessionId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/sessions/$sessionId/context');
      return GetContextResponse.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception('Failed to get context: ${_extractError(e)}');
    }
  }

  Future<GetProgressResponse> getProgress(String sessionId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/sessions/$sessionId/progress');
      return GetProgressResponse.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception('Failed to get progress: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> confirmTransaction({
    required String sessionId,
    required String action,
    String? transactionId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/sessions/$sessionId/confirm',
        data: {
          'action': action,
          if (transactionId != null) 'transaction_id': transactionId,
        },
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to confirm transaction: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> getProjectFileWithVersion(
      String projectId, String filePath) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/projects/$projectId/files/$filePath');
      return _asMap(response.data);
    } catch (e) {
      if (_is404(e)) {
        return {'content': '', 'version_number': null};
      }
      throw Exception('Failed to get project file: ${_extractError(e)}');
    }
  }

  Future<List<Map<String, dynamic>>> listDocuments(String projectId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/projects/$projectId/documents');
      return _asList(response.data)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      throw Exception('Failed to list documents: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> createDocument(
    String projectId,
    String title, {
    String? filePath,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/documents',
        data: {
          'title': title,
          if (filePath != null) 'file_path': filePath,
        },
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to create document: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> renameDocument(
    String projectId,
    String slug,
    String title,
  ) async {
    try {
      final response = await _apiClient.dio.patch(
        '$_designBaseUrl/projects/$projectId/documents/$slug',
        data: {'title': title},
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to rename document: ${_extractError(e)}');
    }
  }

  Future<void> deleteDocument(
    String projectId,
    String slug,
    String userId,
  ) async {
    try {
      await _apiClient.dio.delete(
        '$_designBaseUrl/projects/$projectId/documents/$slug?user_id=$userId',
      );
    } catch (e) {
      throw Exception('Failed to delete document: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> saveDocumentContent({
    required String projectId,
    required String filePath,
    required String contentMarkdown,
    int? baseVersionNumber,
    String? comment,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/files/$filePath/versions',
        data: {
          'content_markdown': contentMarkdown,
          if (baseVersionNumber != null)
            'base_version_number': baseVersionNumber,
          'comment': comment ?? 'User direct edit',
        },
      );
      return _asMap(response.data);
    } catch (e) {
      if (_is409(e)) {
        throw ConflictException(
            'Document was modified by another source. Please reload.');
      }
      throw Exception('Failed to save document: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> saveGddContent({
    required String projectId,
    required String contentMarkdown,
    int? baseVersionNumber,
    String? comment,
  }) async {
    return saveDocumentContent(
      projectId: projectId,
      filePath: 'gdd.md',
      contentMarkdown: contentMarkdown,
      baseVersionNumber: baseVersionNumber,
      comment: comment,
    );
  }

  Future<bool> uploadFile(
    String projectId,
    String fileName, {
    String? filePath,
    Uint8List? bytes,
  }) async {
    try {
      Response response;

      if (bytes != null) {
        response = await _apiClient.uploadFileFromBytes(
          '/projects/$projectId/files',
          fileFieldName: 'file',
          bytes: bytes,
          fileName: fileName,
        );
      } else if (filePath != null) {
        response = await _apiClient.uploadFile(
          '/projects/$projectId/files',
          fileFieldName: 'file',
          filePath: filePath,
          fileName: fileName,
        );
      } else {
        throw ArgumentError('Either filePath or bytes must be provided.');
      }

      final responseData = response.data;
      return responseData['success'] == true || response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to upload file: ${_extractError(e)}');
    }
  }

  void dispose() {
    _apiClient.dispose();
  }
}
