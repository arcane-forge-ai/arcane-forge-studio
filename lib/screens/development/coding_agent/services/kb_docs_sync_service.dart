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
    required this.skippedNoStorage,
    required this.skippedCollision,
    required this.failed,
  });

  final List<String> downloaded;
  final List<String> skippedNoStorage;
  final List<String> skippedCollision;
  final List<KbPullFailure> failed;
}

class KbPushFailure {
  const KbPushFailure({required this.path, required this.reason});

  final String path;
  final String reason;
}

class KbPushResult {
  const KbPushResult({
    required this.uploaded,
    required this.skippedUnchanged,
    required this.skippedConflicts,
    required this.failed,
  });

  final List<String> uploaded;
  final List<String> skippedUnchanged;
  final List<String> skippedConflicts;
  final List<KbPushFailure> failed;
}

class KbSyncStatus {
  const KbSyncStatus({
    required this.workspacePath,
    required this.kbDirectoryPath,
    required this.manifestPath,
    required this.trackedFiles,
    required this.projectId,
    required this.projectName,
    this.lastPullAt,
    this.lastPushAt,
  });

  final String workspacePath;
  final String kbDirectoryPath;
  final String manifestPath;
  final int trackedFiles;
  final String projectId;
  final String projectName;
  final String? lastPullAt;
  final String? lastPushAt;
}

class KbSyncManifestEntry {
  const KbSyncManifestEntry({
    required this.relativePath,
    required this.documentName,
    this.remoteFileId,
    this.remoteCreatedAt,
    this.remoteAuthorityLevel,
    this.localHash,
    this.lastPulledHash,
    this.lastUploadedHash,
    this.lastDownloadedAt,
    this.lastUploadedAt,
  });

  final String relativePath;
  final String documentName;
  final int? remoteFileId;
  final String? remoteCreatedAt;
  final String? remoteAuthorityLevel;
  final String? localHash;
  final String? lastPulledHash;
  final String? lastUploadedHash;
  final String? lastDownloadedAt;
  final String? lastUploadedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'relativePath': relativePath,
      'documentName': documentName,
      'remoteFileId': remoteFileId,
      'remoteCreatedAt': remoteCreatedAt,
      'remoteAuthorityLevel': remoteAuthorityLevel,
      'localHash': localHash,
      'lastPulledHash': lastPulledHash,
      'lastUploadedHash': lastUploadedHash,
      'lastDownloadedAt': lastDownloadedAt,
      'lastUploadedAt': lastUploadedAt,
    };
  }

  factory KbSyncManifestEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rawRemoteFileId = json['remoteFileId'];
    return KbSyncManifestEntry(
      relativePath: json['relativePath'] as String? ?? '',
      documentName: json['documentName'] as String? ?? '',
      remoteFileId: rawRemoteFileId is int
          ? rawRemoteFileId
          : rawRemoteFileId is num
              ? rawRemoteFileId.toInt()
              : int.tryParse('${rawRemoteFileId ?? ''}'),
      remoteCreatedAt: json['remoteCreatedAt'] as String?,
      remoteAuthorityLevel: json['remoteAuthorityLevel'] as String?,
      localHash: json['localHash'] as String?,
      lastPulledHash: json['lastPulledHash'] as String?,
      lastUploadedHash: json['lastUploadedHash'] as String?,
      lastDownloadedAt: json['lastDownloadedAt'] as String?,
      lastUploadedAt: json['lastUploadedAt'] as String?,
    );
  }
}

class KbSyncManifest {
  const KbSyncManifest({
    required this.version,
    required this.projectId,
    required this.projectName,
    required this.entries,
    this.lastPullAt,
    this.lastPushAt,
  });

  final int version;
  final String projectId;
  final String projectName;
  final String? lastPullAt;
  final String? lastPushAt;
  final Map<String, KbSyncManifestEntry> entries;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'projectId': projectId,
      'projectName': projectName,
      'lastPullAt': lastPullAt,
      'lastPushAt': lastPushAt,
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
      projectName: json['projectName'] as String? ?? '',
      lastPullAt: json['lastPullAt'] as String?,
      lastPushAt: json['lastPushAt'] as String?,
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

