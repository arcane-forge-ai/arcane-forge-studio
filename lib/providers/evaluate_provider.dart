import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/evaluate_models.dart';
import '../services/evaluate_api_service.dart';
import 'settings_provider.dart';
import 'auth_provider.dart';

class EvaluateProvider extends ChangeNotifier {
  final EvaluateApiService _apiService;
  
  EvaluateResponse? _latestEvaluation;
  List<EvaluateResponse> _history = [];
  bool _isLoading = false;
  String? _error;
  
  // Polling state
  EvaluateResponse? _activeEvaluation;
  Timer? _pollingTimer;

  EvaluateProvider({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  }) : _apiService = EvaluateApiService(
          settingsProvider: settingsProvider,
          authProvider: authProvider,
        );

  EvaluateResponse? get latestEvaluation => _latestEvaluation;
  List<EvaluateResponse> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;
  EvaluateResponse? get activeEvaluation => _activeEvaluation;
  bool get isEvaluating => _activeEvaluation != null && 
      (_activeEvaluation!.isPending || _activeEvaluation!.isProcessing);

  /// Fetch history and latest evaluation for a project
  Future<void> loadProjectEvaluations(int projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final historyResponse = await _apiService.getEvaluationHistory(projectId);
      _history = historyResponse.evaluations;
      
      try {
        _latestEvaluation = await _apiService.getLatestEvaluation(projectId);
      } catch (e) {
        // It's okay if there's no latest evaluation yet
        _latestEvaluation = null;
      }
      
      // Check if any evaluation is still in progress and resume polling
      print('📊 Checking history for in-progress evaluations...');
      print('📊 History count: ${_history.length}');
      _history.forEach((eval) {
        print('📊   Evaluation #${eval.id}: status=${eval.status}');
      });
      
      EvaluateResponse? inProgress;
      try {
        inProgress = _history.firstWhere(
          (eval) => eval.isPending || eval.isProcessing,
        );
        print('📊 Found in-progress evaluation #${inProgress.id}');
      } catch (e) {
        // No in-progress evaluation found, clear active evaluation
        print('📊 No in-progress evaluations found');
        inProgress = null;
      }
      
      if (inProgress != null) {
        // Resume polling for this evaluation
        print('📊 Resuming polling for evaluation #${inProgress.id}');
        _activeEvaluation = inProgress;
        _startPolling(projectId, inProgress.id);
      } else {
        // No in-progress evaluation, clear active state and stop polling
        print('📊 Clearing active evaluation and stopping polling');
        _activeEvaluation = null;
        _stopPolling();
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start a new evaluation and begin polling for results
  Future<void> startNewEvaluation(int projectId) async {
    if (isEvaluating) return;

    // Stop any existing polling
    _stopPolling();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.startEvaluation(projectId);
      _activeEvaluation = response;
      _isLoading = false;
      notifyListeners();

      _startPolling(projectId, response.id);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _activeEvaluation = null;
      notifyListeners();
    }
  }

  void _startPolling(int projectId, int evaluationId) {
    _pollingTimer?.cancel();
    print('📊 Starting polling for evaluation #$evaluationId on project #$projectId');
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        print('📊 Polling evaluation #$evaluationId...');
        final evaluation = await _apiService.getEvaluationById(projectId, evaluationId);
        print('📊 Evaluation #$evaluationId status: ${evaluation.status}');
        _activeEvaluation = evaluation;
        
        if (evaluation.isCompleted || evaluation.isFailed) {
          print('📊 Evaluation #$evaluationId finished with status: ${evaluation.status}');
          _stopPolling();
          _activeEvaluation = null; // Clear active state
          
          if (evaluation.isCompleted) {
            _latestEvaluation = evaluation;
            // Update history: replace the old entry with the completed one
            final index = _history.indexWhere((e) => e.id == evaluation.id);
            if (index != -1) {
              _history[index] = evaluation;
            } else {
              // Add it to the beginning if not found
              _history.insert(0, evaluation);
            }
          } else {
            _error = evaluation.errorMessage ?? 'Evaluation failed during processing';
          }
          notifyListeners();
        } else {
          notifyListeners(); // Update UI with current status
        }
      } catch (e) {
        print('❌ Polling error for evaluation #$evaluationId: $e');
        // We continue polling despite temporary errors
      }
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      print('📊 Stopping polling');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<EvaluateResponse> getEvaluationDetails(int projectId, int evaluationId) async {
    try {
      return await _apiService.getEvaluationById(projectId, evaluationId);
    } catch (e) {
      print('Error getting evaluation details: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

