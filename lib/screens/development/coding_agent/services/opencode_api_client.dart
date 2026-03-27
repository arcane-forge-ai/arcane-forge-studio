import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/opencode_models.dart';

enum PermissionReplyDecision { once, always, reject }

class OpencodeApiClient {
  OpencodeApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _baseUrl;
  bool _isDisposed = false;

  String? get baseUrl => _baseUrl;

  void setBaseUrl(String? value) {
    _baseUrl = value;
  }

  Future<Map<String, dynamic>> health() async {
    return _getMap('/global/health');
  }

  Future<Map<String, dynamic>> getProviders() async {
    return _getMap('/provider');
  }

  Future<Map<String, dynamic>> getConfigProviders() async {
    return _getMap('/config/providers');
  }

  Future<Map<String, dynamic>> getConfig() async {
    return _getMap('/config');
  }

  Future<List<dynamic>> listSessions({String? workspacePath}) async {
    return _getList('/session', directory: workspacePath);
  }

  Future<Map<String, dynamic>> getGlobalConfig() async {
    return _getMap('/global/config');
  }

  Future<Map<String, dynamic>> updateGlobalConfig(
    Map<String, dynamic> config,
  ) async {
    return _patchMap('/global/config', body: config);
  }

  Future<Map<String, dynamic>> createSession({
    required String workspacePath,
    required String title,
    List<dynamic>? permission,
  }) async {
    return _postMap(
      '/session',
      directory: workspacePath,
      body: <String, dynamic>{
        'title': title,
        ...?permission == null
            ? null
            : <String, dynamic>{'permission': permission},
      },
    );
  }

