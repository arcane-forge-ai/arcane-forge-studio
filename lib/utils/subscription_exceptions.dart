/// Custom exceptions for subscription and quota operations

/// Exception thrown when user exceeds their quota limit
class QuotaExceededException implements Exception {
  final String quotaType;
  final DateTime? resetTime;
  final String message;

  QuotaExceededException(
    this.quotaType, {
    this.resetTime,
    String? customMessage,
  }) : message = customMessage ?? 'Quota exceeded for $quotaType';

  @override
  String toString() => message;

  /// Get user-friendly quota type name
  String get quotaDisplayName {
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

  /// Get formatted reset time message
  String get resetTimeMessage {
    if (resetTime == null) return '';
    
    final now = DateTime.now();
    if (resetTime!.isBefore(now)) {
      return 'Quota resets soon';
    }
    
    final duration = resetTime!.difference(now);
    if (duration.inHours > 24) {
      return 'Resets in ${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return 'Resets in ${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return 'Resets in ${duration.inMinutes}m';
    } else {
      return 'Resets soon';
    }
  }
}

/// Exception thrown when user tries to access a feature requiring higher subscription tier
class SubscriptionRequiredException implements Exception {
  final String feature;
  final int requiredTier;
  final String requiredTierName;
  final String message;

  SubscriptionRequiredException(
    this.feature, {
    this.requiredTier = 1,
    this.requiredTierName = 'Starter',
    String? customMessage,
  }) : message = customMessage ??
            '$feature requires $requiredTierName tier or higher';

  @override
  String toString() => message;

  /// Get user-friendly tier names
  String get tierDescription {
    switch (requiredTier) {
      case 0:
        return 'Free';
      case 1:
        return 'Starter (\$10 early access)';
      case 2:
        return 'Pro (\$30 early access)';
      default:
        return requiredTierName;
    }
  }
}

/// Exception thrown when discount code is invalid or cannot be used
class InvalidDiscountCodeException implements Exception {
  final String code;
  final String reason;
  final String message;

  InvalidDiscountCodeException(
    this.code,
    this.reason, {
    String? customMessage,
  }) : message = customMessage ?? 'Invalid discount code: $reason';

  @override
  String toString() => message;

  /// Get user-friendly error message
  String get friendlyMessage {
    if (reason.toLowerCase().contains('expired')) {
      return 'This discount code has expired';
    } else if (reason.toLowerCase().contains('not found')) {
      return 'This discount code is not valid';
    } else if (reason.toLowerCase().contains('limit')) {
      return 'This discount code has reached its usage limit';
    } else if (reason.toLowerCase().contains('already used')) {
      return 'You have already used this discount code';
    } else {
      return reason;
    }
  }
}

/// Exception thrown when subscription activation fails
class SubscriptionActivationException implements Exception {
  final String message;
  final String? details;

  SubscriptionActivationException(
    this.message, {
    this.details,
  });

  @override
  String toString() => details != null ? '$message: $details' : message;
}

/// Exception thrown when user already has an active subscription
class ExistingSubscriptionException implements Exception {
  final String currentPlan;
  final String message;

  ExistingSubscriptionException(
    this.currentPlan, {
    String? customMessage,
  }) : message = customMessage ??
            'You already have an active $currentPlan subscription';

  @override
  String toString() => message;
}

