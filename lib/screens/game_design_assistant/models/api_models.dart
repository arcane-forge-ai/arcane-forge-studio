// API Request/Response Models for FastAPI Backend

// import 'chat_message.dart'; // Temporarily unused - may be needed for future enhancements

class ChatRequest {
  final String message;
  final int? projectId;
  final String? userId;
  final String? knowledgeBaseName;
  final String? sessionId;
  final String? title;
  final String? agentType;
  final Map<String, dynamic>? extraConfig;

  ChatRequest({
    required this.message,
    this.projectId,
    this.userId,
    this.knowledgeBaseName,
    this.sessionId,
    this.title,
    this.agentType,
    this.extraConfig,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'message': message,
    };
    
    // Only include fields if they have values - let API handle defaults
    if (projectId != null) json['project_id'] = projectId;
    if (userId != null) json['user_id'] = userId;
    if (knowledgeBaseName != null) json['knowledge_base_name'] = knowledgeBaseName;
    if (sessionId != null) json['session_id'] = sessionId;
    if (title != null) json['title'] = title;
    if (agentType != null) json['agent_type'] = agentType;
    if (extraConfig != null) json['extra_config'] = extraConfig;
    
    return json;
  }
}

class ChatResponse {
  final String output;
  final String input;
  final String sessionId;
  final DateTime? timestamp;

  ChatResponse({
    required this.output,
    required this.input,
    required this.sessionId,
    this.timestamp,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      output: json['output'],
      input: json['input'],
      sessionId: json['session_id'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'output': output,
      'input': input,
      'session_id': sessionId,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  // Compatibility methods for existing code
  String get content => output;
  String get role => 'assistant';
}

class MessageResponse {
  final int id;
  final String sessionId;
  final String? message;

  MessageResponse({
    required this.id,
    required this.sessionId,
    this.message,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      id: json['id'],
      sessionId: json['session_id'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'message': message,
    };
  }
}

class ChatHistoryResponse {
  final String sessionId;
  final List<MessageResponse> messages;

  ChatHistoryResponse({
    required this.sessionId,
    required this.messages,
  });

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      sessionId: json['session_id'],
      messages: (json['messages'] as List<dynamic>)
          .map((item) => MessageResponse.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class ChatSession {
  final int id;
  final String sessionId;
  final int projectId;
  final String userId;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.sessionId,
    required this.projectId,
    required this.userId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      sessionId: json['session_id'],
      projectId: json['project_id'],
      userId: json['user_id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'project_id': projectId,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class KnowledgeBaseFile {
  final int id;
  final String documentName;
  final String fileType;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  KnowledgeBaseFile({
    required this.id,
    required this.documentName,
    required this.fileType,
    required this.createdAt,
    this.metadata,
  });

  factory KnowledgeBaseFile.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseFile(
      id: json['id'] ?? 0,
      documentName: json['document_name'] ?? json['documentName'] ?? 'Unknown File',
      fileType: json['file_type'] ?? json['fileType'] ?? 'unknown',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
      metadata: json['metadata'],
    );
  }
}

class FileDownloadResponse {
  final String downloadUrl;
  final String fileName;
  final int? fileSize;
  final String? contentType;
  final int expiresIn;

  FileDownloadResponse({
    required this.downloadUrl,
    required this.fileName,
    this.fileSize,
    this.contentType,
    this.expiresIn = 3600,
  });

  factory FileDownloadResponse.fromJson(Map<String, dynamic> json) {
    return FileDownloadResponse(
      downloadUrl: json['download_url'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      contentType: json['content_type'],
      expiresIn: json['expires_in'] ?? 3600,
    );
  }
}

// Chat Session Management Models
class ChatSessionCreateRequest {
  final String userId;
  final String? sessionId;

  ChatSessionCreateRequest({
    required this.userId,
    this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'session_id': sessionId,
    };
  }
}

class ChatSessionCreateResponse {
  final int id;
  final String sessionId;
  final int projectId;
  final String userId;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSessionCreateResponse({
    required this.id,
    required this.sessionId,
    required this.projectId,
    required this.userId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSessionCreateResponse.fromJson(Map<String, dynamic> json) {
    return ChatSessionCreateResponse(
      id: json['id'],
      sessionId: json['session_id'],
      projectId: json['project_id'],
      userId: json['user_id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class ExtractedDocument {
  final String id;
  final String title;
  final String content;
  final String projectId;
  final DateTime extractedAt;
  final String sourceMessageId;

  ExtractedDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.projectId,
    required this.extractedAt,
    required this.sourceMessageId,
  });

  factory ExtractedDocument.fromJson(Map<String, dynamic> json) {
    return ExtractedDocument(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      projectId: json['projectId'],
      extractedAt: DateTime.parse(json['extractedAt']),
      sourceMessageId: json['sourceMessageId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'projectId': projectId,
      'extractedAt': extractedAt.toIso8601String(),
      'sourceMessageId': sourceMessageId,
    };
  }
} 