import 'package:flutter/material.dart';
import '../models/feedback_models.dart' as feedback_models;
import '../services/feedback_service.dart';

class FeedbackProvider extends ChangeNotifier {
  final FeedbackService _feedbackService;

  List<feedback_models.Feedback> _feedbacks = [];
  List<feedback_models.AnalyzeSession> _analyzeSessions = [];
  bool _isLoading = false;
  String? _error;
  String? _feedbackUrl;
  bool _useMockData = false; // Default to false since we're using project URLs

  FeedbackProvider({FeedbackService? feedbackService})
      : _feedbackService = feedbackService ?? FeedbackService();

  // Getters
  List<feedback_models.Feedback> get feedbacks => _feedbacks;
  List<feedback_models.AnalyzeSession> get analyzeSessions => _analyzeSessions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get feedbackUrl => _feedbackUrl;
  bool get useMockData => _useMockData;
  bool get hasFeedbackUrl => _feedbackUrl != null && _feedbackUrl!.isNotEmpty;

  /// Set the feedback URL for this project
  void setFeedbackUrl(String? url) {
    _feedbackUrl = url;
    notifyListeners();
  }

  /// Toggle between mock and real API data (for development)
  void toggleMockData() {
    _useMockData = !_useMockData;
    notifyListeners();
  }

  /// Load feedbacks from the configured URL or mock data
  Future<void> loadFeedbacks() async {
    _setLoading(true);
    _setError(null);

    try {
      if (_useMockData) {
        final response = await _feedbackService.getMockFeedbacks();
        _feedbacks = response.feedbacks;
      } else if (_feedbackUrl != null && _feedbackUrl!.isNotEmpty) {
        final response =
            await _feedbackService.getFeedbacks(feedbackUrl: _feedbackUrl!);
        _feedbacks = response.feedbacks;
      } else {
        throw Exception(
            'No feedback URL configured. Please set the feedback URL in Release Info.');
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh feedbacks
  Future<void> refreshFeedbacks() async {
    await loadFeedbacks();
  }

  /// Create a new analyze session
  feedback_models.AnalyzeSession createAnalyzeSession({
    required String projectId,
    required feedback_models.AnalyzeMode mode,
    required String title,
    List<String> feedbackIds = const [],
  }) {
    final session = feedback_models.AnalyzeSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: projectId,
      mode: mode,
      title: title,
      createdAt: DateTime.now(),
      feedbackIds: feedbackIds,
    );

    _analyzeSessions.add(session);
    notifyListeners();

    return session;
  }

  /// Update an analyze session
  void updateAnalyzeSession(feedback_models.AnalyzeSession updatedSession) {
    final index = _analyzeSessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _analyzeSessions[index] = updatedSession.copyWith(
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Delete an analyze session
  void deleteAnalyzeSession(String sessionId) {
    _analyzeSessions.removeWhere((s) => s.id == sessionId);
    notifyListeners();
  }

  /// Get feedbacks by IDs
  List<feedback_models.Feedback> getFeedbacksByIds(List<String> feedbackIds) {
    return _feedbacks.where((f) => feedbackIds.contains(f.id)).toList();
  }

  /// Get recent feedbacks (last 7 days)
  List<feedback_models.Feedback> getRecentFeedbacks() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _feedbacks.where((f) => f.createdAt.isAfter(sevenDaysAgo)).toList();
  }

  /// Get feedbacks by date range
  List<feedback_models.Feedback> getFeedbacksByDateRange(
      DateTime startDate, DateTime endDate) {
    return _feedbacks
        .where((f) =>
            f.createdAt.isAfter(startDate) && f.createdAt.isBefore(endDate))
        .toList();
  }

  /// Search feedbacks by message content
  List<feedback_models.Feedback> searchFeedbacks(String query) {
    if (query.isEmpty) return _feedbacks;

    final lowercaseQuery = query.toLowerCase();
    return _feedbacks
        .where((f) => f.message.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get feedback statistics
  Map<String, dynamic> getFeedbackStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = today.subtract(Duration(days: today.weekday - 1));
    final thisMonth = DateTime(now.year, now.month, 1);

    return {
      'total': _feedbacks.length,
      'today': _feedbacks.where((f) => f.createdAt.isAfter(today)).length,
      'this_week':
          _feedbacks.where((f) => f.createdAt.isAfter(thisWeek)).length,
      'this_month':
          _feedbacks.where((f) => f.createdAt.isAfter(thisMonth)).length,
      'with_email': _feedbacks
          .where((f) => f.email != null && f.email!.isNotEmpty)
          .length,
      'want_notify': _feedbacks.where((f) => f.wantNotify).length,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _feedbacks.clear();
    _analyzeSessions.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
