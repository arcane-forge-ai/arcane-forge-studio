import 'dart:async';
import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/services/coding_agent_config_service.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/kb_docs_sync_service.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/coding_agent_embedded_browser_host.dart';
import 'package:arcane_forge/screens/development/coding_agent/models/opencode_models.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/opencode_server_manager.dart';
import 'package:arcane_forge/screens/development/coding_agent_screen.dart';
import 'package:arcane_forge/screens/game_design_assistant/services/chat_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(home: child);
}

const MethodChannel _workspaceAccessChannel = MethodChannel(
  'arcane_forge/workspace_access',
);

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 200,
}) async {
  for (int index = 0; index < maxPumps; index += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_workspaceAccessChannel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_workspaceAccessChannel, null);
  });

  group('CodingAgentScreen', () {
    late Directory workspaceDirectory;
    late Directory supportDirectory;
    late CodingAgentConfigService configService;

    setUp(() {
      workspaceDirectory = Directory.systemTemp.createTempSync(
        'coding-agent-screen-test-',
      );
      supportDirectory = Directory.systemTemp.createTempSync(
        'coding-agent-screen-support-',
      );
      configService = CodingAgentConfigService(
        supportDirectoryProvider: () async => supportDirectory,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() {
      if (workspaceDirectory.existsSync()) {
        workspaceDirectory.deleteSync(recursive: true);
      }
      if (supportDirectory.existsSync()) {
        supportDirectory.deleteSync(recursive: true);
      }
    });

    testWidgets('shows unsupported platform message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          const CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: false,
          ),
        ),
      );

      expect(
        find.text(
          'Coding Agent (Beta) is available on macOS and Windows desktop only.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows workspace setup gate when no workspace is set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          const CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Select Workspace Folder'), findsOneWidget);
      expect(find.text('Select Folder'), findsOneWidget);
    });

    testWidgets('auto-starts OpenCode and loads the embedded web view', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = (methodCall.arguments as Map<Object?, Object?>)['text']
              as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final Completer<String?> startCompleter = Completer<String?>();
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startCompleter: startCompleter,
        managed: true,
        initialLogs: const <String>[
          'Starting opencode serve on port 4096',
        ],
      );
      final _FakeEmbeddedBrowserHost browserHost = _FakeEmbeddedBrowserHost();
      Uri? capturedInitialUrl;

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
            debugEmbeddedBrowserHostFactory: (
              CodingAgentEmbeddedBrowserCallbacks callbacks,
            ) {
              browserHost.callbacks = callbacks;
              browserHost.onLoad = (Uri initialUrl) {
                capturedInitialUrl = initialUrl;
              };
              return browserHost;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Connecting to Coding Agent...'), findsOneWidget);

      startCompleter.complete('http://127.0.0.1:4102');
      await _pumpUntilFound(
          tester, find.byKey(_FakeEmbeddedBrowserHost.viewKey));

      expect(find.byKey(_FakeEmbeddedBrowserHost.viewKey), findsOneWidget);
      expect(capturedInitialUrl, Uri.parse('http://127.0.0.1:4102'));
      expect(serverManager.startCalls, 1);

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('OpenCode Logs'), findsOneWidget);
      expect(find.text('Starting opencode serve on port 4096'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Copy Logs'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Copy Logs'));
      await tester.pump();

      expect(copiedText, contains('Starting opencode serve on port 4096'));
    });

    testWidgets('shows the utilities drawer when Coding Agent is ready', (
      WidgetTester tester,
    ) async {
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startResult: 'http://127.0.0.1:4102',
        managed: true,
      );
      final _FakeEmbeddedBrowserHost browserHost = _FakeEmbeddedBrowserHost();

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
            debugEmbeddedBrowserHostFactory: (
              CodingAgentEmbeddedBrowserCallbacks callbacks,
            ) {
              browserHost.callbacks = callbacks;
              return browserHost;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Utilities'), findsOneWidget);
    });

    testWidgets('shows KB sync actions and the sync status dialog', (
      WidgetTester tester,
    ) async {
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startResult: 'http://127.0.0.1:4102',
        managed: true,
      );
      final _TestKbDocsSyncService kbSyncService = _TestKbDocsSyncService(
        statusResult: KbSyncStatus(
          workspacePath: workspaceDirectory.path,
          kbDirectoryPath: '${workspaceDirectory.path}/docs',
          manifestPath:
              '${workspaceDirectory.path}/.arcane-forge/sync-manifest.json',
          trackedFiles: 3,
          projectId: 'project-1',
          projectName: 'Project One',
          localFiles: 4,
          remoteActiveFiles: 5,
          inSyncCount: 1,
          needsPushCount: 1,
          needsPushExamples: const <String>['docs/design.md'],
          needsPullCount: 1,
          needsPullExamples: const <String>['docs/world.md'],
          needsReviewCount: 1,
          needsReviewExamples: const <String>['docs/conflict.md'],
          remoteUnavailableCount: 1,
          remoteUnavailableExamples: const <String>['docs/pending.md'],
          lastPullAt: '2026-03-01T10:00:00.000Z',
          lastPushAt: '2026-03-02T11:00:00.000Z',
        ),
      );

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
            debugKbDocsSyncService: kbSyncService,
            debugEmbeddedBrowserHostFactory: (
              CodingAgentEmbeddedBrowserCallbacks callbacks,
            ) {
              return _FakeEmbeddedBrowserHost()..callbacks = callbacks;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('KB sync actions'));
      await tester.pumpAndSettle();

      expect(find.text('Pull from KB'), findsOneWidget);
      expect(find.text('Push to KB'), findsOneWidget);
      expect(find.text('Show Sync Status'), findsOneWidget);

      await tester.tap(find.text('Show Sync Status'));
      await tester.pumpAndSettle();

      expect(find.text('KB Sync Status'), findsOneWidget);
      expect(find.text('Local Files'), findsOneWidget);
      expect(find.text('Online KB Docs'), findsOneWidget);
      expect(find.text('Likely Safe to Push'), findsOneWidget);
      expect(find.text('Likely Safe to Pull'), findsOneWidget);
      expect(find.text('Needs Review'), findsOneWidget);
      expect(find.text('Online Not Ready'), findsOneWidget);
      expect(find.text('Tracked Files'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('docs/design.md'), findsOneWidget);
      expect(find.textContaining('docs/world.md'), findsOneWidget);
      expect(find.textContaining('docs/conflict.md'), findsOneWidget);
      expect(find.textContaining('docs/pending.md'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(kbSyncService.statusCalls, 1);
    });

    testWidgets('disables the KB sync control while pull and push are running',
        (
      WidgetTester tester,
    ) async {
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startResult: 'http://127.0.0.1:4102',
        managed: true,
      );
      final Completer<KbPullResult> pullCompleter = Completer<KbPullResult>();
      final Completer<KbPushResult> pushCompleter = Completer<KbPushResult>();
      final _TestKbDocsSyncService kbSyncService = _TestKbDocsSyncService(
        pullCompleter: pullCompleter,
        pushCompleter: pushCompleter,
      );

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
            debugKbDocsSyncService: kbSyncService,
            debugEmbeddedBrowserHostFactory: (
              CodingAgentEmbeddedBrowserCallbacks callbacks,
            ) {
              return _FakeEmbeddedBrowserHost()..callbacks = callbacks;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('KB sync actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pull from KB'));
      await tester.pump();

      expect(find.text('Pulling KB...'), findsOneWidget);
      final PopupMenuButton<dynamic> pullingMenu =
          tester.widget<PopupMenuButton<dynamic>>(
        find.byWidgetPredicate((Widget widget) => widget is PopupMenuButton),
      );
      expect(pullingMenu.enabled, isFalse);
      expect(kbSyncService.pullCalls, 1);

      pullCompleter.complete(
        const KbPullResult(
          downloaded: <String>[],
          skippedNoStorage: <String>[],
          skippedCollision: <String>[],
          failed: <KbPullFailure>[],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('KB sync actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push to KB'));
      await tester.pump();

      expect(find.text('Pushing KB...'), findsOneWidget);
      final PopupMenuButton<dynamic> pushingMenu =
          tester.widget<PopupMenuButton<dynamic>>(
        find.byWidgetPredicate((Widget widget) => widget is PopupMenuButton),
      );
      expect(pushingMenu.enabled, isFalse);
      expect(kbSyncService.pushCalls, 1);

      pushCompleter.complete(
        const KbPushResult(
          uploaded: <String>[],
          skippedUnchanged: <String>[],
          skippedConflicts: <String>[],
          failed: <KbPushFailure>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KB Sync'), findsOneWidget);
    });

    testWidgets('shows launcher failure details when OpenCode cannot start', (
      WidgetTester tester,
    ) async {
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startResult: null,
        fakeLastError: 'The `opencode` binary was not found.',
      );

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await _pumpUntilFound(
          tester, find.text('Coding Agent could not be loaded'));

      expect(find.text('Coding Agent could not be loaded'), findsOneWidget);
      expect(find.text('The `opencode` binary was not found.'), findsOneWidget);
    });

    testWidgets('keeps browser fallback available when embedded view fails', (
      WidgetTester tester,
    ) async {
      final _TestOpencodeServerManager serverManager =
          _TestOpencodeServerManager(
        startResult: 'http://127.0.0.1:4102',
        managed: true,
      );

      await tester.pumpWidget(
        _buildHarness(
          CodingAgentScreen(
            projectId: 'project-1',
            projectName: 'Project One',
            debugIsSupportedPlatformOverride: true,
            debugServerManager: serverManager,
            debugWorkspacePathOverride: workspaceDirectory.path,
            debugConfigService: configService,
            debugEmbeddedBrowserHostFactory: (
              CodingAgentEmbeddedBrowserCallbacks callbacks,
            ) {
              return _FailingEmbeddedBrowserHost(
                callbacks: callbacks,
                message:
                    'Microsoft Edge WebView2 Runtime is required to use the embedded Coding Agent view on Windows. Install WebView2 or use Open in Browser.',
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Coding Agent could not be loaded'), findsOneWidget);
      expect(find.textContaining('Microsoft Edge WebView2 Runtime is required'),
          findsOneWidget);

      await _openUtilitiesDrawer(tester);

      final Finder openInBrowserLabel = find.text('Open in Browser');
      final Finder openInBrowserButtonFinder = find.ancestor(
        of: openInBrowserLabel,
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is ButtonStyleButton,
        ),
      );
      await tester.ensureVisible(openInBrowserLabel);
      final ButtonStyleButton openInBrowserButton =
          tester.widget<ButtonStyleButton>(
        openInBrowserButtonFinder,
      );
      expect(openInBrowserButton.onPressed, isNotNull);
    });
  });
}

class _TestKbDocsSyncService extends KbDocsSyncService {
  _TestKbDocsSyncService({
    this.pullCompleter,
    this.pushCompleter,
    this.statusResult,
  }) : super(chatApiService: ChatApiService());

  final Completer<KbPullResult>? pullCompleter;
  final Completer<KbPushResult>? pushCompleter;
  final KbSyncStatus? statusResult;
  int pullCalls = 0;
  int pushCalls = 0;
  int statusCalls = 0;

  @override
  Future<KbPullResult> pullKnowledgeBaseDocs({
    required String projectId,
    required String workspacePath,
    String? projectName,
  }) async {
    pullCalls += 1;
    if (pullCompleter != null) {
      return pullCompleter!.future;
    }
    return const KbPullResult(
      downloaded: <String>[],
      skippedNoStorage: <String>[],
      skippedCollision: <String>[],
      failed: <KbPullFailure>[],
    );
  }

  @override
  Future<KbPushResult> pushKnowledgeBaseDocs({
    required String projectId,
    required String workspacePath,
    String? projectName,
  }) async {
    pushCalls += 1;
    if (pushCompleter != null) {
      return pushCompleter!.future;
    }
    return const KbPushResult(
      uploaded: <String>[],
      skippedUnchanged: <String>[],
      skippedConflicts: <String>[],
      failed: <KbPushFailure>[],
    );
  }

  @override
  Future<KbSyncStatus> getKnowledgeBaseSyncStatus({
    required String projectId,
    required String workspacePath,
    String? projectName,
  }) async {
    statusCalls += 1;
    return statusResult ??
        KbSyncStatus(
          workspacePath: workspacePath,
          kbDirectoryPath: '$workspacePath/docs',
          manifestPath: '$workspacePath/.arcane-forge/sync-manifest.json',
          trackedFiles: 0,
          projectId: projectId,
          projectName: projectName ?? '',
        );
  }
}

class _TestOpencodeServerManager extends OpencodeServerManager {
  _TestOpencodeServerManager({
    this.startResult,
    this.fakeLastError,
    this.managed = false,
    this.startCompleter,
    List<String> initialLogs = const <String>[],
  }) {
    _recentLogs.addAll(initialLogs);
  }

  final Completer<String?>? startCompleter;
  String? startResult;
  String? fakeLastError;
  bool managed;
  int startCalls = 0;
  int stopCalls = 0;
  int detachCalls = 0;
  ServerLifecycleStatus _status = ServerLifecycleStatus.stopped;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final List<String> _recentLogs = <String>[];

  @override
  Stream<String> get logs => _logController.stream;

  @override
  List<String> get recentLogs => List<String>.unmodifiable(_recentLogs);

  void emitLog(String line) {
    _recentLogs.add(line);
    _logController.add(line);
  }

  @override
  String? get lastError => fakeLastError;

  @override
  bool get ownsManagedServer =>
      managed && _status == ServerLifecycleStatus.running;

  @override
  ServerLifecycleStatus status() => _status;

  @override
  Future<OpencodeDiagnostics> diagnostics() async {
    return OpencodeDiagnostics(
      status: _status,
      binaryDetected: startResult != null || startCompleter != null,
      binarySource: startResult != null || startCompleter != null
          ? OpencodeBinarySource.bundledInstalled
          : OpencodeBinarySource.missing,
      serverReachable: _status == ServerLifecycleStatus.running,
      providerReady: _status == ServerLifecycleStatus.running,
      recentLogs: List<String>.from(_recentLogs),
      sidecarManaged: managed,
      credentialsPresent: true,
      configSyncState: _status == ServerLifecycleStatus.running
          ? OpencodeConfigSyncState.applied
          : OpencodeConfigSyncState.idle,
      binaryPath: startResult != null || startCompleter != null
          ? '/tmp/opencode'
          : null,
      version: startResult != null || startCompleter != null ? '1.3.3' : null,
      serverUrl: _status == ServerLifecycleStatus.running ? startResult : null,
      lastError: fakeLastError,
      bundledVersion:
          startResult != null || startCompleter != null ? '1.3.3' : null,
      selectedProviderId: 'openai',
      selectedProviderLabel: 'OpenAI',
      selectedModel: 'openai/gpt-5',
      configSyncMessage: _status == ServerLifecycleStatus.running
          ? 'Arcane Forge applied its app-managed OpenCode configuration.'
          : null,
    );
  }

  @override
  Future<String?> start() async {
    startCalls += 1;
    _status = ServerLifecycleStatus.starting;
    final String? result =
        startCompleter != null ? await startCompleter!.future : startResult;
    _status = result == null
        ? ServerLifecycleStatus.failed
        : ServerLifecycleStatus.running;
    return result;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    managed = false;
    _status = ServerLifecycleStatus.stopped;
  }

  @override
  Future<void> detach() async {
    detachCalls += 1;
    managed = false;
    _status = ServerLifecycleStatus.stopped;
  }
}

Future<void> _openUtilitiesDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  expect(find.text('Utilities'), findsOneWidget);
}

class _FakeEmbeddedBrowserHost implements CodingAgentEmbeddedBrowserHost {
  static const ValueKey<String> viewKey = ValueKey<String>('fake-webview');

  CodingAgentEmbeddedBrowserCallbacks? callbacks;
  FutureOr<void> Function(Uri initialUrl)? onLoad;
  int reloadCalls = 0;
  int disposeCalls = 0;

  @override
  Widget buildView() => const SizedBox(key: viewKey);

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  @override
  Future<void> load(Uri initialUrl) async {
    await onLoad?.call(initialUrl);
    callbacks?.onUrlChanged(initialUrl.toString());
  }

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }
}

class _FailingEmbeddedBrowserHost implements CodingAgentEmbeddedBrowserHost {
  _FailingEmbeddedBrowserHost({
    required this.callbacks,
    required this.message,
  });

  final CodingAgentEmbeddedBrowserCallbacks callbacks;
  final String message;

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(Uri initialUrl) async {
    callbacks.onUrlChanged(initialUrl.toString());
    throw CodingAgentEmbeddedBrowserException(message);
  }

  @override
  Future<void> reload() async {}
}
