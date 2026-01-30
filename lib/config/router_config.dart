import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_wrapper.dart';
import '../screens/knowledge_base_qa/qa_access_wrapper.dart';

/// Router configuration for go_router
/// 
/// Routes inside ShellRoute require authentication (via AppWrapper)
/// Top-level routes (like QA) are public and don't require login
final router = GoRouter(
  debugLogDiagnostics: true,
  routes: [
    // Public routes (no authentication required)
    // QA route with access control wrapper
    GoRoute(
      path: '/projects/:projectId/qa',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return MaterialPage(
          key: state.pageKey,
          child: QAAccessWrapper(projectId: projectId),
        );
      },
    ),
    
    // Authenticated routes (wrapped in AppWrapper shell)
    ShellRoute(
      builder: (context, state, child) => const AppWrapper(),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SizedBox.shrink(), // AppWrapper handles the actual routing
          ),
        ),
      ],
    ),
  ],
);
