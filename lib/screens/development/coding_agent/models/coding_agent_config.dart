import 'package:flutter/foundation.dart';

enum CodingAgentProviderKind { direct, gateway, custom }

enum CodingAgentAuthScheme { apiKey }

enum CodingAgentPermissionMode { manual, always }

CodingAgentProviderKind codingAgentProviderKindFromName(String? value) {
  return CodingAgentProviderKind.values.firstWhere(
    (CodingAgentProviderKind item) => item.name == value,
    orElse: () => CodingAgentProviderKind.direct,
  );
}

CodingAgentAuthScheme codingAgentAuthSchemeFromName(String? value) {
  return CodingAgentAuthScheme.values.firstWhere(
    (CodingAgentAuthScheme item) => item.name == value,
    orElse: () => CodingAgentAuthScheme.apiKey,
  );
}

CodingAgentPermissionMode codingAgentPermissionModeFromName(String? value) {
  return CodingAgentPermissionMode.values.firstWhere(
    (CodingAgentPermissionMode item) => item.name == value,
    orElse: () => CodingAgentPermissionMode.manual,
  );
}

@immutable
class CodingAgentProviderProfile {
  const CodingAgentProviderProfile({
    required this.id,
    required this.label,
    required this.providerId,
    this.kind = CodingAgentProviderKind.direct,
    this.authScheme = CodingAgentAuthScheme.apiKey,
    this.baseUrl = '',
    this.defaultModel = '',
    this.enabled = true,
    this.availableModels = const <String>[],
  });

  final String id;
  final String label;
  final String providerId;
  final CodingAgentProviderKind kind;
  final CodingAgentAuthScheme authScheme;
  final String baseUrl;
  final String defaultModel;
  final bool enabled;
  final List<String> availableModels;

  CodingAgentProviderProfile copyWith({
    String? id,
    String? label,
    String? providerId,
    CodingAgentProviderKind? kind,
    CodingAgentAuthScheme? authScheme,
    String? baseUrl,
    String? defaultModel,
    bool? enabled,
    List<String>? availableModels,
  }) {
    return CodingAgentProviderProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      providerId: providerId ?? this.providerId,
      kind: kind ?? this.kind,
      authScheme: authScheme ?? this.authScheme,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      enabled: enabled ?? this.enabled,
      availableModels: availableModels ?? this.availableModels,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'providerId': providerId,
      'kind': kind.name,
      'authScheme': authScheme.name,
      'baseUrl': baseUrl,
      'defaultModel': defaultModel,
      'enabled': enabled,
      'availableModels': availableModels,
    };
  }

  factory CodingAgentProviderProfile.fromJson(Map<String, dynamic> json) {
    return CodingAgentProviderProfile(
      id: '${json['id'] ?? ''}'.trim(),
      label: '${json['label'] ?? ''}'.trim(),
      providerId: '${json['providerId'] ?? ''}'.trim(),
      kind: codingAgentProviderKindFromName(json['kind'] as String?),
      authScheme: codingAgentAuthSchemeFromName(json['authScheme'] as String?),
      baseUrl: '${json['baseUrl'] ?? ''}'.trim(),
      defaultModel: '${json['defaultModel'] ?? ''}'.trim(),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      availableModels:
          ((json['availableModels'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic item) => '$item'.trim())
              .where((String item) => item.isNotEmpty)
              .toList(),
    );
  }
}

const List<CodingAgentProviderProfile> kDefaultCodingAgentProviderProfiles =
    <CodingAgentProviderProfile>[
  CodingAgentProviderProfile(
    id: 'openai',
    label: 'OpenAI',
    providerId: 'openai',
  ),
  CodingAgentProviderProfile(
    id: 'anthropic',
    label: 'Anthropic',
    providerId: 'anthropic',
  ),
  CodingAgentProviderProfile(
    id: 'google',
    label: 'Google',
    providerId: 'google',
  ),
  CodingAgentProviderProfile(
    id: 'openrouter',
    label: 'OpenRouter',
    providerId: 'openrouter',
  ),
  CodingAgentProviderProfile(
    id: 'opencode',
    label: 'OpenCode',
    providerId: 'opencode',
  ),
  CodingAgentProviderProfile(
    id: 'arcane-gateway',
    label: 'Arcane Forge Gateway',
    providerId: 'openai',
    kind: CodingAgentProviderKind.gateway,
  ),
  CodingAgentProviderProfile(
    id: 'custom-openai',
    label: 'Custom OpenAI-Compatible',
    providerId: 'openai',
    kind: CodingAgentProviderKind.custom,
  ),
];

