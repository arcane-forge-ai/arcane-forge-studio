import 'package:flutter/foundation.dart';

enum ServerLifecycleStatus { stopped, starting, running, failed }

enum OpencodeBinarySource { override, bundledInstalled, systemPath, missing }

enum OpencodeConfigSyncState { idle, applied, failed }

@immutable
class OpencodeEventEnvelope {
  const OpencodeEventEnvelope({
    required this.directory,
    required this.payload,
    this.eventName,
    this.id,
  });

  final String directory;
  final Map<String, dynamic> payload;
  final String? eventName;
  final String? id;
}

@immutable
class OpencodeDiagnostics {
  const OpencodeDiagnostics({
    required this.status,
    required this.binaryDetected,
    required this.binarySource,
    required this.serverReachable,
    required this.providerReady,
    required this.recentLogs,
    required this.sidecarManaged,
    required this.credentialsPresent,
    required this.configSyncState,
    this.binaryPath,
    this.version,
    this.serverUrl,
    this.healthVersion,
    this.healthError,
    this.providerSummary,
    this.lastError,
    this.sidecarPid,
    this.sidecarResidentMb,
    this.installPath,
    this.bundledVersion,
    this.selectedProviderId,
    this.selectedProviderLabel,
    this.selectedModel,
    this.configSyncMessage,
  });

  final ServerLifecycleStatus status;
  final bool binaryDetected;
  final OpencodeBinarySource binarySource;
  final bool serverReachable;
  final bool providerReady;
  final List<String> recentLogs;
  final String? binaryPath;
  final String? version;
  final String? serverUrl;
  final String? healthVersion;
  final String? healthError;
  final String? providerSummary;
  final String? lastError;
  final int? sidecarPid;
  final int? sidecarResidentMb;
  final bool sidecarManaged;
  final String? installPath;
  final String? bundledVersion;
  final String? selectedProviderId;
  final String? selectedProviderLabel;
  final String? selectedModel;
  final bool credentialsPresent;
  final OpencodeConfigSyncState configSyncState;
  final String? configSyncMessage;

  OpencodeDiagnostics copyWith({
    ServerLifecycleStatus? status,
    bool? binaryDetected,
    OpencodeBinarySource? binarySource,
    bool? serverReachable,
    bool? providerReady,
    List<String>? recentLogs,
    bool? sidecarManaged,
    bool? credentialsPresent,
    OpencodeConfigSyncState? configSyncState,
    String? binaryPath,
    String? version,
    String? serverUrl,
    String? healthVersion,
    String? healthError,
    String? providerSummary,
    String? lastError,
    int? sidecarPid,
    int? sidecarResidentMb,
    String? installPath,
    String? bundledVersion,
    String? selectedProviderId,
    String? selectedProviderLabel,
    String? selectedModel,
    String? configSyncMessage,
  }) {
    return OpencodeDiagnostics(
      status: status ?? this.status,
      binaryDetected: binaryDetected ?? this.binaryDetected,
      binarySource: binarySource ?? this.binarySource,
      serverReachable: serverReachable ?? this.serverReachable,
      providerReady: providerReady ?? this.providerReady,
      recentLogs: recentLogs ?? this.recentLogs,
      sidecarManaged: sidecarManaged ?? this.sidecarManaged,
      credentialsPresent: credentialsPresent ?? this.credentialsPresent,
      configSyncState: configSyncState ?? this.configSyncState,
      binaryPath: binaryPath ?? this.binaryPath,
      version: version ?? this.version,
      serverUrl: serverUrl ?? this.serverUrl,
      healthVersion: healthVersion ?? this.healthVersion,
      healthError: healthError ?? this.healthError,
      providerSummary: providerSummary ?? this.providerSummary,
      lastError: lastError ?? this.lastError,
      sidecarPid: sidecarPid ?? this.sidecarPid,
      sidecarResidentMb: sidecarResidentMb ?? this.sidecarResidentMb,
      installPath: installPath ?? this.installPath,
      bundledVersion: bundledVersion ?? this.bundledVersion,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      selectedProviderLabel:
          selectedProviderLabel ?? this.selectedProviderLabel,
      selectedModel: selectedModel ?? this.selectedModel,
      configSyncMessage: configSyncMessage ?? this.configSyncMessage,
    );
  }
}
