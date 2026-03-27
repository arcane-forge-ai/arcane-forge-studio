import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coding_agent_config.dart';

class CodingAgentConfigBundle {
  const CodingAgentConfigBundle({
    required this.config,
    required this.secrets,
  });

  final CodingAgentGlobalConfig config;
  final CodingAgentSecretConfig secrets;
}

class PreparedCodingAgentConfig {
  const PreparedCodingAgentConfig({
    required this.config,
    required this.secrets,
    required this.runtimeConfig,
    required this.configFilePath,
    required this.settingsFilePath,
    required this.secretsFilePath,
  });

  final CodingAgentGlobalConfig config;
  final CodingAgentSecretConfig secrets;
  final CodingAgentRuntimeConfig runtimeConfig;
  final String configFilePath;
  final String settingsFilePath;
  final String secretsFilePath;
}

class CodingAgentConfigService {
  CodingAgentConfigService({
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory;

  static const String _settingsFileName = 'settings.json';
  static const String _secretsFileName = 'secrets.json';
  static const String _resolvedConfigFileName = 'opencode.json';

  static const String _legacyAutoStartSidecarKey =
      'settings_auto_start_sidecar';
  static const String _legacyDefaultPermissionModeKey =
      'settings_default_permission_mode';
  static const String _legacyDefaultModelKey = 'settings_default_model';
  static const String _legacyDefaultAgentKey = 'settings_default_agent';

  final Future<Directory> Function() _supportDirectoryProvider;
  final JsonEncoder _prettyEncoder = const JsonEncoder.withIndent('  ');

  Future<Directory> _sidecarRootDirectory() async {
    final Directory supportDirectory = await _supportDirectoryProvider();
    return Directory(p.join(supportDirectory.path, 'opencode_sidecar'));
  }

  Future<Directory> _configDirectory() async {
    final Directory root = await _sidecarRootDirectory();
    final Directory config = Directory(p.join(root.path, 'config'));
    if (!await config.exists()) {
      await config.create(recursive: true);
    }
    return config;
  }

  Future<File> settingsFile() async {
    final Directory configDirectory = await _configDirectory();
    return File(p.join(configDirectory.path, _settingsFileName));
  }

  Future<File> secretsFile() async {
    final Directory configDirectory = await _configDirectory();
    return File(p.join(configDirectory.path, _secretsFileName));
  }

  Future<File> resolvedConfigFile() async {
    final Directory configDirectory = await _configDirectory();
    return File(p.join(configDirectory.path, _resolvedConfigFileName));
  }

  Future<CodingAgentConfigBundle> loadBundle() async {
    final File settings = await settingsFile();
    final File secrets = await secretsFile();

    if (!await settings.exists()) {
      final CodingAgentGlobalConfig migrated = await _loadLegacyConfig();
      final CodingAgentConfigBundle bundle = CodingAgentConfigBundle(
        config: _normalizedConfig(migrated),
        secrets: const CodingAgentSecretConfig(),
      );
      await saveBundle(bundle.config, bundle.secrets);
      return bundle;
    }

    return CodingAgentConfigBundle(
      config: _normalizedConfig(await _readConfig(settings)),
      secrets: await _readSecrets(secrets),
    );
  }

  Future<void> saveBundle(
    CodingAgentGlobalConfig config,
    CodingAgentSecretConfig secrets,
  ) async {
    final CodingAgentGlobalConfig normalizedConfig = _normalizedConfig(config);
    final CodingAgentSecretConfig normalizedSecrets = _normalizedSecrets(
      normalizedConfig,
      secrets,
    );
    final File settings = await settingsFile();
    final File secretsFileRef = await secretsFile();

    await settings.writeAsString(
      _prettyEncoder.convert(normalizedConfig.toJson()),
      flush: true,
    );
    await _applyFilePermissions(settings, executable: false);

    await secretsFileRef.writeAsString(
      _prettyEncoder.convert(normalizedSecrets.toJson()),
      flush: true,
    );
    await _applyFilePermissions(secretsFileRef, executable: false);
  }

  Future<PreparedCodingAgentConfig> prepareRuntimeConfig() async {
    final CodingAgentConfigBundle bundle = await loadBundle();
    final CodingAgentRuntimeConfig runtimeConfig = buildRuntimeConfig(
      bundle.config,
      bundle.secrets,
    );
    final File configFile = await resolvedConfigFile();
    await configFile.writeAsString(
      _prettyEncoder.convert(runtimeConfig.opencodeConfig),
      flush: true,
    );
    await _applyFilePermissions(configFile, executable: false);

    final File settings = await settingsFile();
    final File secrets = await secretsFile();

    return PreparedCodingAgentConfig(
      config: bundle.config,
      secrets: bundle.secrets,
      runtimeConfig: runtimeConfig,
      configFilePath: configFile.path,
      settingsFilePath: settings.path,
      secretsFilePath: secrets.path,
    );
  }

  CodingAgentRuntimeConfig buildRuntimeConfig(
    CodingAgentGlobalConfig config,
    CodingAgentSecretConfig secrets,
  ) {
    final CodingAgentProviderProfile? selectedProvider =
        config.selectedProvider;
    final String? trimmedApiKey = selectedProvider == null
        ? null
        : secrets.apiKeys[selectedProvider.id]?.trim();
    final bool credentialsPresent =
        trimmedApiKey != null && trimmedApiKey.isNotEmpty;
    final String apiKeyValue = trimmedApiKey ?? '';

    final Map<String, dynamic> providerOptions = <String, dynamic>{};
    if (selectedProvider != null &&
        selectedProvider.baseUrl.trim().isNotEmpty) {
      providerOptions['baseURL'] = selectedProvider.baseUrl.trim();
    }
    if (credentialsPresent) {
      providerOptions['apiKey'] = '{env:AF_OPENCODE_API_KEY}';
    }

    final Map<String, dynamic> opencodeConfig = <String, dynamic>{
      r'$schema': 'https://opencode.ai/config.json',
    };

    if (selectedProvider != null) {
      opencodeConfig['provider'] = <String, dynamic>{
        selectedProvider.providerId: <String, dynamic>{
          if (providerOptions.isNotEmpty) 'options': providerOptions,
        },
      };
    }

    final String selectedModel = config.defaultModel.trim().isNotEmpty
        ? config.defaultModel.trim()
        : (selectedProvider?.defaultModel.trim() ?? '');
    if (selectedModel.isNotEmpty) {
      opencodeConfig['model'] = selectedModel;
    }

    final String selectedAgent = config.defaultAgent.trim();
    if (selectedAgent.isNotEmpty) {
      opencodeConfig['default_agent'] = selectedAgent;
    }

    final Map<String, dynamic> permission = _permissionConfigForMode(
      config.defaultPermissionMode,
    );
    if (permission.isNotEmpty) {
      opencodeConfig['permission'] = permission;
    }

    return CodingAgentRuntimeConfig(
      opencodeConfig: opencodeConfig,
      environment: <String, String>{
        if (credentialsPresent) 'AF_OPENCODE_API_KEY': apiKeyValue,
      },
      selectedProviderId: selectedProvider?.providerId,
      selectedProviderLabel: selectedProvider?.label,
      selectedModel: selectedModel.isEmpty ? null : selectedModel,
      selectedAgent: selectedAgent.isEmpty ? null : selectedAgent,
      credentialsPresent: credentialsPresent,
    );
  }

  Future<CodingAgentConfigBundle> updateProviderCatalog({
    required String profileId,
    required List<String> availableModels,
    String? defaultModel,
  }) async {
    final CodingAgentConfigBundle current = await loadBundle();
    final List<CodingAgentProviderProfile> nextProfiles =
        current.config.providers.map((CodingAgentProviderProfile profile) {
      if (profile.id != profileId) {
        return profile;
      }
      return profile.copyWith(
        availableModels: _normalizedModels(availableModels),
        defaultModel: (defaultModel ?? profile.defaultModel).trim(),
      );
    }).toList();

    final CodingAgentGlobalConfig nextConfig = current.config.copyWith(
      providers: nextProfiles,
    );
    await saveBundle(nextConfig, current.secrets);
    return CodingAgentConfigBundle(
        config: nextConfig, secrets: current.secrets);
  }

  Future<CodingAgentGlobalConfig> _loadLegacyConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String defaultModel =
        prefs.getString(_legacyDefaultModelKey)?.trim() ?? '';
    final String selectedProviderId = _providerIdFromModel(defaultModel);
    return CodingAgentGlobalConfig(
      autoStartSidecar: prefs.getBool(_legacyAutoStartSidecarKey) ?? true,
      selectedProviderId: selectedProviderId,
      defaultModel: defaultModel,
      defaultAgent: prefs.getString(_legacyDefaultAgentKey)?.trim() ?? '',
      defaultPermissionMode: codingAgentPermissionModeFromName(
        prefs.getString(_legacyDefaultPermissionModeKey),
      ),
      providers: kDefaultCodingAgentProviderProfiles,
    );
  }

  Future<CodingAgentGlobalConfig> _readConfig(File file) async {
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return const CodingAgentGlobalConfig();
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const CodingAgentGlobalConfig();
    }
    return CodingAgentGlobalConfig.fromJson(decoded);
  }

