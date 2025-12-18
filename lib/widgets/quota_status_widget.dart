import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';
import '../constants.dart';

/// Widget displaying quota status with compact and detailed variants
class QuotaStatusWidget extends StatelessWidget {
  final String quotaType;
  final bool isCompact;

  const QuotaStatusWidget({
    Key? key,
    required this.quotaType,
    this.isCompact = false,
  }) : super(key: key);

  /// Factory constructor for compact variant (for generation screen headers)
  factory QuotaStatusWidget.compact(String quotaType) {
    return QuotaStatusWidget(quotaType: quotaType, isCompact: true);
  }

  /// Factory constructor for detailed variant (for subscription hub)
  factory QuotaStatusWidget.detailed(String quotaType) {
    return QuotaStatusWidget(quotaType: quotaType, isCompact: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        // Show loading indicator if not initialized yet
        if (!provider.isInitialized && provider.isLoading) {
          return isCompact
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Center(child: CircularProgressIndicator());
        }
        
        final quota = provider.getQuotaStatus(quotaType);
        
        // If quota doesn't exist, don't show widget (unlimited or not configured)
        if (quota == null) {
          return const SizedBox.shrink();
        }
        
        return isCompact ? _buildCompactView(context, quota) : _buildDetailedView(context, quota);
      },
    );
  }

  Widget _buildCompactView(BuildContext context, QuotaStatus quota) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine status color
    Color statusColor;
    if (quota.isExceeded) {
      statusColor = Colors.red;
    } else if (quota.isLow) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getQuotaIcon(quotaType),
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            '${quota.remaining}/${quota.quotaLimit}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'left',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context, QuotaStatus quota) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Calculate progress percentage
    final progress = quota.quotaLimit > 0 
        ? quota.usageCount / quota.quotaLimit 
        : 0.0;
    
    // Determine status color
    Color statusColor;
    if (quota.isExceeded) {
      statusColor = Colors.red;
    } else if (quota.isLow) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and name
            Row(
              children: [
                Icon(
                  _getQuotaIcon(quotaType),
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quota.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Resets ${quota.resetFrequency}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quota.isExceeded 
                        ? 'EXCEEDED' 
                        : quota.isLow 
                            ? 'LOW' 
                            : 'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${quota.remaining} remaining',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      '${quota.usageCount} / ${quota.quotaLimit}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Reset time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 6),
                Text(
                  'Resets in ${quota.resetTimeFormatted}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getQuotaIcon(String type) {
    switch (type) {
      case 'sfx_generation':
        return Icons.music_note;
      case 'music_generation':
        return Icons.library_music;
      case 'image_generation':
        return Icons.image;
      case 'chat_tokens':
        return Icons.chat;
      default:
        return Icons.data_usage;
    }
  }
}

/// Compact quota summary for multiple quota types
class QuotaSummaryWidget extends StatelessWidget {
  final List<String> quotaTypes;

  const QuotaSummaryWidget({
    Key? key,
    required this.quotaTypes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quotaTypes.map((type) {
            return QuotaStatusWidget.compact(type);
          }).toList(),
        );
      },
    );
  }
}

