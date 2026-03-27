import 'message.dart';

class CreateSessionRequest {
  final String projectId;
  final String? title;
  final String? gameType;

  CreateSessionRequest({
    required this.projectId,
    this.title,
    this.gameType,
  });

  Map<String, dynamic> toJson() {
    return {
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      if (gameType != null && gameType!.trim().isNotEmpty)
        'game_type': gameType!.trim(),
    };
  }
}

class CreateSessionResponse {
  final String sessionId;
  final String? projectId;
  final DateTime createdAt;

  CreateSessionResponse({
    required this.sessionId,
    this.projectId,
    required this.createdAt,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) {
    return CreateSessionResponse(
      sessionId: json['session_id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SessionInfo {
  final String sessionId;
  final String userId;
  final String? projectId;
  final String? projectName;
  final String? title;
  final String? activeDocumentPath;
  final String? currentStage;
  final String? currentPillar;
  final int turnCount;
  final int lastExtractionTurn;
  final DateTime createdAt;
  final DateTime updatedAt;

  SessionInfo({
    required this.sessionId,
    required this.userId,
    this.projectId,
    this.projectName,
    this.title,
    this.activeDocumentPath,
    this.currentStage,
    this.currentPillar,
    this.turnCount = 0,
    this.lastExtractionTurn = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['session_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      projectName: json['project_name']?.toString(),
      title: json['title']?.toString(),
      activeDocumentPath: json['active_document_path']?.toString(),
      currentStage: json['current_stage']?.toString(),
      currentPillar: json['current_pillar']?.toString(),
      turnCount: (json['turn_count'] as num?)?.toInt() ?? 0,
      lastExtractionTurn: (json['last_extraction_turn'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SessionHistoryPayload {
  final String sessionId;
  final int total;
  final int offset;
  final int limit;
  final List<ChatMessage> messages;

  SessionHistoryPayload({
    required this.sessionId,
    required this.total,
    required this.offset,
    required this.limit,
    required this.messages,
  });

  factory SessionHistoryPayload.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List? ?? const [];
    return SessionHistoryPayload(
      sessionId: json['session_id']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      messages: messagesJson
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}

class SessionBootstrapResponse {
  final SessionInfo session;
  final SessionHistoryPayload history;

  SessionBootstrapResponse({
    required this.session,
    required this.history,
  });

  factory SessionBootstrapResponse.fromJson(Map<String, dynamic> json) {
    return SessionBootstrapResponse(
      session: SessionInfo.fromJson(
        Map<String, dynamic>.from(json['session'] as Map? ?? const {}),
      ),
      history: SessionHistoryPayload.fromJson(
        Map<String, dynamic>.from(json['history'] as Map? ?? const {}),
      ),
    );
  }
}