  Future<CodingAgentSecretConfig> _readSecrets(File file) async {
    if (!await file.exists()) {
      return const CodingAgentSecretConfig();
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return const CodingAgentSecretConfig();
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const CodingAgentSecretConfig();
    }
    return CodingAgentSecretConfig.fromJson(decoded);
  }

  CodingAgentGlobalConfig _normalizedConfig(CodingAgentGlobalConfig config) {
    final List<CodingAgentProviderProfile> providers = config.providers.isEmpty
        ? kDefaultCodingAgentProviderProfiles
        : config.providers
            .where((CodingAgentProviderProfile item) => item.id.isNotEmpty)
            .fold<List<CodingAgentProviderProfile>>(
            <CodingAgentProviderProfile>[],
            (
              List<CodingAgentProviderProfile> acc,
              CodingAgentProviderProfile item,
            ) {
              final int existingIndex = acc.indexWhere(
                (CodingAgentProviderProfile profile) => profile.id == item.id,
              );
              final CodingAgentProviderProfile normalized = item.copyWith(
                label: item.label.trim().isEmpty ? item.id : item.label.trim(),
                providerId: item.providerId.trim().isEmpty
                    ? item.id
                    : item.providerId.trim(),
                baseUrl: item.baseUrl.trim(),
                defaultModel: item.defaultModel.trim(),
                availableModels: _normalizedModels(item.availableModels),
              );
              if (existingIndex >= 0) {
                acc[existingIndex] = normalized;
              } else {
                acc.add(normalized);
              }
              return acc;
            },
          );

    final String selectedProviderId = providers.any(
      (CodingAgentProviderProfile item) => item.id == config.selectedProviderId,
    )
        ? config.selectedProviderId
        : providers.first.id;

    return config.copyWith(
      selectedProviderId: selectedProviderId,
      defaultModel: config.defaultModel.trim(),
      defaultAgent: config.defaultAgent.trim(),
      providers: providers,
    );
  }

