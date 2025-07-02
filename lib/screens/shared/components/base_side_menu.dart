import 'package:flutter/material.dart';

/// Base side menu component with common functionality
abstract class BaseSideMenu extends StatelessWidget {
  final String? subtitle;
  
  const BaseSideMenu({Key? key, this.subtitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          _buildDrawerHeader(context),
          ...buildMenuItems(context),
        ],
      ),
    );
  }

  /// Build the drawer header with logo and title
  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      child: Column(
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: Image.asset(
              "assets/images/logo.png",
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          const Text("Arcane Forge"),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Build section header with icon and title
  Widget buildSectionHeader(BuildContext context,
      {required IconData icon, required String title}) {
    final color = Theme.of(context).textTheme.bodyMedium!.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Abstract method to be implemented by subclasses
  /// Return the list of menu items for this specific side menu
  List<Widget> buildMenuItems(BuildContext context);
} 