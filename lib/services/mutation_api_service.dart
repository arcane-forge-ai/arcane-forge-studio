import '../models/feedback_analysis_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'api_client.dart';

class MutationApiService {
  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;

  MutationApiService({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) : _settingsProvider = settingsProvider {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }
  
  /// Get API base URL from settings provider with fallback to environment or default
  String get baseUrl => _apiClient.baseUrl;
  
  /// Get full API URL with version
  String get _apiUrl => _apiClient.apiUrl;

  /// Create a new mutation brief
  Future<MutationBrief> createMutation({
    required int projectId,
    required String runId,
    required String title,
    String? rationale,
    List<String>? changes,
    int? impact,
    int? effort,
    String? novelty,
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'run_id': runId,
      'title': title,
      if (rationale != null) 'rationale': rationale,
      if (changes != null) 'changes': changes,
      if (impact != null) 'impact': impact,
      if (effort != null) 'effort': effort,
      if (novelty != null) 'novelty': novelty,
      if (metadata != null) 'metadata': metadata,
    };

    try {
      final response = await _apiClient.post(
        '/projects/$projectId/mutations',
        data: data,
      );
      
      if (response.statusCode == 200) {
        return MutationBrief.fromJson(response.data);
      } else {
        throw Exception('Failed to create mutation: ${response.statusCode}');
      }
    } catch (e) {
      print('Create Mutation API Error: $e');
      rethrow;
    }
  }

  /// Get a single mutation brief by ID
  Future<MutationBrief> getMutation({
    required int projectId,
    required int mutationId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/projects/$projectId/mutations/$mutationId',
      );
      
      if (response.statusCode == 200) {
        return MutationBrief.fromJson(response.data);
      } else {
        throw Exception('Failed to get mutation: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Mutation API Error: $e');
      rethrow;
    }
  }

  /// Update an existing mutation brief
  Future<MutationBrief> updateMutation({
    required int projectId,
    required int mutationId,
    String? title,
    String? rationale,
    List<String>? changes,
    int? impact,
    int? effort,
    String? novelty,
    Map<String, dynamic>? metadata,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (rationale != null) data['rationale'] = rationale;
    if (changes != null) data['changes'] = changes;
    if (impact != null) data['impact'] = impact;
    if (effort != null) data['effort'] = effort;
    if (novelty != null) data['novelty'] = novelty;
    if (metadata != null) data['metadata'] = metadata;

    try {
      final response = await _apiClient.put(
        '/projects/$projectId/mutations/$mutationId',
        data: data,
      );
      
      if (response.statusCode == 200) {
        return MutationBrief.fromJson(response.data);
      } else {
        throw Exception('Failed to update mutation: ${response.statusCode}');
      }
    } catch (e) {
      print('Update Mutation API Error: $e');
      rethrow;
    }
  }

  /// Delete a mutation brief
  Future<void> deleteMutation({
    required int projectId,
    required int mutationId,
  }) async {
    try {
      final response = await _apiClient.delete(
        '/projects/$projectId/mutations/$mutationId',
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete mutation: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete Mutation API Error: $e');
      rethrow;
    }
  }
}
