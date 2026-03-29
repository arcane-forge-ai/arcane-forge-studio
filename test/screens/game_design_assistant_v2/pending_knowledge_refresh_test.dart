import 'dart:async';

import 'package:arcane_forge/providers/auth_provider.dart';
import 'package:arcane_forge/providers/settings_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/message.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/project_context.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/selection.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/models/session.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/providers/v2_session_provider.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/services/v2_api_service.dart';
import 'package:arcane_forge/screens/game_design_assistant_v2/services/v2_sse_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeApiService extends V2ApiService {
  _FakeApiService({
    required super.settingsProvider,
    required super.authProvider,
    required this.session,
    required this.pendingResponses,
    this.sessionResponses,
    this.sendMessageResponse,
  });

  final SessionInfo session;
  final List<PendingKnowledgeListResponse> pendingResponses;
  final List<List<SessionInfo>>? sessionResponses;
  final ChatMessage? sendMessageResponse;

  int listPendingKnowledgeCalls = 0;
  int listSessionsCalls = 0;

  List<SessionInfo> _sessionResponseAt(int index) {
    final responses = sessionResponses;
    if (responses == null || responses.isEmpty) {
      return [session];
    }
    final safeIndex = index < responses.length ? index : responses.length - 1;
    return responses[safeIndex];
  }

  PendingKnowledgeListResponse _pendingResponseAt(int index) {
    if (pendingResponses.isEmpty) {
      throw StateError('pendingResponses must not be empty');
    }
    final safeIndex =
        index < pendingResponses.length ? index : pendingResponses.length - 1;
    return pendingResponses[safeIndex];
  }

  @override
  Future<SessionBootstrapResponse> getSessionBootstrap(String sessionId) async {
    return SessionBootstrapResponse(
      session: session,
      history: SessionHistoryPayload(
        sessionId: sessionId,
        total: 0,
        offset: 0,
        limit: 50,
        messages: const [],
      ),
    );
  }

  @override
  Future<SessionInfo> getSession(String sessionId) async => session;

  @override
  Future<List<SessionInfo>> listSessions({required String projectId}) async {
    final response = _sessionResponseAt(listSessionsCalls);
    listSessionsCalls += 1;
    return response;
  }

  @override
  Future<GetContextResponse> getContext(String sessionId) async {
    return GetContextResponse();
  }

  @override
  Future<List<Map<String, dynamic>>> listSessionDocuments(
      String sessionId) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String projectId) async {
    return const [];
  }

  @override
  Future<PendingKnowledgeListResponse> listPendingKnowledge(
      String projectId) async {
    final response = _pendingResponseAt(listPendingKnowledgeCalls);
    listPendingKnowledgeCalls += 1;
    return response;
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

  @override
  Future<ChatMessage> sendMessage({
    required String sessionId,
    String? content,
    String? documentPath,
    SelectionAnswer? selectionAnswer,
  }) async {
    final response = sendMessageResponse;
    if (response == null) {
      throw StateError('sendMessageResponse was not configured');
    }
    return response;
  }
}

class _FakeSseService extends V2SSEService {
  _FakeSseService({
    required super.settingsProvider,
    required super.authProvider,
    required this.events,
  });

  final List<SSEEvent> events;

  @override
  Stream<SSEEvent> streamMessage({
    required String sessionId,
    required String content,
    String? documentPath,
    bool Function()? shouldCancel,
  }) async* {
    for (final event in events) {
      if (shouldCancel?.call() ?? false) {
        break;
      }
      yield event;
    }
  }
}

class _FakeAuthProvider extends AuthProvider {
  @override
  String get userId => 'test-user';
}

PendingKnowledgeListResponse _pendingResponse(
    List<PendingKnowledgeItem> items) {
  return PendingKnowledgeListResponse(
    items: items,
    batchVersion: items.isEmpty ? 0 : 1,
    batchEtag: items.isEmpty ? '' : 'etag-1',
    readMode: 'dual',
    migrationState: 'started',
    migrationCoverage: const {},
    writeGate: const {'status': 'open'},
  );
}

PendingKnowledgeItem _pendingItem() {
  return PendingKnowledgeItem(
    id: 'pending-1',
    projectId: 1,
    sessionId: 'sess-1',
    turnNumber: 1,
    type: 'decision',
    content: '新增待确认知识',
    status: 'pending',
    isUserEdited: false,
    source: 'hook',
    createdAt: '2026-03-26T00:00:00Z',
    updatedAt: '2026-03-26T00:00:01Z',
    version: 1,
    etag: 'etag-item-1',
  );
}

