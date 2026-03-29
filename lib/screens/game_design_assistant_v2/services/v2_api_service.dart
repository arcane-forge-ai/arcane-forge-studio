import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/api_client.dart';
import '../models/context.dart';
import '../models/message.dart';
import '../models/progress.dart';
import '../models/project_context.dart';
import '../models/selection.dart';
import '../models/session.dart';

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);

  @override
  String toString() => message;
}

class ConfirmFlowDisabledException implements Exception {
  @override
  String toString() =>
      'Confirmation flow has been removed. Documents are now written directly.';
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

  bool _is410(Object error) {
    return error is DioException && error.response?.statusCode == 410;
  }

  String _encodeFilePath(String filePath) {
    return Uri.encodeComponent(filePath.trim());
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

  Future<SessionBootstrapResponse> getSessionBootstrap(String sessionId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/sessions/$sessionId/bootstrap');
      return SessionBootstrapResponse.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception('Failed to bootstrap session: ${_extractError(e)}');
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

  Future<ChatMessage> sendMessage({
    required String sessionId,
    String? content,
    String? documentPath,
    SelectionAnswer? selectionAnswer,
  }) async {
    try {
      final request = SendMessageRequest(
        content: content?.trim(),
        selectionAnswer: selectionAnswer,
      );
      final payload = request.toJson();
      if (documentPath != null && documentPath.trim().isNotEmpty) {
        payload['document_path'] = documentPath.trim();
      }
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/sessions/$sessionId/message',
        data: payload,
      );
      final data = _asMap(response.data);
      return ChatMessage.fromJson({
        'role': 'assistant',
        'content': data['message']?.toString() ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'pending_knowledge_may_update':
            data['pending_knowledge_may_update'] == true,
        if (data['thinking'] != null) 'thinking': data['thinking'],
        if (data['confirmation'] != null) 'confirmation': data['confirmation'],
        if (data['selection'] != null) 'selection': data['selection'],
        if (data['write_summary'] != null)
          'write_summary': data['write_summary'],
      });
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to send message: ${_extractError(e)}');
    }
  }

  Future<void> updateContext({
    required String sessionId,
    required String key,
    required dynamic value,
  }) async {
    try {
      await _apiClient.dio.patch(
        '$_designBaseUrl/sessions/$sessionId/context',
        data: {
          'key': key,
          'value': value,
        },
      );
    } catch (e) {
      throw Exception('Failed to update context: ${_extractError(e)}');
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
    String? argsChecksum,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/sessions/$sessionId/confirm',
        data: {
          'action': action,
          if (transactionId != null) 'transaction_id': transactionId,
          if (argsChecksum != null) 'args_checksum': argsChecksum,
        },
      );
      return _asMap(response.data);
    } catch (e) {
      if (_is410(e)) {
        throw ConfirmFlowDisabledException();
      }
      throw Exception('Failed to confirm transaction: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> setActiveDocument({
    required String sessionId,
    String? filePath,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '$_designBaseUrl/sessions/$sessionId/active-document',
        data: {'file_path': filePath},
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to set active document: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> getProjectFileWithVersion(
      String projectId, String filePath) async {
    try {
      final encodedPath = _encodeFilePath(filePath);
      final response = await _apiClient.dio
          .get('$_designBaseUrl/projects/$projectId/files/$encodedPath');
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
      final raw = response.data;
      List<dynamic> docs;
      if (raw is Map || raw is String) {
        final map = _asMap(raw);
        final nested = map['documents'];
        docs = nested is List ? nested : _asList(raw);
      } else {
        docs = _asList(raw);
      }
      return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      throw Exception('Failed to list documents: ${_extractError(e)}');
    }
  }

  Future<List<Map<String, dynamic>>> listSessionDocuments(
      String sessionId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/sessions/$sessionId/documents');
      final raw = response.data;
      List<dynamic> docs;
      if (raw is Map || raw is String) {
        final map = _asMap(raw);
        final nested = map['documents'];
        docs = nested is List ? nested : _asList(raw);
      } else {
        docs = _asList(raw);
      }
      return docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      throw Exception('Failed to list session documents: ${_extractError(e)}');
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

  Future<Map<String, dynamic>> createSessionDocument(
    String sessionId,
    String title, {
    String? filePath,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/sessions/$sessionId/documents',
        data: {
          'title': title,
          if (filePath != null) 'file_path': filePath,
        },
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to create session document: ${_extractError(e)}');
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
      final encodedPath = _encodeFilePath(filePath);
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/files/$encodedPath/versions',
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

  /// List all versions of a document
  /// Backend returns {"versions": [...], "total": N}
  Future<List<dynamic>> listVersions(String projectId, String filePath) async {
    try {
      final encodedPath = _encodeFilePath(filePath);
      final response = await _apiClient.dio.get(
        '$_designBaseUrl/projects/$projectId/files/$encodedPath/versions',
      );
      final body = _asMap(response.data);
      return _asList(body['versions']);
    } catch (e) {
      throw Exception('Failed to list versions: ${_extractError(e)}');
    }
  }

  /// Get a specific version's content
  Future<Map<String, dynamic>> getVersion(
    String projectId,
    String filePath,
    int versionNumber,
  ) async {
    try {
      final encodedPath = _encodeFilePath(filePath);
      final response = await _apiClient.dio.get(
        '$_designBaseUrl/projects/$projectId/files/$encodedPath/versions/$versionNumber',
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception('Failed to get version: ${_extractError(e)}');
    }
  }

  /// Restore a specific version
  Future<void> restoreVersion(
    String projectId,
    String filePath,
    int versionNumber,
  ) async {
    try {
      final encodedPath = _encodeFilePath(filePath);
      await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/files/$encodedPath/versions/$versionNumber/restore',
        data: {},
      );
    } catch (e) {
      throw Exception('Failed to restore version: ${_extractError(e)}');
    }
  }

  Future<void> deleteVersion(
    String projectId,
    String filePath,
    int versionNumber,
  ) async {
    try {
      final encodedPath = _encodeFilePath(filePath);
      await _apiClient.dio.delete(
        '$_designBaseUrl/projects/$projectId/files/$encodedPath/versions/$versionNumber',
      );
    } catch (e) {
      throw Exception('Failed to delete version: ${_extractError(e)}');
    }
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

  // ---------------------------------------------------------------------------
  // Project Context / Pending Knowledge
  // ---------------------------------------------------------------------------

  Future<PendingKnowledgeListResponse> listPendingKnowledge(
      String projectId) async {
    try {
      final response = await _apiClient.dio
          .get('$_designBaseUrl/projects/$projectId/knowledge/pending');
      final data = _asMap(response.data);
      return PendingKnowledgeListResponse.fromJson(data);
    } catch (e) {
      throw Exception('Failed to list pending knowledge: ${_extractError(e)}');
    }
  }

  Future<ConfirmKnowledgeResult> confirmPendingKnowledge({
    required String projectId,
    required List<Map<String, String>> decisions,
    required String batchEtag,
    required String mode,
    required String idempotencyKey,
  }) async {
    try {
      final headers = <String, String>{
        if (batchEtag.trim().isNotEmpty) 'If-Match': batchEtag,
        if (idempotencyKey.trim().isNotEmpty) 'Idempotency-Key': idempotencyKey,
      };
      final payloadDecisions = decisions
          .map((d) => {
                'id': d['id'],
                'action': d['action'],
                'version': int.tryParse(d['version'] ?? '') ?? 0,
              })
          .toList(growable: false);
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/knowledge/confirm',
        data: {
          'mode': mode,
          'decisions': payloadDecisions,
        },
        options: Options(headers: headers),
      );
      return ConfirmKnowledgeResult.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception(
          'Failed to confirm pending knowledge: ${_extractError(e)}');
    }
  }

  Future<PendingKnowledgeItem> updatePendingItem({
    required String projectId,
    required String itemId,
    required String ifMatch,
    String? content,
    String? type,
  }) async {
    try {
      final headers = <String, String>{
        if (ifMatch.trim().isNotEmpty) 'If-Match': ifMatch,
      };
      final response = await _apiClient.dio.patch(
        '$_designBaseUrl/projects/$projectId/knowledge/pending/$itemId',
        data: {
          if (content != null) 'content': content,
          if (type != null) 'type': type,
        },
        options: Options(headers: headers),
      );
      return PendingKnowledgeItem.fromJson(_asMap(response.data));
    } catch (e) {
      throw Exception('Failed to update pending item: ${_extractError(e)}');
    }
  }

  Future<void> deletePendingItem({
    required String projectId,
    required String itemId,
    required String ifMatch,
    String? reason,
  }) async {
    try {
      final headers = <String, String>{
        if (ifMatch.trim().isNotEmpty) 'If-Match': ifMatch,
      };
      await _apiClient.dio.delete(
        '$_designBaseUrl/projects/$projectId/knowledge/pending/$itemId',
        data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
        },
        options: Options(headers: headers),
      );
    } catch (e) {
      throw Exception('Failed to delete pending item: ${_extractError(e)}');
    }
  }

  Future<Map<String, dynamic>> extractSessionKnowledge(String sessionId) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/sessions/$sessionId/knowledge/extract',
      );
      return _asMap(response.data);
    } catch (e) {
      throw Exception(
          'Failed to extract to project context: ${_extractError(e)}');
    }
  }

  Future<List<ProjectContextEntry>> listProjectContext({
    required String projectId,
    String? cursor,
    int limit = 50,
    String? type,
    String? query,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (type != null) 'type': type,
        if (query != null) 'q': query,
      };
      final response = await _apiClient.dio.get(
        '$_designBaseUrl/projects/$projectId/project-context',
        queryParameters: params,
      );
      final data = _asMap(response.data);
      final items = data['items'] as List? ?? [];
      return items
          .map((e) =>
              ProjectContextEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw Exception('Failed to list project context: ${_extractError(e)}');
    }
  }

  Future<ProjectContextEntry> createProjectContextEntry({
    required String projectId,
    required String type,
    required String content,
    String? originalText,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '$_designBaseUrl/projects/$projectId/project-context',
        data: {
          'type': type,
          'content': content,
          if (originalText != null) 'original_text': originalText,
        },
      );
      return ProjectContextEntry.fromJson(_asMap(response.data));
    } catch (e) {
      if (_is409(e)) {
        throw ConflictException('Duplicate entry already exists');
      }
      throw Exception(
          'Failed to create project context entry: ${_extractError(e)}');
    }
  }

  Future<ProjectContextEntry> updateProjectContextEntry({
    required String projectId,
    required String entryId,
    String? content,
    String? type,
    int? version,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '$_designBaseUrl/projects/$projectId/project-context/$entryId',
        data: {
          if (content != null) 'content': content,
          if (type != null) 'type': type,
          if (version != null) 'version': version,
        },
      );
      return ProjectContextEntry.fromJson(_asMap(response.data));
    } catch (e) {
      if (_is409(e)) {
        throw ConflictException('Version conflict. Please refresh and retry.');
      }
      throw Exception(
          'Failed to update project context entry: ${_extractError(e)}');
    }
  }

  Future<void> deleteProjectContextEntry({
    required String projectId,
    required String entryId,
  }) async {
    try {
      await _apiClient.dio.delete(
        '$_designBaseUrl/projects/$projectId/project-context/$entryId',
      );
    } catch (e) {
      throw Exception(
          'Failed to delete project context entry: ${_extractError(e)}');
    }
  }

  void dispose() {
    _apiClient.dispose();
  }
}
