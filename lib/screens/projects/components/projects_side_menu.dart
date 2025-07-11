import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/menu_app_controller.dart';
import '../../shared/components/base_side_menu.dart';
import '../../../providers/auth_provider.dart';
import '../../login/login_screen.dart';

class ProjectsSideMenu extends BaseSideMenu {
  const ProjectsSideMenu({
    Key? key,
  }) : super(key: key);

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

} 