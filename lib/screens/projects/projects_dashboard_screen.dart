import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/menu_app_controller.dart';
import '../../responsive.dart';
import '../settings/settings_screen.dart';
import '../user/user_screen.dart';
import 'components/projects_side_menu.dart';
import 'projects_screen.dart';
import 'project_invites_screen.dart';
import '../shared/components/base_side_menu.dart';

class ProjectsDashboardScreen extends StatelessWidget {
  const ProjectsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ProjectsSideMenu(),
      body: SafeArea(
        child: Consumer<MenuAppController>(
          builder: (context, controller, child) {
            final isDesktop = Responsive.isDesktop(context);
            final sidebarWidth =
                isDesktop && controller.isDesktopSidebarCollapsed
                    ? BaseSideMenu.desktopRailWidth
                    : BaseSideMenu.desktopWidth;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  AnimatedContainer(
                    duration: BaseSideMenu.desktopAnimationDuration,
                    curve: Curves.easeInOut,
                    width: sidebarWidth,
                    child: ClipRect(
                      child: SizedBox(
                        width: sidebarWidth,
                        child: controller.isDesktopSidebarCollapsed
                            ? const ProjectsSideMenu().buildDesktopRail(
                                context,
                                onExpand: controller.expandDesktopSidebar,
                              )
                            : const ProjectsSideMenu().buildDesktopPanel(
                                context,
                                onCollapse: controller.toggleDesktopSidebar,
                              ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _buildContent(controller),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(MenuAppController controller) {
    switch (controller.currentScreen) {
      case ScreenType.projects:
        return const ProjectsScreen();
      case ScreenType.invites:
        return const ProjectInvitesScreen();
      case ScreenType.settings:
        return const SettingsScreen();
      case ScreenType.user:
        return const UserScreen();
      default:
        return const ProjectsScreen();
    }
  }
}
