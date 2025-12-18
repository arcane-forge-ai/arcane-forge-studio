/// Subscription and Quota Models
/// Matches backend API response structures from /api/v1/subscriptions
/// 
/// Note: UserSubscription uses a flattened structure where plan fields
/// are included directly rather than as a nested object

class SubscriptionPlan {
  final int id;
  final String name;
  final String displayName;
  final int tierLevel;
  final double originalPriceMonthly;
  final Map<String, dynamic> features;
  final Map<String, dynamic> quotaConfig;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayName,
    required this.tierLevel,
    required this.originalPriceMonthly,
    required this.features,
    required this.quotaConfig,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Unknown Plan',
      tierLevel: (json['tier_level'] as num?)?.toInt() ?? 0,
      originalPriceMonthly: (json['original_price_monthly'] as num?)?.toDouble() ?? 0.0,
      features: (json['features'] as Map<String, dynamic>?) ?? {},
      quotaConfig: (json['quota_config'] as Map<String, dynamic>?) ?? {},
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'tier_level': tierLevel,
      'original_price_monthly': originalPriceMonthly,
      'features': features,
      'quota_config': quotaConfig,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get quota limit for a specific quota type (e.g., 'sfx_generation')
  int? getQuotaLimit(String quotaType) {
    return quotaConfig[quotaType] as int?;
  }

  /// Check if this plan has a specific feature
  bool hasFeature(String featureName) {
    return features[featureName] == true;
  }
}

