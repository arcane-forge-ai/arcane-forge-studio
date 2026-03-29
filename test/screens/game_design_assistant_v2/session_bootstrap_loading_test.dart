import 'dart:async';

import 'package:arcane_forge/providers/auth_provider.dart';
import 'package:arcane_forge/providers/settings_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/message.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/project_context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/session.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/providers/v2_session_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/services/v2_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeV2ApiService extends V2ApiService {
  FakeV2ApiService({
    required super.settingsProvider,
    required super.authProvider,
    required this.bootstrap,
    required this.documentsCompleter,
    required this.contextCompleter,
    required this.pendingCompleter,
    required this.projectContextCompleter,
  });

  final SessionBootstrapResponse bootstrap;
  final Completer<List<Map<String, dynamic>>> documentsCompleter;
  final Completer<GetContextResponse> contextCompleter;
  final Completer<PendingKnowledgeListResponse> pendingCompleter;
  final Completer<List<ProjectContextEntry>> projectContextCompleter;

  int bootstrapCalls = 0;
  int getSessionCalls = 0;
  int getHistoryCalls = 0;
  int getContextCalls = 0;
  int listSessionDocumentsCalls = 0;
  int listPendingKnowledgeCalls = 0;
  int listProjectContextCalls = 0;
  int setActiveDocumentCalls = 0;
  int getProjectFileWithVersionCalls = 0;

  @override
  Future<SessionBootstrapResponse> getSessionBootstrap(String sessionId) async {
    bootstrapCalls += 1;
    return bootstrap;
  }

  @override
  Future<SessionInfo> getSession(String sessionId) async {
    getSessionCalls += 1;
    return bootstrap.session;
  }

  @override
  Future<List<ChatMessage>> getHistory(String sessionId) async {
    getHistoryCalls += 1;
    return bootstrap.history.messages;
  }

  @override
  Future<GetContextResponse> getContext(String sessionId) async {
    getContextCalls += 1;
    return contextCompleter.future;
  }

  @override
  Future<List<Map<String, dynamic>>> listSessionDocuments(
      String sessionId) async {
    listSessionDocumentsCalls += 1;
    return documentsCompleter.future;
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String projectId) async {
    throw StateError(
        'project-level document fallback should not run in this test');
  }

  @override
  Future<PendingKnowledgeListResponse> listPendingKnowledge(
      String projectId) async {
    listPendingKnowledgeCalls += 1;
    return pendingCompleter.future;
  }

  @override
  Future<List<ProjectContextEntry>> listProjectContext({
    required String projectId,
    String? cursor,
    int limit = 50,
    String? type,
    String? query,
  }) async {
    final _ = limit;
    listProjectContextCalls += 1;
    return projectContextCompleter.future;
  }

  @override
  Future<Map<String, dynamic>> setActiveDocument({
    required String sessionId,
    String? filePath,
  }) async {
    setActiveDocumentCalls += 1;
    return {'success': true, 'active_document_path': filePath};
  }

  @override
  Future<Map<String, dynamic>> getProjectFileWithVersion(
    String projectId,
    String filePath,
  ) async {
    getProjectFileWithVersionCalls += 1;
    return {'content': '', 'version_number': null};
  }
}

