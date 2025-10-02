class Feedback {
  final String id;
  final String gameSlug;
  final String message;
  final String? email;
  final bool wantNotify;
  final DateTime createdAt;

  Feedback({
    required this.id,
    required this.gameSlug,
    required this.message,
    this.email,
    required this.wantNotify,
    required this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] as String,
      gameSlug: json['game_slug'] as String,
      message: json['message'] as String,
      email: json['email'] as String?,
      wantNotify: json['want_notify'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_slug': gameSlug,
      'message': message,
      'email': email,
      'want_notify': wantNotify,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Feedback copyWith({
    String? id,
    String? gameSlug,
    String? message,
    String? email,
    bool? wantNotify,
    DateTime? createdAt,
  }) {
    return Feedback(
      id: id ?? this.id,
      gameSlug: gameSlug ?? this.gameSlug,
      message: message ?? this.message,
      email: email ?? this.email,
      wantNotify: wantNotify ?? this.wantNotify,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FeedbackResponse {
  final List<Feedback> feedbacks;

  FeedbackResponse({
    required this.feedbacks,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    final feedbacksJson = json['feedbacks'] as List<dynamic>;
    final feedbacks = feedbacksJson
        .map((feedbackJson) =>
            Feedback.fromJson(feedbackJson as Map<String, dynamic>))
        .toList();

    return FeedbackResponse(
      feedbacks: feedbacks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feedbacks': feedbacks.map((feedback) => feedback.toJson()).toList(),
    };
  }
}

enum AnalyzeMode {
  freeDiscuss,
  improvementDoc,
}

class AnalyzeSession {
  final String id;
  final String projectId;
  final AnalyzeMode mode;
  final String title;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;
  final List<String> feedbackIds; // IDs of feedbacks being analyzed
  final Map<String, dynamic> metadata;

  AnalyzeSession({
    required this.id,
    required this.projectId,
    required this.mode,
    required this.title,
    required this.createdAt,
    this.lastUpdatedAt,
    this.feedbackIds = const [],
    this.metadata = const {},
  });

  AnalyzeSession copyWith({
    String? id,
    String? projectId,
    AnalyzeMode? mode,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    List<String>? feedbackIds,
    Map<String, dynamic>? metadata,
  }) {
    return AnalyzeSession(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      mode: mode ?? this.mode,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      feedbackIds: feedbackIds ?? this.feedbackIds,
      metadata: metadata ?? this.metadata,
    );
  }
}
