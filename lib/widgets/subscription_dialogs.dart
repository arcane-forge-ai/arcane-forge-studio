import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';
import '../constants.dart';

/// Dialog for comparing subscription plans
class PlanComparisonDialog extends StatefulWidget {
  final VoidCallback? onActivateCode;

  const PlanComparisonDialog({
    Key? key,
    this.onActivateCode,
  }) : super(key: key);

  @override
  State<PlanComparisonDialog> createState() => _PlanComparisonDialogState();
}

class _PlanComparisonDialogState extends State<PlanComparisonDialog> {
  bool _hasLoadedPlans = false;

  @override
  void initState() {
    super.initState();
    // Load plans only once when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedPlans && mounted) {
        _hasLoadedPlans = true;
        final provider = Provider.of<SubscriptionProvider>(context, listen: false);
        provider.loadPlansIfNeeded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final plans = provider.availablePlans;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: primaryColor, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Choose Your Plan',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock powerful AI tools to create your game',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Plans Grid
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : plans.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Unable to load plans',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                  ),
                                  if (provider.errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        provider.errorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => provider.refresh(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                          scrollDirection: Axis.horizontal,
                          children: plans.map((plan) => _buildPlanCard(
                            context,
                            plan,
                            isDark,
                            colorScheme,
                          )).toList(),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Early Access Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Early Access Special',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Activate with your early access code.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (widget.onActivateCode != null) widget.onActivateCode!();
                        },
                        icon: const Icon(Icons.vpn_key),
                        label: const Text('I Have a Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final isPopular = plan.tierLevel == 1; // Starter is popular
    
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? secondaryColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? primaryColor : colorScheme.outline.withOpacity(0.2),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Popular badge
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name
                Text(
                  plan.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Price
                // Row(
                //   crossAxisAlignment: CrossAxisAlignment.end,
                //   children: [
                //     Text(
                //       '\$${(plan.originalPriceMonthly / 2).toStringAsFixed(0)}',
                //       style: const TextStyle(
                //         fontSize: 36,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //     const SizedBox(width: 4),
                //     Padding(
                //       padding: const EdgeInsets.only(bottom: 8),
                //       child: Text(
                //         '/month',
                //         style: TextStyle(
                //           fontSize: 16,
                //           color: isDark ? Colors.white70 : Colors.black54,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
                
                // // Original price
                // if (plan.tierLevel > 0)
                //   Text(
                //     'Regular: \$${plan.originalPriceMonthly.toStringAsFixed(0)}/month',
                //     style: TextStyle(
                //       fontSize: 14,
                //       decoration: TextDecoration.lineThrough,
                //       color: isDark ? Colors.white54 : Colors.black45,
                //     ),
                //   ),
                
                // const SizedBox(height: 20),
                // const Divider(),
                // const SizedBox(height: 20),
                
                // Quotas
                if (plan.quotaConfig.isNotEmpty) ...[
                  ..._buildQuotaSection(plan),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuotaSection(SubscriptionPlan plan) {
    // Extract daily and monthly quotas
    Map<String, dynamic>? dailyQuotas = plan.quotaConfig['daily'] as Map<String, dynamic>?;
    Map<String, dynamic>? monthlyQuotas = plan.quotaConfig['monthly'] as Map<String, dynamic>?;
    
    List<Widget> widgets = [
      const Text(
        'Monthly Quotas',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 12),
    ];
    
    // Build quota items for each generation type
    final quotaTypes = ['image_generation', 'sfx_generation', 'music_generation'];
    
    for (final quotaType in quotaTypes) {
      final dailyValue = (dailyQuotas?[quotaType] as num?)?.toInt() ?? 0;
      final monthlyValue = (monthlyQuotas?[quotaType] as num?)?.toInt() ?? 0;
      
      // Only show if at least one value is > 0
      if (dailyValue > 0 || monthlyValue > 0) {
        widgets.add(_buildQuotaItem(quotaType, dailyValue, monthlyValue));
      }
    }
    
    return widgets;
  }

  Widget _buildQuotaItem(String quotaType, int dailyValue, int monthlyValue) {
    String displayName;
    
    // Get display name
    switch (quotaType) {
      case 'sfx_generation':
        displayName = 'SFX Generation';
        break;
      case 'music_generation':
        displayName = 'Music Generation';
        break;
      case 'image_generation':
        displayName = 'Image Generation';
        break;
      default:
        displayName = quotaType;
    }
    
    // Build quota value lines (only show if > 0)
    List<String> quotaLines = [];
    if (dailyValue > 0) {
      quotaLines.add(dailyValue >= 999999 ? 'Unlimited daily' : '$dailyValue / day');
    }
    if (monthlyValue > 0) {
      quotaLines.add(monthlyValue >= 999999 ? 'Unlimited monthly' : '$monthlyValue / month');
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                ...quotaLines.map((line) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for activating early access with discount code
class ActivateEarlyAccessDialog extends StatefulWidget {
  const ActivateEarlyAccessDialog({Key? key}) : super(key: key);

  @override
  State<ActivateEarlyAccessDialog> createState() => _ActivateEarlyAccessDialogState();
}

class _ActivateEarlyAccessDialogState extends State<ActivateEarlyAccessDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  bool _isActivating = false;
  DiscountCodeValidation? _validation;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _validation = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<SubscriptionProvider>(context, listen: false);
      final validation = await provider.validateDiscountCode(_codeController.text.trim());
      
      setState(() {
        _validation = validation;
        _isValidating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isValidating = false;
      });
    }
  }

  Future<void> _activateCode() async {
    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<SubscriptionProvider>(context, listen: false);
      final success = await provider.activateEarlyAccess(_codeController.text.trim());
      
      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Early access activated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = provider.errorMessage ?? 'Failed to activate subscription';
          _isActivating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isActivating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.vpn_key, color: primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Activate Early Access',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isActivating ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your discount code to activate your subscription',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            
            // Code input
            TextField(
              controller: _codeController,
              enabled: !_isActivating,
              decoration: InputDecoration(
                labelText: 'Discount Code',
                hintText: 'Enter your code...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number),
                suffixIcon: _isValidating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _validation != null
                        ? Icon(
                            _validation!.isValid ? Icons.check_circle : Icons.error,
                            color: _validation!.isValid ? Colors.green : Colors.red,
                          )
                        : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                // Debounce validation
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_codeController.text == value) {
                    _validateCode();
                  }
                });
              },
            ),
            
            // Validation feedback
            if (_validation != null && _validation!.isValid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Valid Code',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          if (_validation!.planName != null)
                            Text(
                              'Plan: ${_validation!.planName}',
                              style: const TextStyle(fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!.replaceAll('Exception:', '').trim(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isActivating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isActivating || _validation?.isValid != true
                      ? null
                      : _activateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog shown when user exceeds quota
class QuotaExceededDialog extends StatelessWidget {
  final String quotaType;
  final DateTime? resetTime;
  final VoidCallback? onUpgrade;

  const QuotaExceededDialog({
    Key? key,
    required this.quotaType,
    this.resetTime,
    this.onUpgrade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          const Text('Quota Exceeded'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'ve used all your ${_getQuotaDisplayName(quotaType)} for this period.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (resetTime != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    _getResetTimeMessage(resetTime!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Upgrade to get higher quotas and continue creating!',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            if (onUpgrade != null) onUpgrade!();
          },
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Upgrade Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getQuotaDisplayName(String type) {
    switch (type) {
      case 'sfx_generation':
        return 'SFX generations';
      case 'music_generation':
        return 'music generations';
      case 'image_generation':
        return 'image generations';
      default:
        return type;
    }
  }

  String _getResetTimeMessage(DateTime reset) {
    final now = DateTime.now();
    if (reset.isBefore(now)) {
      return 'Quota resets soon';
    }
    
    final duration = reset.difference(now);
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

/// Dialog prompting user to upgrade for feature access
class UpgradePromptDialog extends StatelessWidget {
  final String feature;
  final int requiredTier;
  final String requiredTierName;
  final VoidCallback? onActivateCode;
  final VoidCallback? onViewPlans;

  const UpgradePromptDialog({
    Key? key,
    required this.feature,
    this.requiredTier = 1,
    this.requiredTierName = 'Starter',
    this.onActivateCode,
    this.onViewPlans,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock, color: primaryColor, size: 28),
          const SizedBox(width: 12),
          const Text('Upgrade Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$feature is available on $requiredTierName tier and higher.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.stars, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Early Access Special',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Activate with your early access code and get 50% off!',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        if (onViewPlans != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onViewPlans!();
            },
            child: const Text('View Plans'),
          ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            if (onActivateCode != null) onActivateCode!();
          },
          icon: const Icon(Icons.vpn_key),
          label: const Text('Activate Code'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

