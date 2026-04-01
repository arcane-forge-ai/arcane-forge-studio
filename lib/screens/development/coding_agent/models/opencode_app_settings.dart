import 'package:flutter/foundation.dart';

enum DefaultPermissionMode { manual, always }

DefaultPermissionMode defaultPermissionModeFromName(String? value) {
  return DefaultPermissionMode.values.firstWhere(
    (DefaultPermissionMode mode) => mode.name == value,
    orElse: () => DefaultPermissionMode.manual,
  );
}

@immutable
class OpencodeAppSettings {
  const OpencodeAppSettings({
    this.autoStartSidecar = true,
    this.defaultPermissionMode = DefaultPermissionMode.manual,
    this.defaultModel = '',
    this.defaultAgent = '',
  });

  final bool autoStartSidecar;
  final DefaultPermissionMode defaultPermissionMode;
  final String defaultModel;
  final String defaultAgent;

  OpencodeAppSettings copyWith({
    bool? autoStartSidecar,
    DefaultPermissionMode? defaultPermissionMode,
    String? defaultModel,
    String? defaultAgent,
  }) {
    return OpencodeAppSettings(
      autoStartSidecar: autoStartSidecar ?? this.autoStartSidecar,
      defaultPermissionMode:
          defaultPermissionMode ?? this.defaultPermissionMode,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultAgent: defaultAgent ?? this.defaultAgent,
    );
  }
}
