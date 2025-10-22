import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/menu_app_controller.dart';
import '../../responsive.dart';
import '../dashboard/dashboard_screen.dart';
import 'components/side_menu.dart';
import 'components/project_home_screen.dart';
import '../game_design_assistant/game_design_assistant_screen.dart';
import '../game_design_assistant/providers/project_provider.dart';
import '../knowledge_base/knowledge_base_screen.dart';
import '../image_generation/image_overview_screen.dart';
import '../image_generation/image_generation_screen.dart';
import '../sfx_generation/sfx_generation_screen.dart';
import '../sfx_generation/sfx_overview_screen.dart';
import '../music_generation/music_generation_screen.dart';
import '../music_generation/music_overview_screen.dart';
import '../feedback/feedback_screen.dart';
import 'release_info_screen.dart';
import '../shared/coming_soon_screen.dart';
import '../development/code_screen.dart';

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
    // Ensure we start with project home screen when entering a project
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<MenuAppController>(context, listen: false);
      if (controller.currentScreen != ScreenType.projectHome) {
        controller.changeScreen(ScreenType.projectHome);
      }
    });

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
                      return ProjectHomeScreen(
                        key: ValueKey('project_home_$projectId'),
                        projectId: projectId,
                      );
                    case ScreenType.knowledgeBase:
                      return ChangeNotifierProvider(
                        create: (context) {
                          final provider = ProjectProvider();
                          provider.initializeWithProject(
                              projectId, projectName);
                          return provider;
                        },
                        child: KnowledgeBaseScreen(),
                      );
                    case ScreenType.gameDesignAssistant:
                      return ChangeNotifierProvider(
                        create: (context) {
                          final provider = ProjectProvider();
                          provider.initializeWithProject(
                              projectId, projectName);
                          return provider;
                        },
                        child: GameDesignAssistantScreen(),
                      );
                    case ScreenType.codeEditor:
                      return CodeScreen(
                        projectId: projectId,
                        projectName: projectName,
                      );
                    case ScreenType.imageGenerationOverview:
                      return ImageOverviewScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.imageGenerationGeneration:
                      return ImageGenerationScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.soundGenerator:
                    case ScreenType.sfxGenerationGeneration:
                      return SfxGenerationScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.sfxGenerationOverview:
                      return SfxOverviewScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.musicGenerator:
                    case ScreenType.musicGenerationGeneration:
                      return MusicGenerationScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.musicGenerationOverview:
                      return MusicOverviewScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.feedbacks:
                      return FeedbackScreen(
                          projectId: projectId, projectName: projectName);
                    case ScreenType.versions:
                      return ReleaseInfoScreen(
                        projectId: projectId,
                        projectName: projectName,
                      );
                    case ScreenType.stats:
                      return const ComingSoonScreen(
                        featureName: 'Analytics & Stats',
                        icon: Icons.analytics_outlined,
                        description: 'Comprehensive analytics and statistics for your game project will be available soon. Track performance, user engagement, and more.',
                      );
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
