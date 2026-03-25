import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/confirmation.dart';
import '../models/selection.dart';
import '../models/write_summary.dart';

class CanvasDocument {
  final String filePath;
  final int versionNumber;
  final String? contentMarkdown;
  final String source;
  final String createdAt;

  CanvasDocument({
    required this.filePath,
    required this.versionNumber,
    this.contentMarkdown,
    required this.source,
    required this.createdAt,
  });

  factory CanvasDocument.fromJson(Map<String, dynamic> json) {
    return CanvasDocument(
      filePath: json['file_path'] as String,
      versionNumber: json['version_number'] as int,
      contentMarkdown: json['content_markdown'] as String?,
      source: json['source'] as String? ?? 'ai',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SSEEvent {
  final String type;
  final String? content;
  final String? contentMode;
  final String? finalContent;
  final String? sessionId;
  final String? logId;
  final Map<String, dynamic>? toolCall;
  final Confirmation? confirmation;
  final SelectionInfo? selection;
  final String? stage;
  final String? pillar;
  final bool? isFinal;
  final CanvasDocument? canvasDocument;
  final DocumentWriteSummary? writeSummary;

  SSEEvent({
    required this.type,
    this.content,
    this.contentMode,
    this.finalContent,
    this.sessionId,
    this.logId,
    this.toolCall,
    this.confirmation,
    this.selection,
    this.stage,
    this.pillar,
    this.isFinal,
    this.canvasDocument,
    this.writeSummary,
  });

  factory SSEEvent.fromJson(Map<String, dynamic> json) {
    return SSEEvent(
      type: json['type']?.toString() ?? 'error',
      content: json['content']?.toString(),
      contentMode: json['content_mode']?.toString(),
      finalContent: json['final_content']?.toString(),
      sessionId: json['session_id']?.toString(),
      logId: json['log_id']?.toString(),
      toolCall: json['tool_call'] == null
          ? null
          : Map<String, dynamic>.from(json['tool_call'] as Map),
      confirmation: json['confirmation'] == null
          ? null
          : Confirmation.fromJson(
              Map<String, dynamic>.from(json['confirmation'] as Map)),
      selection: json['selection'] == null
          ? null
          : SelectionInfo.fromJson(
              Map<String, dynamic>.from(json['selection'] as Map)),
      stage: json['stage']?.toString(),
      pillar: json['pillar']?.toString(),
      isFinal: json['is_final'] as bool?,
      canvasDocument: json['canvas_document'] != null
          ? CanvasDocument.fromJson(
              Map<String, dynamic>.from(json['canvas_document'] as Map))
          : null,
      writeSummary: json['write_summary'] != null
          ? DocumentWriteSummary.fromJson(
              Map<String, dynamic>.from(json['write_summary'] as Map))
          : null,
    );
  }
}

class V2SSEService {
  final SettingsProvider _settingsProvider;
  final AuthProvider _authProvider;
  http.Client? _activeClient;
  bool _disposed = false;

  V2SSEService({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  })  : _settingsProvider = settingsProvider,
        _authProvider = authProvider;

  String get _baseUrl => _settingsProvider.apiBaseUrl;

  void cancelActiveStream() {
    final client = _activeClient;
    _activeClient = null;
    client?.close();
  }

  void dispose() {
    _disposed = true;
    cancelActiveStream();
  }

  Map<String, String> _headers() {
    final userId = _authProvider.userId.trim();
    if (userId.isEmpty) {
      throw Exception('You must be signed in to use Game Design Assistant v2.');
    }

    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-User-ID': userId,
    };

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Stream<SSEEvent> streamMessage({
    required String sessionId,
    required String content,
    String? documentPath,
    bool Function()? shouldCancel,
  }) async* {
    if (_disposed) {
      throw StateError('V2SSEService has been disposed.');
    }
    cancelActiveStream();
    final query = StringBuffer(
      '?content=${Uri.encodeComponent(content)}',
    );
    if (documentPath != null && documentPath.trim().isNotEmpty) {
      query.write('&document_path=${Uri.encodeComponent(documentPath.trim())}');
    }
    query.write('&stream_mode=delta_v1');
    final uri = Uri.parse(
      '$_baseUrl/api/v2/design-agent/sessions/$sessionId/stream'
      '$query',
    );

    final client = http.Client();
    _activeClient = client;
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(_headers());
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw Exception('SSE request failed (${response.statusCode}): $body');
      }

      const idleTimeout = Duration(seconds: 90);
      var buffer = '';
      var cancelled = false;

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(idleTimeout, onTimeout: (sink) {
        sink.addError(
            TimeoutException('SSE stream idle too long', idleTimeout));
        sink.close();
      })) {
        if (shouldCancel?.call() ?? false) {
          cancelled = true;
          cancelActiveStream();
          break;
        }
        buffer += chunk;
        while (true) {
          final lineBreak = buffer.indexOf('\n');
          if (lineBreak == -1) break;
          var line = buffer.substring(0, lineBreak);
          buffer = buffer.substring(lineBreak + 1);
          if (line.endsWith('\r')) {
            line = line.substring(0, line.length - 1);
          }
          if (line.isEmpty || line.startsWith(':')) continue;
          if (line.startsWith('data: ')) {
            if (shouldCancel?.call() ?? false) {
              cancelled = true;
              cancelActiveStream();
              break;
            }
            final jsonStr = line.substring(6);
            if (jsonStr.isEmpty) continue;
            try {
              final data = jsonDecode(jsonStr);
              if (data is Map<String, dynamic>) {
                yield SSEEvent.fromJson(data);
              } else if (data is Map) {
                yield SSEEvent.fromJson(Map<String, dynamic>.from(data));
              }
            } catch (e) {
              yield SSEEvent(
                  type: 'error', content: 'Failed to parse stream event: $e');
            }
          }
        }
        if (cancelled) {
          break;
        }
      }
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      client.close();
    }
  }
}