SessionInfo _session() {
  return SessionInfo(
    sessionId: 'sess-1',
    userId: 'test-user',
    projectId: '1',
    projectName: 'Project',
    title: 'Test Session',
    createdAt: DateTime.parse('2026-03-26T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-26T00:00:00Z'),
  );
}

SessionInfo _sessionWithTitle(String? title) {
  return SessionInfo(
    sessionId: 'sess-1',
    userId: 'test-user',
    projectId: '1',
    projectName: 'Project',
    title: title,
    createdAt: DateTime.parse('2026-03-26T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-26T00:00:00Z'),
  );
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

  test(
      'submitSelection polls pending knowledge when write response may update it',
      () async {
    final settingsProvider = SettingsProvider();
    final authProvider = _FakeAuthProvider();
    final apiService = _FakeApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      session: _session(),
      pendingResponses: [
        _pendingResponse(const []),
        _pendingResponse(const []),
        _pendingResponse([_pendingItem()]),
      ],
      sendMessageResponse: ChatMessage(
        role: 'assistant',
        content: '写入完成',
        timestamp: DateTime.parse('2026-03-26T00:00:02Z'),
        pendingKnowledgeMayUpdate: true,
      ),
    );

    final provider = V2SessionProvider(
      projectId: '1',
      projectName: 'Project',
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      apiService: apiService,
    );

    await provider.selectSession('sess-1');

    final result = await provider.submitSelection(
      selection: SelectionInfo(
        questionId: 'q-1',
        title: '开始写入？',
        options: [
          SelectionOption(id: 'execute_plan', label: '开始写入'),
        ],
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
      selectedIds: const ['execute_plan'],
    );

    expect(result.status, 'success');
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    expect(apiService.listPendingKnowledgeCalls, greaterThanOrEqualTo(3));
    expect(provider.pendingKnowledgeItems, isNotEmpty);

    provider.dispose();
    authProvider.dispose();
  });

  test(
      'stream done polls pending knowledge when SSE marks a delayed knowledge update',
      () async {
    final settingsProvider = SettingsProvider();
    final authProvider = _FakeAuthProvider();
    final apiService = _FakeApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      session: _session(),
      pendingResponses: [
        _pendingResponse(const []),
        _pendingResponse(const []),
        _pendingResponse([_pendingItem()]),
      ],
    );
    final sseService = _FakeSseService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      events: [
        SSEEvent(type: 'content', content: '写入中', contentMode: 'replace'),
        SSEEvent(
          type: 'done',
          isFinal: true,
          pendingKnowledgeMayUpdate: true,
        ),
      ],
    );

    final provider = V2SessionProvider(
      projectId: '1',
      projectName: 'Project',
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      apiService: apiService,
      sseService: sseService,
    );

    await provider.selectSession('sess-1');
    await provider.sendMessage('请写入这一章');
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    expect(apiService.listPendingKnowledgeCalls, greaterThanOrEqualTo(3));
    expect(provider.pendingKnowledgeItems, isNotEmpty);

    provider.dispose();
    authProvider.dispose();
  });

  test('stream done polls sessions until fallback title is replaced', () async {
    final settingsProvider = SettingsProvider();
    final authProvider = _FakeAuthProvider();
    final untitledSession = _sessionWithTitle(null);
    final titledSession = _sessionWithTitle('抓鬼卡牌消除游戏设计');
    final apiService = _FakeApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      session: untitledSession,
      sessionResponses: [
        [untitledSession],
        [untitledSession],
        [titledSession],
      ],
      pendingResponses: [
        _pendingResponse(const []),
      ],
    );
    final sseService = _FakeSseService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      events: [
        SSEEvent(type: 'content', content: '已整理计划', contentMode: 'replace'),
        SSEEvent(type: 'done', isFinal: true),
      ],
    );

    final provider = V2SessionProvider(
      projectId: '1',
      projectName: 'Project',
      settingsProvider: settingsProvider,
      authProvider: authProvider,
      apiService: apiService,
      sseService: sseService,
    );

    await provider.selectSession('sess-1');
    await provider.sendMessage('请先整理写入计划');
    await Future<void>.delayed(const Duration(milliseconds: 1700));

    expect(apiService.listSessionsCalls, greaterThanOrEqualTo(3));
    expect(provider.currentSession?.title, '抓鬼卡牌消除游戏设计');
    expect(provider.sessions.first.title, '抓鬼卡牌消除游戏设计');

    provider.dispose();
    authProvider.dispose();
  });
}
