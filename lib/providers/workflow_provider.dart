import 'package:flutter/foundation.dart';
import '../models/workflow_models.dart';
import '../models/image_generation_models.dart';
import '../services/workflow_api_service.dart';
import '../services/api_client.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

/// Provider for managing workflow state and operations
class WorkflowProvider extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final AuthProvider? _authProvider;
  late final WorkflowApiService _apiService;

  // State
  List<Workflow> _workflows = [];
  List<Workflow> _recommendedWorkflows = [];
  Workflow? _selectedWorkflow;
  bool _isLoading = false;
  bool _isExecuting = false;
  String? _errorMessage;

  WorkflowProvider(
    this._settingsProvider, {
    AuthProvider? authProvider,
  }) : _authProvider = authProvider {
    _apiService = WorkflowApiService(
      ApiClient(
        settingsProvider: _settingsProvider,
        authProvider: _authProvider,
      ),
    );
  }

  // Getters
  List<Workflow> get workflows => _workflows;
  List<Workflow> get recommendedWorkflows => _recommendedWorkflows;
  Workflow? get selectedWorkflow => _selectedWorkflow;
  bool get isLoading => _isLoading;
  bool get isExecuting => _isExecuting;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load all workflows with optional filters
  Future<void> loadWorkflows({
    String? search,
    String? category,
    String? visibility,
    bool activeOnly = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.listWorkflows(
        search: search,
        category: category,
        visibility: visibility,
        activeOnly: activeOnly,
      );
      _workflows = response.workflows;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load workflows: $e';
      _workflows = [];
      print('Error loading workflows: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a specific workflow by ID
  Future<Workflow?> getWorkflow(String workflowId) async {
    try {
      final workflow = await _apiService.getWorkflow(workflowId);
      return workflow;
    } catch (e) {
      _errorMessage = 'Failed to get workflow: $e';
      notifyListeners();
      print('Error getting workflow: $e');
      return null;
    }
  }

  /// Get workflow recommendations based on user instruction
  Future<void> recommendWorkflows(
    String instruction, {
    Map<String, dynamic>? additionalInfo,
    int count = 3,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.recommendWorkflows(
        instruction,
        additionalInfo: additionalInfo,
        count: count,
      );
      _recommendedWorkflows = response.workflows;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to get workflow recommendations: $e';
      _recommendedWorkflows = [];
      print('Error recommending workflows: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a workflow
  void selectWorkflow(Workflow? workflow) {
    _selectedWorkflow = workflow;
    notifyListeners();
  }

  /// Clear recommended workflows
  void clearRecommendations() {
    _recommendedWorkflows = [];
    notifyListeners();
  }

  /// Execute a workflow to create an image generation
  Future<ImageGeneration?> executeWorkflow({
    required String assetId,
    required String prompt,
    int? version,
    Map<String, dynamic>? configOverrides,
  }) async {
    if (_selectedWorkflow == null) {
      _errorMessage = 'No workflow selected';
      notifyListeners();
      return null;
    }

    _isExecuting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generation = await _apiService.executeWorkflow(
        workflowId: _selectedWorkflow!.id,
        assetId: assetId,
        prompt: prompt,
        version: version,
        configOverrides: configOverrides,
      );
      _errorMessage = null;
      return generation;
    } catch (e) {
      _errorMessage = 'Failed to execute workflow: $e';
      print('Error executing workflow: $e');
      return null;
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Get versions for a specific workflow
  Future<List<WorkflowVersion>> getWorkflowVersions(String workflowId) async {
    try {
      final versions = await _apiService.listWorkflowVersions(workflowId);
      return versions;
    } catch (e) {
      _errorMessage = 'Failed to get workflow versions: $e';
      notifyListeners();
      print('Error getting workflow versions: $e');
      return [];
    }
  }

  /// Get a specific workflow version
  Future<WorkflowVersion?> getWorkflowVersion(
    String workflowId,
    int versionNum,
  ) async {
    try {
      final version = await _apiService.getWorkflowVersion(workflowId, versionNum);
      return version;
    } catch (e) {
      _errorMessage = 'Failed to get workflow version: $e';
      notifyListeners();
      print('Error getting workflow version: $e');
      return null;
    }
  }

  /// Reset provider state
  void reset() {
    _workflows = [];
    _recommendedWorkflows = [];
    _selectedWorkflow = null;
    _isLoading = false;
    _isExecuting = false;
    _errorMessage = null;
    notifyListeners();
  }
}

