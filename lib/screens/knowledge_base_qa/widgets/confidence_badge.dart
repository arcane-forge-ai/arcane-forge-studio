import 'package:flutter/material.dart';

/// Badge widget to display confidence levels for QA responses
class ConfidenceBadge extends StatelessWidget {
  final String confidence;

  const ConfidenceBadge({
    super.key,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final badgeInfo = _getBadgeInfo(confidence);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeInfo.color.withOpacity(0.2),
        border: Border.all(color: badgeInfo.color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeInfo.icon,
            size: 14,
            color: badgeInfo.color,
          ),
          const SizedBox(width: 4),
          Text(
            badgeInfo.text,
            style: TextStyle(
              color: badgeInfo.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeInfo _getBadgeInfo(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return _BadgeInfo(
          color: Colors.green,
          text: 'High Confidence',
          icon: Icons.check_circle,
        );
      case 'medium':
        return _BadgeInfo(
          color: Colors.orange,
          text: 'Medium Confidence',
          icon: Icons.info,
        );
      case 'low':
        return _BadgeInfo(
          color: Colors.deepOrange,
          text: 'Low Confidence',
          icon: Icons.warning,
        );
      case 'unknown':
      default:
        return _BadgeInfo(
          color: Colors.grey,
          text: 'Unverified',
          icon: Icons.help_outline,
        );
    }
  }
}

class _BadgeInfo {
  final Color color;
  final String text;
  final IconData icon;

  _BadgeInfo({
    required this.color,
    required this.text,
    required this.icon,
  });
}