  Future<List<dynamic>> loadMessages(
    String sessionId, {
    required String workspacePath,
    int limit = 200,
  }) async {
    return _getList(
      '/session/$sessionId/message',
      directory: workspacePath,
      query: <String, String>{'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String sessionId,
    required String workspacePath,
    required List<Map<String, dynamic>> parts,
    String? system,
    String? format,
    String? agent,
    String? model,
    String? variant,
    bool noReply = false,
  }) async {
    return _postMap(
      '/session/$sessionId/message',
      directory: workspacePath,
      body: <String, dynamic>{
        'parts': parts,
        'noReply': noReply,
        if (system != null && system.isNotEmpty) 'system': system,
        if (format != null && format.isNotEmpty) 'format': format,
        if (agent != null && agent.isNotEmpty) 'agent': agent,
        if (model != null && model.isNotEmpty) 'model': model,
        if (variant != null && variant.isNotEmpty) 'variant': variant,
      },
    );
  }

  Future<Map<String, dynamic>> abortSession({
    required String sessionId,
    required String workspacePath,
  }) async {
    return _postMap('/session/$sessionId/abort', directory: workspacePath);
  }

  Future<Map<String, dynamic>> updateSession({
    required String sessionId,
    required String workspacePath,
    String? title,
  }) async {
    return _postMap(
      '/session/$sessionId',
      directory: workspacePath,
      body: <String, dynamic>{
        if (title != null && title.isNotEmpty) 'title': title,
      },
    );
  }

  Future<List<dynamic>> listPermissions({required String workspacePath}) async {
    return _getList('/permission', directory: workspacePath);
  }

  Future<List<dynamic>> listQuestions({required String workspacePath}) async {
    return _getList('/question', directory: workspacePath);
  }

  Future<Map<String, dynamic>> replyPermission({
    required String requestId,
    required PermissionReplyDecision decision,
    required String workspacePath,
    String? message,
  }) async {
    final bool approved = decision != PermissionReplyDecision.reject;
    final String primaryReply = switch (decision) {
      PermissionReplyDecision.once => 'once',
      PermissionReplyDecision.always => 'always',
      PermissionReplyDecision.reject => 'reject',
    };
    final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[
      <String, dynamic>{
        'reply': primaryReply,
        if (message != null && message.isNotEmpty) 'message': message,
      },
      <String, dynamic>{
        'reply': approved ? 'allow' : 'deny',
        if (message != null && message.isNotEmpty) 'message': message,
      },
      <String, dynamic>{
        'reply': approved ? 'approved' : 'denied',
        if (message != null && message.isNotEmpty) 'message': message,
      },
      <String, dynamic>{
        'reply': approved,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    ];

    return _tryPostFallbacks(
      '/permission/$requestId/reply',
      directory: workspacePath,
      payloads: payloads,
    );
  }

  Future<Map<String, dynamic>> replySessionPermission({
    required String sessionId,
    required String permissionId,
    required PermissionReplyDecision decision,
    required String workspacePath,
  }) async {
    final bool approved = decision != PermissionReplyDecision.reject;
    final String primaryReply = switch (decision) {
      PermissionReplyDecision.once => 'once',
      PermissionReplyDecision.always => 'always',
      PermissionReplyDecision.reject => 'reject',
    };
    final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[
      <String, dynamic>{'response': primaryReply},
      <String, dynamic>{'reply': primaryReply},
      <String, dynamic>{'response': approved ? 'allow' : 'deny'},
      <String, dynamic>{'response': approved ? 'approved' : 'denied'},
      <String, dynamic>{'response': approved},
    ];

    return _tryPostFallbacks(
      '/session/$sessionId/permissions/$permissionId',
      directory: workspacePath,
      payloads: payloads,
    );
  }

  Future<Map<String, dynamic>> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    required String workspacePath,
  }) async {
    final List<List<String>> normalizedAnswers = answers
        .map(
          (List<String> row) => row
              .map((String item) => item.trim())
              .where((String item) => item.isNotEmpty)
              .toList(),
        )
        .where((List<String> row) => row.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[
      <String, dynamic>{'answers': normalizedAnswers},
      <String, dynamic>{
        'answers': normalizedAnswers
            .map((List<String> row) => row.join(', '))
            .toList(),
      },
      <String, dynamic>{'reply': normalizedAnswers},
    ];

    return _tryPostFallbacks(
      '/question/$requestId/reply',
      directory: workspacePath,
      payloads: payloads,
    );
  }

  Future<Map<String, dynamic>> rejectQuestion({
    required String requestId,
    required String workspacePath,
  }) async {
    return _postMap('/question/$requestId/reject', directory: workspacePath);
  }

  Stream<OpencodeEventEnvelope> subscribeEvents(String workspacePath) async* {
    try {
      final Uri uri = _buildUri(
        '/event',
        query: <String, String>{'directory': workspacePath},
      );

      final http.Request request = http.Request('GET', uri);
      request.headers.addAll(_headers(directory: workspacePath, json: false));
      request.headers['Accept'] = 'text/event-stream';

      final http.StreamedResponse response = await _httpClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('SSE subscribe failed: ${response.statusCode}');
      }

      String? eventName;
      String? eventId;
      final List<String> dataLines = <String>[];

      await for (final String line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (dataLines.isEmpty) {
            eventName = null;
            eventId = null;
            continue;
          }

          final String data = dataLines.join('\n');
          final dynamic decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            yield OpencodeEventEnvelope(
              directory: decoded['directory'] as String? ?? workspacePath,
              payload: decoded['payload'] as Map<String, dynamic>? ??
                  decoded.cast<String, dynamic>(),
              eventName: eventName,
              id: eventId,
            );
          }

          dataLines.clear();
          eventName = null;
          eventId = null;
          continue;
        }

        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('id:')) {
          eventId = line.substring(3).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
    } on http.ClientException {
      if (_isDisposed) {
        return;
      }
      rethrow;
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    String? directory,
    Map<String, String>? query,
  }) async {
    final dynamic response = await _request(
      'GET',
      path,
      directory: directory,
      query: query,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{};
  }

  Future<List<dynamic>> _getList(
    String path, {
    String? directory,
    Map<String, String>? query,
  }) async {
    final dynamic response = await _request(
      'GET',
      path,
      directory: directory,
      query: query,
    );
    if (response is List<dynamic>) {
      return response;
    }
    if (response is Map<String, dynamic>) {
      final dynamic items =
          response['items'] ?? response['messages'] ?? response['data'];
      if (items is List<dynamic>) {
        return items;
      }
    }
    return const <dynamic>[];
  }

  Future<Map<String, dynamic>> _postMap(
    String path, {
    String? directory,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final dynamic response = await _request(
      'POST',
      path,
      directory: directory,
      query: query,
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{'data': response};
  }

  Future<Map<String, dynamic>> _patchMap(
    String path, {
    String? directory,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final dynamic response = await _request(
      'PATCH',
      path,
      directory: directory,
      query: query,
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return <String, dynamic>{'data': response};
  }

  Future<Map<String, dynamic>> _tryPostFallbacks(
    String path, {
    required String directory,
    required List<Map<String, dynamic>> payloads,
  }) async {
    Object? lastError;
    for (final Map<String, dynamic> payload in payloads) {
      try {
        return await _postMap(path, directory: directory, body: payload);
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception('All fallback payloads failed for $path: $lastError');
  }

  Future<dynamic> _request(
    String method,
    String path, {
    String? directory,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = _buildUri(path, query: query);
    final http.Request request = http.Request(method, uri);
    request.headers.addAll(_headers(directory: directory, json: body != null));
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final http.StreamedResponse response = await _httpClient.send(request);
    final String text = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Opencode request failed (${response.statusCode}) $path: $text',
      );
    }
    if (text.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(text);
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw StateError('OpencodeApiClient.baseUrl must be set before use.');
    }

    final Uri base = Uri.parse(_baseUrl!);
    return base.replace(
      path: path,
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  Map<String, String> _headers({String? directory, bool json = true}) {
    return <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?directory == null
          ? null
          : <String, String>{'x-opencode-directory': directory},
    };
  }

  void dispose() {
    _isDisposed = true;
    _httpClient.close();
  }
}