Future<void> _pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  test('selectSession uses bootstrap as the only blocking request', () async {
    final settingsProvider = SettingsProvider();
    final authProvider = AuthProvider();
    final documentsCompleter = Completer<List<Map<String, dynamic>>>();
    final contextCompleter = Completer<GetContextResponse>();
    final pendingCompleter = Completer<PendingKnowledgeListResponse>();
    final projectContextCompleter = Completer<List<ProjectContextEntry>>();

    final apiService = FakeV2ApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      bootstrap: SessionBootstrapResponse(
        session: SessionInfo(
          sessionId: 'sess-1',
          userId: 'test-user',
          projectId: '1',
          projectName: 'Project',
          title: 'Bootstrap Session',
          createdAt: DateTime.parse('2026-03-20T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-20T00:01:00Z'),
        ),
        history: SessionHistoryPayload(
          sessionId: 'sess-1',
          total: 1,
          offset: 0,
          limit: 50,
          messages: [
            ChatMessage(
              role: 'assistant',
              content: 'hello from bootstrap',
              timestamp: DateTime.parse('2026-03-20T00:00:00Z'),
            ),
          ],
        ),
      ),
      documentsCompleter: documentsCompleter,
      contextCompleter: contextCompleter,
      pendingCompleter: pendingCompleter,
      projectContextCompleter: projectContextCompleter,
    );

    final provider = V2SessionProvider(
      projectId: '1',
      projectName: 'Project',
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      apiService: apiService,
    );

    await provider
        .selectSession('sess-1')
        .timeout(const Duration(milliseconds: 100));

    expect(provider.isLoading, isFalse);
    expect(provider.currentSession?.sessionId, 'sess-1');
    expect(provider.messages.map((m) => m.content), ['hello from bootstrap']);
    expect(apiService.bootstrapCalls, 1);
    expect(apiService.getSessionCalls, 0);
    expect(apiService.getHistoryCalls, 0);

    documentsCompleter.complete([
      {
        'slug': 'combat_md',
        'title': 'Combat',
        'file_path': 'combat.md',
        'created_session_id': 'sess-1',
        'current_version_number': 1,
      }
    ]);
    contextCompleter.complete(GetContextResponse());
    pendingCompleter.complete(
      PendingKnowledgeListResponse(
        items: const [],
        batchVersion: 0,
        batchEtag: '',
        readMode: 'dual',
        migrationState: 'started',
        migrationCoverage: const {},
        writeGate: const {'status': 'open'},
      ),
    );
    projectContextCompleter.complete([]);

    await _pumpMicrotasks();

    expect(apiService.listSessionDocumentsCalls, 1);
    expect(apiService.getContextCalls, 1);
    expect(apiService.listPendingKnowledgeCalls, 1);
    expect(apiService.listProjectContextCalls, 1);
    expect(provider.documents, isNotEmpty);

    provider.dispose();
    authProvider.dispose();
  });

  test(
      'selectSession does not fallback to project documents when session docs are empty',
      () async {
    final settingsProvider = SettingsProvider();
    final authProvider = AuthProvider();
    final documentsCompleter = Completer<List<Map<String, dynamic>>>();
    final contextCompleter = Completer<GetContextResponse>();
    final pendingCompleter = Completer<PendingKnowledgeListResponse>();
    final projectContextCompleter = Completer<List<ProjectContextEntry>>();

    final apiService = FakeV2ApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      bootstrap: SessionBootstrapResponse(
        session: SessionInfo(
          sessionId: 'sess-empty',
          userId: 'test-user',
          projectId: '1',
          projectName: 'Project',
          title: 'Bootstrap Session',
          createdAt: DateTime.parse('2026-03-20T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-20T00:01:00Z'),
          activeDocumentPath: 'other-session.md',
        ),
        history: SessionHistoryPayload(
          sessionId: 'sess-empty',
          total: 0,
          offset: 0,
          limit: 50,
          messages: const [],
        ),
      ),
      documentsCompleter: documentsCompleter,
      contextCompleter: contextCompleter,
      pendingCompleter: pendingCompleter,
      projectContextCompleter: projectContextCompleter,
    );

    final provider = V2SessionProvider(
      projectId: '1',
      projectName: 'Project',
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      apiService: apiService,
    );

    await provider
        .selectSession('sess-empty')
        .timeout(const Duration(milliseconds: 100));

    documentsCompleter.complete(const []);
    contextCompleter.complete(GetContextResponse());
    pendingCompleter.complete(
      PendingKnowledgeListResponse(
        items: const [],
        batchVersion: 0,
        batchEtag: '',
        readMode: 'dual',
        migrationState: 'started',
        migrationCoverage: const {},
        writeGate: const {'status': 'open'},
      ),
    );
    projectContextCompleter.complete([]);

    await _pumpMicrotasks();

    expect(apiService.listSessionDocumentsCalls, 1);
    expect(provider.documents, isEmpty);
    expect(provider.selectedDocPath, isNull);

    provider.dispose();
    authProvider.dispose();
  });
}
