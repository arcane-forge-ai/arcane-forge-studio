import 'dart:async';

import 'package:arcane_forge/providers/auth_provider.dart';
import 'package:arcane_forge/providers/settings_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/project_context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/session.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/providers/v2_session_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/services/v2_api_service.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/widgets/v2_chat_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthProvider extends AuthProvider {
  @override
  String get userId => 'test-user';
}

class _DelayedBootstrapApiService extends V2ApiService {
  _DelayedBootstrapApiService({
    required super.settingsProvider,
    required super.authProvider,
    required this.bootstrapCompleter,
  });

  final Completer<SessionBootstrapResponse> bootstrapCompleter;

  @override
  Future<SessionBootstrapResponse> getSessionBootstrap(String sessionId) {
    return bootstrapCompleter.future;
  }

  @override
  Future<GetContextResponse> getContext(String sessionId) async {
    return GetContextResponse();
  }

  @override
  Future<List<Map<String, dynamic>>> listSessionDocuments(
    String sessionId,
  ) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String projectId) async {
    return const [];
  }

  @override
  Future<PendingKnowledgeListResponse> listPendingKnowledge(
    String projectId,
  ) async {
    return PendingKnowledgeListResponse(
      items: const [],
      batchVersion: 0,
      batchEtag: '',
      readMode: 'dual',
      migrationState: 'started',
      migrationCoverage: const {},
      writeGate: const {'status': 'open'},
    );
  }

  @override
  Future<List<ProjectContextEntry>> listProjectContext({
    required String projectId,
    String? cursor,
    int limit = 50,
    String? type,
    String? query,
  }) async {
    return const [];
  }
}

Future<void> _initAuth() async {
  SharedPreferences.setMockInitialValues({});
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _initAuth();
  });

  testWidgets(
    'shows only one loading prompt while switching chat sessions',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final authProvider = _FakeAuthProvider();
      final bootstrapCompleter = Completer<SessionBootstrapResponse>();
      final provider = V2SessionProvider(
        projectId: '1',
        projectName: 'Project',
        settingsProvider: settingsProvider,
        authProvider: authProvider,
        apiService: _DelayedBootstrapApiService(
          settingsProvider: settingsProvider,
          authProvider: authProvider,
          bootstrapCompleter: bootstrapCompleter,
        ),
      );

      unawaited(provider.selectSession('sess-1'));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<V2SessionProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: V2ChatPanel(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading chat session...'), findsOneWidget);
      expect(
        find.text('Select a chat from the sidebar or start a new chat.'),
        findsNothing,
      );

      bootstrapCompleter.complete(
        SessionBootstrapResponse(
          session: SessionInfo(
            sessionId: 'sess-1',
            userId: 'test-user',
            projectId: '1',
            projectName: 'Project',
            title: 'Session',
            createdAt: DateTime.parse('2026-03-20T00:00:00Z'),
            updatedAt: DateTime.parse('2026-03-20T00:00:00Z'),
          ),
          history: SessionHistoryPayload(
            sessionId: 'sess-1',
            total: 0,
            offset: 0,
            limit: 50,
            messages: const [],
          ),
        ),
      );

      await tester.pump();

      provider.dispose();
      authProvider.dispose();
    },
  );
}
