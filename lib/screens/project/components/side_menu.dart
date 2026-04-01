import 'package:arcane_forge/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../controllers/menu_app_controller.dart';
import '../../shared/components/base_side_menu.dart';
import '../../shared/components/menu_badge.dart';
import '../../projects/projects_dashboard_screen.dart';

class SideMenu extends BaseSideMenu {
  const SideMenu({
    super.key,
    String? projectName,
  }) : super(subtitle: projectName);

  Widget _buildMenuTitleWithBadge(String title, MenuBadgeType badgeType) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MenuBadge(badgeType),
        Text(title),
      ],
    );
  }

  void _goToProjects(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ProjectsDashboardScreen(),
      ),
    );
  }

  // Helper method to build a menu item with a "Coming Soon" badge
  Widget _buildComingSoonMenuItem(
    BuildContext context, {
    required String title,
    required ScreenType screenType,
    IconData? icon,
  }) {
    return ListTile(
      title: _buildMenuTitleWithBadge(title, MenuBadgeType.comingSoon),
      leading: icon != null ? Icon(icon) : null,
      onTap: () {
        Provider.of<MenuAppController>(context, listen: false)
            .changeScreen(screenType);
      },
    );
  }

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

  Widget _buildRailPopupMenu(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool selected,
    required List<PopupMenuEntry<Never>> items,
  }) {
    return buildRailPopupButton<Never>(
      context,
      icon: icon,
      tooltip: tooltip,
      selected: selected,
      items: items,
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
      // Navigation section
      buildSectionHeader(context,
          icon: Icons.navigate_before, title: "Navigation"),
      ListTile(
        title: const Text("All Projects"),
        leading: const Icon(Icons.folder_open),
        onTap: () => _goToProjects(context),
      ),

      // Overview
      buildSectionHeader(context, icon: Icons.dashboard, title: "Overview"),
      ListTile(
        title: const Text("Project Home"),
        leading: const Icon(Icons.home),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.projectHome);
        },
      ),
      ListTile(
        title: const Text("Knowledge Base"),
        leading: const Icon(Icons.library_books),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.knowledgeBase);
        },
      ),
      ListTile(
        title: const Text("Knowledge Base Q&A"),
        leading: const Icon(Icons.question_answer),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.knowledgeBaseQA);
        },
      ),

      // Idealization
      buildSectionHeader(context, icon: Icons.lightbulb, title: "Idealization"),
      ListTile(
        title: const Text("Game Design Assistant"),
        leading: const Icon(Icons.psychology),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.gameDesignAssistant);
        },
      ),
      ListTile(
        title: _buildMenuTitleWithBadge(
          "Game Design Assistant v2",
          MenuBadgeType.alpha,
        ),
        leading: const Icon(Icons.psychology_alt),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.gameDesignAssistantV2);
        },
      ),

      ListTile(
        title: const Text("Design Evaluation"),
        leading: const Icon(Icons.analytics),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.evaluate);
        },
      ),

      // Development - code editor, image generator, sound generator, music generator, web server
      buildSectionHeader(context, icon: Icons.code, title: "Development"),
      ExpansionTile(
        title: _buildMenuTitleWithBadge("Image Generation", MenuBadgeType.beta),
        leading: const Icon(Icons.image, color: iconColor),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Overview"),
              leading: const Icon(Icons.grid_view, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.imageGenerationOverview);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Generation"),
              leading: const Icon(Icons.auto_awesome, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.imageGenerationGeneration);
              },
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text("SFX Generation"),
        leading: const Icon(Icons.audiotrack, color: iconColor),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Overview"),
              leading: const Icon(Icons.library_music, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.sfxGenerationOverview);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Generation"),
              leading: const Icon(Icons.audiotrack, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.sfxGenerationGeneration);
              },
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text("Music Generation"),
        leading: const Icon(Icons.music_note, color: iconColor),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Overview"),
              leading: const Icon(Icons.queue_music, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.musicGenerationOverview);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: const Text("Generation"),
              leading: const Icon(Icons.music_note, size: 20),
              onTap: () {
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.musicGenerationGeneration);
              },
            ),
          ),
        ],
      ),
      ListTile(
        title: const Text("Coding Agent (Beta)"),
        leading: const Icon(Icons.code),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.codingAgent);
        },
      ),
      ListTile(
        title: const Text("Developer Toolkit"),
        leading: const Icon(Icons.build_circle_outlined),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.developerToolkit);
        },
      ),
      // ListTile(
      //     title: const Text("Web Server"),
      //     onTap: () {
      //       Provider.of<MenuAppController>(context, listen: false)
      //           .changeScreen(ScreenType.webServer);
      //     }),

      // Production - Release Info, Stats, Feedbacks
      buildSectionHeader(context,
          icon: Icons.production_quantity_limits, title: "Production"),
      ListTile(
        title: const Text("Release Info"),
        leading: const Icon(Icons.rocket_launch),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.versions);
        },
      ),
      _buildComingSoonMenuItem(
        context,
        title: "Stats",
        screenType: ScreenType.stats,
        icon: Icons.analytics_outlined,
      ),
      ListTile(
        title: const Text("Feedbacks"),
        leading: const Icon(Icons.feedback),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.feedbacks);
        },
      ),
    ];
  }

  @override
  List<Widget> buildCollapsedMenuItems(BuildContext context) {
    return [
      buildRailButton(
        context,
        icon: Icons.folder_open,
        tooltip: 'All Projects',
        onTap: () => _goToProjects(context),
      ),
      _buildRailDivider(),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.projectHome,
        icon: Icons.home,
        tooltip: 'Project Home',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.knowledgeBase,
        icon: Icons.library_books,
        tooltip: 'Knowledge Base',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.knowledgeBaseQA,
        icon: Icons.question_answer,
        tooltip: 'Knowledge Base Q&A',
      ),
      _buildRailDivider(),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.gameDesignAssistant,
        icon: Icons.psychology,
        tooltip: 'Game Design Assistant',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.gameDesignAssistantV2,
        icon: Icons.psychology_alt,
        tooltip: 'Game Design Assistant v2',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.evaluate,
        icon: Icons.analytics,
        tooltip: 'Design Evaluation',
      ),
      _buildRailDivider(),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return _buildRailPopupMenu(
            context,
            icon: Icons.image,
            tooltip: 'Image Generation',
            selected: controller.currentScreen ==
                    ScreenType.imageGenerationOverview ||
                controller.currentScreen ==
                    ScreenType.imageGenerationGeneration,
            items: [
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.imageGenerationOverview);
                },
                child: const Text('Overview'),
              ),
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.imageGenerationGeneration);
                },
                child: const Text('Generation'),
              ),
            ],
          );
        },
      ),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return _buildRailPopupMenu(
            context,
            icon: Icons.audiotrack,
            tooltip: 'SFX Generation',
            selected: controller.currentScreen ==
                    ScreenType.sfxGenerationOverview ||
                controller.currentScreen == ScreenType.sfxGenerationGeneration,
            items: [
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.sfxGenerationOverview);
                },
                child: const Text('Overview'),
              ),
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.sfxGenerationGeneration);
                },
                child: const Text('Generation'),
              ),
            ],
          );
        },
      ),
      Consumer<MenuAppController>(
        builder: (context, controller, child) {
          return _buildRailPopupMenu(
            context,
            icon: Icons.music_note,
            tooltip: 'Music Generation',
            selected: controller.currentScreen ==
                    ScreenType.musicGenerationOverview ||
                controller.currentScreen ==
                    ScreenType.musicGenerationGeneration,
            items: [
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.musicGenerationOverview);
                },
                child: const Text('Overview'),
              ),
              PopupMenuItem<Never>(
                onTap: () {
                  Provider.of<MenuAppController>(context, listen: false)
                      .changeScreen(ScreenType.musicGenerationGeneration);
                },
                child: const Text('Generation'),
              ),
            ],
          );
        },
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.codingAgent,
        icon: Icons.code,
        tooltip: 'Coding Agent (Beta)',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.developerToolkit,
        icon: Icons.build_circle_outlined,
        tooltip: 'Developer Toolkit',
      ),
      _buildRailDivider(),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.versions,
        icon: Icons.rocket_launch,
        tooltip: 'Release Info',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.stats,
        icon: Icons.analytics_outlined,
        tooltip: 'Stats (Coming Soon)',
      ),
      _buildRailScreenButton(
        context,
        screenType: ScreenType.feedbacks,
        icon: Icons.feedback,
        tooltip: 'Feedbacks',
      ),
    ];
  }
}

class DrawerListTile extends StatelessWidget {
  const DrawerListTile({
    super.key,
    // For selecting those three line once press "Command+D"
    required this.title,
    required this.svgSrc,
    required this.press,
  });

  final String title, svgSrc;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: press,
      horizontalTitleGap: 0.0,
      leading: SvgPicture.asset(
        svgSrc,
        colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn),
        height: 16,
      ),
      title: const Text(
        'title',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
