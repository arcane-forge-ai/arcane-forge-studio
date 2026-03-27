import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../game_design_assistant/models/api_models.dart';
import '../../../game_design_assistant/services/chat_api_service.dart';

typedef DownloadBytes = Future<List<int>> Function(String downloadUrl);

class KbPullFailure {
  const KbPullFailure({required this.documentName, required this.reason});

  final String documentName;
  final String reason;
}

class KbPullResult {
  const KbPullResult({
    required this.downloaded,
    required this.skippedCollision,
    required this.failed,
  });

  final List<String> downloaded;
  final List<String> skippedCollision;
  final List<KbPullFailure> failed;
}

class KbSyncManifestEntry {
  const KbSyncManifestEntry({
    required this.relativePath,
    required this.documentName,
    this.remoteFileId,
    this.remoteCreatedAt,
    this.remoteAuthorityLevel,
    this.lastPulledHash,
    this.lastDownloadedAt,
  });

  final String relativePath;
  final String documentName;
  final int? remoteFileId;
  final String? remoteCreatedAt;
  final String? remoteAuthorityLevel;
  final String? lastPulledHash;
  final String? lastDownloadedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'relativePath': relativePath,
      'documentName': documentName,
      'remoteFileId': remoteFileId,
      'remoteCreatedAt': remoteCreatedAt,
      'remoteAuthorityLevel': remoteAuthorityLevel,
      'lastPulledHash': lastPulledHash,
      'lastDownloadedAt': lastDownloadedAt,
    };
  }

  factory KbSyncManifestEntry.fromJson(Map<String, dynamic> json) {
    return KbSyncManifestEntry(
      relativePath: json['relativePath'] as String? ?? '',
      documentName: json['documentName'] as String? ?? '',
      remoteFileId: json['remoteFileId'] as int?,
      remoteCreatedAt: json['remoteCreatedAt'] as String?,
      remoteAuthorityLevel: json['remoteAuthorityLevel'] as String?,
      lastPulledHash: json['lastPulledHash'] as String?,
      lastDownloadedAt: json['lastDownloadedAt'] as String?,
    );
  }

  KbSyncManifestEntry merge(KbSyncManifestEntry other) {
    return KbSyncManifestEntry(
      relativePath:
          other.relativePath.isEmpty ? relativePath : other.relativePath,
      documentName:
          other.documentName.isEmpty ? documentName : other.documentName,
      remoteFileId: other.remoteFileId ?? remoteFileId,
      remoteCreatedAt: other.remoteCreatedAt ?? remoteCreatedAt,
      remoteAuthorityLevel: other.remoteAuthorityLevel ?? remoteAuthorityLevel,
      lastPulledHash: other.lastPulledHash ?? lastPulledHash,
      lastDownloadedAt: other.lastDownloadedAt ?? lastDownloadedAt,
    );
  }
}

class KbSyncManifest {
  const KbSyncManifest({
    required this.version,
    required this.projectId,
    required this.entries,
    this.lastPullAt,
  });

  final int version;
  final String projectId;
  final String? lastPullAt;
  final Map<String, KbSyncManifestEntry> entries;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'projectId': projectId,
      'lastPullAt': lastPullAt,
      'entries': entries.map(
        (String key, KbSyncManifestEntry value) =>
            MapEntry<String, dynamic>(key, value.toJson()),
      ),
    };
  }

  factory KbSyncManifest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawEntries =
        json['entries'] is Map<String, dynamic>
            ? json['entries'] as Map<String, dynamic>
            : <String, dynamic>{};
    return KbSyncManifest(
      version: json['version'] as int? ?? 1,
      projectId: json['projectId'] as String? ?? '',
      lastPullAt: json['lastPullAt'] as String?,
      entries: rawEntries.map(
        (String key, dynamic value) => MapEntry<String, KbSyncManifestEntry>(
          key,
          KbSyncManifestEntry.fromJson(
            value is Map<String, dynamic>
                ? value
                : Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
        ),
      ),
    );
  }

  factory KbSyncManifest.empty(String projectId) {
    return KbSyncManifest(
      version: 1,
      projectId: projectId,
      entries: const <String, KbSyncManifestEntry>{},
    );
  }
}

class _PullTarget {
  const _PullTarget({required this.entry, required this.relativePath});

  final KnowledgeBaseFile entry;
  final String relativePath;
}

class KbDocsSyncService {
  KbDocsSyncService({
    required ChatApiService chatApiService,
    Dio? dio,
    DownloadBytes? downloadBytes,
  })  : _chatApiService = chatApiService,
        _dio = dio ?? Dio(),
        _downloadBytes = downloadBytes;

