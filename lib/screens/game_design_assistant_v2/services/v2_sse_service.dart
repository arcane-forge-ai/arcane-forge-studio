import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/confirmation.dart';
import '../models/selection.dart';

class SSEEvent {
  final String type;
  final String? content;
  final String? logId;
  final Map<String, dynamic>? toolCall;
  final Confirmation? confirmation;
  final SelectionInfo? selection;
  final bool? isFinal;

  SSEEvent({
    required this.type,
    this.content,
    this.logId,
    this.toolCall,
    this.confirmation,
    this.selection,
    this.isFinal,
  });

  factory SSEEvent.fromJson(Map<String, dynamic> json) {
    return SSEEvent(
      type: json['type']?.toString() ?? 'error',
      content: json['content']?.toString(),
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
      isFinal: json['is_final'] as bool?,
    );
  }
}

class V2SSEService {
  final SettingsProvider _settingsProvider;
  final AuthProvider _authProvider;

  V2SSEService({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  })  : _settingsProvider = settingsProvider,
        _authProvider = authProvider;

  String get _baseUrl => _settingsProvider.apiBaseUrl;

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
  }) async* {
    final uri = Uri.parse(
      '$_baseUrl/api/v2/design-agent/sessions/$sessionId/stream'
      '?content=${Uri.encodeComponent(content)}',
    );

    final client = http.Client();
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

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(idleTimeout, onTimeout: (sink) {
        sink.addError(
            TimeoutException('SSE stream idle too long', idleTimeout));
        sink.close();
      })) {
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
      }
    } finally {
      client.close();
    }
  }
}
