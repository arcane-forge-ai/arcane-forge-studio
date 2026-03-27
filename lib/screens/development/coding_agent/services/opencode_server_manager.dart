import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/coding_agent_config.dart';
import '../models/opencode_models.dart';
import 'coding_agent_config_service.dart';

class OpencodeServerManager {
  OpencodeServerManager({
    http.Client? httpClient,
    CodingAgentConfigService? configService,
    Future<Directory> Function()? supportDirectoryProvider,
    Map<String, String> Function()? environmentProvider,
    String Function()? resolvedExecutablePathProvider,
    Future<String?> Function()? systemBinaryPathResolver,
  })  : _httpClient = httpClient ?? http.Client(),
        _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory,
        _environmentProvider =
            environmentProvider ?? (() => Platform.environment),
        _resolvedExecutablePathProvider = resolvedExecutablePathProvider ??
            (() => Platform.resolvedExecutable),
        _systemBinaryPathResolver = systemBinaryPathResolver,
        _configService = configService ??
            CodingAgentConfigService(
              supportDirectoryProvider:
                  supportDirectoryProvider ?? getApplicationSupportDirectory,
            );

  static const List<int> _candidatePorts = <int>[
    4096,
    4099,
    ...<int>[4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110],
  ];
  static const String _sidecarStateFileName = 'server_state.json';
  static const String _binaryPathOverrideEnv = 'OPENCODE_BINARY_PATH';
  static const String _packagedSidecarFolderName = 'opencode_sidecar';
  static const String _packagedManifestFileName = 'manifest.json';

  final http.Client _httpClient;
  final CodingAgentConfigService _configService;
  final Future<Directory> Function() _supportDirectoryProvider;
  final Map<String, String> Function() _environmentProvider;
  final String Function() _resolvedExecutablePathProvider;
  final Future<String?> Function()? _systemBinaryPathResolver;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final List<String> _recentLogs = <String>[];

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  String? _binaryPath;
  String? _version;
  String? _serverUrl;
  String? _lastError;
  String? _installPath;
  String? _bundledVersion;
  String? _selectedProviderId;
  String? _selectedProviderLabel;
  String? _selectedModel;
  String? _configSyncMessage;
  int? _managedPid;
  bool _ownsManagedProcess = false;
  bool _credentialsPresent = false;
  OpencodeBinarySource _binarySource = OpencodeBinarySource.missing;
  OpencodeConfigSyncState _configSyncState = OpencodeConfigSyncState.idle;
  ServerLifecycleStatus _status = ServerLifecycleStatus.stopped;

  Stream<String> get logs => _logController.stream;
  List<String> get recentLogs => List<String>.unmodifiable(_recentLogs);
  String? get serverUrl => _serverUrl;
  String? get lastError => _lastError;
  bool get ownsManagedServer => _ownsManagedProcess && _serverUrl != null;
  ServerLifecycleStatus status() => _status;

  @visibleForTesting
  static List<int> get candidatePortsForTesting =>
      List<int>.unmodifiable(_candidatePorts);

  @visibleForTesting
  static bool looksLikeManagedServeCommandForTesting(String command) =>
      _looksLikeManagedServeCommand(command);