  final ChatApiService _chatApiService;
  final Dio _dio;
  final DownloadBytes? _downloadBytes;

  Future<KbPullResult> pullKnowledgeBaseDocs({
    required String projectId,
    required String workspacePath,
  }) async {
    final Directory docsRoot = Directory(p.join(workspacePath, 'docs'));
    if (!await docsRoot.exists()) {
      await docsRoot.create(recursive: true);
    }

    KbSyncManifest manifest = await _loadManifest(projectId, workspacePath);

    final List<KnowledgeBaseFile> remoteEntries =
        await _chatApiService.getKnowledgeBaseFiles(projectId);
    final List<KnowledgeBaseFile> documentEntries = remoteEntries
        .where((KnowledgeBaseFile entry) => entry.entryType == 'document')
        .toList();

    final List<KnowledgeBaseFile> activeEntries = _resolveActiveEntries(
      documentEntries,
    );
    final ({
      List<_PullTarget> targets,
      List<String> skippedCollision
    }) resolvedTargets = _resolvePullTargets(activeEntries);

    final List<String> downloaded = <String>[];
    final List<String> skippedCollision = <String>[
      ...resolvedTargets.skippedCollision,
    ];
    final List<KbPullFailure> failed = <KbPullFailure>[];

    for (final _PullTarget target in resolvedTargets.targets) {
      final String localPath = p.joinAll(
        <String>[docsRoot.path, ...target.relativePath.split('/')],
      );
      final File localFile = File(localPath);

      if (await localFile.exists()) {
        final String localHash = await _hashFile(localFile);
        final KbSyncManifestEntry? existing =
            manifest.entries[target.relativePath];
        final bool safeToOverwrite = existing != null &&
            existing.lastPulledHash != null &&
            localHash == existing.lastPulledHash;
        if (!safeToOverwrite) {
          skippedCollision.add(target.entry.documentName);
          continue;
        }
      }

      try {
        final FileDownloadResponse? downloadResponse = await _chatApiService
            .getFileDownloadUrl(projectId, target.entry.id);
        if (downloadResponse == null || downloadResponse.downloadUrl.isEmpty) {
          failed.add(
            KbPullFailure(
              documentName: target.entry.documentName,
              reason: 'Missing signed download URL.',
            ),
          );
          continue;
        }

        final List<int> bytes = await _downloadBytesForUrl(
          downloadResponse.downloadUrl,
        );
        if (bytes.isEmpty) {
          failed.add(
            KbPullFailure(
              documentName: target.entry.documentName,
              reason: 'Downloaded file was empty.',
            ),
          );
          continue;
        }

        if (!await localFile.parent.exists()) {
          await localFile.parent.create(recursive: true);
        }
        await localFile.writeAsBytes(bytes, flush: true);
        final String pulledHash = _hashBytes(bytes);

        final KbSyncManifestEntry nextEntry = KbSyncManifestEntry(
          relativePath: target.relativePath,
          documentName: target.entry.documentName,
          remoteFileId: target.entry.id,
          remoteCreatedAt: target.entry.createdAt.toIso8601String(),
          remoteAuthorityLevel: target.entry.authorityLevel,
          lastPulledHash: pulledHash,
          lastDownloadedAt: DateTime.now().toIso8601String(),
        );

        final KbSyncManifestEntry? previous =
            manifest.entries[target.relativePath];
        manifest = KbSyncManifest(
          version: manifest.version,
          projectId: projectId,
          lastPullAt: manifest.lastPullAt,
          entries: <String, KbSyncManifestEntry>{
            ...manifest.entries,
            target.relativePath:
                previous == null ? nextEntry : previous.merge(nextEntry),
          },
        );
        downloaded.add(target.relativePath);
      } catch (error) {
        failed.add(
          KbPullFailure(
            documentName: target.entry.documentName,
            reason: '$error',
          ),
        );
      }
    }

    final KbSyncManifest savedManifest = KbSyncManifest(
      version: manifest.version,
      projectId: projectId,
      lastPullAt: DateTime.now().toIso8601String(),
      entries: manifest.entries,
    );
    await _saveManifest(workspacePath, savedManifest);

    return KbPullResult(
      downloaded: downloaded,
      skippedCollision: skippedCollision,
      failed: failed,
    );
  }

