import 'package:flutter/material.dart';

enum MenuBadgeType { alpha, beta, comingSoon }

class MenuBadge extends StatelessWidget {
  const MenuBadge(this.type, {Key? key}) : super(key: key);

  final MenuBadgeType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      MenuBadgeType.alpha => ('ALPHA', Colors.blue),
      MenuBadgeType.beta => ('BETA', Colors.purple.shade200),
      MenuBadgeType.comingSoon => ('COMING SOON', Colors.orange),
    };

    final textColor =
        type == MenuBadgeType.comingSoon ? Colors.orange.shade700 : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
