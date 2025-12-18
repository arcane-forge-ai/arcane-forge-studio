import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../constants.dart';
import '../../utils/app_constants.dart' as app_utils;
import '../../widgets/subscription_dialogs.dart';
import '../../widgets/quota_status_widget.dart';
import '../login/login_screen.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? bgColor : Colors.grey.shade100,
            isDark ? bgColor.withOpacity(0.8) : Colors.grey.shade50,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile Avatar
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 64,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // User Status
              if (user != null) ...[
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? 'User',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // User Info Card
              Card(
                color: isDark ? secondaryColor : Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (user != null) ...[
                        _buildUidRow(
                          uid: user.id,
                          isDark: isDark,
                          context: context,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user.email ?? 'Not provided',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Email Verified',
                          value: user.emailConfirmedAt != null ? 'Yes' : 'No',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Member Since',
                          value: user.createdAt != null 
                              ? app_utils.DateUtils.formatDateString(user.createdAt!)
                              : 'Unknown',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.login_outlined,
                          label: 'Last Login',
                          value: user.lastSignInAt != null 
                              ? app_utils.DateUtils.formatDateString(user.lastSignInAt!)
                              : 'Unknown',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Subscription Section (only for authenticated users)
              if (user != null) ...[
                _buildSubscriptionSection(context, isDark),
                const SizedBox(height: 32),
              ],
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    if (auth.isAuthenticated) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await auth.signOut();
                              if (context.mounted) {
                                // Explicitly navigate to login screen and clear navigation stack
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false, // Remove all routes from stack
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Signed out successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sign out failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUidRow({
    required String uid,
    required bool isDark,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Icon(
          Icons.fingerprint_outlined,
          color: primaryColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User ID',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      uid,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('User ID copied to clipboard'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.copy,
                      size: 16,
                      color: primaryColor,
                    ),
                    tooltip: 'Copy full User ID',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection(BuildContext context, bool isDark) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscription, child) {
        if (!subscription.isInitialized) {
          return Card(
            color: isDark ? secondaryColor : Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Current Plan Card
            _buildCurrentPlanCard(context, subscription, isDark),
            const SizedBox(height: 16),
            
            // Early Access Activation (only for free users)
            if (subscription.isFreeUser) ...[
              _buildEarlyAccessCard(context, subscription, isDark),
              const SizedBox(height: 16),
            ],
            
            // Quota Overview
            _buildQuotaOverviewCard(context, subscription, isDark),
            const SizedBox(height: 16),
            
            // Usage History (for all authenticated users)
            _buildUsageHistoryCard(context, subscription, isDark),
          ],
        );
      },
    );
  }

  Widget _buildCurrentPlanCard(
    BuildContext context,
    SubscriptionProvider subscription,
    bool isDark,
  ) {
    final currentSub = subscription.currentSubscription;

    return Card(
      color: isDark ? secondaryColor : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: subscription.isPaidUser
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: subscription.isPaidUser
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  child: Text(
                    subscription.planName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: subscription.isPaidUser
                          ? Colors.green
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (currentSub != null) ...[
              if (subscription.isPaidUser) ...[
                _buildInfoRow(
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: '\$${currentSub.actualPrice.toStringAsFixed(0)}/month',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                if (currentSub.discountCodeUsed != null)
                  _buildInfoRow(
                    icon: Icons.local_offer,
                    label: 'Discount Code Used',
                    value: currentSub.discountCodeUsed!,
                    isDark: isDark,
                  ),
              ] else ...[
                Text(
                  'You are on the free plan. Activate early access to unlock more features!',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyAccessCard(
    BuildContext context,
    SubscriptionProvider subscription,
    bool isDark,
  ) {
    return Card(
      color: isDark ? secondaryColor : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.1),
              primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.stars,
                    color: primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Activate Early Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Activate Starter or Pro plans with your early access code. If you don\'t have a code, reach out to us!',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showActivateCodeDialog(context),
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('I Have a Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPlanComparisonDialog(context),
                      icon: const Icon(Icons.compare),
                      label: const Text('View Plans'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: primaryColor),
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaOverviewCard(
    BuildContext context,
    SubscriptionProvider subscription,
    bool isDark,
  ) {
    final quotas = subscription.quotas;
    
    if (quotas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: isDark ? secondaryColor : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.data_usage,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Your Quotas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Display quota widgets
            ...quotas.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: QuotaStatusWidget.detailed(entry.key),
              );
            }).toList(),
            
            // Refresh button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => subscription.refreshQuotaStatus(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivateCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ActivateEarlyAccessDialog(),
    ).then((result) {
      // Refresh subscription data if activation was successful
      if (result == true) {
        final subscription = Provider.of<SubscriptionProvider>(context, listen: false);
        subscription.refresh();
      }
    });
  }

  void _showPlanComparisonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PlanComparisonDialog(
        onActivateCode: () => _showActivateCodeDialog(context),
      ),
    );
  }

  Widget _buildUsageHistoryCard(
    BuildContext context,
    SubscriptionProvider subscription,
    bool isDark,
  ) {
    return Card(
      color: isDark ? secondaryColor : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Usage History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showUsageHistoryDetails(context, subscription),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View History'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Show message to click "View History" instead of auto-loading
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Click "View History" to see your recent usage',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUsageHistoryDetails(BuildContext context, SubscriptionProvider subscription) {
    showDialog(
      context: context,
      builder: (context) => _UsageHistoryDialog(subscription: subscription),
    );
  }

  IconData _getOperationIcon(String operationType) {
    switch (operationType) {
      case 'image_gen':
        return Icons.image;
      case 'sfx_gen':
        return Icons.music_note;
      case 'music_gen':
        return Icons.library_music;
      case 'chat':
        return Icons.chat;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}

/// Dialog showing full usage history with filtering
class _UsageHistoryDialog extends StatefulWidget {
  final SubscriptionProvider subscription;

  const _UsageHistoryDialog({required this.subscription});

  @override
  State<_UsageHistoryDialog> createState() => _UsageHistoryDialogState();
}

class _UsageHistoryDialogState extends State<_UsageHistoryDialog> {
  String? _filterQuotaType;
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    // Load history only once when dialog opens
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    await widget.subscription.loadUsageHistory(
      limit: 50,
      quotaType: _filterQuotaType,
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.history, color: primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Usage History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Filter dropdown
            Row(
              children: [
                const Text('Filter by: '),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _filterQuotaType,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Types')),
                    const DropdownMenuItem(value: 'sfx_generation', child: Text('SFX')),
                    const DropdownMenuItem(value: 'music_generation', child: Text('Music')),
                    const DropdownMenuItem(value: 'image_generation', child: Text('Images')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterQuotaType = value;
                    });
                    _loadHistory();
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadHistory,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // History list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.subscription.usageHistory.isEmpty
                      ? Center(
                          child: Text(
                            'No usage history',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.subscription.usageHistory.length,
                          itemBuilder: (context, index) {
                            final entry = widget.subscription.usageHistory[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  _getOperationIcon(entry.operationType),
                                  color: primaryColor,
                                ),
                                title: Text(entry.displayName),
                                subtitle: Text(
                                  _formatDateTime(entry.createdAt),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${entry.unitsConsumed} units',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (entry.resourceId != null)
                                      Text(
                                        entry.resourceId!.substring(0, 8),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getOperationIcon(String operationType) {
    switch (operationType) {
      case 'image_gen':
        return Icons.image;
      case 'sfx_gen':
        return Icons.music_note;
      case 'music_gen':
        return Icons.library_music;
      case 'chat':
        return Icons.chat;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 