  Future<_ResolvedBinary?> _resolveBinary() async {
    if (_binaryPath != null &&
        _binaryPath!.isNotEmpty &&
        await _isExecutableFile(_binaryPath!)) {
      return _ResolvedBinary(
        binaryPath: _binaryPath!,
        source: _binarySource,
        installPath: _installPath,
        bundledVersion: _bundledVersion,
      );
    }

    final Map<String, String> environment = _environmentProvider();
    final String? envOverride = environment[_binaryPathOverrideEnv];
    if (envOverride != null && envOverride.trim().isNotEmpty) {
      final String overridePath = envOverride.trim();
      if (await _isExecutableFile(overridePath)) {
        _binaryPath = overridePath;
        _binarySource = OpencodeBinarySource.override;
        _installPath = null;
        _bundledVersion = null;
        return _ResolvedBinary(
          binaryPath: overridePath,
          source: _binarySource,
          installPath: _installPath,
          bundledVersion: _bundledVersion,
        );
      }
      _appendLog(
        'Ignoring $_binaryPathOverrideEnv because file is not executable: $overridePath',
      );
    }

    try {
      final _PackagedSidecarBundle? bundle = await _packagedSidecarBundle();
      if (bundle != null) {
        final _ResolvedBinary installed = await _resolveOrInstallBundledBinary(
          bundle,
        );
        _binaryPath = installed.binaryPath;
        _binarySource = installed.source;
        _installPath = installed.installPath;
        _bundledVersion = installed.bundledVersion;
        return installed;
      }
    } on _BundledSidecarException catch (error) {
      _binarySource = OpencodeBinarySource.missing;
      _lastError = 'Bundled OpenCode install failed: ${error.message}';
      _appendLog(_lastError!);
      return null;
    }

    final String? systemBinary =
        await (_systemBinaryPathResolver?.call() ?? _resolveSystemBinaryPath());
    if (systemBinary != null && await _isExecutableFile(systemBinary)) {
      _binaryPath = systemBinary;
      _binarySource = OpencodeBinarySource.systemPath;
      _installPath = null;
      _bundledVersion = null;
      return _ResolvedBinary(
        binaryPath: systemBinary,
        source: _binarySource,
        installPath: _installPath,
        bundledVersion: _bundledVersion,
      );
    }

    _binaryPath = null;
    _binarySource = OpencodeBinarySource.missing;
    return null;
  }

  Future<String?> _resolveBinaryPath() async {
    final _ResolvedBinary? resolved = await _resolveBinary();
    return resolved?.binaryPath;
  }

  Future<String?> _resolveVersion() async {
    if (_version != null && _version!.isNotEmpty) {
      return _version;
    }

    final String? binaryPath = await _resolveBinaryPath();
    if (binaryPath == null) {
      return null;
    }

    try {
      _version = await _verifyBinaryAndReadVersion(binaryPath);
    } catch (error) {
      _appendLog('Failed to read OpenCode version: $error');
    }
    return _version;
  }

  Future<String?> start() async {
    if (_serverUrl != null) {
      final Map<String, dynamic>? health = await _safeGetJson('/global/health');
      if (health != null) {
        return _serverUrl;
      }
    }

    final _ResolvedBinary? binary = await _resolveBinary();
    await _resolveVersion();
    if (binary == null) {
      _status = ServerLifecycleStatus.failed;
      _lastError = _lastError ??
          'Bundled OpenCode is unavailable in this build, and no development `opencode` binary was found in PATH. Set $_binaryPathOverrideEnv or package the sidecar.';
      return null;
    }

    final PreparedCodingAgentConfig preparedConfig;
    try {
      preparedConfig = await _configService.prepareRuntimeConfig();
      _selectedProviderId = preparedConfig.runtimeConfig.selectedProviderId;
      _selectedProviderLabel =
          preparedConfig.runtimeConfig.selectedProviderLabel;
      _selectedModel = preparedConfig.runtimeConfig.selectedModel;
      _credentialsPresent = preparedConfig.runtimeConfig.credentialsPresent;
      _configSyncState = OpencodeConfigSyncState.idle;
      _configSyncMessage = 'Prepared app-managed OpenCode configuration.';
    } catch (error) {
      _status = ServerLifecycleStatus.failed;
      _lastError =
          'Failed to prepare the bundled OpenCode configuration: $error';
      _appendLog(_lastError!);
      return null;
    }

    await stop();
    await _stopLingeringManagedSidecars();

    _status = ServerLifecycleStatus.starting;
    _lastError = null;

    for (final int port in _candidatePorts) {
      final bool started = await _startOnPort(
        binary.binaryPath,
        port,
        preparedConfig,
      );
      if (started) {
        await _verifyRuntimeConfig(preparedConfig);
        return _serverUrl;
      }
    }

    _status = ServerLifecycleStatus.failed;
    _lastError ??= 'Unable to start OpenCode on ports 4096 or 4099-4110.';
    return null;
  }