/// User subscription with flattened plan data
/// Matches UserSubscriptionResponse from backend API
class UserSubscription {
  final int subscriptionId;
  final String userId;
  final int planId;
  final String planName;
  final String planDisplayName;
  final int tierLevel;
  final String status; // 'active', 'suspended', 'expired'
  final double originalPrice;
  final double actualPrice;
  final String? discountCodeUsed;
  final Map<String, dynamic> features;
  final Map<String, dynamic> quotaConfig;
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
    required this.features,
    required this.quotaConfig,
    this.subscribedAt,
    this.expiresAt,
    required this.autoRenew,
    required this.isFreeTier,
    required this.isPaidTier,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      subscriptionId: (json['subscription_id'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      planName: json['plan_name'] as String? ?? '',
      planDisplayName: json['plan_display_name'] as String? ?? 'Unknown Plan',
      tierLevel: (json['tier_level'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'inactive',
      originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0.0,
      actualPrice: (json['actual_price'] as num?)?.toDouble() ?? 0.0,
      discountCodeUsed: json['discount_code_used'] as String?,
      features: (json['features'] as Map<String, dynamic>?) ?? {},
      quotaConfig: (json['quota_config'] as Map<String, dynamic>?) ?? {},
      subscribedAt: json['subscribed_at'] != null 
          ? DateTime.parse(json['subscribed_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      autoRenew: json['auto_renew'] as bool? ?? false,
      isFreeTier: json['is_free_tier'] as bool? ?? true,
      isPaidTier: json['is_paid_tier'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscription_id': subscriptionId,
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'plan_display_name': planDisplayName,
      'tier_level': tierLevel,
      'status': status,
      'original_price': originalPrice,
      'actual_price': actualPrice,
      'discount_code_used': discountCodeUsed,
      'features': features,
      'quota_config': quotaConfig,
      'subscribed_at': subscribedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'auto_renew': autoRenew,
      'is_free_tier': isFreeTier,
      'is_paid_tier': isPaidTier,
    };
  }

  bool get isActive => status == 'active';
  bool get isFree => tierLevel == 0;
  bool get isPaid => tierLevel > 0;
  
  /// Get quota limit for a specific quota type (e.g., 'sfx_generation')
  int? getQuotaLimit(String quotaType) {
    return quotaConfig[quotaType] as int?;
  }

  /// Check if this subscription has a specific feature
  bool hasFeature(String featureName) {
    return features[featureName] == true;
  }
}

class QuotaStatus {
  final int id;
  final String userId;
  final String quotaType; // 'sfx_generation', 'music_generation', 'image_generation', 'chat_tokens'
  final DateTime periodStart;
  final DateTime periodEnd;
  final int quotaLimit;
  final int usageCount;
  final String resetFrequency; // 'daily', 'monthly'
  final DateTime createdAt;
  final DateTime updatedAt;

  QuotaStatus({
    required this.id,
    required this.userId,
    required this.quotaType,
    required this.periodStart,
    required this.periodEnd,
    required this.quotaLimit,
    required this.usageCount,
    required this.resetFrequency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    return QuotaStatus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      quotaType: json['quota_type'] as String? ?? '',
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : DateTime.now(),
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : DateTime.now(),
      quotaLimit: (json['quota_limit'] as num?)?.toInt() ?? 0,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      resetFrequency: json['reset_frequency'] as String? ?? 'monthly',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'quota_type': quotaType,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'quota_limit': quotaLimit,
      'usage_count': usageCount,
      'reset_frequency': resetFrequency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get remaining => (quotaLimit - usageCount).clamp(0, quotaLimit);
  bool get isExceeded => usageCount >= quotaLimit;
  bool get isLow => remaining <= (quotaLimit * 0.2).ceil() && remaining > 0;
  
  Duration get timeUntilReset {
    final now = DateTime.now();
    if (periodEnd.isBefore(now)) {
      return Duration.zero;
    }
    return periodEnd.difference(now);
  }

  String get resetTimeFormatted {
    final duration = timeUntilReset;
    if (duration.inHours > 24) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Soon';
    }
  }

  /// Get user-friendly name for quota type
  String get displayName {
    switch (quotaType) {
      case 'sfx_generation':
        return 'SFX Generation';
      case 'music_generation':
        return 'Music Generation';
      case 'image_generation':
        return 'Image Generation';
      case 'chat_tokens':
        return 'Chat Tokens';
      default:
        return quotaType;
    }
  }
}

class UsageHistoryEntry {
  final int id;
  final String userId;
  final String operationType; // 'image_gen', 'sfx_gen', 'music_gen', 'chat'
  final String? resourceId;
  final int unitsConsumed;
  final String quotaType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  UsageHistoryEntry({
    required this.id,
    required this.userId,
    required this.operationType,
    this.resourceId,
    required this.unitsConsumed,
    required this.quotaType,
    this.metadata,
    required this.createdAt,
  });

  factory UsageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return UsageHistoryEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      operationType: json['operation_type'] as String? ?? '',
      resourceId: json['resource_id'] as String?,
      unitsConsumed: (json['units_consumed'] as num?)?.toInt() ?? 0,
      quotaType: json['quota_type'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'operation_type': operationType,
      'resource_id': resourceId,
      'units_consumed': unitsConsumed,
      'quota_type': quotaType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName {
    switch (operationType) {
      case 'image_gen':
        return 'Image Generated';
      case 'sfx_gen':
        return 'SFX Generated';
      case 'music_gen':
        return 'Music Generated';
      case 'chat':
        return 'Chat Message';
      default:
        return operationType;
    }
  }
}

class DiscountCodeValidation {
  final String code;
  final bool isValid;
  final int? planId;
  final String? planName;
  final String? discountType; // 'percentage', 'fixed', 'free'
  final double? discountValue;
  final String? errorMessage;

  DiscountCodeValidation({
    required this.code,
    required this.isValid,
    this.planId,
    this.planName,
    this.discountType,
    this.discountValue,
    this.errorMessage,
  });

  factory DiscountCodeValidation.fromJson(Map<String, dynamic> json) {
    return DiscountCodeValidation(
      code: json['code'] as String? ?? '',
      isValid: json['is_valid'] as bool? ?? false,
      planId: (json['plan_id'] as num?)?.toInt(),
      planName: json['plan_name'] as String?,
      discountType: json['discount_type'] as String?,
      discountValue: json['discount_value'] != null
          ? (json['discount_value'] as num?)?.toDouble()
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'is_valid': isValid,
      'plan_id': planId,
      'plan_name': planName,
      'discount_type': discountType,
      'discount_value': discountValue,
      'error_message': errorMessage,
    };
  }
}

/// Request model for activating subscription with discount code
class ActivateSubscriptionRequest {
  final String discountCode;

  ActivateSubscriptionRequest({required this.discountCode});

  Map<String, dynamic> toJson() {
    return {
      'discount_code': discountCode,
    };
  }
}