@immutable
class CodingAgentGlobalConfig {
  const CodingAgentGlobalConfig({
    this.autoStartSidecar = true,
    this.selectedProviderId = 'openai',
    this.defaultModel = '',
    this.defaultAgent = '',
    this.defaultPermissionMode = CodingAgentPermissionMode.manual,
    this.providers = kDefaultCodingAgentProviderProfiles,
  });

  final bool autoStartSidecar;
  final String selectedProviderId;
  final String defaultModel;
  final String defaultAgent;
  final CodingAgentPermissionMode defaultPermissionMode;
  final List<CodingAgentProviderProfile> providers;

  CodingAgentProviderProfile? get selectedProvider {
    for (final CodingAgentProviderProfile profile in providers) {
      if (profile.id == selectedProviderId) {
        return profile;
      }
    }
    for (final CodingAgentProviderProfile profile in providers) {
      if (profile.enabled) {
        return profile;
      }
    }
    return providers.isEmpty ? null : providers.first;
  }

  CodingAgentGlobalConfig copyWith({
    bool? autoStartSidecar,
    String? selectedProviderId,
    String? defaultModel,
    String? defaultAgent,
    CodingAgentPermissionMode? defaultPermissionMode,
    List<CodingAgentProviderProfile>? providers,
  }) {
    return CodingAgentGlobalConfig(
      autoStartSidecar: autoStartSidecar ?? this.autoStartSidecar,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultAgent: defaultAgent ?? this.defaultAgent,
      defaultPermissionMode:
          defaultPermissionMode ?? this.defaultPermissionMode,
      providers: providers ?? this.providers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autoStartSidecar': autoStartSidecar,
      'selectedProviderId': selectedProviderId,
      'defaultModel': defaultModel,
      'defaultAgent': defaultAgent,
      'defaultPermissionMode': defaultPermissionMode.name,
      'providers': providers
          .map((CodingAgentProviderProfile item) => item.toJson())
          .toList(),
    };
  }

  factory CodingAgentGlobalConfig.fromJson(Map<String, dynamic> json) {
    final List<CodingAgentProviderProfile> providers =
        ((json['providers'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CodingAgentProviderProfile.fromJson)
            .toList();
    return CodingAgentGlobalConfig(
      autoStartSidecar: json['autoStartSidecar'] is bool
          ? json['autoStartSidecar'] as bool
          : true,
      selectedProviderId: '${json['selectedProviderId'] ?? 'openai'}'.trim(),
      defaultModel: '${json['defaultModel'] ?? ''}'.trim(),
      defaultAgent: '${json['defaultAgent'] ?? ''}'.trim(),
      defaultPermissionMode: codingAgentPermissionModeFromName(
        json['defaultPermissionMode'] as String?,
      ),
      providers:
          providers.isEmpty ? kDefaultCodingAgentProviderProfiles : providers,
    );
  }
}

@immutable
class CodingAgentSecretConfig {
  const CodingAgentSecretConfig({
    this.apiKeys = const <String, String>{},
  });

  final Map<String, String> apiKeys;

  CodingAgentSecretConfig copyWith({
    Map<String, String>? apiKeys,
  }) {
    return CodingAgentSecretConfig(
      apiKeys: apiKeys ?? this.apiKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'apiKeys': apiKeys};
  }

  factory CodingAgentSecretConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawApiKeys =
        (json['apiKeys'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CodingAgentSecretConfig(
      apiKeys: rawApiKeys.map(
        (String key, dynamic value) =>
            MapEntry<String, String>(key, '$value'.trim()),
      )..removeWhere((String _, String value) => value.isEmpty),
    );
  }
}

@immutable
class CodingAgentRuntimeConfig {
  const CodingAgentRuntimeConfig({
    required this.opencodeConfig,
    required this.environment,
    required this.credentialsPresent,
    this.selectedProviderId,
    this.selectedProviderLabel,
    this.selectedModel,
    this.selectedAgent,
  });

  final Map<String, dynamic> opencodeConfig;
  final Map<String, String> environment;
  final String? selectedProviderId;
  final String? selectedProviderLabel;
  final String? selectedModel;
  final String? selectedAgent;
  final bool credentialsPresent;
}
