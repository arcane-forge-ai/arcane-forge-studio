import 'dart:async';
import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/services/coding_agent_config_service.dart';
import 'package:arcane_forge/screens/development/coding_agent/models/opencode_models.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/opencode_server_manager.dart';
import 'package:arcane_forge/screens/development/coding_agent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

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
    WebViewPlatform.instance = _FakeWebViewPlatform();
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
        find.text('Coding Agent (Beta) is available on macOS desktop only.'),
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
            debugControllerFactory: (
              NavigationDelegate _,
              Uri initialUrl,
            ) {
              capturedInitialUrl = initialUrl;
              return WebViewController.fromPlatform(
                _FakePlatformWebViewController(
                  const PlatformWebViewControllerCreationParams(),
                  initialUrl.toString(),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Connecting to Coding Agent...'), findsOneWidget);

      startCompleter.complete('http://127.0.0.1:4102');
      await _pumpUntilFound(
          tester, find.byKey(_FakePlatformWebViewWidget.viewKey));

      expect(find.byKey(_FakePlatformWebViewWidget.viewKey), findsOneWidget);
      expect(capturedInitialUrl, Uri.parse('http://127.0.0.1:4102'));
      expect(serverManager.startCalls, 1);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Utilities'));
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

    testWidgets('shows the Agent Settings entry when Coding Agent is ready', (
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
            debugControllerFactory: (
              NavigationDelegate _,
              Uri initialUrl,
            ) {
              return WebViewController.fromPlatform(
                _FakePlatformWebViewController(
                  const PlatformWebViewControllerCreationParams(),
                  initialUrl.toString(),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Agent Settings'), findsOneWidget);
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
  });
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

class _FakeWebViewPlatform extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate
    with MockPlatformInterfaceMixin {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback onHttpAuthRequest) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) {
    return Future<void>.value();
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) {
    return Future<void>.value();
  }
}

class _FakePlatformWebViewController extends PlatformWebViewController
    with MockPlatformInterfaceMixin {
  _FakePlatformWebViewController(super.params, [this._currentUrl])
      : super.implementation();

  String? _currentUrl;

  @override
  Future<bool> canGoBack() => Future<bool>.value(false);

  @override
  Future<bool> canGoForward() => Future<bool>.value(false);

  @override
  Future<String?> currentUrl() => Future<String?>.value(_currentUrl);

  @override
  Future<void> loadRequest(LoadRequestParams params) {
    _currentUrl = params.uri.toString();
    return Future<void>.value();
  }

  @override
  Future<void> reload() => Future<void>.value();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) {
    return Future<void>.value();
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) {
    return Future<void>.value();
  }
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  static const ValueKey<String> viewKey = ValueKey<String>('fake-webview');

  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: viewKey);
  }
}
