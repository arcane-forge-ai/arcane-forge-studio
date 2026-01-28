import 'package:flutter/material.dart';

/// A reusable widget for displaying the greenlight status indicator
class EvaluateGreenlightIndicator extends StatelessWidget {
  final String status;

  const EvaluateGreenlightIndicator({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'green':
        color = Colors.green;
        label = 'READY FOR PRODUCTION';
        icon = Icons.check_circle;
        break;
      case 'yellow':
        color = Colors.orange;
        label = 'NEEDS ATTENTION';
        icon = Icons.warning;
        break;
      case 'red':
        color = Colors.red;
        label = 'CRITICAL ISSUES';
        icon = Icons.cancel;
        break;
      case 'not yet':
        color = Colors.grey;
        label = 'NOT READY YET';
        icon = Icons.pending;
        break;
      default:
        color = Colors.grey;
        label = 'UNKNOWN';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

