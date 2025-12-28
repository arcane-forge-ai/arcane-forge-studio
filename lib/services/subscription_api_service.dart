import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'api_client.dart';

/// Models for Subscription API

class SubscriptionPlan {
  final int id;
  final String name;
  final String displayName;
  final int tierLevel;
  final double originalPriceMonthly;
  final Map<String, dynamic>? features;
  final Map<String, dynamic>? quotaConfig;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayName,
    required this.tierLevel,
    required this.originalPriceMonthly,
    this.features,
    this.quotaConfig,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      tierLevel: json['tier_level'],
      originalPriceMonthly: (json['original_price_monthly'] as num).toDouble(),
      features: json['features'],
      quotaConfig: json['quota_config'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class UserSubscription {
  final int subscriptionId;
  final String userId;
  final int planId;
  final String planName;
  final String planDisplayName;
  final int tierLevel;
  final String status;
  final double originalPrice;
  final double actualPrice;
  final String? discountCodeUsed;
  final Map<String, dynamic>? features;
  final Map<String, dynamic>? quotaConfig;
  final DateTime? subscribedAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final bool isFreeTier;
  final bool isPaidTier;

  UserSubscription({
    required this.subscriptionId,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.planDisplayName,
    required this.tierLevel,
    required this.status,
    required this.originalPrice,
    required this.actualPrice,
    this.discountCodeUsed,
    this.features,
    this.quotaConfig,
    this.subscribedAt,
    this.expiresAt,
    required this.autoRenew,
    required this.isFreeTier,
    required this.isPaidTier,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      subscriptionId: json['subscription_id'],
      userId: json['user_id'],
      planId: json['plan_id'],
      planName: json['plan_name'],
      planDisplayName: json['plan_display_name'],
      tierLevel: json['tier_level'],
      status: json['status'],
      originalPrice: (json['original_price'] as num).toDouble(),
      actualPrice: (json['actual_price'] as num).toDouble(),
      discountCodeUsed: json['discount_code_used'],
      features: json['features'],
      quotaConfig: json['quota_config'],
      subscribedAt: json['subscribed_at'] != null 
          ? DateTime.parse(json['subscribed_at']) 
          : null,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      autoRenew: json['auto_renew'] ?? false,
      isFreeTier: json['is_free_tier'],
      isPaidTier: json['is_paid_tier'],
    );
  }
}

class QuotaStatus {
  final String quotaType;
  final String resetFrequency;
  final int quotaLimit;
  final int usageCount;
  final int remaining;
  final bool isAvailable;
  final bool isExceeded;
  final String periodStart;
  final String periodEnd;
  final double percentageUsed;

  QuotaStatus({
    required this.quotaType,
    required this.resetFrequency,
    required this.quotaLimit,
    required this.usageCount,
    required this.remaining,
    required this.isAvailable,
    required this.isExceeded,
    required this.periodStart,
    required this.periodEnd,
    required this.percentageUsed,
  });

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    return QuotaStatus(
      quotaType: json['quota_type'],
      resetFrequency: json['reset_frequency'],
      quotaLimit: json['quota_limit'],
      usageCount: json['usage_count'],
      remaining: json['remaining'],
      isAvailable: json['is_available'],
      isExceeded: json['is_exceeded'],
      periodStart: json['period_start'],
      periodEnd: json['period_end'],
      percentageUsed: (json['percentage_used'] as num).toDouble(),
    );
  }
}

/// Service for interacting with Subscription API endpoints
class SubscriptionApiService {
  final SettingsProvider? _settingsProvider;
  late final ApiClient _apiClient;

