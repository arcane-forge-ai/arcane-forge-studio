import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/login/login_screen.dart';
import '../screens/projects/projects_dashboard_screen.dart';

/// Wrapper widget that handles authentication state and routing
/// to the appropriate screen (login or projects dashboard)
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
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
        return Consumer2<AuthProvider, SubscriptionProvider>(
          builder: (context, auth, subscription, child) {
            if (auth.isAuthenticated) {
              // Initialize subscription data ONCE when user is authenticated
              if (!subscription.isInitialized && !subscription.isLoading) {
                // Initialize subscription in background (only once)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!subscription.isInitialized && !subscription.isLoading) {
                    subscription.initialize();
                  }
                });
              }
              return const ProjectsDashboardScreen();
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}
