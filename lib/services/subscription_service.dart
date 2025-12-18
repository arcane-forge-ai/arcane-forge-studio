import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_handler.dart';
import 'api_client.dart';

/// Service for managing subscription and quota operations
/// Communicates with backend API at /api/v1/subscriptions
class SubscriptionService {
  late final ApiClient _apiClient;

  SubscriptionService({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  /// Get all available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      debugPrint('📋 Fetching subscription plans from: ${_apiClient.apiUrl}/subscriptions/plans');
      final response = await _apiClient.get('/subscriptions/plans');
      
      debugPrint('✅ Plans API response received: ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;
      final plansData = data['plans'] as List<dynamic>;
      
      debugPrint('📊 Loaded ${plansData.length} subscription plans');
      return plansData
          .map((planJson) => SubscriptionPlan.fromJson(planJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching plans: $e');
      throw Exception('Failed to get available plans: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get current user's subscription
  Future<UserSubscription> getMySubscription() async {
    try {
      debugPrint('👤 Fetching user subscription from: ${_apiClient.apiUrl}/subscriptions/me');
      final response = await _apiClient.get('/subscriptions/me');
      
      debugPrint('✅ Subscription API response received: ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;
      debugPrint('📦 Subscription data keys: ${data.keys.toList()}');
      return UserSubscription.fromJson(data);
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching subscription: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to get subscription: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Activate subscription with discount code
  /// Backend automatically knows which plan based on the code
  Future<UserSubscription> activateSubscription(String discountCode) async {
    try {
      final request = ActivateSubscriptionRequest(discountCode: discountCode);
      
      final response = await _apiClient.post(
        '/subscriptions/activate',
        data: request.toJson(),
      );
      
      final data = response.data as Map<String, dynamic>;
      return UserSubscription.fromJson(data);
    } on DioException catch (e) {
      // Handle specific error cases
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data as Map<String, dynamic>?;
        final message = errorData?['detail'] ?? 'Invalid discount code';
        throw Exception(message);
      } else if (e.response?.statusCode == 404) {
        throw Exception('Discount code not found');
      } else if (e.response?.statusCode == 409) {
        throw Exception('You already have an active subscription');
      }
      throw Exception('Failed to activate subscription: ${ErrorHandler.getErrorMessage(e)}');
    } catch (e) {
      throw Exception('Failed to activate subscription: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get quota status for all quota types
  Future<Map<String, QuotaStatus>> getQuotaStatus() async {
    try {
      debugPrint('📊 Fetching quota status from: ${_apiClient.apiUrl}/subscriptions/quotas');
      final response = await _apiClient.get('/subscriptions/quotas');
      
      debugPrint('✅ Quotas API response received: ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;
      debugPrint('📦 Quotas response keys: ${data.keys.toList()}');
      final quotasData = data['quotas'] as List<dynamic>;
      debugPrint('📦 Quotas count: ${quotasData.length}');
      
      // Convert list to map keyed by quota_type
      final quotasMap = <String, QuotaStatus>{};
      for (var i = 0; i < quotasData.length; i++) {
        final quotaJson = quotasData[i] as Map<String, dynamic>;
        debugPrint('📦 Quota $i keys: ${quotaJson.keys.toList()}');
        final quota = QuotaStatus.fromJson(quotaJson);
        quotasMap[quota.quotaType] = quota;
      }
      
      debugPrint('📊 Loaded ${quotasMap.length} quota types: ${quotasMap.keys.toList()}');
      return quotasMap;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching quotas: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to get quota status: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Get usage history with optional filtering
  Future<List<UsageHistoryEntry>> getUsageHistory({
    int limit = 50,
    int offset = 0,
    String? quotaType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      
      if (quotaType != null) queryParams['quota_type'] = quotaType;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
      
      final response = await _apiClient.get(
        '/subscriptions/usage-history',
        queryParameters: queryParams,
      );
      
      final data = response.data as Map<String, dynamic>;
      final historyData = data['usage_history'] as List<dynamic>;
      
      return historyData
          .map((entry) => UsageHistoryEntry.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get usage history: ${ErrorHandler.getErrorMessage(e)}');
    }
  }

  /// Validate discount code (client-side only)
  /// Note: Backend doesn't provide a validation endpoint, so this just checks basic format
  /// Real validation happens during activation
  Future<DiscountCodeValidation> validateDiscountCode(String code) async {
    // Client-side validation only - just check if code is not empty
    final trimmedCode = code.trim();
    
    if (trimmedCode.isEmpty) {
      return DiscountCodeValidation(
        code: code,
        isValid: false,
        errorMessage: 'Discount code cannot be empty',
      );
    }
    
    if (trimmedCode.length < 3) {
      return DiscountCodeValidation(
        code: code,
        isValid: false,
        errorMessage: 'Discount code is too short',
      );
    }
    
    // Basic format check passed - actual validation happens on activation
    return DiscountCodeValidation(
      code: trimmedCode,
      isValid: true,
      errorMessage: null,
    );
  }

  /// Check if a specific quota is available (client-side check)
  /// Note: Backend also enforces quotas, this is just for UI feedback
  Future<bool> checkQuotaAvailable(String quotaType) async {
    try {
      final quotas = await getQuotaStatus();
      final quota = quotas[quotaType];
      
      if (quota == null) {
        // No quota record means unlimited or not configured
        return true;
      }
      
      return !quota.isExceeded;
    } catch (e) {
      // On error, allow the operation (backend will enforce)
      return true;
    }
  }
}

/// Factory to create subscription service with dependencies
class SubscriptionServiceFactory {
  static SubscriptionService create({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) {
    return SubscriptionService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }
}

