import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/feedback_analysis_models.dart';

class MutationApiService {
  // Get configuration from environment variables with fallback defaults
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  final Dio _dio;

  MutationApiService() : _dio = Dio(BaseOptions(baseUrl: '$baseUrl/api/v1')) {
    // Add interceptor for request/response logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
    ));
  }

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
    final url = '/projects/$projectId/mutations';
    
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
      final response = await _dio.post(url, data: data);
      
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
    final url = '/projects/$projectId/mutations/$mutationId';

    try {
      final response = await _dio.get(url);
      
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
    final url = '/projects/$projectId/mutations/$mutationId';
    
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (rationale != null) data['rationale'] = rationale;
    if (changes != null) data['changes'] = changes;
    if (impact != null) data['impact'] = impact;
    if (effort != null) data['effort'] = effort;
    if (novelty != null) data['novelty'] = novelty;
    if (metadata != null) data['metadata'] = metadata;

    try {
      final response = await _dio.put(url, data: data);
      
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
    final url = '/projects/$projectId/mutations/$mutationId';

    try {
      final response = await _dio.delete(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete mutation: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete Mutation API Error: $e');
      rethrow;
    }
  }
}
