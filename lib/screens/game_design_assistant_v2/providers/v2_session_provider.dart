import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/confirmation.dart';
import '../models/context.dart';
import '../models/message.dart';
import '../models/project_context.dart';
import '../models/selection.dart';
import '../models/session.dart';
import '../models/write_summary.dart';
import '../services/v2_api_service.dart';
import '../services/v2_sse_service.dart';

class V2SessionProvider with ChangeNotifier {
  static const int _knowledgeExtractionPromptTurnGap = 1;

  final String projectId;
  final String projectName;
  final V2ApiService _apiService;
  final V2SSEService _sseService;
  final AuthProvider _authProvider;

  V2SessionProvider({
    required this.projectId,
    required this.projectName,
    required SettingsProvider settingsProvider,
    required AuthProvider authProvider,
  })  : _apiService = V2ApiService(
          settingsProvider: settingsProvider,
          authProvider: authProvider,
        ),
        _sseService = V2SSEService(
          settingsProvider: settingsProvider,
          authProvider: authProvider,
        ),
        _authProvider = authProvider;

  List<SessionInfo> _sessions = [];
  SessionInfo? _currentSession;
  List<ChatMessage> _messages = [];
  GetContextResponse? _contextData;
  List<Map<String, dynamic>> _documents = [];
  String? _selectedDocPath;
  String? _selectedDocContent;
  int? _selectedDocVersionNumber;
  String? _gddContent;
  int? _gddVersionNumber;
  Confirmation? _pendingConfirmation;
  SelectionInfo? _pendingSelection;

  bool _isLoading = false;
  bool _isSessionsLoading = false;
  bool _isSending = false;
  bool _isConfirming = false;
  bool _hasDraftConversation = false;

  String _streamingContent = '';
  String? _thinkingContent;
  DocumentWriteSummary? _pendingWriteSummary;

  String? _sessionsError;
  String? _chatError;

  // -- Project Context / Pending Knowledge state --
  List<PendingKnowledgeItem> _pendingKnowledgeItems = [];
  List<ProjectContextEntry> _projectContextEntries = [];
  bool _isPendingKnowledgeLoading = false;
  bool _isPendingKnowledgeSubmitting = false;
  bool _isProjectContextLoading = false;
  String? _pendingKnowledgeError;
  String? _projectContextError;
  bool _shouldPromptSessionKnowledgeExtraction = false;
  String? _promptEligibleSessionId;
  Map<String, String> _pendingItemSessionMap = {};

  List<SessionInfo> get sessions => _sessions;
  SessionInfo? get currentSession => _currentSession;
  List<ChatMessage> get messages => _messages;
  GetContextResponse? get contextData => _contextData;
  List<Map<String, dynamic>> get documents => _documents;
  String? get selectedDocPath => _selectedDocPath;
  String? get selectedDocContent => _selectedDocContent;
  int? get selectedDocVersionNumber => _selectedDocVersionNumber;
  String? get gddContent => _gddContent;
  int? get gddVersionNumber => _gddVersionNumber;
  Confirmation? get pendingConfirmation => _pendingConfirmation;
  SelectionInfo? get pendingSelection => _pendingSelection;
  bool get isLoading => _isLoading;
  bool get isSessionsLoading => _isSessionsLoading;
  bool get isSending => _isSending;
  bool get isConfirming => _isConfirming;
  bool get hasDraftConversation => _hasDraftConversation;
  String get streamingContent => _streamingContent;
  String? get thinkingContent => _thinkingContent;
  String? get sessionsError => _sessionsError;
  String? get chatError => _chatError;

  // -- Project Context / Pending Knowledge getters --
  List<PendingKnowledgeItem> get pendingKnowledgeItems =>
      _pendingKnowledgeItems;
  List<ProjectContextEntry> get projectContextEntries => _projectContextEntries;
  bool get isPendingKnowledgeLoading => _isPendingKnowledgeLoading;
  bool get isPendingKnowledgeSubmitting => _isPendingKnowledgeSubmitting;
  bool get isProjectContextLoading => _isProjectContextLoading;
  String? get pendingKnowledgeError => _pendingKnowledgeError;
  String? get projectContextError => _projectContextError;
  bool get hasPendingKnowledge => _pendingKnowledgeItems.isNotEmpty;
  bool get shouldPromptSessionKnowledgeExtraction =>
      _shouldPromptSessionKnowledgeExtraction;

