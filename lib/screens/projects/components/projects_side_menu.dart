import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/menu_app_controller.dart';
import '../../shared/components/base_side_menu.dart';
import '../../../providers/auth_provider.dart';
import '../../login/login_screen.dart';

class ProjectsSideMenu extends BaseSideMenu {
  const ProjectsSideMenu({
    super.key,
  });

  Widget _buildRailScreenButton(
    BuildContext context, {
    required ScreenType screenType,
    required IconData icon,
    required String tooltip,
  }) {
    return Consumer<MenuAppController>(
      builder: (context, controller, child) {
        return buildRailButton(
          context,
          icon: icon,
          tooltip: tooltip,
          selected: controller.currentScreen == screenType,
          onTap: () {
            Provider.of<MenuAppController>(context, listen: false)
                .changeScreen(screenType);
          },
        );
      },
    );
  }

  Widget _buildRailDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Divider(height: 1),
    );
  }

  @override
  List<Widget> buildMenuItems(BuildContext context) {
    return [
      // Projects section
      buildSectionHeader(context, icon: Icons.folder, title: "Projects"),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return ListTile(
            title: const Text("Projects"),
            leading: const Icon(Icons.folder_open),
            selected: controller.currentScreen == ScreenType.projects,
            onTap: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.projects);
            },
          );
        },
      ),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return ListTile(
            title: const Text("Invites"),
            leading: const Icon(Icons.mail_outline),
            selected: controller.currentScreen == ScreenType.invites,
            onTap: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.invites);
            },
          );
        },
      ),

      const SizedBox(height: 16),

      // Settings section
      buildSectionHeader(context, icon: Icons.settings, title: "Settings"),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return ListTile(
            title: const Text("Settings"),
            leading: const Icon(Icons.settings),
            selected: controller.currentScreen == ScreenType.settings,
            onTap: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.settings);
            },
          );
        },
      ),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return ListTile(
            title: const Text("User"),
            leading: const Icon(Icons.person),
            selected: controller.currentScreen == ScreenType.user,
            onTap: () {
              Provider.of<MenuAppController>(context, listen: false)
                  .changeScreen(ScreenType.user);
            },
          );
        },
      ),

      const Divider(),
      Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await auth.signOut();
              if (context.mounted) {
                // Explicitly navigate to login screen and clear navigation stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false, // Remove all routes from stack
                );
              }
            },
          );
        },
      ),
    ];
  }

  @override
  List<Widget> buildCollapsedMenuItems(BuildContext context) {
    return [
      _buildRailScreenButton(
        context,
        screenType: ScreenType.projects,
        icon: Icons.folder_open,
        tooltip: 'Projects',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.invites,
        icon: Icons.mail_outline,
        tooltip: 'Invites',
      ),
      _buildRailDivider(),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.settings,
        icon: Icons.settings,
        tooltip: 'Settings',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.user,
        icon: Icons.person,
        tooltip: 'User',
      ),
      _buildRailDivider(),
      Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return buildRailButton(
            context,
            icon: Icons.logout,
            tooltip: 'Sign Out',
            onTap: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          );
        },
      ),
    ];
  }
}
