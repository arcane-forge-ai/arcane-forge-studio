import 'package:arcane_forge/constants.dart';
import 'package:flutter/material.dart';

/// Base side menu component with common functionality
abstract class BaseSideMenu extends StatelessWidget {
  static const double desktopWidth = 280;
  static const double desktopRailWidth = 76;
  static const Duration desktopAnimationDuration = Duration(milliseconds: 220);

  final String? subtitle;

  const BaseSideMenu({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: buildMenuPanel(context),
    );
  }

  Widget buildDesktopPanel(
    BuildContext context, {
    required VoidCallback onCollapse,
  }) {
    return Material(
      color: Theme.of(context).drawerTheme.backgroundColor ?? secondaryColor,
      child: buildMenuPanel(
        context,
        showCollapseButton: true,
        onCollapse: onCollapse,
      ),
    );
  }

  Widget buildDesktopRail(
    BuildContext context, {
    required VoidCallback onExpand,
  }) {
    return Material(
      color: Theme.of(context).drawerTheme.backgroundColor ?? secondaryColor,
      child: Column(
        children: [
          _buildRailHeader(context, onExpand: onExpand),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: buildCollapsedMenuItems(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuPanel(
    BuildContext context, {
    bool showCollapseButton = false,
    VoidCallback? onCollapse,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildDrawerHeader(
          context,
          showCollapseButton: showCollapseButton,
          onCollapse: onCollapse,
        ),
        ...buildMenuItems(context),
      ],
    );
  }

  /// Build the drawer header with logo and title
  Widget _buildDrawerHeader(
    BuildContext context, {
    bool showCollapseButton = false,
    VoidCallback? onCollapse,
  }) {
    return DrawerHeader(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          if (showCollapseButton && onCollapse != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Collapse sidebar',
                onPressed: onCollapse,
                icon: const Icon(Icons.menu_open),
              ),
            ),
          Align(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        ],
      ),
    );
  }

  Widget _buildRailHeader(
    BuildContext context, {
    required VoidCallback onExpand,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Expand sidebar',
              onPressed: onExpand,
              icon: const Icon(Icons.menu),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            width: 36,
            child: Image.asset(
              "assets/images/logo.png",
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRailButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foregroundColor = selected
        ? colorScheme.onPrimaryContainer
        : theme.iconTheme.color ?? Colors.white;
    final Color backgroundColor =
        selected ? colorScheme.primaryContainer : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Icon(icon, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRailPopupButton<T>(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required List<PopupMenuEntry<T>> items,
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foregroundColor = selected
        ? colorScheme.onPrimaryContainer
        : theme.iconTheme.color ?? Colors.white;
    final Color backgroundColor =
        selected ? colorScheme.primaryContainer : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          child: PopupMenuButton<T>(
            tooltip: tooltip,
            icon: Icon(icon, color: foregroundColor),
            itemBuilder: (context) => items,
          ),
        ),
      ),
    );
  }

  /// Build section header with icon and title
  Widget buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
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
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontWeight: FontWeight.w600),
              ),
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

  /// Return the compact rail items for desktop collapsed mode
  List<Widget> buildCollapsedMenuItems(BuildContext context) => const [];
}
