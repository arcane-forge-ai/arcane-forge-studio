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
    if (knowledgeBaseName != null)
      json['knowledge_base_name'] = knowledgeBaseName;
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
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
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
  final String?
      creatorUsername; // Username for display in collaborative projects

  ChatSession({
    required this.id,
    required this.sessionId,
    required this.projectId,
    required this.userId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.creatorUsername,
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
      creatorUsername: json['creator_username'],
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
      'creator_username': creatorUsername,
    };
  }
}

class KnowledgeBaseFile {
  final int id;
  final String documentName;
  final String fileType;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  
  // Unified Knowledge Base fields
  final String entryType;        // 'document', 'link', 'folder', 'contact', 'other'
  final String visibility;       // 'vendor_visible', 'internal_only'
  final String authorityLevel;   // 'source_of_truth', 'reference', 'deprecated'
  final List<String> tags;       // Keywords for search
  final String? description;     // Summary/context
  final String? url;            // For link entries
  final Map<String, String>? contactInfo; // For contact entries

  KnowledgeBaseFile({
    required this.id,
    required this.documentName,
    required this.fileType,
    required this.createdAt,
    this.metadata,
    this.entryType = 'document',
    this.visibility = 'vendor_visible',
    this.authorityLevel = 'reference',
    this.tags = const [],
    this.description,
    this.url,
    this.contactInfo,
  });

  factory KnowledgeBaseFile.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseFile(
      id: json['id'] ?? 0,
      documentName:
          json['document_name'] ?? json['documentName'] ?? 'Unknown File',
      fileType: json['file_type'] ?? json['fileType'] ?? 'unknown',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
      metadata: json['metadata'],
      entryType: json['entry_type'] ?? json['entryType'] ?? 'document',
      visibility: json['visibility'] ?? 'vendor_visible',
      authorityLevel: json['authority_level'] ?? json['authorityLevel'] ?? 'reference',
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'])
          : [],
      description: json['description'],
      url: json['url'],
      contactInfo: json['contact_info'] != null
          ? Map<String, String>.from(json['contact_info'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_name': documentName,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      'entry_type': entryType,
      'visibility': visibility,
      'authority_level': authorityLevel,
      'tags': tags,
      if (description != null) 'description': description,
      if (url != null) 'url': url,
      if (contactInfo != null) 'contact_info': contactInfo,
    };
  }

  KnowledgeBaseFile copyWith({
    int? id,
    String? documentName,
    String? fileType,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    String? entryType,
    String? visibility,
    String? authorityLevel,
    List<String>? tags,
    String? description,
    String? url,
    Map<String, String>? contactInfo,
  }) {
    return KnowledgeBaseFile(
      id: id ?? this.id,
      documentName: documentName ?? this.documentName,
      fileType: fileType ?? this.fileType,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      entryType: entryType ?? this.entryType,
      visibility: visibility ?? this.visibility,
      authorityLevel: authorityLevel ?? this.authorityLevel,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      url: url ?? this.url,
      contactInfo: contactInfo ?? this.contactInfo,
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
