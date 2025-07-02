import 'package:arcane_forge/constants.dart';
import 'package:arcane_forge/controllers/menu_app_controller.dart';
import 'package:arcane_forge/screens/projects/projects_dashboard_screen.dart';
import 'package:arcane_forge/screens/game_design_assistant/providers/project_provider.dart';
import 'package:arcane_forge/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // If .env file doesn't exist, continue with defaults
    debugPrint('Could not load .env file: $e');
  }

  // Handle Flutter keyboard assertion errors on Windows
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filter out the known Windows keyboard assertion error
    if (details.exception.toString().contains('KeyDownEvent is dispatched') ||
        details.exception.toString().contains('_pressedKeys.containsKey')) {
      // Log the error but don't crash the app
      debugPrint('Filtered keyboard assertion error: ${details.exception}');
      return;
    }
    // For other errors, use the default handler
    FlutterError.presentError(details);
  };

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MenuAppController()..changeScreen(ScreenType.projects)),
        ChangeNotifierProvider(create: (context) => ProjectProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Admin Panel',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: bgColor,
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
              .apply(bodyColor: Colors.white),
          canvasColor: secondaryColor,
        ),
        home: const ProjectsDashboardScreen(),
      ),
    );
  }
}
