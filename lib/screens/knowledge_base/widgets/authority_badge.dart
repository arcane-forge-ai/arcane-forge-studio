import 'package:flutter/material.dart';

/// Badge widget to display authority level
class AuthorityBadge extends StatelessWidget {
  final String authorityLevel;
  final bool compact;

  const AuthorityBadge({
    Key? key,
    required this.authorityLevel,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    if (compact) {
      return Tooltip(
        message: config['tooltip'] as String,
        child: Icon(
          config['icon'] as IconData,
          size: 16,
          color: config['color'] as Color,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (config['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 14,
            color: config['color'] as Color,
          ),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getConfig() {
    switch (authorityLevel.toLowerCase()) {
      case 'source_of_truth':
        return {
          'icon': Icons.star,
          'label': 'Source',
          'tooltip': 'Source of Truth',
          'color': Colors.amber,
        };
      case 'reference':
        return {
          'icon': Icons.book,
          'label': 'Reference',
          'tooltip': 'Reference Material',
          'color': Colors.blue,
        };
      case 'deprecated':
        return {
          'icon': Icons.warning,
          'label': 'Deprecated',
          'tooltip': 'Deprecated - Use with Caution',
          'color': Colors.orange,
        };
      default:
        return {
          'icon': Icons.help_outline,
          'label': 'Unknown',
          'tooltip': 'Unknown Authority Level',
          'color': Colors.grey,
        };
    }
  }
}
