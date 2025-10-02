import 'package:flutter/material.dart';
import '../models/feedback_models.dart' as feedback_models;
import '../models/feedback_analysis_models.dart';
import '../services/feedback_service.dart';
import '../services/feedback_analysis_service.dart';

class FeedbackProvider extends ChangeNotifier {
  final FeedbackService _feedbackService;
  final FeedbackAnalysisService? _analysisService;

  List<feedback_models.Feedback> _feedbacks = [];
  List<feedback_models.AnalyzeSession> _analyzeSessions = [];
  List<FeedbackRunSummary> _apiAnalysisRuns = []; // API analysis runs
  bool _isLoading = false;
  bool _isLoadingAnalysisRuns = false;
  String? _error;
  String? _feedbackUrl;
  bool _useMockData = false; // Default to false since we're using project URLs

  FeedbackProvider({
    FeedbackService? feedbackService,
    FeedbackAnalysisService? analysisService,
  })  : _feedbackService = feedbackService ?? FeedbackService(),
        _analysisService = analysisService;

  // Getters
  List<feedback_models.Feedback> get feedbacks => _feedbacks;
  List<feedback_models.AnalyzeSession> get analyzeSessions => _analyzeSessions;
  List<FeedbackRunSummary> get apiAnalysisRuns => _apiAnalysisRuns;
  bool get isLoading => _isLoading;
  bool get isLoadingAnalysisRuns => _isLoadingAnalysisRuns;
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

  /// Load existing analysis runs from the API
  Future<void> loadAnalysisRuns(int projectId) async {
    if (_analysisService == null) {
      return; // No analysis service available
    }

    _setLoadingAnalysisRuns(true);

    try {
      final response = await _analysisService!.listFeedbackAnalysisRuns(
        projectId: projectId,
        status: 'completed', // Only load completed runs
      );
      
      _apiAnalysisRuns = response.runs;
      notifyListeners();
    } catch (e) {
      print('Error loading analysis runs: $e');
      // Don't set error for this as it's not critical
    } finally {
      _setLoadingAnalysisRuns(false);
    }
  }

  /// Get detailed analysis run with results
  Future<FeedbackRunDetailResponse?> getAnalysisRunDetails({
    required int projectId,
    required String runId,
  }) async {
    if (_analysisService == null) {
      return null;
    }

    try {
      return await _analysisService!.getFeedbackAnalysis(
        projectId: projectId,
        runId: runId,
      );
    } catch (e) {
      print('Error loading analysis run details: $e');
      return null;
    }
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

  void _setLoadingAnalysisRuns(bool loading) {
    _isLoadingAnalysisRuns = loading;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _feedbacks.clear();
    _analyzeSessions.clear();
    _apiAnalysisRuns.clear();
    _error = null;
    _isLoading = false;
    _isLoadingAnalysisRuns = false;
    notifyListeners();
  }
}
