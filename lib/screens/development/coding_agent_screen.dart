// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../constants.dart';
import '../game_design_assistant/services/chat_api_service.dart';
import 'coding_agent/services/kb_docs_sync_service.dart';
import 'coding_agent/services/coding_agent_embedded_browser_host.dart';
import 'coding_agent/models/coding_agent_config.dart';
import 'coding_agent/models/opencode_models.dart';
import 'coding_agent/services/coding_agent_config_service.dart';
import 'coding_agent/services/opencode_api_client.dart';
import 'coding_agent/services/opencode_server_manager.dart';
import 'coding_agent/services/workspace_service.dart';

enum _OpencodeViewState { loading, ready, error, unsupported, workspaceSetup }

enum _KbSyncOperation { idle, pulling, pushing }

enum _KbSyncMenuAction { pull, push, status }

class CodingAgentScreen extends StatefulWidget {
  const CodingAgentScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.debugIsSupportedPlatformOverride,
    this.debugInitialUrl,
    this.debugEmbeddedBrowserHostFactory,
    this.debugServerManager,
    this.debugWorkspacePathOverride,
    this.debugConfigService,
    this.debugKbDocsSyncService,
  });

  final String projectId;
  final String projectName;
  @visibleForTesting
  final bool? debugIsSupportedPlatformOverride;
  @visibleForTesting
  final Uri? debugInitialUrl;
  @visibleForTesting
  final CodingAgentEmbeddedBrowserHostFactory? debugEmbeddedBrowserHostFactory;
  @visibleForTesting
  final OpencodeServerManager? debugServerManager;
  @visibleForTesting
  final String? debugWorkspacePathOverride;
  @visibleForTesting
  final CodingAgentConfigService? debugConfigService;
  @visibleForTesting
  final KbDocsSyncService? debugKbDocsSyncService;

  @override
  State<CodingAgentScreen> createState() => _CodingAgentScreenState();
}

class _SettingsDialogResult {
  const _SettingsDialogResult({
    required this.config,
    required this.secrets,
  });

  final CodingAgentGlobalConfig config;
  final CodingAgentSecretConfig secrets;
}

class _ProviderCatalogResult {
  const _ProviderCatalogResult({
    required this.providerId,
    required this.models,
    required this.defaultModel,
    required this.connected,
  });

  final String providerId;
  final List<String> models;
  final String defaultModel;
  final bool connected;
}

class _CodingAgentScreenState extends State<CodingAgentScreen> {
  static const int _maxVisibleServerLogs = 300;

  final WorkspaceService _workspaceService = WorkspaceService();
  late final ChatApiService _chatApiService;
  late final KbDocsSyncService _kbDocsSyncService;
  late final OpencodeServerManager _serverManager =
      widget.debugServerManager ?? OpencodeServerManager();
  late final CodingAgentConfigService _configService =
      widget.debugConfigService ?? CodingAgentConfigService();
  final OpencodeApiClient _opencodeApiClient = OpencodeApiClient();

  _OpencodeViewState _state = _OpencodeViewState.loading;
  CodingAgentEmbeddedBrowserHost? _embeddedBrowserHost;
  StreamSubscription<String>? _serverLogSubscription;
  String? _errorMessage;
  String? _workspacePath;
  Uri? _serverBaseUrl;
  String _currentUrl = '';
  String _loadingMessage = 'Loading your saved workspace selection...';
  _KbSyncOperation _kbSyncOperation = _KbSyncOperation.idle;
  List<String> _serverLogs = <String>[];
  OpencodeDiagnostics? _diagnostics;

  bool get _supportsCodingAgentPlatform =>
      widget.debugIsSupportedPlatformOverride ??
      (!kIsWeb && (Platform.isMacOS || Platform.isWindows));

  String get _visibleUrl => _currentUrl.isNotEmpty
      ? _currentUrl
      : (_serverBaseUrl?.toString() ?? 'Not connected yet');

  bool get _hasBrowserTarget =>
      _currentUrl.trim().isNotEmpty || _serverBaseUrl != null;

  bool get _showsManagedServerActions => _serverManager.ownsManagedServer;

  bool get _isSyncingDocs => _kbSyncOperation != _KbSyncOperation.idle;

  String get _kbSyncButtonLabel {
    switch (_kbSyncOperation) {
      case _KbSyncOperation.idle:
        return 'KB Sync';
      case _KbSyncOperation.pulling:
        return 'Pulling KB...';
      case _KbSyncOperation.pushing:
        return 'Pushing KB...';
    }
  }

  String get _serverLifecycleLabel {
    switch (_serverManager.status()) {
      case ServerLifecycleStatus.starting:
        return 'Starting';
      case ServerLifecycleStatus.running:
        return _serverManager.ownsManagedServer
            ? 'App-managed'
            : 'External/Reused';
      case ServerLifecycleStatus.failed:
        return 'Failed';
      case ServerLifecycleStatus.stopped:
        return 'Stopped';
    }
  }

