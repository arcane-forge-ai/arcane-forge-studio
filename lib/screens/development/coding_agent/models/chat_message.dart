import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant, system }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.localId,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isStreaming = false,
    this.remoteMessageId,
    this.partId,
    this.label,
    this.raw,
  });

  final String localId;
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final bool isStreaming;
  final String? remoteMessageId;
  final String? partId;
  final String? label;
  final Map<String, dynamic>? raw;

  String get stableKey {
    if (remoteMessageId != null && partId != null) {
      return '$remoteMessageId:$partId';
    }
    return remoteMessageId ?? localId;
  }

  ChatMessage copyWith({
    String? localId,
    ChatRole? role,
    String? text,
    DateTime? timestamp,
    bool? isStreaming,
    String? remoteMessageId,
    String? partId,
    String? label,
    Map<String, dynamic>? raw,
  }) {
    return ChatMessage(
      localId: localId ?? this.localId,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
      partId: partId ?? this.partId,
      label: label ?? this.label,
      raw: raw ?? this.raw,
    );
  }
}
