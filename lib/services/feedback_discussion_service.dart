import '../models/feedback_models.dart' as feedback_models;

class FeedbackDiscussionService {
  static final FeedbackDiscussionService _instance = FeedbackDiscussionService._internal();
  factory FeedbackDiscussionService() => _instance;
  FeedbackDiscussionService._internal();

  String? _pendingTopic;
  List<feedback_models.Feedback>? _pendingFeedbacks;
  String? _pendingProjectId;
  String? _pendingProjectName;
  String? _pendingGameIntroduction;

  // Getters
  String? get pendingTopic => _pendingTopic;
  List<feedback_models.Feedback>? get pendingFeedbacks => _pendingFeedbacks;
  String? get pendingProjectId => _pendingProjectId;
  String? get pendingProjectName => _pendingProjectName;
  String? get pendingGameIntroduction => _pendingGameIntroduction;
  bool get hasPendingFeedbackDiscussion => _pendingTopic != null && _pendingFeedbacks != null;

  // Set feedback discussion data
  void setFeedbackDiscussionData({
    required String topic,
    required List<feedback_models.Feedback> feedbacks,
    required String projectId,
    required String projectName,
    String? gameIntroduction,
  }) {
    _pendingTopic = topic;
    _pendingFeedbacks = feedbacks;
    _pendingProjectId = projectId;
    _pendingProjectName = projectName;
    _pendingGameIntroduction = gameIntroduction;
  }

  // Clear feedback discussion data after it's been used
  void clearFeedbackDiscussionData() {
    _pendingTopic = null;
    _pendingFeedbacks = null;
    _pendingProjectId = null;
    _pendingProjectName = null;
    _pendingGameIntroduction = null;
  }

  // Format feedbacks for chat message
  String formatFeedbacksForChat(List<feedback_models.Feedback> feedbacks, String topic, {String? gameIntroduction}) {
    final buffer = StringBuffer();
    
    // Add game introduction if available
    if (gameIntroduction != null && gameIntroduction.isNotEmpty) {
      buffer.writeln('# Game Introduction');
      buffer.writeln();
      buffer.writeln(gameIntroduction);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    
    // Add the topic/question at the top
    buffer.writeln('# Free Discussion Topic');
    buffer.writeln();
    buffer.writeln(topic);
    buffer.writeln();
    
    // Add feedbacks section
    buffer.writeln('# Selected Feedbacks (${feedbacks.length} items)');
    buffer.writeln();
    
    for (int i = 0; i < feedbacks.length; i++) {
      final feedback = feedbacks[i];
      buffer.writeln('## Feedback ${i + 1}');
      buffer.writeln('**Date:** ${feedback.createdAt.toIso8601String()}');
      // Email and Wants Notification are not needed for free discussion
      // if (feedback.email != null) {
      //   buffer.writeln('**Email:** ${feedback.email}');
      // }
      // buffer.writeln('**Wants Notification:** ${feedback.wantNotify ? 'Yes' : 'No'}');
      // buffer.writeln();
      buffer.writeln('**Message:**');
      buffer.writeln(feedback.message);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    
    // Add instructions for AI
    buffer.writeln('# Instructions');
    buffer.writeln('Please analyze the above feedbacks in the context of the discussion topic. ');
    buffer.writeln('Use your knowledge base about the game project to provide relevant insights, ');
    buffer.writeln('suggestions, and answers. Focus on actionable recommendations where appropriate.');
    
    return buffer.toString();
  }
} 