import 'confirmation.dart';
import 'selection.dart';
import 'write_summary.dart';

class SendMessageRequest {
  final String? content;
  final SelectionAnswer? selectionAnswer;
  final Map<String, dynamic> metadata;

  SendMessageRequest({
    this.content,
    this.selectionAnswer,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      if (content != null && content!.trim().isNotEmpty) 'content': content,
      if (selectionAnswer != null)
        'selection_answer': selectionAnswer!.toJson(),
      'metadata': metadata,
    };
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isPartial;
  final String? thinking;
  final Confirmation? confirmation;
  final SelectionInfo? selection;
  final DocumentWriteSummary? writeSummary;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isPartial = false,
    this.thinking,
    this.confirmation,
    this.selection,
    this.writeSummary,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role']?.toString() ?? 'user',
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isPartial: json['partial'] == true,
      thinking: json['thinking']?.toString(),
      confirmation: json['confirmation'] != null
          ? Confirmation.fromJson(
              Map<String, dynamic>.from(json['confirmation'] as Map))
          : null,
      selection: json['selection'] != null
          ? SelectionInfo.fromJson(
              Map<String, dynamic>.from(json['selection'] as Map))
          : null,
      writeSummary: json['write_summary'] != null
          ? DocumentWriteSummary.fromJson(
              Map<String, dynamic>.from(json['write_summary'] as Map))
          : null,
    );
  }
}