  factory KbSyncManifest.empty(
    String projectId, {
    String projectName = '',
  }) {
    return KbSyncManifest(
      version: 1,
      projectId: projectId,
      projectName: projectName,
      entries: const <String, KbSyncManifestEntry>{},
    );
  }

  KbSyncManifest copyWith({
    int? version,
    String? projectId,
    String? projectName,
    String? lastPullAt,
    String? lastPushAt,
    bool clearLastPullAt = false,
    bool clearLastPushAt = false,
    Map<String, KbSyncManifestEntry>? entries,
  }) {
    return KbSyncManifest(
      version: version ?? this.version,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      lastPullAt: clearLastPullAt ? null : (lastPullAt ?? this.lastPullAt),
      lastPushAt: clearLastPushAt ? null : (lastPushAt ?? this.lastPushAt),
      entries: entries ?? this.entries,
    );
  }
}

class _PullTarget {
  const _PullTarget({required this.entry, required this.relativePath});

  final KnowledgeBaseFile entry;
  final String relativePath;
}

class _ScannedLocalFile {
  const _ScannedLocalFile({
    required this.absolutePath,
    required this.relativePath,
    required this.hash,
  });

  final String absolutePath;
  final String relativePath;
  final String hash;
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
    String? projectName,
  }) async {
    final Directory docsRoot = Directory(_docsRootPath(workspacePath));
    if (!await docsRoot.exists()) {
      await docsRoot.create(recursive: true);
    }

    final DateTime now = DateTime.now();
    final KbSyncManifest manifest = await _loadManifest(
      projectId,
      workspacePath,
      projectName: projectName,
    );
    final Map<String, KbSyncManifestEntry> manifestEntries =
        <String, KbSyncManifestEntry>{...manifest.entries};

    final List<KnowledgeBaseFile> remoteEntries =
        await _chatApiService.getKnowledgeBaseFiles(projectId);
    final Map<String, KnowledgeBaseFile> activeEntries = _resolveActiveEntries(
      remoteEntries.where(
        (KnowledgeBaseFile entry) => entry.entryType == 'document',
      ),
    );
    final ({
      List<_PullTarget> targets,
      List<String> skippedCollision
    }) resolvedTargets = _resolvePullTargets(activeEntries.values.toList());

    final List<String> downloaded = <String>[];
    final List<String> skippedNoStorage = <String>[];
    final List<String> skippedCollision = <String>[
      ...resolvedTargets.skippedCollision,
    ];
    final List<KbPullFailure> failed = <KbPullFailure>[];

    for (final _PullTarget target in resolvedTargets.targets) {
      if (!target.entry.hasStorage) {
        skippedNoStorage.add(target.entry.documentName);
        continue;
      }

      final String localPath = p.joinAll(
        <String>[docsRoot.path, ...target.relativePath.split('/')],
      );
      final File localFile = File(localPath);

      if (await localFile.exists()) {
        final String localHash = await _hashFile(localFile);
        final KbSyncManifestEntry? existing =
            manifestEntries[target.relativePath];
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

        manifestEntries[target.relativePath] = _mergeManifestEntry(
          manifestEntries[target.relativePath],
          KbSyncManifestEntry(
            relativePath: target.relativePath,
            documentName: target.entry.documentName,
            remoteFileId: target.entry.id,
            remoteCreatedAt: target.entry.createdAt.toIso8601String(),
            remoteAuthorityLevel: target.entry.authorityLevel,
            localHash: pulledHash,
            lastPulledHash: pulledHash,
            lastDownloadedAt: now.toIso8601String(),
          ),
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

    await _saveManifest(
      workspacePath,
      KbSyncManifest(
        version: manifest.version,
        projectId: projectId,
        projectName: manifest.projectName,
        lastPullAt: now.toIso8601String(),
        lastPushAt: manifest.lastPushAt,
        entries: manifestEntries,
      ),
    );

    return KbPullResult(
      downloaded: downloaded,
      skippedNoStorage: skippedNoStorage,
      skippedCollision: skippedCollision,
      failed: failed,
    );
  }

  Future<KbPushResult> pushKnowledgeBaseDocs({
    required String projectId,
    required String workspacePath,
    String? projectName,
  }) async {
    final DateTime now = DateTime.now();
    final KbSyncManifest manifest = await _loadManifest(
      projectId,
      workspacePath,
      projectName: projectName,
    );
    final Map<String, KbSyncManifestEntry> manifestEntries =
        <String, KbSyncManifestEntry>{...manifest.entries};
    final Map<String, _ScannedLocalFile> scannedFiles = await _scanLocalFiles(
      _docsRootPath(workspacePath),
    );

    for (final _ScannedLocalFile scanned in scannedFiles.values) {
      final KbSyncManifestEntry? existing =
          manifestEntries[scanned.relativePath];
      manifestEntries[scanned.relativePath] = _mergeManifestEntry(
        existing,
        KbSyncManifestEntry(
          relativePath: scanned.relativePath,
          documentName: existing?.documentName ?? scanned.relativePath,
          localHash: scanned.hash,
        ),
      );
    }

    final List<String> uploaded = <String>[];
    final List<String> skippedUnchanged = <String>[];
    final List<String> skippedConflicts = <String>[];
    final List<KbPushFailure> failed = <KbPushFailure>[];
    final List<_ScannedLocalFile> changedFiles = <_ScannedLocalFile>[];

    for (final _ScannedLocalFile scanned in scannedFiles.values) {
      final KbSyncManifestEntry? manifestEntry =
          manifestEntries[scanned.relativePath];
      final String? baseline =
          manifestEntry?.lastUploadedHash ?? manifestEntry?.lastPulledHash;
      if (baseline != null && baseline == scanned.hash) {
        skippedUnchanged.add(scanned.relativePath);
      } else {
        changedFiles.add(scanned);
      }
    }

    if (changedFiles.isNotEmpty) {
      final Map<String, KnowledgeBaseFile> activeRemoteBefore =
          _resolveActiveEntries(
        (await _chatApiService.getKnowledgeBaseFiles(projectId)).where(
          (KnowledgeBaseFile entry) => entry.entryType == 'document',
        ),
      );

      final List<({String documentName, _ScannedLocalFile file})> uploadQueue =
          <({String documentName, _ScannedLocalFile file})>[];
      for (final _ScannedLocalFile localFile in changedFiles) {
        final KbSyncManifestEntry? manifestEntry =
            manifestEntries[localFile.relativePath];
        final String trackedDocumentName =
            manifestEntry?.documentName.trim() ?? '';
        final String documentName = trackedDocumentName.isNotEmpty
            ? manifestEntry!.documentName
            : localFile.relativePath;
        final KnowledgeBaseFile? activeRemote =
            activeRemoteBefore[documentName];
        final int? trackedRemoteFileId = manifestEntry?.remoteFileId;

        if (trackedRemoteFileId != null &&
            activeRemote != null &&
            activeRemote.id != trackedRemoteFileId) {
          skippedConflicts.add(localFile.relativePath);
          continue;
        }

        uploadQueue.add((documentName: documentName, file: localFile));
      }

      for (final ({String documentName, _ScannedLocalFile file}) item
          in uploadQueue) {
        try {
          final bool success = await _chatApiService.uploadFile(
            projectId,
            p.basename(item.file.absolutePath),
            filePath: item.file.absolutePath,
            remoteDocumentName: item.documentName,
          );
          if (!success) {
            throw Exception('Upload did not succeed.');
          }
          uploaded.add(item.file.relativePath);
        } catch (error) {
          failed.add(
            KbPushFailure(path: item.file.relativePath, reason: '$error'),
          );
        }
      }

      if (uploaded.isNotEmpty) {
        final Map<String, KnowledgeBaseFile> activeRemoteAfter =
            _resolveActiveEntries(
          (await _chatApiService.getKnowledgeBaseFiles(projectId)).where(
            (KnowledgeBaseFile entry) => entry.entryType == 'document',
          ),
        );

        for (final String relativePath in uploaded) {
          final _ScannedLocalFile? scanned = scannedFiles[relativePath];
          if (scanned == null) {
            continue;
          }
          final KbSyncManifestEntry? current = manifestEntries[relativePath];
          final String trackedDocumentName = current?.documentName.trim() ?? '';
          final String documentName = trackedDocumentName.isNotEmpty
              ? current!.documentName
              : relativePath;
          final KnowledgeBaseFile? remote = activeRemoteAfter[documentName];
          manifestEntries[relativePath] = _mergeManifestEntry(
            current,
            KbSyncManifestEntry(
              relativePath: relativePath,
              documentName: documentName,
              remoteFileId: remote?.id,
              remoteCreatedAt: remote?.createdAt.toIso8601String(),
              remoteAuthorityLevel: remote?.authorityLevel,
              localHash: scanned.hash,
              lastUploadedHash: scanned.hash,
              lastUploadedAt: now.toIso8601String(),
            ),
          );
        }
      }
    }

    await _saveManifest(
      workspacePath,
      manifest.copyWith(
        projectName: projectName ?? manifest.projectName,
        lastPushAt: now.toIso8601String(),
        entries: manifestEntries,
      ),
    );

    return KbPushResult(
      uploaded: uploaded,
      skippedUnchanged: skippedUnchanged,
      skippedConflicts: skippedConflicts,
      failed: failed,
    );
  }

  Future<KbSyncStatus> getKnowledgeBaseSyncStatus({
    required String projectId,
    required String workspacePath,
    String? projectName,
  }) async {
    final KbSyncManifest manifest = await _loadManifest(
      projectId,
      workspacePath,
      projectName: projectName,
    );
    return KbSyncStatus(
      workspacePath: workspacePath,
      kbDirectoryPath: _docsRootPath(workspacePath),
      manifestPath: _manifestPath(workspacePath),
      trackedFiles: manifest.entries.length,
      projectId: manifest.projectId,
      projectName: manifest.projectName.isNotEmpty
          ? manifest.projectName
          : (projectName ?? ''),
      lastPullAt: manifest.lastPullAt,
      lastPushAt: manifest.lastPushAt,
    );
  }

  Future<KbSyncManifest> _loadManifest(
    String projectId,
    String workspacePath, {
    String? projectName,
  }) async {
    final File file = File(_manifestPath(workspacePath));
    if (!await file.exists()) {
      return KbSyncManifest.empty(
        projectId,
        projectName: projectName ?? '',
      );
    }

    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return KbSyncManifest.empty(
          projectId,
          projectName: projectName ?? '',
        );
      }
      final KbSyncManifest manifest = KbSyncManifest.fromJson(decoded);
      if (manifest.projectId != projectId) {
        return KbSyncManifest.empty(
          projectId,
          projectName: projectName ?? '',
        );
      }
      return manifest.copyWith(
        projectName: manifest.projectName.isNotEmpty
            ? manifest.projectName
            : (projectName ?? ''),
      );
    } catch (_) {
      return KbSyncManifest.empty(
        projectId,
        projectName: projectName ?? '',
      );
    }
  }

  Future<void> _saveManifest(
    String workspacePath,
    KbSyncManifest manifest,
  ) async {
    final File file = File(_manifestPath(workspacePath));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
      flush: true,
    );
  }

  Future<Map<String, _ScannedLocalFile>> _scanLocalFiles(
    String docsRootPath,
  ) async {
    final Map<String, _ScannedLocalFile> results =
        <String, _ScannedLocalFile>{};
    final Directory docsRoot = Directory(docsRootPath);
    if (!await docsRoot.exists()) {
      return results;
    }
    await _walkDirectory(docsRootPath, '', results);
    return results;
  }

  Future<void> _walkDirectory(
    String rootPath,
    String currentRelative,
    Map<String, _ScannedLocalFile> output,
  ) async {
    final Directory directory = Directory(
      currentRelative.isEmpty
          ? rootPath
          : p.joinAll(<String>[rootPath, ...currentRelative.split('/')]),
    );
    final List<FileSystemEntity> entries = await directory
        .list(
          recursive: false,
          followLinks: false,
        )
        .toList()
      ..sort((FileSystemEntity a, FileSystemEntity b) {
        return a.path.compareTo(b.path);
      });

    for (final FileSystemEntity entry in entries) {
      final String name = p.basename(entry.path);
      if (_shouldIgnoreLocalName(name)) {
        continue;
      }

      final String childRelative =
          currentRelative.isEmpty ? name : '$currentRelative/$name';
      if (childRelative == '.arcane-forge' ||
          childRelative.startsWith('.arcane-forge/')) {
        continue;
      }

      if (entry is Directory) {
        await _walkDirectory(rootPath, childRelative, output);
        continue;
      }
      if (entry is! File) {
        continue;
      }

      output[childRelative] = _ScannedLocalFile(
        absolutePath: entry.path,
        relativePath: childRelative,
        hash: await _hashFile(entry),
      );
    }
  }

  bool _shouldIgnoreLocalName(String name) {
    return name.startsWith('.');
  }

  Map<String, KnowledgeBaseFile> _resolveActiveEntries(
    Iterable<KnowledgeBaseFile> entries,
  ) {
    final Map<String, List<KnowledgeBaseFile>> grouped =
        <String, List<KnowledgeBaseFile>>{};
    for (final KnowledgeBaseFile entry in entries) {
      grouped
          .putIfAbsent(entry.documentName, () => <KnowledgeBaseFile>[])
          .add(entry);
    }

    final Map<String, KnowledgeBaseFile> active = <String, KnowledgeBaseFile>{};
    for (final MapEntry<String, List<KnowledgeBaseFile>> group
        in grouped.entries) {
      final List<KnowledgeBaseFile> nonDeprecated = group.value
          .where(
            (KnowledgeBaseFile entry) => entry.authorityLevel != 'deprecated',
          )
          .toList();
      final List<KnowledgeBaseFile> candidates =
          nonDeprecated.isNotEmpty ? nonDeprecated : group.value;
      KnowledgeBaseFile winner = candidates.first;
      for (int index = 1; index < candidates.length; index += 1) {
        if (_compareRecency(candidates[index], winner) > 0) {
          winner = candidates[index];
        }
      }
      active[group.key] = winner;
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

  KbSyncManifestEntry _mergeManifestEntry(
    KbSyncManifestEntry? existing,
    KbSyncManifestEntry patch,
  ) {
    return KbSyncManifestEntry(
      relativePath: patch.relativePath.isEmpty
          ? existing?.relativePath ?? ''
          : patch.relativePath,
      documentName: patch.documentName.isEmpty
          ? existing?.documentName ?? patch.relativePath
          : patch.documentName,
      remoteFileId: patch.remoteFileId ?? existing?.remoteFileId,
      remoteCreatedAt: patch.remoteCreatedAt ?? existing?.remoteCreatedAt,
      remoteAuthorityLevel:
          patch.remoteAuthorityLevel ?? existing?.remoteAuthorityLevel,
      localHash: patch.localHash ?? existing?.localHash,
      lastPulledHash: patch.lastPulledHash ?? existing?.lastPulledHash,
      lastUploadedHash: patch.lastUploadedHash ?? existing?.lastUploadedHash,
      lastDownloadedAt: patch.lastDownloadedAt ?? existing?.lastDownloadedAt,
      lastUploadedAt: patch.lastUploadedAt ?? existing?.lastUploadedAt,
    );
  }

  int _compareRecency(KnowledgeBaseFile a, KnowledgeBaseFile b) {
    final int dateDelta =
        a.createdAt.millisecondsSinceEpoch - b.createdAt.millisecondsSinceEpoch;
    if (dateDelta != 0) {
      return dateDelta;
    }
    return a.id - b.id;
  }

  String _sanitizeDocumentNameToRelativePath(
    String documentName, {
    int? fallbackId,
  }) {
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

  String _docsRootPath(String workspacePath) {
    return p.join(workspacePath, 'docs');
  }

  String _manifestPath(String workspacePath) {
    return p.join(workspacePath, '.arcane-forge', 'sync-manifest.json');
  }
}