  Future<KbSyncManifest> _loadManifest(
    String projectId,
    String workspacePath,
  ) async {
    final File file = File(
      p.join(workspacePath, '.arcane-forge', 'sync-manifest.json'),
    );
    if (!await file.exists()) {
      return KbSyncManifest.empty(projectId);
    }

    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return KbSyncManifest.empty(projectId);
      }
      final KbSyncManifest manifest = KbSyncManifest.fromJson(decoded);
      if (manifest.projectId != projectId) {
        return KbSyncManifest.empty(projectId);
      }
      return manifest;
    } catch (_) {
      return KbSyncManifest.empty(projectId);
    }
  }

  Future<void> _saveManifest(
      String workspacePath, KbSyncManifest manifest) async {
    final File file = File(
      p.join(workspacePath, '.arcane-forge', 'sync-manifest.json'),
    );
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
      flush: true,
    );
  }

  List<KnowledgeBaseFile> _resolveActiveEntries(
      List<KnowledgeBaseFile> entries) {
    final Map<String, List<KnowledgeBaseFile>> grouped =
        <String, List<KnowledgeBaseFile>>{};
    for (final KnowledgeBaseFile entry in entries) {
      grouped
          .putIfAbsent(entry.documentName, () => <KnowledgeBaseFile>[])
          .add(entry);
    }

    final List<KnowledgeBaseFile> active = <KnowledgeBaseFile>[];
    for (final List<KnowledgeBaseFile> group in grouped.values) {
      final List<KnowledgeBaseFile> nonDeprecated = group
          .where(
              (KnowledgeBaseFile entry) => entry.authorityLevel != 'deprecated')
          .toList();
      final List<KnowledgeBaseFile> candidates =
          nonDeprecated.isNotEmpty ? nonDeprecated : group;
      KnowledgeBaseFile winner = candidates.first;
      for (int index = 1; index < candidates.length; index += 1) {
        if (_compareRecency(candidates[index], winner) > 0) {
          winner = candidates[index];
        }
      }
      active.add(winner);
    }

    return active;
  }

  ({List<_PullTarget> targets, List<String> skippedCollision})
      _resolvePullTargets(
    List<KnowledgeBaseFile> entries,
  ) {
    final Map<String, _PullTarget> byLocalPath = <String, _PullTarget>{};
    final List<String> skippedCollision = <String>[];

    for (final KnowledgeBaseFile entry in entries) {
      final String relativePath = _sanitizeDocumentNameToRelativePath(
        entry.documentName,
        fallbackId: entry.id,
      );
      final _PullTarget candidate = _PullTarget(
        entry: entry,
        relativePath: relativePath,
      );
      final _PullTarget? existing = byLocalPath[relativePath];

      if (existing == null) {
        byLocalPath[relativePath] = candidate;
        continue;
      }

      if (_compareRecency(candidate.entry, existing.entry) > 0) {
        skippedCollision.add(existing.entry.documentName);
        byLocalPath[relativePath] = candidate;
      } else {
        skippedCollision.add(candidate.entry.documentName);
      }
    }

    final List<_PullTarget> targets = byLocalPath.values.toList()
      ..sort((_PullTarget a, _PullTarget b) {
        return a.relativePath.compareTo(b.relativePath);
      });

    return (targets: targets, skippedCollision: skippedCollision);
  }

  int _compareRecency(KnowledgeBaseFile a, KnowledgeBaseFile b) {
    final int dateDelta =
        a.createdAt.millisecondsSinceEpoch - b.createdAt.millisecondsSinceEpoch;
    if (dateDelta != 0) {
      return dateDelta;
    }
    return a.id - b.id;
  }

  String _sanitizeDocumentNameToRelativePath(String documentName,
      {int? fallbackId}) {
    final String normalized = documentName.replaceAll('\\', '/');
    final List<String> rawSegments = normalized
        .split('/')
        .map((String segment) => segment.trim())
        .where(
          (String segment) =>
              segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .toList();

    final List<String> sanitizedSegments = rawSegments
        .map(_sanitizePathSegment)
        .where((String segment) => segment.isNotEmpty)
        .toList();

    if (sanitizedSegments.isEmpty) {
      sanitizedSegments.add(fallbackId == null ? 'file' : 'file_$fallbackId');
    }

    return sanitizedSegments.join('/');
  }

  String _sanitizePathSegment(String segment) {
    String out = segment.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    out = out.replaceAll(RegExp(r'[. ]+$'), '');
    out = out.trim();
    return out.isEmpty ? '_' : out;
  }

  Future<String> _hashFile(File file) async {
    return _hashBytes(await file.readAsBytes());
  }

  String _hashBytes(List<int> bytes) {
    const int offsetBasis = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    int hash = offsetBasis;

    for (final int value in bytes) {
      hash ^= value;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<List<int>> _downloadBytesForUrl(String downloadUrl) async {
    final DownloadBytes? override = _downloadBytes;
    if (override != null) {
      return override(downloadUrl);
    }
    final Response<List<int>> response = await _dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }
}