  CodingAgentSecretConfig _normalizedSecrets(
    CodingAgentGlobalConfig config,
    CodingAgentSecretConfig secrets,
  ) {
    final Set<String> providerIds = config.providers
        .map((CodingAgentProviderProfile item) => item.id)
        .toSet();
    final Map<String, String> filtered = Map<String, String>.from(
      secrets.apiKeys,
    )..removeWhere(
        (String key, String value) =>
            !providerIds.contains(key) || value.trim().isEmpty,
      );
    return CodingAgentSecretConfig(apiKeys: filtered);
  }

  List<String> _normalizedModels(List<String> input) {
    final Set<String> seen = <String>{};
    final List<String> output = <String>[];
    for (final String raw in input) {
      final String value = raw.trim();
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }
      output.add(value);
    }
    output.sort();
    return output;
  }

  String _providerIdFromModel(String value) {
    final String trimmed = value.trim();
    if (!trimmed.contains('/')) {
      return 'openai';
    }
    final String providerId = trimmed.split('/').first.trim();
    return providerId.isEmpty ? 'openai' : providerId;
  }

  Map<String, dynamic> _permissionConfigForMode(
    CodingAgentPermissionMode mode,
  ) {
    switch (mode) {
      case CodingAgentPermissionMode.always:
        return const <String, dynamic>{};
      case CodingAgentPermissionMode.manual:
        return const <String, dynamic>{
          'edit': 'ask',
          'bash': 'ask',
          'webfetch': 'ask',
        };
    }
  }

  Future<void> _applyFilePermissions(
    File file, {
    required bool executable,
  }) async {
    if (Platform.isWindows) {
      return;
    }

    final String mode = executable ? '755' : '600';
    final String chmodPath = Platform.isMacOS ? '/bin/chmod' : 'chmod';
    try {
      await Process.run(chmodPath, <String>[mode, file.path]);
    } catch (_) {
      // Best effort only; the file still exists even if chmod is unavailable.
    }
  }
}
