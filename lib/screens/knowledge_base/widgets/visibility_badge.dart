import 'package:flutter/material.dart';

/// Badge widget to display visibility status
class VisibilityBadge extends StatelessWidget {
  final String visibility;
  final bool compact;

  const VisibilityBadge({
    Key? key,
    required this.visibility,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isVendorVisible = visibility == 'vendor_visible';
    final icon = isVendorVisible ? Icons.visibility : Icons.lock;
    final label = isVendorVisible ? 'Vendor' : 'Internal';
    final color = isVendorVisible ? Colors.green : Colors.grey;

    if (compact) {
      return Tooltip(
        message: isVendorVisible ? 'Vendor Visible' : 'Internal Only',
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
