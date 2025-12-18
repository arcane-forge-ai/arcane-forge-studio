import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

import '../../providers/auth_provider.dart';
import '../../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      // When authenticated, don't display login screen
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Card(
            color: secondaryColor,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to Arcane Forge',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Supabase Auth UI Email Auth
                  SupaEmailAuth(
                    redirectTo: 'arcaneforge://auth-callback', // Windows deep linking
                    onSignInComplete: (response) {
                      // Navigation is handled by the Consumer in main.dart
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Welcome back!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    onSignUpComplete: (response) {
                      // Navigation is handled by the Consumer in main.dart
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Account created successfully! Please check your email to verify your account.'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                    onError: (error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Authentication failed: ${error.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Social Auth (Google only)
                  // SupaSocialsAuth(
                  //   socialProviders: const [OAuthProvider.google],
                  //   redirectUrl: 'arcaneforge://auth-callback', // Windows deep linking
                  //   onSuccess: (session) {
                  //     // Navigation is handled by the Consumer in main.dart
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       SnackBar(
                  //         content: Text('Welcome, ${session.user.email ?? 'User'}!'),
                  //         backgroundColor: Colors.green,
                  //       ),
                  //     );
                  //   },
                  //   onError: (error) {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       SnackBar(
                  //         content: Text('Authentication failed: ${error.toString()}'),
                  //         backgroundColor: Colors.red,
                  //         duration: const Duration(seconds: 4),
                  //       ),
                  //     );
                  //   },
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
