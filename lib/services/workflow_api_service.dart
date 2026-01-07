import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/workflow_models.dart';
import '../models/image_generation_models.dart';

/// API service for workflow-related operations
class WorkflowApiService {
  final ApiClient _apiClient;

  WorkflowApiService(this._apiClient);

  /// List all workflows with optional filters
  /// 
  /// [search] - Search term for workflow name/description
  /// [category] - Filter by category
  /// [visibility] - Filter by visibility (public, org, project, user)
  /// [activeOnly] - Only return active workflows (default: true)
  Future<WorkflowListResponse> listWorkflows({
    String? search,
    String? category,
    String? visibility,
    bool activeOnly = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (visibility != null) 'visibility': visibility,
        'active_only': activeOnly,
      };

      final response = await _apiClient.dio.get(
        '/workflows',
        queryParameters: queryParams,
      );

      return WorkflowListResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to list workflows: ${e.message}');
    }
  }

  /// Get a specific workflow by ID
  /// 
  /// [workflowId] - UUID of the workflow
  Future<Workflow> getWorkflow(String workflowId) async {
    try {
      final response = await _apiClient.dio.get('/workflows/$workflowId');
      return Workflow.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to get workflow: ${e.message}');
    }
  }

  /// Recommend workflows based on user instruction
  /// 
  /// [instruction] - User's description of what they want to create
  /// [additionalInfo] - Additional context (e.g., asset type, style, etc.)
  /// [count] - Number of recommendations to return (1-10, default 3)
  Future<WorkflowListResponse> recommendWorkflows(
    String instruction, {
    Map<String, dynamic>? additionalInfo,
    int count = 3,
  }) async {
    try {
      final request = WorkflowRecommendRequest(
        instruction: instruction,
        additionalInfo: additionalInfo ?? {},
        count: count,
      );

      final response = await _apiClient.dio.post(
        '/workflows/recommend',
        data: request.toJson(),
      );

      return WorkflowListResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to get workflow recommendations: ${e.message}');
    }
  }

  /// Execute a workflow to create an image generation
  /// 
  /// [workflowId] - UUID of the workflow to execute
  /// [assetId] - ID of the asset to generate for
  /// [prompt] - User's generation prompt
  /// [version] - Optional workflow version number (uses default if not specified)
  /// [configOverrides] - Optional additional config overrides
  Future<ImageGeneration> executeWorkflow({
    required String workflowId,
    required String assetId,
    required String prompt,
    int? version,
    Map<String, dynamic>? configOverrides,
  }) async {
    try {
      final request = WorkflowExecuteRequest(
        assetId: assetId,
        prompt: prompt,
        version: version,
        generationConfig: configOverrides,
      );

      final response = await _apiClient.dio.post(
        '/workflows/$workflowId/execute',
        data: request.toJson(),
      );

      return _parseImageGeneration(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to execute workflow: ${e.message}');
    }
  }

  /// Parse ImageGeneration from API response
  ImageGeneration _parseImageGeneration(Map<String, dynamic> json) {
    // Parse parameters and merge top-level fields that should be in parameters
    final parameters = Map<String, dynamic>.from(json['parameters'] as Map? ?? {});
    
    // Add model_name from top level if not in parameters
    if (json['model_name'] != null && !parameters.containsKey('model_name')) {
      parameters['model_name'] = json['model_name'];
    }
    
    // Add provider from top level if not in parameters
    if (json['provider'] != null && !parameters.containsKey('provider')) {
      parameters['provider'] = json['provider'];
    }
    
    return ImageGeneration(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      imagePath: json['image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      parameters: parameters,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _parseGenerationStatus(json['status'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Parse status string to GenerationStatus enum
  GenerationStatus _parseGenerationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return GenerationStatus.pending;
      case 'generating':
      case 'queued':
        return GenerationStatus.generating;
      case 'completed':
        return GenerationStatus.completed;
      case 'failed':
        return GenerationStatus.failed;
      default:
        return GenerationStatus.pending;
    }
  }

  /// List all versions of a workflow
  /// 
  /// [workflowId] - UUID of the workflow
  Future<List<WorkflowVersion>> listWorkflowVersions(String workflowId) async {
    try {
      final response = await _apiClient.dio.get('/workflows/$workflowId/versions');
      final data = response.data as Map<String, dynamic>;
      final versions = (data['versions'] as List<dynamic>)
          .map((e) => WorkflowVersion.fromJson(e as Map<String, dynamic>))
          .toList();
      return versions;
    } on DioException catch (e) {
      throw Exception('Failed to list workflow versions: ${e.message}');
    }
  }

  /// Get a specific version of a workflow
  /// 
  /// [workflowId] - UUID of the workflow
  /// [versionNum] - Version number
  Future<WorkflowVersion> getWorkflowVersion(
    String workflowId,
    int versionNum,
  ) async {
    try {
      final response = await _apiClient.dio.get(
        '/workflows/$workflowId/versions/$versionNum',
      );
      return WorkflowVersion.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to get workflow version: ${e.message}');
    }
  }
}

