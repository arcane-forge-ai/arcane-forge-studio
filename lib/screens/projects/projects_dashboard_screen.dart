import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/menu_app_controller.dart';
import '../../responsive.dart';
import '../settings/settings_screen.dart';
import '../user/user_screen.dart';
import 'components/projects_side_menu.dart';
import 'projects_screen.dart';

class ProjectsDashboardScreen extends StatelessWidget {
  const ProjectsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ProjectsSideMenu(),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // We want this side menu only for large screen  
            if (Responsive.isDesktop(context))
              const Expanded(
                // default flex = 1
                // and it takes 1/6 part of the screen
                child: ProjectsSideMenu(),
              ),
            Expanded(
              // It takes 5/6 part of the screen
              flex: 5,
              child: Consumer<MenuAppController>(
                builder: (context, controller, child) {
                  switch (controller.currentScreen) {
                    case ScreenType.projects:
                      return const ProjectsScreen();
                    case ScreenType.settings:
                      return const SettingsScreen();
                    case ScreenType.user:
                      return const UserScreen();
                    default:
                      return const ProjectsScreen();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 