  SubscriptionApiService({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
  }) : _settingsProvider = settingsProvider {
    _apiClient = ApiClient(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  /// Get current mock mode setting
  bool get _useMockMode => _settingsProvider?.useMockMode ?? false;

  /// Get all available subscription plans (public endpoint)
  Future<List<SubscriptionPlan>> getSubscriptionPlans({bool activeOnly = true}) async {
    if (_useMockMode) {
      return _mockGetPlans();
    }

    try {
      final response = await _apiClient.get(
        '/subscriptions/plans',
        queryParameters: {'active_only': activeOnly},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> plans = data['plans'] ?? [];
        return plans.map((json) => SubscriptionPlan.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get subscription plans: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Subscription Plans API Error: $e');
      rethrow;
    }
  }

  /// Get current user's subscription (requires authentication)
  Future<UserSubscription> getMySubscription() async {
    if (_useMockMode) {
      return _mockGetMySubscription();
    }

    try {
      final response = await _apiClient.get('/subscriptions/me');

      if (response.statusCode == 200) {
        return UserSubscription.fromJson(response.data);
      } else {
        throw Exception('Failed to get subscription: ${response.statusCode}');
      }
    } catch (e) {
      print('Get My Subscription API Error: $e');
      rethrow;
    }
  }

  /// Activate subscription using a discount code (requires authentication)
  Future<UserSubscription> activateSubscription(String discountCode) async {
    if (_useMockMode) {
      return _mockActivateSubscription(discountCode);
    }

    try {
      final response = await _apiClient.post(
        '/subscriptions/activate',
        data: {'discount_code': discountCode},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return UserSubscription.fromJson(data['subscription']);
      } else {
        throw Exception('Failed to activate subscription: ${response.statusCode}');
      }
    } catch (e) {
      print('Activate Subscription API Error: $e');
      rethrow;
    }
  }

  /// Get all quota statuses for the current user (requires authentication)
  Future<List<QuotaStatus>> getMyQuotas() async {
    if (_useMockMode) {
      return _mockGetQuotas();
    }

    try {
      final response = await _apiClient.get('/subscriptions/quotas');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> quotas = data['quotas'] ?? [];
        return quotas.map((json) => QuotaStatus.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get quotas: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Quotas API Error: $e');
      rethrow;
    }
  }

  /// Get status for a specific quota type (requires authentication)
  Future<QuotaStatus> getQuotaStatus(String quotaType) async {
    if (_useMockMode) {
      return _mockGetQuotaStatus(quotaType);
    }

    try {
      final response = await _apiClient.get('/subscriptions/quotas/$quotaType');

      if (response.statusCode == 200) {
        return QuotaStatus.fromJson(response.data);
      } else {
        throw Exception('Failed to get quota status: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Quota Status API Error: $e');
      rethrow;
    }
  }

  // Mock data methods
  List<SubscriptionPlan> _mockGetPlans() {
    final now = DateTime.now();
    return [
      SubscriptionPlan(
        id: 1,
        name: 'free',
        displayName: 'Free Tier',
        tierLevel: 0,
        originalPriceMonthly: 0.0,
        features: {'max_projects': 2, 'basic_features': true},
        quotaConfig: {'chat_messages': 100, 'image_generations': 10},
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      SubscriptionPlan(
        id: 2,
        name: 'pro',
        displayName: 'Pro',
        tierLevel: 1,
        originalPriceMonthly: 29.99,
        features: {'max_projects': 10, 'advanced_features': true},
        quotaConfig: {'chat_messages': 1000, 'image_generations': 100},
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  UserSubscription _mockGetMySubscription() {
    return UserSubscription(
      subscriptionId: 1,
      userId: '00000000-0000-0000-0000-000000000000',
      planId: 1,
      planName: 'free',
      planDisplayName: 'Free Tier',
      tierLevel: 0,
      status: 'active',
      originalPrice: 0.0,
      actualPrice: 0.0,
      features: {'max_projects': 2, 'basic_features': true},
      quotaConfig: {'chat_messages': 100, 'image_generations': 10},
      subscribedAt: DateTime.now().subtract(const Duration(days: 30)),
      autoRenew: false,
      isFreeTier: true,
      isPaidTier: false,
    );
  }

  UserSubscription _mockActivateSubscription(String discountCode) {
    return UserSubscription(
      subscriptionId: 2,
      userId: '00000000-0000-0000-0000-000000000000',
      planId: 2,
      planName: 'pro',
      planDisplayName: 'Pro',
      tierLevel: 1,
      status: 'active',
      originalPrice: 29.99,
      actualPrice: 0.0,
      discountCodeUsed: discountCode,
      features: {'max_projects': 10, 'advanced_features': true},
      quotaConfig: {'chat_messages': 1000, 'image_generations': 100},
      subscribedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      autoRenew: false,
      isFreeTier: false,
      isPaidTier: true,
    );
  }

  List<QuotaStatus> _mockGetQuotas() {
    return [
      QuotaStatus(
        quotaType: 'chat_messages',
        resetFrequency: 'monthly',
        quotaLimit: 100,
        usageCount: 45,
        remaining: 55,
        isAvailable: true,
        isExceeded: false,
        periodStart: DateTime.now().toIso8601String(),
        periodEnd: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        percentageUsed: 45.0,
      ),
      QuotaStatus(
        quotaType: 'image_generations',
        resetFrequency: 'monthly',
        quotaLimit: 10,
        usageCount: 8,
        remaining: 2,
        isAvailable: true,
        isExceeded: false,
        periodStart: DateTime.now().toIso8601String(),
        periodEnd: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        percentageUsed: 80.0,
      ),
    ];
  }

  QuotaStatus _mockGetQuotaStatus(String quotaType) {
    return QuotaStatus(
      quotaType: quotaType,
      resetFrequency: 'monthly',
      quotaLimit: 100,
      usageCount: 45,
      remaining: 55,
      isAvailable: true,
      isExceeded: false,
      periodStart: DateTime.now().toIso8601String(),
      periodEnd: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      percentageUsed: 45.0,
    );
  }
}



















