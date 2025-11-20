import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../controllers/menu_app_controller.dart';
import '../../shared/components/base_side_menu.dart';
import '../../projects/projects_dashboard_screen.dart';

class SideMenu extends BaseSideMenu {
  const SideMenu({
    Key? key,
    String? projectName,
  }) : super(key: key, subtitle: projectName);

  // Helper method to build a menu item with a "Coming Soon" badge
  Widget _buildComingSoonMenuItem(
    BuildContext context, {
    required String title,
    required ScreenType screenType,
    IconData? icon,
  }) {
    return ListTile(
      title: Row(
        children: [
          Text(title),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange,
                width: 1,
              ),
            ),
            child: Text(
              'COMING SOON',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      leading: icon != null ? Icon(icon) : null,
      onTap: () {
        Provider.of<MenuAppController>(context, listen: false)
            .changeScreen(screenType);
      },
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
        onTap: () {
          // Clear focus to prevent keyboard issues
          FocusScope.of(context).unfocus();

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ProjectsDashboardScreen(),
            ),
          );
        },
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

      // Development - code editor, image generator, sound generator, music generator, web server
      buildSectionHeader(context, icon: Icons.code, title: "Development"),
      ExpansionTile(
        title: const Text("Image Generation"),
        leading: const Icon(Icons.image),
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
        leading: const Icon(Icons.audiotrack),
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
        leading: const Icon(Icons.music_note),
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
        title: const Text("Code"),
        leading: const Icon(Icons.code),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.codeEditor);
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
}

class DrawerListTile extends StatelessWidget {
  const DrawerListTile({
    Key? key,
    // For selecting those three line once press "Command+D"
    required this.title,
    required this.svgSrc,
    required this.press,
  }) : super(key: key);

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
