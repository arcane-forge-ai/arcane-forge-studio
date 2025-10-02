class Project {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userId;
  final String? difyDatasetId;
  final List<String> documentIds;
  final bool hasKnowledgeBase;
  final String? gameReleaseUrl;
  final String? gameFeedbackUrl;
  final String? gameIntroduction;
  final String? codeMapUrl;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    this.userId,
    this.difyDatasetId,
    this.documentIds = const [],
    this.hasKnowledgeBase = false,
    this.gameReleaseUrl,
    this.gameFeedbackUrl,
    this.gameIntroduction,
    this.codeMapUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'difyDatasetId': difyDatasetId,
      'documentIds': documentIds,
      'hasKnowledgeBase': hasKnowledgeBase,
      'gameReleaseUrl': gameReleaseUrl,
      'gameFeedbackUrl': gameFeedbackUrl,
      'gameIntroduction': gameIntroduction,
      'codeMapUrl': codeMapUrl,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      userId: json['userId'],
      difyDatasetId: json['difyDatasetId'],
      documentIds: List<String>.from(json['documentIds'] ?? []),
      hasKnowledgeBase: json['hasKnowledgeBase'] ?? false,
      gameReleaseUrl: json['gameReleaseUrl'],
      gameFeedbackUrl: json['gameFeedbackUrl'],
      gameIntroduction: json['gameIntroduction'],
      codeMapUrl: json['codeMapUrl'],
    );
  }

  // Factory method for API response (matches the OpenAPI schema)
  factory Project.fromApiJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'].toString(), // API returns int, but we store as string
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userId: json['user_id'],
      difyDatasetId: json['dify_dataset_id'],
      documentIds: const [], // API doesn't return this, we'll handle it separately
      hasKnowledgeBase: json['dify_dataset_id'] !=
          null, // Has knowledge base if dataset exists
      gameReleaseUrl: json['game_release_url'],
      gameFeedbackUrl: json['game_feedback_url'],
      gameIntroduction: json['game_introduction'],
      codeMapUrl: json['code_map_url'],
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? difyDatasetId,
    List<String>? documentIds,
    bool? hasKnowledgeBase,
    String? gameReleaseUrl,
    String? gameFeedbackUrl,
    String? gameIntroduction,
    String? codeMapUrl,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      difyDatasetId: difyDatasetId ?? this.difyDatasetId,
      documentIds: documentIds ?? this.documentIds,
      hasKnowledgeBase: hasKnowledgeBase ?? this.hasKnowledgeBase,
      gameReleaseUrl: gameReleaseUrl ?? this.gameReleaseUrl,
      gameFeedbackUrl: gameFeedbackUrl ?? this.gameFeedbackUrl,
      gameIntroduction: gameIntroduction ?? this.gameIntroduction,
      codeMapUrl: codeMapUrl ?? this.codeMapUrl,
    );
  }
}
