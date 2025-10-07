import 'package:arcane_forge/constants.dart';
import 'package:arcane_forge/controllers/menu_app_controller.dart';
import 'package:arcane_forge/screens/projects/projects_dashboard_screen.dart';
import 'package:arcane_forge/screens/game_design_assistant/providers/project_provider.dart';
import 'package:arcane_forge/providers/settings_provider.dart';
import 'package:arcane_forge/providers/auth_provider.dart';
import 'package:arcane_forge/providers/image_generation_provider.dart';
import 'package:arcane_forge/providers/sfx_generation_provider.dart';
import 'package:arcane_forge/services/sfx_generation_services.dart';
import 'package:arcane_forge/providers/music_generation_provider.dart';
import 'package:arcane_forge/services/music_generation_services.dart';
import 'package:arcane_forge/screens/login/login_screen.dart';
import 'package:arcane_forge/services/comfyui_service_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

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

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
          // Dispose AI image generation service when app closes
      AIImageGenerationServiceManager.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Only dispose when app is actually terminating
    if (state == AppLifecycleState.detached) {
              AIImageGenerationServiceManager.instance.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MenuAppController()..changeScreen(ScreenType.projects)),
        ChangeNotifierProvider(create: (context) => ProjectProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ImageGenerationProvider>(
          create: (context) => ImageGenerationProvider(
            context.read<SettingsProvider>(),
          ),
          update: (context, settingsProvider, previous) => previous ?? ImageGenerationProvider(
            settingsProvider,
          ),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, SfxGenerationProvider>(
          create: (context) => SfxGenerationProvider(
            SfxAssetServiceFactory.create(
              useApiService: !context.read<SettingsProvider>().useMockMode,
              settingsProvider: context.read<SettingsProvider>(),
            ),
          ),
          update: (context, settingsProvider, previous) => previous ?? SfxGenerationProvider(
            SfxAssetServiceFactory.create(
              useApiService: !settingsProvider.useMockMode,
              settingsProvider: settingsProvider,
            ),
          ),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, MusicGenerationProvider>(
          create: (context) => MusicGenerationProvider(
            MusicAssetServiceFactory.create(
              useApiService: !context.read<SettingsProvider>().useMockMode,
              settingsProvider: context.read<SettingsProvider>(),
            ),
          ),
          update: (context, settingsProvider, previous) => previous ?? MusicGenerationProvider(
            MusicAssetServiceFactory.create(
              useApiService: !settingsProvider.useMockMode,
              settingsProvider: settingsProvider,
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter Admin Panel',
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.grey.shade100,
            textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
                .apply(bodyColor: Colors.black87),
            canvasColor: Colors.white,
            
            // Light theme for Supabase Auth UI components
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              labelStyle: TextStyle(color: Colors.grey.shade700),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
            
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            dividerTheme: DividerThemeData(
              color: Colors.grey.shade300,
              thickness: 1,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: bgColor,
            textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
                .apply(bodyColor: Colors.white),
            canvasColor: secondaryColor,
            
            // Enhanced theming for Supabase Auth UI components
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
            ),
            
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade600),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            dividerTheme: DividerThemeData(
              color: Colors.grey.shade700,
              thickness: 1,
            ),
          ),
          themeMode: context.watch<SettingsProvider>().isLoading
              ? ThemeMode.system // Use system theme while loading
              : (context.watch<SettingsProvider>().isDarkMode ? ThemeMode.dark : ThemeMode.light),
          home: Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              if (settingsProvider.isLoading) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading application...'),
                      ],
                    ),
                  ),
                );
              }
              return Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  if (auth.isAuthenticated || auth.isVisitor) {
                    return const ProjectsDashboardScreen();
                  }
                  return const LoginScreen();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
