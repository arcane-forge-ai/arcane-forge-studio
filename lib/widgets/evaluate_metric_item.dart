import 'package:flutter/material.dart';
import '../constants.dart';

/// A reusable widget for displaying evaluation metrics (gaps, risks, next steps)
class EvaluateMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const EvaluateMetricItem({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