  @override
  void initState() {
    super.initState();
    final SettingsProvider? settingsProvider =
        Provider.of<SettingsProvider?>(context, listen: false);
    final AuthProvider? authProvider =
        Provider.of<AuthProvider?>(context, listen: false);
    _chatApiService = ChatApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
    _kbDocsSyncService = widget.debugKbDocsSyncService ??
        KbDocsSyncService(chatApiService: _chatApiService);
    _serverLogs = List<String>.from(_serverManager.recentLogs);
    _serverLogSubscription = _serverManager.logs.listen(_handleServerLog);
    if (!_supportsCodingAgentPlatform) {
      _state = _OpencodeViewState.unsupported;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    unawaited(_serverLogSubscription?.cancel());
    unawaited(_serverManager.detach());
    unawaited(_disposeEmbeddedBrowserHost());
    _opencodeApiClient.dispose();
    _chatApiService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!_supportsCodingAgentPlatform) {
      return;
    }

    if (mounted) {
      setState(() {
        _state = _OpencodeViewState.loading;
        _errorMessage = null;
        _serverBaseUrl = null;
        _currentUrl = '';
        _loadingMessage = 'Loading your saved workspace selection...';
      });
    }

    final String? debugWorkspacePath = widget.debugWorkspacePathOverride;
    if (debugWorkspacePath != null && debugWorkspacePath.trim().isNotEmpty) {
      setState(() {
        _workspacePath = debugWorkspacePath;
      });
      await _connectToOpencode();
      return;
    }

    final String? workspacePath =
        await _workspaceService.loadWorkspacePath(widget.projectId);
    if (!mounted) {
      return;
    }

    if (workspacePath == null || workspacePath.trim().isEmpty) {
      setState(() {
        _workspacePath = null;
        _state = _OpencodeViewState.workspaceSetup;
      });
      return;
    }

    final bool accessible = await _workspaceService.isWorkspaceAccessible(
      workspacePath,
    );
    if (!mounted) {
      return;
    }

    if (!accessible) {
      await _workspaceService.clearWorkspacePath(widget.projectId);
      setState(() {
        _workspacePath = null;
        _state = _OpencodeViewState.workspaceSetup;
        _errorMessage =
            'Workspace access was denied by the OS. Please select the folder again.';
      });
      return;
    }

    setState(() {
      _workspacePath = workspacePath;
    });
    final CodingAgentConfigBundle bundle = await _configService.loadBundle();
    if (!bundle.config.autoStartSidecar) {
      await _refreshDiagnostics();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _OpencodeViewState.error;
        _errorMessage =
            'Auto-start for bundled OpenCode is disabled. Use Retry or Agent Settings to launch it manually.';
      });
      return;
    }
    await _connectToOpencode();
  }

  Future<void> _connectToOpencode({
    String loadingMessage = 'Starting local OpenCode...',
  }) async {
    if (!_supportsCodingAgentPlatform || _workspacePath == null) {
      return;
    }

    await _disposeEmbeddedBrowserHost();
    if (mounted) {
      setState(() {
        _state = _OpencodeViewState.loading;
        _errorMessage = null;
        _embeddedBrowserHost = null;
        _serverBaseUrl = null;
        _currentUrl = '';
        _loadingMessage = loadingMessage;
      });
    }

    final String? serverUrl = await _serverManager.start();
    if (!mounted) {
      return;
    }

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      await _refreshDiagnostics();
      setState(() {
        _state = _OpencodeViewState.error;
        _errorMessage = _serverManager.lastError ??
            'Unable to start the local OpenCode server.';
      });
      return;
    }

    final Uri initialUrl = widget.debugInitialUrl ?? Uri.parse(serverUrl);
    await _initializeEmbeddedBrowser(initialUrl);
    await _refreshDiagnostics();
  }

  Future<void> _initializeEmbeddedBrowser(Uri initialUrl) async {
    final Uri origin = _originOf(initialUrl);
    CodingAgentEmbeddedBrowserHost? host;

    try {
      final CodingAgentEmbeddedBrowserCallbacks callbacks =
          CodingAgentEmbeddedBrowserCallbacks(
        onUrlChanged: _handleEmbeddedBrowserUrlChanged,
        onLoadError: _handleEmbeddedBrowserLoadError,
        openExternalUrl: _launchExternally,
      );
      final CodingAgentEmbeddedBrowserHostFactory factory =
          widget.debugEmbeddedBrowserHostFactory ??
              createDefaultCodingAgentEmbeddedBrowserHost;
      host = factory(callbacks);
      await host.load(initialUrl);

      if (!mounted) {
        await host.dispose();
        return;
      }

      setState(() {
        _embeddedBrowserHost = host;
        _state = _OpencodeViewState.ready;
        _serverBaseUrl = origin;
        _currentUrl = initialUrl.toString();
        _errorMessage = null;
      });
    } catch (error) {
      await host?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _OpencodeViewState.error;
        _errorMessage = error is CodingAgentEmbeddedBrowserException
            ? error.message
            : 'Failed to create the embedded Coding Agent view: $error';
        _serverBaseUrl = origin;
        _currentUrl = initialUrl.toString();
      });
    }
  }

  Uri _originOf(Uri uri) {
    if (uri.hasPort) {
      return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
    }
    return Uri(scheme: uri.scheme, host: uri.host);
  }

  Future<void> _disposeEmbeddedBrowserHost() async {
    final CodingAgentEmbeddedBrowserHost? host = _embeddedBrowserHost;
    _embeddedBrowserHost = null;
    if (host == null) {
      return;
    }
    await host.dispose();
  }

  Future<void> _copyValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showNotice('$label copied');
  }

  void _showNotice(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleServerLog(String line) {
    if (!mounted) {
      return;
    }
    setState(() {
      _serverLogs.add(line);
      if (_serverLogs.length > _maxVisibleServerLogs) {
        _serverLogs.removeRange(0, _serverLogs.length - _maxVisibleServerLogs);
      }
    });
  }

  Future<void> _refreshDiagnostics() async {
    final OpencodeDiagnostics diagnostics = await _serverManager.diagnostics();
    _opencodeApiClient.setBaseUrl(diagnostics.serverUrl);
    if (!mounted) {
      return;
    }
    setState(() {
      _diagnostics = diagnostics;
    });
  }

  Future<void> _copyServerLogs() async {
    if (_serverLogs.isEmpty) {
      _showNotice('OpenCode logs are not available yet.');
      return;
    }
    await _copyValue('OpenCode logs', _serverLogs.join('\n'));
  }

  Future<_ProviderCatalogResult> _loadProviderCatalog(String providerId) async {
    final String? serverUrl = await _serverManager.start();
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      throw Exception(
        _serverManager.lastError ??
            'Unable to start the local OpenCode server.',
      );
    }

    _opencodeApiClient.setBaseUrl(serverUrl);
    final Map<String, dynamic> providers =
        await _opencodeApiClient.getProviders();
    final List<dynamic> allProviders =
        providers['all'] as List<dynamic>? ?? const <dynamic>[];
    final Map<String, dynamic> defaultModels =
        (providers['default'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final List<String> connectedProviders =
        ((providers['connected'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic item) => '$item'.trim())
            .where((String item) => item.isNotEmpty)
            .toList();

    for (final dynamic item in allProviders) {
      if (item is! Map) {
        continue;
      }
      final Map<String, dynamic> provider = item.cast<String, dynamic>();
      if ('${provider['id'] ?? ''}'.trim() != providerId) {
        continue;
      }
      final Map<String, dynamic> models =
          (provider['models'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final List<String> modelIds = models.keys.toList()..sort();
      return _ProviderCatalogResult(
        providerId: providerId,
        models: modelIds,
        defaultModel: '${defaultModels[providerId] ?? ''}'.trim(),
        connected: connectedProviders.contains(providerId),
      );
    }

    return _ProviderCatalogResult(
      providerId: providerId,
      models: const <String>[],
      defaultModel: '${defaultModels[providerId] ?? ''}'.trim(),
      connected: connectedProviders.contains(providerId),
    );
  }

  Future<String> _runConnectionSmokeTest(String providerId) async {
    final String? serverUrl = await _serverManager.start();
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      throw Exception(
        _serverManager.lastError ??
            'Unable to start the local OpenCode server.',
      );
    }

    _opencodeApiClient.setBaseUrl(serverUrl);
    final Map<String, dynamic> health = await _opencodeApiClient.health();
    final _ProviderCatalogResult catalog =
        await _loadProviderCatalog(providerId);
    final bool healthy = health['healthy'] == true ||
        health['version'] != null ||
        health.isNotEmpty;
    final String version = '${health['version'] ?? 'unknown'}';
    final String providerStatus = catalog.connected
        ? 'provider is connected'
        : catalog.models.isNotEmpty
            ? 'provider is available but not yet connected'
            : 'provider is not listed by OpenCode';
    return healthy
        ? 'Sidecar healthy ($version); $providerStatus.'
        : 'OpenCode responded unexpectedly; $providerStatus.';
  }

  Future<void> _openSettingsDialog() async {
    final CodingAgentConfigBundle bundle = await _configService.loadBundle();
    if (!mounted) {
      return;
    }

    final _SettingsDialogResult? result =
        await showDialog<_SettingsDialogResult>(
      context: context,
      builder: (BuildContext context) {
        String selectedProviderId = bundle.config.selectedProviderId;
        List<CodingAgentProviderProfile> profiles =
            List<CodingAgentProviderProfile>.from(bundle.config.providers);
        final Map<String, String> apiKeys = Map<String, String>.from(
          bundle.secrets.apiKeys,
        );
        final TextEditingController modelController = TextEditingController(
          text: bundle.config.defaultModel.isNotEmpty
              ? bundle.config.defaultModel
              : (bundle.config.selectedProvider?.defaultModel ?? ''),
        );
        final TextEditingController agentController = TextEditingController(
          text: bundle.config.defaultAgent,
        );
        final TextEditingController baseUrlController = TextEditingController(
          text: bundle.config.selectedProvider?.baseUrl ?? '',
        );
        final TextEditingController apiKeyController = TextEditingController(
          text: apiKeys[selectedProviderId] ?? '',
        );
        CodingAgentPermissionMode permissionMode =
            bundle.config.defaultPermissionMode;
        bool autoStartSidecar = bundle.config.autoStartSidecar;
        bool busy = false;
        String statusMessage = '';

        void syncControllersForProvider(String providerId) {
          final CodingAgentProviderProfile profile = profiles.firstWhere(
            (CodingAgentProviderProfile item) => item.id == providerId,
            orElse: () => profiles.first,
          );
          baseUrlController.text = profile.baseUrl;
          apiKeyController.text = apiKeys[providerId] ?? '';
          if (modelController.text.trim().isEmpty) {
            modelController.text = profile.defaultModel;
          }
        }

        syncControllersForProvider(selectedProviderId);

        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            Future<void> refreshModels() async {
              setDialogState(() {
                busy = true;
                statusMessage = 'Refreshing models from the current sidecar...';
              });
              try {
                final CodingAgentProviderProfile currentProfile =
                    profiles.firstWhere(
                  (CodingAgentProviderProfile item) =>
                      item.id == selectedProviderId,
                );
                final _ProviderCatalogResult catalog =
                    await _loadProviderCatalog(
                  currentProfile.providerId,
                );
                profiles = profiles.map((CodingAgentProviderProfile item) {
                  if (item.id != selectedProviderId) {
                    return item;
                  }
                  return item.copyWith(
                    availableModels: catalog.models,
                    defaultModel: catalog.defaultModel.isNotEmpty
                        ? catalog.defaultModel
                        : item.defaultModel,
                  );
                }).toList();
                if (modelController.text.trim().isEmpty &&
                    catalog.defaultModel.isNotEmpty) {
                  modelController.text = catalog.defaultModel;
                }
                setDialogState(() {
                  statusMessage = catalog.models.isEmpty
                      ? 'No models were returned for ${currentProfile.label}.'
                      : 'Loaded ${catalog.models.length} models for ${currentProfile.label}.';
                });
              } catch (error) {
                setDialogState(() {
                  statusMessage = 'Unable to refresh models: $error';
                });
              } finally {
                setDialogState(() {
                  busy = false;
                });
              }
            }

            Future<void> testConnection() async {
              setDialogState(() {
                busy = true;
                statusMessage =
                    'Testing the currently applied sidecar config...';
              });
              try {
                final CodingAgentProviderProfile currentProfile =
                    profiles.firstWhere(
                  (CodingAgentProviderProfile item) =>
                      item.id == selectedProviderId,
                );
                final String result = await _runConnectionSmokeTest(
                  currentProfile.providerId,
                );
                setDialogState(() {
                  statusMessage = result;
                });
              } catch (error) {
                setDialogState(() {
                  statusMessage = 'Connection test failed: $error';
                });
              } finally {
                setDialogState(() {
                  busy = false;
                });
              }
            }

            final CodingAgentProviderProfile selectedProfile =
                profiles.firstWhere(
              (CodingAgentProviderProfile item) =>
                  item.id == selectedProviderId,
              orElse: () => profiles.first,
            );
            final String modelHint = selectedProfile.availableModels.isEmpty
                ? 'Enter a model id like `openai/gpt-5`.'
                : 'Known models: ${selectedProfile.availableModels.take(5).join(', ')}'
                    '${selectedProfile.availableModels.length > 5 ? '...' : ''}';

            return AlertDialog(
              title: const Text('Coding Agent Settings'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedProviderId,
                        decoration: const InputDecoration(
                          labelText: 'Provider / Gateway',
                        ),
                        items: profiles
                            .map(
                              (CodingAgentProviderProfile item) =>
                                  DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (String? value) {
                                if (value == null || value.isEmpty) {
                                  return;
                                }
                                setDialogState(() {
                                  apiKeys[selectedProviderId] =
                                      apiKeyController.text.trim();
                                  selectedProviderId = value;
                                  syncControllersForProvider(value);
                                  statusMessage = '';
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Stored in app-managed secrets.json',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'Optional custom endpoint or gateway URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: modelController,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: 'Default Model',
                          helperText: modelHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: agentController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Default Agent',
                          hintText: 'Examples: build, plan',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CodingAgentPermissionMode>(
                        initialValue: permissionMode,
                        decoration: const InputDecoration(
                          labelText: 'Permission Mode',
                        ),
                        items: const <DropdownMenuItem<
                            CodingAgentPermissionMode>>[
                          DropdownMenuItem<CodingAgentPermissionMode>(
                            value: CodingAgentPermissionMode.manual,
                            child: Text('Manual approvals'),
                          ),
                          DropdownMenuItem<CodingAgentPermissionMode>(
                            value: CodingAgentPermissionMode.always,
                            child: Text('Allow by default'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (CodingAgentPermissionMode? value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  permissionMode = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: autoStartSidecar,
                        onChanged: busy
                            ? null
                            : (bool value) {
                                setDialogState(() {
                                  autoStartSidecar = value;
                                });
                              },
                        title: const Text('Auto-start bundled OpenCode'),
                        subtitle: const Text(
                          'When enabled, Arcane Forge starts the managed sidecar automatically when the screen loads.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: busy ? null : refreshModels,
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('Refresh Models'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : testConnection,
                            icon: const Icon(Icons.monitor_heart_outlined),
                            label: const Text('Test Connection'),
                          ),
                        ],
                      ),
                      if (statusMessage.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          statusMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          apiKeys[selectedProviderId] =
                              apiKeyController.text.trim();
                          final List<CodingAgentProviderProfile> nextProfiles =
                              profiles.map((CodingAgentProviderProfile item) {
                            if (item.id != selectedProviderId) {
                              return item;
                            }
                            return item.copyWith(
                              baseUrl: baseUrlController.text.trim(),
                              defaultModel: modelController.text.trim(),
                            );
                          }).toList();
                          final CodingAgentGlobalConfig nextConfig =
                              bundle.config.copyWith(
                            autoStartSidecar: autoStartSidecar,
                            selectedProviderId: selectedProviderId,
                            defaultModel: modelController.text.trim(),
                            defaultAgent: agentController.text.trim(),
                            defaultPermissionMode: permissionMode,
                            providers: nextProfiles,
                          );
                          final CodingAgentSecretConfig nextSecrets =
                              bundle.secrets.copyWith(
                            apiKeys: Map<String, String>.from(apiKeys)
                              ..removeWhere(
                                (String _, String value) =>
                                    value.trim().isEmpty,
                              ),
                          );
                          Navigator.of(context).pop(
                            _SettingsDialogResult(
                              config: nextConfig,
                              secrets: nextSecrets,
                            ),
                          );
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await _configService.saveBundle(result.config, result.secrets);
    if (!mounted) {
      return;
    }
    _showNotice('Coding Agent settings saved.');
    if (_workspacePath != null && _workspacePath!.trim().isNotEmpty) {
      await _connectToOpencode(
        loadingMessage: 'Applying Coding Agent settings...',
      );
    } else {
      await _refreshDiagnostics();
    }
  }

  Future<void> _runGame() async {
    final String? workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showNotice('Set a workspace folder before running the game.');
      return;
    }
    if (kIsWeb) {
      _showNotice('Run Game is desktop-only.');
      return;
    }

    final String escapedPath = workspacePath.replaceAll('"', r'\"');
    try {
      if (Platform.isMacOS) {
        final String script =
            'tell application "Terminal" to do script "cd \\"$escapedPath\\" && make run-game"';
        await Process.start('osascript', <String>['-e', script]);
      } else if (Platform.isWindows) {
        await Process.start('cmd', <String>[
          '/c',
          'start',
          'cmd',
          '/k',
          'cd /d "$escapedPath" && make run-game',
        ]);
      } else {
        final String command = 'cd "$escapedPath" && make run-game';
        final List<List<String>> launchAttempts = <List<String>>[
          <String>['x-terminal-emulator', '-e', 'bash', '-lc', command],
          <String>['gnome-terminal', '--', 'bash', '-lc', command],
          <String>['konsole', '-e', 'bash', '-lc', command],
        ];
        bool launched = false;
        for (final List<String> args in launchAttempts) {
          try {
            await Process.start(args.first, args.sublist(1));
            launched = true;
            break;
          } catch (_) {}
        }
        if (!launched) {
          throw Exception(
            'Unable to find a supported terminal launcher on this system.',
          );
        }
      }
      _showNotice('Launching `make run-game` in external terminal.');
    } catch (error) {
      _showNotice('Run Game failed to launch: $error');
    }
  }

  Future<void> _openWorkspaceFolder() async {
    final String? workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showNotice('Set a workspace folder first.');
      return;
    }
    if (kIsWeb) {
      _showNotice('Open Folder is desktop-only.');
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.start('open', <String>[workspacePath]);
      } else if (Platform.isWindows) {
        await Process.start('explorer', <String>[workspacePath]);
      } else {
        final List<List<String>> launchAttempts = <List<String>>[
          <String>['xdg-open', workspacePath],
          <String>['gio', 'open', workspacePath],
        ];
        bool opened = false;
        for (final List<String> args in launchAttempts) {
          try {
            await Process.start(args.first, args.sublist(1));
            opened = true;
            break;
          } catch (_) {}
        }
        if (!opened) {
          throw Exception('No supported file manager launcher found.');
        }
      }
      _showNotice('Opened workspace folder.');
    } catch (error) {
      _showNotice('Failed to open workspace folder: $error');
    }
  }

  Future<void> _pullKbDocs() async {
    final String? workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showNotice('Set a workspace folder before pulling KB docs.');
      return;
    }
    if (_isSyncingDocs) {
      return;
    }

    if (mounted) {
      setState(() {
        _kbSyncOperation = _KbSyncOperation.pulling;
      });
    }

    try {
      final KbPullResult result =
          await _kbDocsSyncService.pullKnowledgeBaseDocs(
        projectId: widget.projectId,
        workspacePath: workspacePath,
        projectName: widget.projectName,
      );
      if (result.failed.isNotEmpty ||
          result.skippedNoStorage.isNotEmpty ||
          result.skippedCollision.isNotEmpty) {
        _showNotice(
          'KB pull finished with issues: downloaded ${result.downloaded.length}, no storage ${result.skippedNoStorage.length}, collisions ${result.skippedCollision.length}, failed ${result.failed.length}. Local deletions do not affect the knowledge base.',
        );
      } else {
        _showNotice(
          'KB pull complete: downloaded ${result.downloaded.length}. Local deletions do not affect the knowledge base.',
        );
      }
    } catch (error) {
      _showNotice('KB pull failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _kbSyncOperation = _KbSyncOperation.idle;
        });
      }
    }
  }

  Future<void> _pushKbDocs() async {
    final String? workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showNotice('Set a workspace folder before pushing KB docs.');
      return;
    }
    if (_isSyncingDocs) {
      return;
    }

    if (mounted) {
      setState(() {
        _kbSyncOperation = _KbSyncOperation.pushing;
      });
    }

    try {
      final KbPushResult result =
          await _kbDocsSyncService.pushKnowledgeBaseDocs(
        projectId: widget.projectId,
        workspacePath: workspacePath,
        projectName: widget.projectName,
      );
      if (result.failed.isNotEmpty || result.skippedConflicts.isNotEmpty) {
        _showNotice(
          'KB push finished with issues: uploaded ${result.uploaded.length}, unchanged ${result.skippedUnchanged.length}, conflicts ${result.skippedConflicts.length}, failed ${result.failed.length}. Local deletions do not delete KB entries.',
        );
      } else {
        _showNotice(
          'KB push complete: uploaded ${result.uploaded.length}, unchanged ${result.skippedUnchanged.length}. Local deletions do not delete KB entries.',
        );
      }
    } catch (error) {
      _showNotice('KB push failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _kbSyncOperation = _KbSyncOperation.idle;
        });
      }
    }
  }

  Future<void> _showKbSyncStatus() async {
    final String? workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      _showNotice('Set a workspace folder before viewing KB sync status.');
      return;
    }

    try {
      final KbSyncStatus status =
          await _kbDocsSyncService.getKnowledgeBaseSyncStatus(
        projectId: widget.projectId,
        workspacePath: workspacePath,
        projectName: widget.projectName,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('KB Sync Status'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildStatusLine(
                      'Project',
                      status.projectName.trim().isNotEmpty
                          ? '${status.projectName} (${status.projectId})'
                          : status.projectId,
                    ),
                    _buildStatusLine(
                      'Local Files',
                      '${status.localFiles}',
                    ),
                    _buildStatusLine(
                      'Online KB Docs',
                      '${status.remoteActiveFiles}',
                    ),
                    _buildStatusLine(
                      'Tracked Files',
                      '${status.trackedFiles}',
                    ),
                    _buildStatusLine(
                      'In Sync',
                      '${status.inSyncCount}',
                    ),
                    _buildStatusLine(
                      'Last Pull',
                      _formatKbSyncTimestamp(status.lastPullAt),
                    ),
                    _buildStatusLine(
                      'Last Push',
                      _formatKbSyncTimestamp(status.lastPushAt),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Heuristic comparison based on your last synced hashes and the current active online KB documents.',
                    ),
                    const SizedBox(height: 12),
                    _buildStatusSection(
                      'Likely Safe to Push',
                      status.needsPushCount,
                      status.needsPushExamples,
                      emptyMessage: 'No local-only changes detected.',
                    ),
                    _buildStatusSection(
                      'Likely Safe to Pull',
                      status.needsPullCount,
                      status.needsPullExamples,
                      emptyMessage: 'No remote-only changes detected.',
                    ),
                    _buildStatusSection(
                      'Needs Review',
                      status.needsReviewCount,
                      status.needsReviewExamples,
                      emptyMessage: 'No conflicts or ambiguous cases detected.',
                    ),
                    _buildStatusSection(
                      'Online Not Ready',
                      status.remoteUnavailableCount,
                      status.remoteUnavailableExamples,
                      emptyMessage:
                          'No online KB documents are waiting on storage or processing.',
                    ),
                    const Divider(height: 24),
                    _buildStatusLine('Workspace', status.workspacePath),
                    _buildStatusLine('KB Directory', status.kbDirectoryPath),
                    _buildStatusLine('Manifest', status.manifestPath),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      _showNotice('Unable to load KB sync status: $error');
    }
  }

  void _handleKbSyncMenuAction(_KbSyncMenuAction action) {
    switch (action) {
      case _KbSyncMenuAction.pull:
        unawaited(_pullKbDocs());
        return;
      case _KbSyncMenuAction.push:
        unawaited(_pushKbDocs());
        return;
      case _KbSyncMenuAction.status:
        unawaited(_showKbSyncStatus());
        return;
    }
  }

  String _formatKbSyncTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Never';
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return parsed.toLocal().toString();
  }

  Widget _buildStatusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }

  Widget _buildStatusSection(
    String label,
    int count,
    List<String> examples, {
    required String emptyMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText('$count item${count == 1 ? '' : 's'}'),
          const SizedBox(height: 4),
          if (examples.isEmpty)
            Text(emptyMessage)
          else
            ...examples.map(
              (String example) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText('• $example'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKbSyncButton(bool supported) {
    final bool enabled = supported && _workspacePath != null && !_isSyncingDocs;
    return PopupMenuButton<_KbSyncMenuAction>(
      enabled: enabled,
      tooltip: 'KB sync actions',
      onSelected: _handleKbSyncMenuAction,
      itemBuilder: (BuildContext context) =>
          const <PopupMenuEntry<_KbSyncMenuAction>>[
        PopupMenuItem<_KbSyncMenuAction>(
          value: _KbSyncMenuAction.pull,
          child: Text('Pull from KB'),
        ),
        PopupMenuItem<_KbSyncMenuAction>(
          value: _KbSyncMenuAction.push,
          child: Text('Push to KB'),
        ),
        PopupMenuDivider(),
        PopupMenuItem<_KbSyncMenuAction>(
          value: _KbSyncMenuAction.status,
          child: Text('Show Sync Status'),
        ),
      ],
      child: AbsorbPointer(
        child: FilledButton.tonalIcon(
          onPressed: enabled ? () {} : null,
          icon: Icon(
            _isSyncingDocs ? Icons.sync : Icons.library_books_outlined,
          ),
          label: Text(_kbSyncButtonLabel),
        ),
      ),
    );
  }

  String get _viewStatusLabel {
    switch (_state) {
      case _OpencodeViewState.loading:
        return 'Loading';
      case _OpencodeViewState.ready:
        return 'Ready';
      case _OpencodeViewState.error:
        return 'Error';
      case _OpencodeViewState.unsupported:
        return 'Unsupported';
      case _OpencodeViewState.workspaceSetup:
        return 'Select Workspace';
    }
  }

  String _binarySourceLabel(OpencodeBinarySource source) {
    switch (source) {
      case OpencodeBinarySource.override:
        return 'Override';
      case OpencodeBinarySource.bundledInstalled:
        return 'Bundled';
      case OpencodeBinarySource.systemPath:
        return 'PATH fallback';
      case OpencodeBinarySource.missing:
        return 'Missing';
    }
  }

  String _configSyncLabel(OpencodeConfigSyncState state) {
    switch (state) {
      case OpencodeConfigSyncState.idle:
        return 'Pending';
      case OpencodeConfigSyncState.applied:
        return 'Applied';
      case OpencodeConfigSyncState.failed:
        return 'Failed';
    }
  }

  String _buildEmbeddedBrowserErrorMessage(String description) {
    final StringBuffer buffer = StringBuffer(
      'Unable to load ${_currentUrl.isNotEmpty ? _currentUrl : 'the local OpenCode page'}.',
    );
    if (description.trim().isNotEmpty) {
      buffer.write(' ${description.trim()}');
    }
    final String? launcherError = _serverManager.lastError;
    if (launcherError != null &&
        launcherError.trim().isNotEmpty &&
        launcherError.trim() != description.trim()) {
      buffer.write(' $launcherError');
    }
    buffer.write(' Use Retry to reconnect to the local server.');
    return buffer.toString();
  }

  void _handleEmbeddedBrowserUrlChanged(String url) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUrl = url;
    });
  }

  void _handleEmbeddedBrowserLoadError(String description) {
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _OpencodeViewState.error;
      _errorMessage = _buildEmbeddedBrowserErrorMessage(description);
    });
  }

  Future<void> _pickWorkspaceDirectory() async {
    if (kIsWeb) {
      return;
    }

    final String? selected = Platform.isMacOS
        ? await file_selector.getDirectoryPath(
            confirmButtonText: 'Select Folder',
            canCreateDirectories: true,
          )
        : await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Select workspace folder for ${widget.projectName}',
          );

    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    try {
      await _workspaceService.setWorkspacePath(widget.projectId, selected);
      if (!mounted) {
        return;
      }
      setState(() {
        _workspacePath = selected;
      });
      await _connectToOpencode();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _OpencodeViewState.error;
        _errorMessage = 'Failed to set workspace folder: $error';
      });
    }
  }

  Future<void> _openInBrowser() async {
    final Uri? current = Uri.tryParse(_currentUrl);
    final Uri? target = current ?? _serverBaseUrl;
    if (target == null) {
      _showNotice('OpenCode is not connected yet.');
      return;
    }
    await _launchExternally(target);
  }

  Future<void> _launchExternally(Uri target) async {
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }

  Future<void> _restartManagedServer() async {
    if (!_showsManagedServerActions) {
      return;
    }
    await _serverManager.stop();
    await _refreshDiagnostics();
    if (!mounted) {
      return;
    }
    await _connectToOpencode(loadingMessage: 'Restarting local OpenCode...');
  }

  Future<void> _stopManagedServer() async {
    if (!_showsManagedServerActions) {
      return;
    }
    await _serverManager.stop();
    await _disposeEmbeddedBrowserHost();
    await _refreshDiagnostics();
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _OpencodeViewState.error;
      _embeddedBrowserHost = null;
      _serverBaseUrl = null;
      _currentUrl = '';
      _errorMessage =
          'The app-managed OpenCode server was stopped. Use Retry to start it again.';
    });
    _showNotice('Stopped the local OpenCode server.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: _buildToolsDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context),
            const SizedBox(height: defaultPadding),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool supported = _state != _OpencodeViewState.unsupported;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Text(
            //   'Coding Agent (Beta)',
            //   style: Theme.of(context).textTheme.titleLarge,
            // ),
            // const SizedBox(height: 4),
            // Text(
            //   'Embedded Coding Agent powered by a local OpenCode web UI that Arcane Forge can start and reuse automatically.',
            //   style: Theme.of(context).textTheme.bodyMedium,
            // ),
            // const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildCopyableField(
                    context,
                    label: 'Workspace',
                    value: _workspacePath ?? 'Please select a workspace',
                    onCopy: _workspacePath == null
                        ? null
                        : () => _copyValue('Workspace path', _workspacePath!),
                    singleLineValue: true,
                    actions: <Widget>[
                      IconButton(
                        tooltip: 'Change workspace',
                        onPressed: supported ? _pickWorkspaceDirectory : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Open workspace folder',
                        onPressed: supported ? _openWorkspaceFolder : null,
                        icon: const Icon(Icons.folder_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed:
                      supported && _workspacePath != null ? _runGame : null,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Run Game'),
                ),
                const SizedBox(width: 8),
                _buildKbSyncButton(supported),
                const SizedBox(width: 8),
                // FilledButton.tonalIcon(
                //   onPressed: supported ? _openSettingsDialog : null,
                //   icon: const Icon(Icons.tune_outlined),
                //   label: const Text('Agent Settings'),
                // ),
                Builder(
                  builder: (BuildContext context) {
                    return IconButton(
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                      icon: const Icon(Icons.settings_outlined),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsDrawer() {
    final bool ready = _state == _OpencodeViewState.ready;
    final bool supported = _state != _OpencodeViewState.unsupported;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    const Color drawerPrimaryTextColor = Color(0xFFE6EDF7);
    const Color drawerSecondaryTextColor = Color(0xFFA7B2C4);
    final ThemeData drawerTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        bodyColor: drawerPrimaryTextColor,
        displayColor: drawerPrimaryTextColor,
      ),
      iconTheme: theme.iconTheme.copyWith(color: drawerSecondaryTextColor),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: drawerPrimaryTextColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: drawerPrimaryTextColor,
        ),
      ),
    );
    final TextTheme drawerTextTheme = drawerTheme.textTheme;
    final TextStyle bodySmallStyle =
        (drawerTextTheme.bodySmall ?? const TextStyle(fontSize: 12))
            .copyWith(color: drawerPrimaryTextColor);
    final TextStyle titleMediumStyle = (drawerTextTheme.titleMedium ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))
        .copyWith(color: drawerPrimaryTextColor);
    final TextStyle headlineSmallStyle = (drawerTextTheme.headlineSmall ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.w400))
        .copyWith(color: drawerPrimaryTextColor);

    return Theme(
      data: drawerTheme,
      child: Drawer(
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Utilities',
                      style: headlineSmallStyle,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.settings_outlined,
                      color: drawerSecondaryTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Utilities for the embedded Coding Agent view and local OpenCode server.',
                          style: bodySmallStyle,
                        ),
                        const SizedBox(height: 16),
                        _buildCopyableField(
                          context,
                          label: 'URL',
                          value: _visibleUrl,
                          onCopy: () => _copyValue('URL', _visibleUrl),
                          labelColor: drawerSecondaryTextColor,
                          valueColor: drawerPrimaryTextColor,
                          iconColor: drawerSecondaryTextColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Status',
                          style: titleMediumStyle,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'High-use workspace actions stay pinned in the main header for quicker access.',
                          style: bodySmallStyle,
                        ),
                        if (_diagnostics?.configSyncMessage !=
                            null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _diagnostics!.configSyncMessage!,
                            style: bodySmallStyle,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_diagnostics?.binaryPath?.trim().isNotEmpty == true)
                          _buildCopyableField(
                            context,
                            label: 'Binary Path',
                            value: _diagnostics!.binaryPath!,
                            onCopy: () => _copyValue(
                              'Binary path',
                              _diagnostics!.binaryPath!,
                            ),
                            labelColor: drawerSecondaryTextColor,
                            valueColor: drawerPrimaryTextColor,
                            iconColor: drawerSecondaryTextColor,
                          ),
                        if (_diagnostics?.installPath?.trim().isNotEmpty ==
                            true)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildCopyableField(
                              context,
                              label: 'Install Path',
                              value: _diagnostics!.installPath!,
                              onCopy: () => _copyValue(
                                'Install path',
                                _diagnostics!.installPath!,
                              ),
                              labelColor: drawerSecondaryTextColor,
                              valueColor: drawerPrimaryTextColor,
                              iconColor: drawerSecondaryTextColor,
                            ),
                          ),
                        if (_diagnostics?.installPath?.trim().isNotEmpty ==
                            true)
                          const SizedBox(height: 16),
                        Text(
                          'Web View',
                          style: titleMediumStyle,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: supported && _hasBrowserTarget
                                  ? _openInBrowser
                                  : null,
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text('Open in Browser'),
                            ),
                            OutlinedButton.icon(
                              onPressed: supported && _workspacePath != null
                                  ? _connectToOpencode
                                  : null,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Retry'),
                            ),
                            if (_showsManagedServerActions)
                              OutlinedButton.icon(
                                onPressed:
                                    supported ? _restartManagedServer : null,
                                icon: const Icon(Icons.restart_alt_outlined),
                                label: const Text('Restart OpenCode'),
                              ),
                            if (_showsManagedServerActions)
                              OutlinedButton.icon(
                                onPressed:
                                    supported ? _stopManagedServer : null,
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: const Text('Stop OpenCode'),
                              ),
                            OutlinedButton.icon(
                              onPressed: ready
                                  ? () => _embeddedBrowserHost?.reload()
                                  : null,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reload'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'OpenCode Logs',
                                style: titleMediumStyle,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _serverLogs.isNotEmpty
                                  ? _copyServerLogs
                                  : null,
                              icon: const Icon(Icons.copy_all_outlined),
                              label: const Text('Copy Logs'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Live output from `opencode serve --print-logs`.',
                          style: bodySmallStyle,
                        ),
                        const SizedBox(height: 8),
                        _buildScrollablePanel(
                          context,
                          terminalStyle: true,
                          child: _serverLogs.isEmpty
                              ? Text(
                                  'Waiting for OpenCode log output...',
                                  style: bodySmallStyle.copyWith(
                                    color: drawerSecondaryTextColor,
                                  ),
                                )
                              : SelectableText(
                                  _serverLogs.join('\n'),
                                  style: bodySmallStyle.copyWith(
                                    fontFamily: 'monospace',
                                    color: const Color(0xFFB5F5B0),
                                  ),
                                ),
                        ),
                        if (_errorMessage != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Text(
                            'Latest Error',
                            style: titleMediumStyle,
                          ),
                          const SizedBox(height: 8),
                          _buildScrollablePanel(
                            context,
                            child: SelectableText(
                              _errorMessage!,
                              style: bodySmallStyle,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Workspace switching still happens inside the embedded OpenCode UI.',
                          style: bodySmallStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _OpencodeViewState.unsupported:
        return _buildMessageCard(
          context,
          icon: Icons.desktop_windows_outlined,
          title:
              'Coding Agent (Beta) is available on macOS and Windows desktop only.',
          message:
              'This beta release embeds the local OpenCode web UI on macOS and Windows desktop.',
        );
      case _OpencodeViewState.loading:
        return Card(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding * 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Connecting to Coding Agent...',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _OpencodeViewState.workspaceSetup:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(defaultPadding * 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(defaultPadding * 1.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.folder_open,
                          size: 56, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Select Workspace Folder',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pick a folder for this project so the Coding Agent utilities can target the right workspace.',
                        textAlign: TextAlign.center,
                      ),
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _pickWorkspaceDirectory,
                        icon: const Icon(Icons.folder_outlined),
                        label: const Text('Select Folder'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case _OpencodeViewState.error:
        return Card(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(defaultPadding * 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Coding Agent could not be loaded',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ??
                      'Unable to display the embedded Coding Agent view.',
                ),
                if (_workspacePath != null) ...<Widget>[
                  const SizedBox(height: 12),
                  SelectableText('Workspace: $_workspacePath'),
                  const SizedBox(height: 12),
                  SelectableText('URL: $_visibleUrl'),
                ],
              ],
            ),
          ),
        );
      case _OpencodeViewState.ready:
        final CodingAgentEmbeddedBrowserHost? host = _embeddedBrowserHost;
        if (host == null) {
          return const SizedBox.shrink();
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: host.buildView(),
        );
    }
  }

  Widget _buildMessageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding * 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 52, color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableField(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback? onCopy,
    List<Widget> actions = const <Widget>[],
    bool singleLineValue = false,
    Color? labelColor,
    Color? valueColor,
    Color? iconColor,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color effectiveLabelColor =
        labelColor ?? colorScheme.onSurfaceVariant;
    final Color effectiveValueColor = valueColor ?? colorScheme.onSurface;
    final Color effectiveIconColor = iconColor ?? colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(
                        color: effectiveLabelColor,
                      ),
                ),
                const SizedBox(height: 4),
                if (singleLineValue)
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: effectiveValueColor),
                  )
                else
                  SelectableText(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: effectiveValueColor),
                  ),
              ],
            ),
          ),
          ...actions,
          IconButton(
            tooltip: 'Copy $label',
            onPressed: onCopy,
            icon: Icon(
              Icons.copy_all_outlined,
              color: effectiveIconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollablePanel(
    BuildContext context, {
    required Widget child,
    bool terminalStyle = false,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(16);
    final Color panelColor = terminalStyle
        ? const Color(0xFF000000)
        : colorScheme.surfaceContainerHigh;
    final Color borderColor =
        terminalStyle ? colorScheme.outline : colorScheme.outlineVariant;

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