  Future<bool> _startOnPort(
    String binaryPath,
    int port,
    PreparedCodingAgentConfig preparedConfig,
  ) async {
    await stop();
    _appendLog('Starting bundled OpenCode on port $port');

    final Completer<bool> ready = Completer<bool>();
    final RegExp readyPattern = RegExp(
      r'opencode server listening on (http://127\.0\.0\.1:\d+)',
    );
    final Completer<void> exited = Completer<void>();

    final Map<String, String> environment = <String, String>{
      ..._environmentProvider(),
      ...preparedConfig.runtimeConfig.environment,
      'OPENCODE_CONFIG': preparedConfig.configFilePath,
    };

    try {
      _process = await Process.start(
        binaryPath,
        <String>[
          'serve',
          '--hostname',
          '127.0.0.1',
          '--port',
          '$port',
          '--print-logs',
        ],
        environment: environment,
      );
    } catch (error) {
      _lastError = 'Failed to launch bundled OpenCode: $error';
      _appendLog(_lastError!);
      return false;
    }

    void handleLine(String line) {
      _appendLog(line);
      final RegExpMatch? match = readyPattern.firstMatch(line);
      if (match != null && !ready.isCompleted) {
        _serverUrl = match.group(1);
        _status = ServerLifecycleStatus.running;
        ready.complete(true);
        return;
      }

      if ((line.contains('Failed to start server on port') ||
              line.contains('Unexpected error')) &&
          !ready.isCompleted) {
        _lastError = line;
        ready.complete(false);
      }
    }

    _stdoutSubscription = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);
    _stderrSubscription = _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);

    unawaited(
      _process!.exitCode.then((int _) {
        if (!ready.isCompleted) {
          ready.complete(false);
        }
        if (!exited.isCompleted) {
          exited.complete();
        }
      }),
    );

    final bool started = await ready.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _lastError = 'Timed out waiting for OpenCode to report readiness.';
        return false;
      },
    );

    if (started) {
      _managedPid = _process?.pid;
      _ownsManagedProcess = true;
      await _writeSidecarState(
        _SidecarState(pid: _managedPid, url: _serverUrl!),
      );
      return true;
    }

    await stop();
    await exited.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {},
    );
    return false;
  }

  Future<void> _verifyRuntimeConfig(
    PreparedCodingAgentConfig preparedConfig,
  ) async {
    final Map<String, dynamic>? effectiveConfig = await _safeGetJson('/config');
    if (effectiveConfig == null) {
      _configSyncState = OpencodeConfigSyncState.failed;
      _configSyncMessage =
          'OpenCode started, but Arcane Forge could not verify /config.';
      return;
    }

    final CodingAgentRuntimeConfig runtimeConfig = preparedConfig.runtimeConfig;
    final bool modelMatches = runtimeConfig.selectedModel == null ||
        effectiveConfig['model'] == runtimeConfig.selectedModel;
    final bool providerMatches = runtimeConfig.selectedProviderId == null ||
        ((effectiveConfig['provider'] as Map<String, dynamic>?) ??
                <String, dynamic>{})
            .containsKey(runtimeConfig.selectedProviderId);

    if (modelMatches && providerMatches) {
      _configSyncState = OpencodeConfigSyncState.applied;
      _configSyncMessage =
          'Arcane Forge applied its app-managed OpenCode configuration.';
      return;
    }

    _configSyncState = OpencodeConfigSyncState.failed;
    _configSyncMessage =
        'OpenCode is running, but the effective config does not match Arcane Forge settings.';
  }

  Future<void> _stopLingeringManagedSidecars() async {
    final Set<int> candidatePids = <int>{};
    final _SidecarState? savedState = await _readSidecarState();
    if (savedState?.pid != null) {
      candidatePids.add(savedState!.pid!);
    }
    candidatePids.addAll(await _findManagedSidecarPids());

    if (candidatePids.isEmpty) {
      await _clearSidecarState();
      return;
    }

    final List<int> sortedPids = candidatePids.toList()..sort();
    _appendLog('Stopping lingering OpenCode sidecar(s): $sortedPids.');
    for (final int pid in sortedPids) {
      await _terminatePidIfManagedSidecar(pid);
    }
    await _clearSidecarState();
  }

  Future<void> stop() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    final int? managedPid = _managedPid;
    final bool ownsManagedProcess = _ownsManagedProcess;
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      try {
        await _process!.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        _process!.kill(ProcessSignal.sigkill);
      }
    } else if (shouldTerminateManagedPid(
      ownsManagedProcess: ownsManagedProcess,
      managedPid: managedPid,
    )) {
      await _terminatePidIfManaged(managedPid!);
    }

    if (ownsManagedProcess) {
      await _clearSidecarState();
    }

    _process = null;
    _serverUrl = null;
    _managedPid = null;
    _ownsManagedProcess = false;
    if (_status != ServerLifecycleStatus.failed) {
      _status = ServerLifecycleStatus.stopped;
    }
  }

  @visibleForTesting
  static bool shouldTerminateManagedPid({
    required bool ownsManagedProcess,
    required int? managedPid,
  }) {
    return ownsManagedProcess && managedPid != null;
  }

  Future<OpencodeDiagnostics> diagnostics() async {
    final String? binaryPath = await _resolveBinaryPath();
    final String? version = await _resolveVersion();
    bool serverReachable = false;
    bool providerReady = false;
    String? healthVersion;
    String? healthError;
    String? providerSummary;
    final int? sidecarPid = _process?.pid ?? _managedPid;
    final int? sidecarResidentMb =
        sidecarPid == null ? null : await _readResidentMemoryMb(sidecarPid);

    if (_serverUrl != null) {
      final Map<String, dynamic>? health = await _safeGetJson('/global/health');
      if (health != null) {
        serverReachable = health['healthy'] == true || health.isNotEmpty;
        healthVersion = health['version'] as String?;
      } else {
        healthError = 'Unable to reach /global/health';
      }

      final Map<String, dynamic>? providerResponse = await _safeGetJson(
        '/provider',
      );
      if (providerResponse != null) {
        final List<dynamic> connected =
            providerResponse['connected'] as List<dynamic>? ??
                const <dynamic>[];
        providerReady = connected.isNotEmpty;
        providerSummary = '${connected.length} connected provider entries';
      } else {
        final Map<String, dynamic>? configProviders = await _safeGetJson(
          '/config/providers',
        );
        if (configProviders != null) {
          final List<dynamic> providers =
              configProviders['providers'] as List<dynamic>? ??
                  const <dynamic>[];
          providerReady = providers.isNotEmpty;
          providerSummary = '${providers.length} configured provider entries';
        }
      }
    }

    return OpencodeDiagnostics(
      status: _status,
      binaryDetected: binaryPath != null,
      binarySource: _binarySource,
      serverReachable: serverReachable,
      providerReady: providerReady,
      recentLogs: List<String>.unmodifiable(
        _recentLogs.reversed.take(80).toList(),
      ),
      binaryPath: binaryPath,
      version: version,
      serverUrl: _serverUrl,
      healthVersion: healthVersion,
      healthError: healthError,
      providerSummary: providerSummary,
      lastError: _lastError,
      sidecarPid: sidecarPid,
      sidecarResidentMb: sidecarResidentMb,
      sidecarManaged: _ownsManagedProcess,
      installPath: _installPath,
      bundledVersion: _bundledVersion,
      selectedProviderId: _selectedProviderId,
      selectedProviderLabel: _selectedProviderLabel,
      selectedModel: _selectedModel,
      credentialsPresent: _credentialsPresent,
      configSyncState: _configSyncState,
      configSyncMessage: _configSyncMessage,
    );
  }

  Future<Map<String, dynamic>?> _safeGetJson(String path) async {
    final dynamic response = await _safeGet(path);
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<dynamic> _safeGet(String path) async {
    if (_serverUrl == null) {
      return null;
    }

    try {
      final Uri uri = Uri.parse('$_serverUrl$path');
      final http.Response response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } catch (error) {
      _appendLog('Diagnostics request failed for $path: $error');
      return null;
    }
  }

  void _appendLog(String line) {
    _recentLogs.add(line);
    if (_recentLogs.length > 300) {
      _recentLogs.removeAt(0);
    }
    if (!_logController.isClosed) {
      _logController.add(line);
    }
  }

  Future<void> detach() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process = null;
    _serverUrl = null;
    _managedPid = null;
    _ownsManagedProcess = false;
    if (_status != ServerLifecycleStatus.failed) {
      _status = ServerLifecycleStatus.stopped;
    }
  }

  Future<void> dispose({bool stopServer = true}) async {
    if (stopServer) {
      await stop();
    } else {
      await detach();
    }
    await _logController.close();
    _httpClient.close();
  }

  Future<Directory> _sidecarRootDirectory() async {
    final Directory supportDirectory = await _supportDirectoryProvider();
    return Directory(p.join(supportDirectory.path, 'opencode_sidecar'));
  }

  Future<File> _sidecarStateFile() async {
    final Directory rootDirectory = await _sidecarRootDirectory();
    if (!await rootDirectory.exists()) {
      await rootDirectory.create(recursive: true);
    }
    return File(p.join(rootDirectory.path, _sidecarStateFileName));
  }

  Future<void> _writeSidecarState(_SidecarState state) async {
    try {
      final File file = await _sidecarStateFile();
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'pid': state.pid,
          'url': state.url,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (error) {
      _appendLog('Failed to write sidecar state: $error');
    }
  }

  Future<_SidecarState?> _readSidecarState() async {
    try {
      final File file = await _sidecarStateFile();
      if (!await file.exists()) {
        return null;
      }
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final dynamic pidValue = decoded['pid'];
      final int? pid =
          pidValue is int ? pidValue : int.tryParse('${pidValue ?? ''}');
      final String? url = decoded['url'] as String?;
      if (url == null || url.isEmpty) {
        return null;
      }
      return _SidecarState(pid: pid, url: url);
    } catch (error) {
      _appendLog('Failed to read sidecar state: $error');
      return null;
    }
  }

  Future<void> _clearSidecarState() async {
    try {
      final File file = await _sidecarStateFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      _appendLog('Failed to clear sidecar state: $error');
    }
  }

  Future<bool> _terminatePidIfManaged(int pid) async {
    if (!await _looksLikeOpencodeProcess(pid)) {
      _appendLog('Skipping termination for PID $pid: not an OpenCode process.');
      return false;
    }

    final bool sentSigterm = Process.killPid(pid, ProcessSignal.sigterm);
    if (!sentSigterm) {
      return false;
    }
    final bool exited = await _waitForPidExit(
      pid,
      timeout: const Duration(seconds: 2),
    );
    if (exited) {
      return true;
    }
    Process.killPid(pid, ProcessSignal.sigkill);
    return _waitForPidExit(pid, timeout: const Duration(seconds: 1));
  }

  Future<bool> _terminatePidIfManagedSidecar(int pid) async {
    if (!await _looksLikeManagedSidecarProcess(pid)) {
      _appendLog(
        'Skipping termination for PID $pid: not an app-managed OpenCode sidecar.',
      );
      return false;
    }
    return _terminatePidIfManaged(pid);
  }

  Future<List<int>> _findManagedSidecarPids() async {
    if (Platform.isWindows) {
      return const <int>[];
    }

    try {
      final ProcessResult result = await Process.run('/bin/ps', <String>[
        '-axo',
        'pid=,command=',
      ]);
      if (result.exitCode != 0) {
        return const <int>[];
      }

      final String stdout = result.stdout as String;
      if (stdout.trim().isEmpty) {
        return const <int>[];
      }

      final List<int> pids = <int>[];
      for (final String line in const LineSplitter().convert(stdout)) {
        final int? pid = managedSidecarPidFromPsLine(line);
        if (pid != null) {
          pids.add(pid);
        }
      }
      return pids;
    } catch (error) {
      _appendLog('Failed to inspect running OpenCode processes: $error');
      return const <int>[];
    }
  }

  @visibleForTesting
  static int? managedSidecarPidFromPsLine(String line) {
    final RegExpMatch? match =
        RegExp(r'^\s*(\d+)\s+(.*?)\s*$').firstMatch(line);
    if (match == null) {
      return null;
    }
    final int? pid = int.tryParse(match.group(1) ?? '');
    final String command = match.group(2) ?? '';
    if (pid == null || !_looksLikeManagedServeCommand(command)) {
      return null;
    }
    return pid;
  }

  static bool _looksLikeManagedServeCommand(String command) {
    final String normalized = command.toLowerCase();
    if (!normalized.contains('opencode') ||
        !normalized.contains(' serve') ||
        !normalized.contains('--print-logs') ||
        !normalized.contains('--hostname 127.0.0.1')) {
      return false;
    }

    for (final int port in _candidatePorts) {
      if (normalized.contains('--port $port')) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _isPidRunning(int pid) async {
    if (Platform.isWindows) {
      return false;
    }

    try {
      final ProcessResult result = await Process.run('/bin/kill', <String>[
        '-0',
        '$pid',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForPidExit(int pid, {required Duration timeout}) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await _isPidRunning(pid)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return !await _isPidRunning(pid);
  }

  Future<bool> _looksLikeOpencodeProcess(int pid) async {
    try {
      final String? command = await _readCommandForPid(pid);
      if (command == null) {
        return false;
      }
      final String normalized = command.toLowerCase();
      return normalized.contains('opencode') && normalized.contains('serve');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _looksLikeManagedSidecarProcess(int pid) async {
    final String? command = await _readCommandForPid(pid);
    if (command == null) {
      return false;
    }
    return _looksLikeManagedServeCommand(command);
  }

  Future<String?> _readCommandForPid(int pid) async {
    if (Platform.isWindows) {
      return null;
    }

    try {
      final ProcessResult result = await Process.run('/bin/ps', <String>[
        '-o',
        'command=',
        '-p',
        '$pid',
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      final String command = (result.stdout as String).trim();
      if (command.isEmpty) {
        return null;
      }
      return command;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readResidentMemoryMb(int pid) async {
    if (Platform.isWindows) {
      return null;
    }

    try {
      final ProcessResult result = await Process.run('/bin/ps', <String>[
        '-o',
        'rss=',
        '-p',
        '$pid',
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      final int? rssKb = int.tryParse((result.stdout as String).trim());
      if (rssKb == null) {
        return null;
      }
      return rssKb ~/ 1024;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isExecutableFile(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) {
        return false;
      }
      if (Platform.isWindows) {
        return path.toLowerCase().endsWith('.exe');
      }
      final ProcessResult result = await Process.run('/bin/test', <String>[
        '-x',
        path,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveSystemBinaryPath() async {
    if (Platform.isWindows) {
      try {
        final ProcessResult result = await Process.run('where', <String>[
          'opencode',
        ]);
        if (result.exitCode == 0) {
          final String value =
              (result.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
          return value.isEmpty ? null : value;
        }
      } catch (error) {
        _appendLog('Failed to resolve OpenCode in PATH: $error');
      }
      return null;
    }

    try {
      final ProcessResult result = await Process.run('/bin/sh', <String>[
        '-lc',
        'export PATH="\$PATH:/opt/homebrew/bin:/usr/local/bin:\$HOME/.local/bin:\$HOME/bin"; command -v opencode || which opencode',
      ]);
      if (result.exitCode == 0) {
        final String value = (result.stdout as String).split('\n').first.trim();
        return value.isEmpty ? null : value;
      }
    } catch (error) {
      _appendLog('Failed to resolve OpenCode in PATH: $error');
    }

    final List<String> candidatePaths = <String>[
      '/opt/homebrew/bin/opencode',
      '/usr/local/bin/opencode',
      '/usr/bin/opencode',
      '${_environmentProvider()['HOME'] ?? ''}/.local/bin/opencode',
      '${_environmentProvider()['HOME'] ?? ''}/bin/opencode',
    ].where((String value) => value.trim().isNotEmpty).toList();

    for (final String candidate in candidatePaths) {
      if (await _isExecutableFile(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Future<_PackagedSidecarBundle?> _packagedSidecarBundle() async {
    final Directory? packagedDirectory = _packagedSidecarDirectory();
    if (packagedDirectory == null || !await packagedDirectory.exists()) {
      return null;
    }

    final File manifestFile = File(
      p.join(packagedDirectory.path, _packagedManifestFileName),
    );
    if (!await manifestFile.exists()) {
      throw _BundledSidecarException(
        'Packaged sidecar metadata is missing at ${manifestFile.path}.',
      );
    }

    late final Map<String, dynamic> manifest;
    try {
      final dynamic decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('manifest.json must contain an object');
      }
      manifest = decoded;
    } catch (error) {
      throw _BundledSidecarException(
        'Packaged sidecar metadata is unreadable: $error',
      );
    }

    final String version = '${manifest['version'] ?? ''}'.trim();
    final String binaryName =
        '${manifest['binaryName'] ?? _sidecarBinaryFileName()}'.trim();
    if (version.isEmpty) {
      throw const _BundledSidecarException(
        'Packaged sidecar metadata is missing a version.',
      );
    }

    final File binaryFile = File(p.join(packagedDirectory.path, binaryName));
    if (!await binaryFile.exists()) {
      throw _BundledSidecarException(
        'Packaged sidecar binary is missing at ${binaryFile.path}.',
      );
    }

    return _PackagedSidecarBundle(
      directory: packagedDirectory,
      manifestFile: manifestFile,
      binaryFile: binaryFile,
      version: version,
      binaryName: binaryName,
    );
  }

  Directory? _packagedSidecarDirectory() {
    final String executablePath = _resolvedExecutablePathProvider();
    if (executablePath.trim().isEmpty) {
      return null;
    }

    if (Platform.isMacOS) {
      final Directory macOsDirectory = Directory(p.dirname(executablePath));
      if (p.basename(macOsDirectory.path) != 'MacOS') {
        return null;
      }
      final Directory contentsDirectory = Directory(
        p.normalize(p.join(macOsDirectory.path, '..')),
      );
      if (p.basename(contentsDirectory.path) != 'Contents') {
        return null;
      }
      return Directory(
        p.join(
          contentsDirectory.path,
          'Resources',
          _packagedSidecarFolderName,
        ),
      );
    }

    if (Platform.isWindows) {
      return Directory(
        p.join(
          p.dirname(executablePath),
          _packagedSidecarFolderName,
        ),
      );
    }

    return Directory(
      p.join(
        p.dirname(executablePath),
        _packagedSidecarFolderName,
      ),
    );
  }

  Future<_ResolvedBinary> _resolveOrInstallBundledBinary(
    _PackagedSidecarBundle bundle,
  ) async {
    final Directory installDirectory = await _installedVersionDirectory(
      bundle.version,
    );
    final File installedBinary = File(
      p.join(installDirectory.path, _sidecarBinaryFileName()),
    );

    if (await _isExecutableFile(installedBinary.path)) {
      try {
        final String version = await _verifyBinaryAndReadVersion(
          installedBinary.path,
        );
        _version = version;
        return _ResolvedBinary(
          binaryPath: installedBinary.path,
          source: OpencodeBinarySource.bundledInstalled,
          installPath: installDirectory.path,
          bundledVersion: bundle.version,
        );
      } catch (error) {
        _appendLog(
            'Reinstalling bundled OpenCode after verification failed: $error');
      }
    }

    await installDirectory.create(recursive: true);
    final String tempPath = p.join(
      installDirectory.path,
      '${_sidecarBinaryFileName()}.tmp',
    );
    final File tempBinary = File(tempPath);
    if (await tempBinary.exists()) {
      await tempBinary.delete();
    }
    await bundle.binaryFile.copy(tempBinary.path);
    await _applyExecutablePermissions(tempBinary.path);

    if (await installedBinary.exists()) {
      await installedBinary.delete();
    }
    await tempBinary.rename(installedBinary.path);

    try {
      final String version = await _verifyBinaryAndReadVersion(
        installedBinary.path,
      );
      _version = version;
    } catch (error) {
      throw _BundledSidecarException(
        'Installed bundled OpenCode could not be verified: $error',
      );
    }

    await _pruneOlderInstalledVersions(bundle.version);

    return _ResolvedBinary(
      binaryPath: installedBinary.path,
      source: OpencodeBinarySource.bundledInstalled,
      installPath: installDirectory.path,
      bundledVersion: bundle.version,
    );
  }

  Future<Directory> _installedBinRootDirectory() async {
    final Directory sidecarRoot = await _sidecarRootDirectory();
    return Directory(p.join(sidecarRoot.path, 'bin'));
  }

  Future<Directory> _installedVersionDirectory(String version) async {
    final Directory binRoot = await _installedBinRootDirectory();
    return Directory(p.join(binRoot.path, version));
  }

  Future<void> _pruneOlderInstalledVersions(String keepVersion) async {
    final Directory binRoot = await _installedBinRootDirectory();
    if (!await binRoot.exists()) {
      return;
    }

    await for (final FileSystemEntity entity in binRoot.list()) {
      if (entity is! Directory) {
        continue;
      }
      if (p.basename(entity.path) == keepVersion) {
        continue;
      }
      try {
        await entity.delete(recursive: true);
      } catch (error) {
        _appendLog('Failed to prune old bundled OpenCode version: $error');
      }
    }
  }

  Future<void> _applyExecutablePermissions(String filePath) async {
    if (Platform.isWindows) {
      return;
    }

    final String chmodPath = Platform.isMacOS ? '/bin/chmod' : 'chmod';
    try {
      await Process.run(chmodPath, <String>['755', filePath]);
    } catch (error) {
      throw _BundledSidecarException(
        'Unable to restore executable permissions for $filePath: $error',
      );
    }
  }

  Future<String> _verifyBinaryAndReadVersion(String binaryPath) async {
    final ProcessResult result = await Process.run(binaryPath, <String>[
      '--version',
    ]);
    if (result.exitCode != 0) {
      throw Exception(
        '`${p.basename(binaryPath)} --version` failed with exit code ${result.exitCode}.',
      );
    }
    final String version = (result.stdout as String).trim();
    if (version.isEmpty) {
      throw Exception(
          '`${p.basename(binaryPath)} --version` returned no output.');
    }
    return version;
  }

  String _sidecarBinaryFileName() {
    return Platform.isWindows ? 'opencode.exe' : 'opencode';
  }
}

class _ResolvedBinary {
  const _ResolvedBinary({
    required this.binaryPath,
    required this.source,
    this.installPath,
    this.bundledVersion,
  });

  final String binaryPath;
  final OpencodeBinarySource source;
  final String? installPath;
  final String? bundledVersion;
}

class _PackagedSidecarBundle {
  const _PackagedSidecarBundle({
    required this.directory,
    required this.manifestFile,
    required this.binaryFile,
    required this.version,
    required this.binaryName,
  });

  final Directory directory;
  final File manifestFile;
  final File binaryFile;
  final String version;
  final String binaryName;
}

class _BundledSidecarException implements Exception {
  const _BundledSidecarException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _SidecarState {
  const _SidecarState({required this.pid, required this.url});

  final int? pid;
  final String url;
}
