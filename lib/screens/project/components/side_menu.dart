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

  @override
  List<Widget> buildMenuItems(BuildContext context) {
    return [
      // Navigation section
      buildSectionHeader(context, icon: Icons.navigate_before, title: "Navigation"),
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
      buildSectionHeader(context,
          icon: Icons.dashboard, title: "Overview"),
      ListTile(
        title: const Text("Project Home"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.projectHome);
        },
      ),
      ListTile(
        title: const Text("Knowledge Base"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.knowledgeBase);
        },
      ),

      // Idealization
      buildSectionHeader(context,
          icon: Icons.lightbulb, title: "Idealization"),
      ListTile(
        title: const Text("Game Design Assistant"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.gameDesignAssistant);
        },
      ),

      // Development - code editor, image generator, sound generator, music generator, web server
      buildSectionHeader(context, icon: Icons.code, title: "Development"),
      ListTile(
        title: const Text("Code Editor"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.codeEditor);
        },
      ),
      ListTile(
        title: const Text("Image Generator"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.imageGenerator);
        },
      ),
      ListTile(
        title: const Text("Sound Generator"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.soundGenerator);
        },
      ),
      ListTile(
        title: const Text("Music Generator"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.musicGenerator);
        },
      ),
      ListTile(
          title: const Text("Web Server"),
          onTap: () {
            Provider.of<MenuAppController>(context, listen: false)
                .changeScreen(ScreenType.webServer);
          }),

      // Production - Versions, Stats, Feedbacks
      buildSectionHeader(context,
          icon: Icons.production_quantity_limits, title: "Production"),
      ListTile(
        title: const Text("Versions"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.versions);
        },
      ),
      ListTile(
        title: const Text("Stats"),
        onTap: () {
          Provider.of<MenuAppController>(context, listen: false)
              .changeScreen(ScreenType.stats);
        },
      ),
      ListTile(
        title: const Text("Feedbacks"),
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
