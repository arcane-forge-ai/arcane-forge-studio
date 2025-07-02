import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/menu_app_controller.dart';
import '../../responsive.dart';
import '../dashboard/dashboard_screen.dart';
import 'components/side_menu.dart';
import 'components/project_home_screen.dart';
import '../development/command_line_screen.dart';
import '../game_design_assistant/game_design_assistant_screen.dart';
import '../game_design_assistant/providers/project_provider.dart';
import '../knowledge_base/knowledge_base_screen.dart';

class ProjectDashboardScreen extends StatelessWidget {
  final String projectId;
  final String projectName;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ProjectDashboardScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(projectName: projectName),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // We want this side menu only for large screen
            if (Responsive.isDesktop(context))
              Expanded(
                // default flex = 1
                // and it takes 1/6 part of the screen
                child: SideMenu(projectName: projectName),
              ),
            Expanded(
              // It takes 5/6 part of the screen
              flex: 5,
              child: Consumer<MenuAppController>(
                builder: (context, controller, child) {
                  switch (controller.currentScreen) {
                    case ScreenType.projectHome:
                      return ProjectHomeScreen(projectId: projectId);
                    case ScreenType.knowledgeBase:
                      return ChangeNotifierProvider(
                        create: (context) {
                          final provider = ProjectProvider();
                          provider.initializeWithProject(projectId, projectName);
                          return provider;
                        },
                        child: KnowledgeBaseScreen(),
                      );
                    case ScreenType.gameDesignAssistant:
                      return ChangeNotifierProvider(
                        create: (context) {
                          final provider = ProjectProvider();
                          provider.initializeWithProject(projectId, projectName);
                          return provider;
                        },
                        child: GameDesignAssistantScreen(),
                      );
                    case ScreenType.codeEditor:
                      return CommandLineScreen();
                    default:
                      return DashboardScreen();
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
