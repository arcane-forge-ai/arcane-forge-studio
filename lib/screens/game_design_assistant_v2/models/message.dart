import 'confirmation.dart';
import 'selection.dart';

class SendMessageRequest {
  final String content;
  final Map<String, dynamic> metadata;

  SendMessageRequest({
    required this.content,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'metadata': metadata,
    };
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final String? thinking;
  final Confirmation? confirmation;
  final SelectionInfo? selection;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.thinking,
    this.confirmation,
    this.selection,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() ?? 'user',
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      thinking: json['thinking']?.toString(),
      confirmation: json['confirmation'] != null
          ? Confirmation.fromJson(
              Map<String, dynamic>.from(json['confirmation'] as Map))
          : null,
      selection: json['selection'] != null
          ? SelectionInfo.fromJson(
              Map<String, dynamic>.from(json['selection'] as Map))
          : null,
    );
  }
}
