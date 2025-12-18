import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

/// Provider for managing subscription and quota state
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service;

  // State
  UserSubscription? _currentSubscription;
  List<SubscriptionPlan> _availablePlans = [];
  Map<String, QuotaStatus> _quotas = {}; // keyed by quotaType
  List<UsageHistoryEntry> _usageHistory = [];
  
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  
  // Throttling for quota refresh
  DateTime? _lastQuotaRefresh;
  static const _quotaRefreshCooldown = Duration(seconds: 5);

  // Getters
  UserSubscription? get currentSubscription => _currentSubscription;
  List<SubscriptionPlan> get availablePlans => _availablePlans;
  Map<String, QuotaStatus> get quotas => _quotas;
  List<UsageHistoryEntry> get usageHistory => _usageHistory;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  // Subscription status helpers
  bool get hasActiveSubscription => _currentSubscription?.isActive ?? false;
  bool get isFreeUser => _currentSubscription?.isFree ?? true;
  bool get isPaidUser => _currentSubscription?.isPaid ?? false;
  int get tierLevel => _currentSubscription?.tierLevel ?? 0;
  String get planName => _currentSubscription?.planDisplayName ?? 'Free';

  SubscriptionProvider(this._service);

  /// Factory constructor for creating with dependencies
  factory SubscriptionProvider.create({
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  }) {
    final service = SubscriptionService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    return SubscriptionProvider(service);
  }

  /// Initialize subscription data on app start
  /// Called after user authentication
  Future<void> initialize() async {
    // Prevent multiple simultaneous initializations
    if (_isInitialized || _isLoading) {
      debugPrint('⚠️ Subscription already initialized or loading, skipping');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🚀 Initializing subscription provider...');
      // Load subscription and quotas in parallel
      await Future.wait([
        _loadSubscription(),
        _loadQuotaStatus(),
      ]);
      
      // Don't load plans automatically - only when user requests them

      _isInitialized = true;
      _error = null;
      debugPrint('✅ Subscription provider initialized');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error initializing subscription provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload subscription data
  Future<void> refresh() async {
    _isInitialized = false; // Allow re-initialization
    await initialize();
  }
  
  /// Load plans on demand (only when user clicks "View Plans")
  Future<void> loadPlansIfNeeded() async {
    if (_availablePlans.isNotEmpty) {
      debugPrint('⚠️ Plans already loaded, skipping');
      return;
    }
    
    debugPrint('📋 Loading plans on demand...');
    await _loadAvailablePlans();
    notifyListeners();
  }

  /// Load user's current subscription
  Future<void> _loadSubscription() async {
    try {
      _currentSubscription = await _service.getMySubscription();
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      // Don't throw - allow other operations to continue
    }
  }

  /// Load available subscription plans
  Future<void> _loadAvailablePlans() async {
    try {
      _availablePlans = await _service.getAvailablePlans();
    } catch (e) {
      debugPrint('Error loading plans: $e');
    }
  }

  /// Load quota status for all quota types
  Future<void> _loadQuotaStatus() async {
    try {
      _quotas = await _service.getQuotaStatus();
    } catch (e) {
      debugPrint('Error loading quota status: $e');
    }
  }

  /// Activate early access subscription with discount code
  Future<bool> activateEarlyAccess(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSubscription = await _service.activateSubscription(code);
      
      // Reload quotas after activation
      await _loadQuotaStatus();
      
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Validate discount code before activation
  Future<DiscountCodeValidation> validateDiscountCode(String code) async {
    try {
      return await _service.validateDiscountCode(code);
    } catch (e) {
      return DiscountCodeValidation(
        code: code,
        isValid: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Check if quota is available for a specific type
  /// Returns true if user has remaining quota, false otherwise
  Future<bool> checkQuotaAvailable(String quotaType) async {
    // If not initialized, try to load quotas first
    if (!_isInitialized) {
      await _loadQuotaStatus();
    }

    final quota = _quotas[quotaType];
    
    // If no quota record exists, assume unlimited (or not configured)
    if (quota == null) {
      return true;
    }

    return !quota.isExceeded;
  }

  /// Check quota availability synchronously (using cached data)
  bool checkQuotaAvailableSync(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return true;
    return !quota.isExceeded;
  }

  /// Refresh quota status after generation (with throttling)
  Future<void> refreshQuotaStatus() async {
    // Throttle quota refresh to prevent excessive API calls
    final now = DateTime.now();
    if (_lastQuotaRefresh != null) {
      final timeSinceLastRefresh = now.difference(_lastQuotaRefresh!);
      if (timeSinceLastRefresh < _quotaRefreshCooldown) {
        debugPrint('⚠️ Quota refresh throttled (last refresh ${timeSinceLastRefresh.inSeconds}s ago)');
        return;
      }
    }
    
    try {
      debugPrint('🔄 Refreshing quota status...');
      _quotas = await _service.getQuotaStatus();
      _lastQuotaRefresh = now;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error refreshing quota status: $e');
    }
  }

  /// Get remaining quota for a specific type
  int getRemainingQuota(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return -1; // -1 indicates unlimited or not configured
    return quota.remaining;
  }

  /// Get quota limit for a specific type
  int getQuotaLimit(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return -1;
    return quota.quotaLimit;
  }

  /// Get usage count for a specific type
  int getUsageCount(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return 0;
    return quota.usageCount;
  }

  /// Get formatted reset time for a specific quota
  String getQuotaResetTime(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return '';
    return quota.resetTimeFormatted;
  }

  /// Get quota status object for a specific type
  QuotaStatus? getQuotaStatus(String quotaType) {
    return _quotas[quotaType];
  }

  /// Check if quota is low (below 20%)
  bool isQuotaLow(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return false;
    return quota.isLow;
  }

  /// Check if quota is exceeded
  bool isQuotaExceeded(String quotaType) {
    final quota = _quotas[quotaType];
    if (quota == null) return false;
    return quota.isExceeded;
  }

  /// Load usage history with optional filtering
  Future<void> loadUsageHistory({
    int limit = 50,
    String? quotaType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _usageHistory = await _service.getUsageHistory(
        limit: limit,
        quotaType: quotaType,
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading usage history: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get specific plan by ID
  SubscriptionPlan? getPlanById(int planId) {
    try {
      return _availablePlans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  /// Get plans by tier level
  List<SubscriptionPlan> getPlansByTier(int tierLevel) {
    return _availablePlans.where((plan) => plan.tierLevel == tierLevel).toList();
  }

  /// Check if user has access to a specific feature
  bool hasFeature(String featureName) {
    if (_currentSubscription == null) return false;
    return _currentSubscription!.hasFeature(featureName);
  }

  /// Get user-friendly error message
  String? get errorMessage {
    if (_error == null) return null;
    
    // Clean up error messages
    final error = _error!;
    if (error.contains('Exception:')) {
      return error.replaceAll('Exception:', '').trim();
    }
    return error;
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state (useful for logout)
  void reset() {
    _currentSubscription = null;
    _availablePlans = [];
    _quotas = {};
    _usageHistory = [];
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    notifyListeners();
  }
}