  bool get canUseV2 => _authProvider.userId.trim().isNotEmpty;
  bool get hasSelectedDocument =>
      _selectedDocPath != null && _selectedDocPath!.trim().isNotEmpty;

  String? _pendingKnowledgeScopeSessionId() {
    final current = _currentSession?.sessionId;
    if (current != null && current.trim().isNotEmpty) {
      return current;
    }
    for (final session in _sessions) {
      final candidate = session.sessionId.trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  List<String> _pendingKnowledgeScopeSessionIds() {
    final seen = <String>{};
    final ids = <String>[];

    final current = _currentSession?.sessionId.trim();
    if (current != null && current.isNotEmpty && seen.add(current)) {
      ids.add(current);
    }

    for (final session in _sessions) {
      final id = session.sessionId.trim();
      if (id.isNotEmpty && seen.add(id)) {
        ids.add(id);
      }
    }

    return ids;
  }

  String? _sessionIdForPendingItem(String itemId) {
    var sessionId = _pendingItemSessionMap[itemId];
    sessionId ??= _pendingKnowledgeItems
        .where((i) => i.id == itemId)
        .map((i) => i.sessionId)
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (sessionId.trim().isEmpty) {
      sessionId = null;
    }
    sessionId ??= _pendingKnowledgeScopeSessionId();
    return sessionId;
  }

  Future<void> loadSessions() async {
    _isSessionsLoading = true;
    _sessionsError = null;
    notifyListeners();

    try {
      final loaded = await _apiService.listSessions(projectId: projectId);
      _sessions = loaded;
      if (_currentSession != null) {
        final match = loaded
            .where((s) => s.sessionId == _currentSession!.sessionId)
            .toList();
        if (match.isNotEmpty) {
          _currentSession = match.first;
        }
      }
      if (_currentSession == null) {
        await loadPendingKnowledge(notify: false);
      }
    } catch (e) {
      _sessionsError = e.toString();
      if (kDebugMode) {
        print('Error loading v2 sessions: $e');
      }
    } finally {
      _isSessionsLoading = false;
      notifyListeners();
    }
  }

  void startNewChat() {
    _currentSession = null;
    _messages = [];
    _contextData = null;
    _clearSelectedDocument();
    _pendingConfirmation = null;
    _pendingSelection = null;
    _streamingContent = '';
    _thinkingContent = null;
    _pendingWriteSummary = null;
    _chatError = null;
    _hasDraftConversation = true;
    _shouldPromptSessionKnowledgeExtraction = false;
    _promptEligibleSessionId = null;
    // Keep document inventory loaded for optional selection in draft mode.
    unawaited(loadDocuments());
    // Pending queue is project-scoped; keep it visible in draft/new-chat mode.
    unawaited(loadPendingKnowledge());
    // Load project context for new chat
    unawaited(loadProjectContext());
    notifyListeners();
  }

  Future<void> selectSession(String sessionId) async {
    _isLoading = true;
    _chatError = null;
    _promptEligibleSessionId = null;
    notifyListeners();

    try {
      _currentSession = await _apiService.getSession(sessionId);
      _hasDraftConversation = false;
      await _loadSessionData(sessionId, reloadHistory: true);
    } catch (e) {
      _chatError = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSessionData(String sessionId,
      {bool reloadHistory = true}) async {
    _promptEligibleSessionId = null;
    _clearSelectedDocument();
    _documents = [];
    await loadDocuments(notify: false);
    _contextData = await _apiService.getContext(sessionId);

    if (reloadHistory) {
      _messages = await _apiService.getHistory(sessionId);
    }

    _currentSession = await _apiService.getSession(sessionId);
    await _syncDocumentSelectionWithSession();

    // Load session-scoped pending knowledge when switching sessions.
    await loadPendingKnowledge(notify: false);

    // Load project context when switching sessions
    await loadProjectContext();

    _pendingConfirmation = null;
    _pendingSelection = null;
    _streamingContent = '';
    _thinkingContent = null;
    _refreshExtractionPromptFlag();
  }

  Future<void> _createAndSelectSession() async {
    final req = CreateSessionRequest(
      projectId: projectId,
    );
    final created = await _apiService.createSession(req);
    await loadSessions();
    await selectSession(created.sessionId);
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (!canUseV2) {
      _chatError = 'You must be signed in to use Game Design Assistant v2.';
      notifyListeners();
      return;
    }

    if (_currentSession == null) {
      final draftSelectedPath = _selectedDocPath;
      _isLoading = true;
      _chatError = null;
      notifyListeners();
      try {
        await _createAndSelectSession();
        if (draftSelectedPath != null && draftSelectedPath.trim().isNotEmpty) {
          await selectDocument(draftSelectedPath);
        }
      } catch (e) {
        _chatError = e.toString();
        _isLoading = false;
        notifyListeners();
        return;
      }
      _isLoading = false;
      notifyListeners();
    }

    final session = _currentSession;
    if (session == null) return;
    _promptEligibleSessionId = session.sessionId;

    final userMsg = ChatMessage(
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );
    _messages = [..._messages, userMsg];
    _hasDraftConversation = false;
    _isSending = true;
    _chatError = null;
    _streamingContent = '';
    _thinkingContent = null;
    _pendingWriteSummary = null;
    _pendingConfirmation = null;
    _pendingSelection = null;
    notifyListeners();

    try {
      await for (final event in _sseService.streamMessage(
        sessionId: session.sessionId,
        content: trimmed,
        documentPath: _selectedDocPath,
      )) {
        switch (event.type) {
          case 'thinking':
            _thinkingContent = (_thinkingContent ?? '') + (event.content ?? '');
            notifyListeners();
            break;
          case 'content':
            _streamingContent += (event.content ?? '');
            notifyListeners();
            break;
          case 'done':
            // Canvas mode guard: only suppress file_merge_section confirmation
            // when canvas_document is present (backend canvas mode is active).
            // Without canvas_document, show all confirmations normally.
            if (event.confirmation != null) {
              final isCanvasMode = event.canvasDocument != null;
              if (isCanvasMode &&
                  _isFileMergeConfirmation(event.confirmation!)) {
                // Canvas mode: suppress file_merge_section confirmation card
              } else {
                _pendingConfirmation = event.confirmation;
              }
            } else {
              _pendingConfirmation = null;
            }
            _pendingSelection = event.selection;
            _pendingWriteSummary = event.writeSummary;
            notifyListeners();
            break;
          case 'error':
            _chatError = event.content ?? 'Unknown streaming error';
            notifyListeners();
            break;
          case 'meta':
          case 'tool_call':
            break;
          default:
            break;
        }
      }
    } catch (e) {
      _chatError = 'Failed to get response: $e';
      if (kDebugMode) {
        print('Error sending v2 message: $e');
      }
    } finally {
      final shouldAppendAssistantMessage = _streamingContent.isNotEmpty ||
          (_thinkingContent?.isNotEmpty ?? false) ||
          _pendingConfirmation != null ||
          _pendingSelection != null ||
          _pendingWriteSummary != null;
      if (shouldAppendAssistantMessage) {
        _messages = [
          ..._messages,
          ChatMessage(
            role: 'assistant',
            content: _streamingContent,
            timestamp: DateTime.now(),
            thinking: _thinkingContent,
            confirmation: _pendingConfirmation,
            selection: _pendingSelection,
            writeSummary: _pendingWriteSummary,
          ),
        ];
      }

      _isSending = false;
      _streamingContent = '';
      _thinkingContent = null;
      _pendingWriteSummary = null;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));
      await refreshData();
      await loadSessions();
    }
  }

  Future<void> confirmTransaction({
    String? transactionId,
    String? argsChecksum,
    int retryCount = 0,
  }) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _isConfirming = true;
    _pendingConfirmation = null;
    _chatError = null;
    notifyListeners();

    try {
      final result = await _apiService.confirmTransaction(
        sessionId: sessionId,
        action: 'confirm',
        transactionId: transactionId,
        argsChecksum: argsChecksum,
      );

      if (result['status'] == 'awaiting_confirmation' &&
          result['confirmation'] != null) {
        // New pending step: append a message with confirmation card
        final conf = Confirmation.fromJson(
          Map<String, dynamic>.from(result['confirmation'] as Map),
        );
        _pendingConfirmation = conf;
        _messages = [
          ..._messages,
          ChatMessage(
            role: 'assistant',
            content: '',
            timestamp: DateTime.now(),
            confirmation: conf,
          ),
        ];
        notifyListeners();
        // Refresh context/doc but don't reload history (avoid overwriting local confirmation message)
        await Future.delayed(const Duration(milliseconds: 300));
        await refreshData(reloadHistory: false);
        await loadSessions();
      } else {
        // Normal completion or failure: reload history (TurnManager wrote the completion message)
        await Future.delayed(const Duration(milliseconds: 300));
        await refreshData(reloadHistory: true);
        await loadSessions();
      }
    } on DioException catch (e) {
      // Handle 409 conflict with automatic retry
      if (e.response?.statusCode == 409 && retryCount == 0) {
        // Extract latest_confirmation from response
        final responseData = e.response?.data;
        if (responseData is Map &&
            responseData['latest_confirmation'] != null) {
          final latestConfirmation = Confirmation.fromJson(
            Map<String, dynamic>.from(
                responseData['latest_confirmation'] as Map),
          );

          // Update pending confirmation
          _pendingConfirmation = latestConfirmation;
          notifyListeners();

          // Automatic retry after 500ms
          await Future.delayed(const Duration(milliseconds: 500));
          return confirmTransaction(
            transactionId: latestConfirmation.transactionId,
            argsChecksum: latestConfirmation.argsChecksum,
            retryCount: 1,
          );
        } else {
          // 409 without latest_confirmation
          _chatError =
              'Operation content has changed. Review the latest content and confirm again.';
        }
      } else if (e.response?.statusCode == 409 && retryCount > 0) {
        // Retry failed: show friendly error
        _chatError =
            'Operation content has changed. Review the latest content and confirm again.';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        _chatError = 'Network timeout. Check your connection and try again.';
      } else if (e.response?.statusCode == 500) {
        _chatError = 'Server error. Please try again later.';
      } else if (e.response?.statusCode == 401) {
        _chatError = 'Login expired. Please sign in again.';
        // TODO: Handle auth expiration
      } else {
        _chatError = 'Action failed. Please try again.';
      }

      if (_chatError != null) {
        _messages = [
          ..._messages,
          ChatMessage(
            role: 'assistant',
            content: _chatError!,
            timestamp: DateTime.now(),
          ),
        ];
      }
    } on ConfirmFlowDisabledException {
      _pendingConfirmation = null;
      _chatError = null;
      // Silently dismiss — confirmation card is stale, no user-facing error needed.
    } catch (e) {
      _chatError = 'Error confirming transaction: $e';
      _messages = [
        ..._messages,
        ChatMessage(
          role: 'assistant',
          content: 'Error confirming transaction: $e',
          timestamp: DateTime.now(),
        ),
      ];
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  Future<void> cancelTransaction({String? transactionId}) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _isConfirming = true;
    _pendingConfirmation = null;
    _chatError = null;
    notifyListeners();

    try {
      await _apiService.confirmTransaction(
        sessionId: sessionId,
        action: 'cancel',
        transactionId: transactionId,
      );

      // Add friendly feedback message
      _messages = [
        ..._messages,
        ChatMessage(
          role: 'assistant',
          content: 'Operation cancelled. You can continue the conversation.',
          timestamp: DateTime.now(),
        ),
      ];

      await Future.delayed(const Duration(milliseconds: 300));
      await refreshData(reloadHistory: true);
      await loadSessions();
    } on ConfirmFlowDisabledException {
      _pendingConfirmation = null;
      _chatError = null;
    } catch (e) {
      _chatError = 'Error cancelling transaction: $e';
      _messages = [
        ..._messages,
        ChatMessage(
          role: 'assistant',
          content: 'Error cancelling transaction: $e',
          timestamp: DateTime.now(),
        ),
      ];
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  Future<void> refreshData({bool reloadHistory = false}) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    try {
      _contextData = await _apiService.getContext(sessionId);
      _currentSession = await _apiService.getSession(sessionId);
      await loadDocuments(notify: false);
      final selectionChanged = await _syncDocumentSelectionWithSession();
      if (!selectionChanged) {
        await _refreshSelectedDocumentContent();
      }

      if (reloadHistory) {
        _messages = await _apiService.getHistory(sessionId);
      }

      await loadPendingKnowledge(notify: false);

      _refreshExtractionPromptFlag();
      notifyListeners();
    } catch (e) {
      _chatError = e.toString();
      if (kDebugMode) {
        print('Error refreshing v2 data: $e');
      }
      notifyListeners();
    }
  }

  Future<void> closeOpenQuestion(String question) async {
    final sessionId = _currentSession?.sessionId;
    final contextData = _contextData;
    if (sessionId == null || contextData == null) return;

    final normalizedTarget = _normalizeQuestionForCompare(question);
    if (normalizedTarget.isEmpty) return;

    final remainingQuestions = contextData.openQuestions.where((item) {
      final text = item['question']?.toString() ?? '';
      return _normalizeQuestionForCompare(text) != normalizedTarget;
    }).toList(growable: false);

    if (remainingQuestions.length == contextData.openQuestions.length) {
      return;
    }

    final previousContext = contextData;
    _contextData = contextData.copyWith(openQuestions: remainingQuestions);
    _chatError = null;
    notifyListeners();

    try {
      await _apiService.updateContext(
        sessionId: sessionId,
        key: 'open_questions_remove',
        value: {'question': question},
      );
      await refreshData();
    } catch (e) {
      _contextData = previousContext;
      _chatError = 'Failed to close question: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadDocuments({bool notify = true}) async {
    try {
      final sessionId = _currentSession?.sessionId;
      if (sessionId == null || sessionId.trim().isEmpty) {
        _documents = [];
      } else {
        final sessionDocuments =
            await _apiService.listSessionDocuments(sessionId);
        var mergedDocuments = List<Map<String, dynamic>>.from(sessionDocuments);
        final activePath =
            _asNonEmptyString(_currentSession?.activeDocumentPath);
        final selectedPath = _asNonEmptyString(_selectedDocPath);

        // Backward compatibility:
        // when backend doesn't support session-scoped document filtering yet,
        // session endpoint may return empty; fallback to project-level list
        // only when we have an existing selection/active-path to recover.
        final shouldFallbackToProject = mergedDocuments.isEmpty &&
            (activePath != null || selectedPath != null);
        if (shouldFallbackToProject) {
          final projectDocuments = await _apiService.listDocuments(projectId);
          mergedDocuments = _mergeDocumentsByPath([], projectDocuments);
        }

        _documents = mergedDocuments;
      }
      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading documents: $e');
      }
    }
  }

  Future<void> selectDocument(
    String filePath, {
    bool syncSession = true,
  }) async {
    final normalized = filePath.trim();
    if (normalized.isEmpty) return;

    _selectedDocPath = normalized;
    _chatError = null;
    try {
      final fileData =
          await _apiService.getProjectFileWithVersion(projectId, normalized);
      _selectedDocContent = fileData['content']?.toString() ?? '';
      _selectedDocVersionNumber = (fileData['version_number'] as num?)?.toInt();
      _gddContent = _selectedDocContent;
      _gddVersionNumber = _selectedDocVersionNumber;

      final sessionId = _currentSession?.sessionId;
      if (syncSession && sessionId != null) {
        await _apiService.setActiveDocument(
          sessionId: sessionId,
          filePath: normalized,
        );
      }
      notifyListeners();
    } catch (e) {
      _chatError = e.toString();
      notifyListeners();
    }
  }

  Future<void> createDocument(String title, {String? filePath}) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) {
      _chatError = 'Please select a session before creating documents.';
      notifyListeners();
      throw Exception(_chatError);
    }
    _chatError = null;
    try {
      final created = await _apiService.createSessionDocument(
        sessionId,
        title,
        filePath: filePath,
      );
      await loadDocuments();
      final createdPath = created['file_path']?.toString();
      if (createdPath != null && createdPath.isNotEmpty) {
        await selectDocument(createdPath);
      }
    } catch (e) {
      _chatError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> renameDocument(String slug, String title) async {
    try {
      await _apiService.renameDocument(projectId, slug, title);
      await loadDocuments();
    } catch (e) {
      _chatError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDocument(String slug) async {
    try {
      final deletedPath = _documents
          .where((d) => d['slug']?.toString() == slug)
          .map(_documentPathFromInventoryItem)
          .whereType<String>()
          .firstOrNull;
      await _apiService.deleteDocument(projectId, slug, _authProvider.userId);
      await loadDocuments();
      if (_selectedDocPath == deletedPath) {
        _clearSelectedDocument();
      }
    } catch (e) {
      _chatError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> saveDocumentContent(String newContent, {String? comment}) async {
    if (projectId.isEmpty || _selectedDocPath == null) return false;
    try {
      final result = await _apiService.saveDocumentContent(
        projectId: projectId,
        filePath: _selectedDocPath!,
        contentMarkdown: newContent,
        baseVersionNumber: _selectedDocVersionNumber,
        comment: comment,
      );
      _selectedDocContent = newContent;
      _selectedDocVersionNumber = (result['version_number'] as num?)?.toInt();
      _gddContent = _selectedDocContent;
      _gddVersionNumber = _selectedDocVersionNumber;
      notifyListeners();
      return true;
    } on ConflictException {
      await refreshData();
      rethrow;
    } catch (e) {
      _chatError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> saveGddContent(String newContent, {String? comment}) async {
    return saveDocumentContent(newContent, comment: comment);
  }

  Future<bool> uploadFileToKnowledgeBase(
    String fileName, {
    String? filePath,
    Uint8List? bytes,
  }) async {
    return _apiService.uploadFile(
      projectId,
      fileName,
      filePath: filePath,
      bytes: bytes,
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _refreshSelectedDocumentContent() async {
    if (_selectedDocPath == null) return;
    final fileData = await _apiService.getProjectFileWithVersion(
        projectId, _selectedDocPath!);
    _selectedDocContent = fileData['content']?.toString() ?? '';
    _selectedDocVersionNumber = (fileData['version_number'] as num?)?.toInt();
    _gddContent = _selectedDocContent;
    _gddVersionNumber = _selectedDocVersionNumber;
  }

  void _clearSelectedDocument() {
    _selectedDocPath = null;
    _selectedDocContent = null;
    _selectedDocVersionNumber = null;
    _gddContent = null;
    _gddVersionNumber = null;
  }

  String? _documentPathFromInventoryItem(Map<String, dynamic> doc) {
    return _asNonEmptyString(doc['file_path']) ??
        _asNonEmptyString(doc['path']) ??
        _asNonEmptyString(doc['document_path']) ??
        _asNonEmptyString(doc['filePath']) ??
        _asNonEmptyString(doc['documentPath']);
  }

  Future<bool> _syncDocumentSelectionWithSession() async {
    final knownPaths = _documents
        .map(_documentPathFromInventoryItem)
        .whereType<String>()
        .toList(growable: false);
    final knownPathSet = knownPaths.toSet();
    final activePath = _asNonEmptyString(_currentSession?.activeDocumentPath);

    final selectedPath = _asNonEmptyString(_selectedDocPath);
    final sessionId = _currentSession?.sessionId;
    if (activePath != null && !knownPathSet.contains(activePath)) {
      if (sessionId != null) {
        try {
          await _apiService.setActiveDocument(
            sessionId: sessionId,
            filePath: null,
          );
          _currentSession = await _apiService.getSession(sessionId);
        } catch (e) {
          if (kDebugMode) {
            print('Error clearing stale active document path: $e');
          }
        }
      }

      if (selectedPath == activePath ||
          (selectedPath != null && !knownPathSet.contains(selectedPath))) {
        _clearSelectedDocument();
      }

      if (_selectedDocPath == null && knownPaths.isNotEmpty) {
        await selectDocument(knownPaths.first);
      }
      return true;
    }

    if (activePath != null &&
        knownPathSet.contains(activePath) &&
        selectedPath != activePath) {
      await selectDocument(activePath, syncSession: false);
      return true;
    }

    if (selectedPath != null && !knownPathSet.contains(selectedPath)) {
      _clearSelectedDocument();
    }

    if (_selectedDocPath == null && knownPaths.isNotEmpty) {
      // Heal stale session active_document_path by syncing to a valid document.
      await selectDocument(knownPaths.first);
      return true;
    }

    return false;
  }

  bool _isFileMergeConfirmation(Confirmation conf) {
    return conf.action.contains('file_merge_section') ||
        conf.action.contains('Merge section');
  }

  String? _asNonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeQuestionForCompare(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]+'), '');
  }

  List<Map<String, dynamic>> _mergeDocumentsByPath(
    List<Map<String, dynamic>> sessionDocuments,
    List<Map<String, dynamic>> projectDocuments,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final doc in [...projectDocuments, ...sessionDocuments]) {
      final path = _documentPathFromInventoryItem(doc);
      if (path == null) continue;
      merged[path] = doc;
    }

    return merged.values.toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Project Context / Pending Knowledge Methods
  // ---------------------------------------------------------------------------

  /// Load project-scoped pending knowledge items.
  /// Uses active session id, or falls back to any session in the same project.
  Future<void> loadPendingKnowledge({bool notify = true}) async {
    final sessionIds = _pendingKnowledgeScopeSessionIds();
    if (sessionIds.isEmpty) {
      _pendingKnowledgeItems = [];
      _pendingItemSessionMap = {};
      _shouldPromptSessionKnowledgeExtraction = false;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    _isPendingKnowledgeLoading = true;
    _pendingKnowledgeError = null;
    if (notify) {
      notifyListeners();
    }

    try {
      final mergedItems = <PendingKnowledgeItem>[];
      final itemSessionMap = <String, String>{};
      Object? lastError;
      var anySuccess = false;

      for (final sessionId in sessionIds) {
        try {
          final items = await _apiService.listPendingKnowledge(sessionId);
          anySuccess = true;
          for (final item in items) {
            if (itemSessionMap.containsKey(item.id)) {
              continue;
            }
            mergedItems.add(item);
            final sourceSession =
                item.sessionId.trim().isNotEmpty ? item.sessionId : sessionId;
            itemSessionMap[item.id] = sourceSession;
          }
        } catch (e) {
          lastError = e;
        }
      }

      _pendingKnowledgeItems = mergedItems;
      _pendingItemSessionMap = itemSessionMap;
      if (!anySuccess && lastError != null) {
        _pendingKnowledgeError = lastError.toString();
      } else {
        _pendingKnowledgeError = null;
      }
      _refreshExtractionPromptFlag();
    } catch (e) {
      _pendingKnowledgeError = e.toString();
    } finally {
      _isPendingKnowledgeLoading = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  /// Confirm or reject pending knowledge items.
  Future<ConfirmKnowledgeResult?> confirmPendingKnowledge(
      List<Map<String, String>> decisions) async {
    if (decisions.isEmpty) return null;

    _isPendingKnowledgeSubmitting = true;
    _pendingKnowledgeError = null;
    notifyListeners();

    try {
      final grouped = <String, List<Map<String, String>>>{};
      final errors = <Map<String, String>>[];
      for (final decision in decisions) {
        final id = decision['id'];
        final action = decision['action'];
        if (id == null || action == null) continue;
        final sessionId = _pendingItemSessionMap[id] ??
            _pendingKnowledgeItems
                .where((i) => i.id == id)
                .map((i) => i.sessionId)
                .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
        if (sessionId.isEmpty) {
          errors.add({'id': id, 'error': 'Missing session scope'});
          continue;
        }
        grouped.putIfAbsent(sessionId, () => []).add({
          'id': id,
          'action': action,
        });
      }

      final approved = <String>[];
      final rejected = <String>[];
      for (final entry in grouped.entries) {
        try {
          final result = await _apiService.confirmPendingKnowledge(
            sessionId: entry.key,
            decisions: entry.value,
          );
          approved.addAll(result.approved);
          rejected.addAll(result.rejected);
          errors.addAll(result.errors);
        } catch (e) {
          for (final d in entry.value) {
            final id = d['id'];
            if (id == null) continue;
            errors.add({'id': id, 'error': e.toString()});
          }
        }
      }

      final result = ConfirmKnowledgeResult(
        approved: approved,
        rejected: rejected,
        errors: errors,
      );
      // Refresh pending list and project context after confirmation
      await loadPendingKnowledge();
      await loadProjectContext();
      return result;
    } catch (e) {
      _pendingKnowledgeError = e.toString();
      return null;
    } finally {
      _isPendingKnowledgeSubmitting = false;
      notifyListeners();
    }
  }

  /// Edit a pending knowledge item.
  Future<bool> updatePendingItem(String itemId,
      {String? content, String? type}) async {
    final sessionId = _sessionIdForPendingItem(itemId);
    if (sessionId == null) return false;

    try {
      final updated = await _apiService.updatePendingItem(
        sessionId: sessionId,
        itemId: itemId,
        content: content,
        type: type,
      );
      final idx = _pendingKnowledgeItems.indexWhere((i) => i.id == itemId);
      if (idx >= 0) {
        _pendingKnowledgeItems[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _pendingKnowledgeError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a pending knowledge item.
  Future<bool> deletePendingItem(String itemId) async {
    final sessionId = _sessionIdForPendingItem(itemId);
    if (sessionId == null) return false;

    try {
      await _apiService.deletePendingItem(
        sessionId: sessionId,
        itemId: itemId,
      );
      _pendingKnowledgeItems.removeWhere((i) => i.id == itemId);
      _pendingItemSessionMap.remove(itemId);
      notifyListeners();
      return true;
    } catch (e) {
      _pendingKnowledgeError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Trigger context extraction from this session into project context.
  ///
  /// Returns backend extraction payload when successful, otherwise null.
  Future<Map<String, dynamic>?> extractSessionKnowledge({
    bool refreshAfterExtraction = true,
    bool showLoadingState = true,
  }) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return null;

    if (showLoadingState) {
      _isPendingKnowledgeLoading = true;
    }
    _shouldPromptSessionKnowledgeExtraction = false;
    _pendingKnowledgeError = null;
    if (showLoadingState) {
      notifyListeners();
    }

    try {
      final result = Map<String, dynamic>.from(
        await _apiService.extractSessionKnowledge(sessionId),
      );

      if (refreshAfterExtraction) {
        _currentSession = await _apiService.getSession(sessionId);
        await loadPendingKnowledge(notify: false);
        await loadProjectContext();
        _refreshExtractionPromptFlag();
      }
      return result;
    } catch (e) {
      _pendingKnowledgeError = e.toString();
      return null;
    } finally {
      if (showLoadingState) {
        _isPendingKnowledgeLoading = false;
        notifyListeners();
      }
    }
  }

  void _refreshExtractionPromptFlag() {
    final session = _currentSession;
    final hasSession = session != null;
    final hasPending = _pendingKnowledgeItems.isNotEmpty;
    final isPromptEligibleSession =
        session != null && session.sessionId == _promptEligibleSessionId;
    final unextractedTurns =
        session == null ? 0 : session.turnCount - session.lastExtractionTurn;
    final hasNewMessages =
        unextractedTurns >= _knowledgeExtractionPromptTurnGap;

    _shouldPromptSessionKnowledgeExtraction =
        hasSession && isPromptEligibleSession && !hasPending && hasNewMessages;
  }

  /// Load project context entries (confirmed knowledge).
  Future<void> loadProjectContext({String? type, String? query}) async {
    _isProjectContextLoading = true;
    _projectContextError = null;
    notifyListeners();

    try {
      _projectContextEntries = await _apiService.listProjectContext(
        projectId: projectId,
        type: type,
        query: query,
      );
    } catch (e) {
      _projectContextError = e.toString();
    } finally {
      _isProjectContextLoading = false;
      notifyListeners();
    }
  }

  /// Add a new entry to project context.
  Future<bool> addProjectContextEntry({
    required String type,
    required String content,
  }) async {
    try {
      final entry = await _apiService.createProjectContextEntry(
        projectId: projectId,
        type: type,
        content: content,
      );
      _projectContextEntries.insert(0, entry);
      notifyListeners();
      return true;
    } catch (e) {
      _projectContextError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Edit a project context entry.
  Future<bool> updateProjectContextEntry(String entryId,
      {String? content, String? type}) async {
    try {
      final updated = await _apiService.updateProjectContextEntry(
        projectId: projectId,
        entryId: entryId,
        content: content,
        type: type,
      );
      final idx = _projectContextEntries.indexWhere((e) => e.id == entryId);
      if (idx >= 0) {
        _projectContextEntries[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _projectContextError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a project context entry (soft delete).
  Future<bool> deleteProjectContextEntry(String entryId) async {
    try {
      await _apiService.deleteProjectContextEntry(
        projectId: projectId,
        entryId: entryId,
      );
      _projectContextEntries.removeWhere((e) => e.id == entryId);
      notifyListeners();
      return true;
    } catch (e) {
      _projectContextError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
