import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/confirmation.dart';
import '../models/context.dart';
import '../models/message.dart';
import '../models/progress.dart';
import '../models/selection.dart';
import '../models/session.dart';
import '../services/v2_api_service.dart';
import '../services/v2_sse_service.dart';

class V2SessionProvider with ChangeNotifier {
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
  GetProgressResponse? _progress;
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

  String? _sessionsError;
  String? _chatError;

  List<SessionInfo> get sessions => _sessions;
  SessionInfo? get currentSession => _currentSession;
  List<ChatMessage> get messages => _messages;
  GetContextResponse? get contextData => _contextData;
  GetProgressResponse? get progress => _progress;
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

  bool get canUseV2 => _authProvider.userId.trim().isNotEmpty;

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
    _progress = null;
    _gddContent = null;
    _gddVersionNumber = null;
    _pendingConfirmation = null;
    _pendingSelection = null;
    _streamingContent = '';
    _thinkingContent = null;
    _chatError = null;
    _hasDraftConversation = true;
    notifyListeners();
  }

  Future<void> selectSession(String sessionId) async {
    _isLoading = true;
    _chatError = null;
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
    _contextData = await _apiService.getContext(sessionId);

    try {
      _progress = await _apiService.getProgress(sessionId);
    } catch (_) {
      _progress = null;
    }

    final fileData =
        await _apiService.getProjectFileWithVersion(projectId, 'gdd.md');
    _gddContent = fileData['content']?.toString() ?? '';
    _gddVersionNumber = (fileData['version_number'] as num?)?.toInt();

    if (reloadHistory) {
      _messages = await _apiService.getHistory(sessionId);
    }

    _pendingConfirmation = null;
    _pendingSelection = null;
    _streamingContent = '';
    _thinkingContent = null;
  }

  Future<void> _createAndSelectSession({String? initialMessage}) async {
    final req = CreateSessionRequest(
      projectId: projectId,
      title: _buildDraftTitle(initialMessage),
    );
    final created = await _apiService.createSession(req);
    await loadSessions();
    await selectSession(created.sessionId);
  }

  String? _buildDraftTitle(String? content) {
    if (content == null) return null;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= 60) return trimmed;
    return '${trimmed.substring(0, 57)}...';
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
      _isLoading = true;
      _chatError = null;
      notifyListeners();
      try {
        await _createAndSelectSession(initialMessage: trimmed);
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
    _pendingConfirmation = null;
    _pendingSelection = null;
    notifyListeners();

    try {
      await for (final event in _sseService.streamMessage(
        sessionId: session.sessionId,
        content: trimmed,
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
            _pendingConfirmation = event.confirmation;
            _pendingSelection = event.selection;
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
          _pendingSelection != null;
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
          ),
        ];
      }

      _isSending = false;
      _streamingContent = '';
      _thinkingContent = null;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));
      await refreshData();
      await loadSessions();
    }
  }

  Future<void> confirmTransaction({String? transactionId}) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _isConfirming = true;
    _pendingConfirmation = null;
    _chatError = null;
    notifyListeners();

    try {
      await _apiService.confirmTransaction(
        sessionId: sessionId,
        action: 'confirm',
        transactionId: transactionId,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      await refreshData(reloadHistory: true);
      await loadSessions();
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
      await Future.delayed(const Duration(milliseconds: 300));
      await refreshData(reloadHistory: true);
      await loadSessions();
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
      try {
        _progress = await _apiService.getProgress(sessionId);
      } catch (_) {
        _progress = null;
      }
      final fileData =
          await _apiService.getProjectFileWithVersion(projectId, 'gdd.md');
      _gddContent = fileData['content']?.toString() ?? '';
      _gddVersionNumber = (fileData['version_number'] as num?)?.toInt();
      _currentSession = await _apiService.getSession(sessionId);

      if (reloadHistory) {
        _messages = await _apiService.getHistory(sessionId);
      }

      notifyListeners();
    } catch (e) {
      _chatError = e.toString();
      if (kDebugMode) {
        print('Error refreshing v2 data: $e');
      }
      notifyListeners();
    }
  }

  Future<bool> saveGddContent(String newContent, {String? comment}) async {
    if (_currentSession?.projectId == null && projectId.isEmpty) return false;
    try {
      final result = await _apiService.saveGddContent(
        projectId: projectId,
        contentMarkdown: newContent,
        baseVersionNumber: _gddVersionNumber,
        comment: comment,
      );
      _gddContent = newContent;
      _gddVersionNumber = (result['version_number'] as num?)?.toInt();
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
}
