import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arcane_forge/screens/development/coding_agent/services/kb_docs_sync_service.dart';
import 'package:arcane_forge/screens/game_design_assistant/models/api_models.dart';
import 'package:arcane_forge/screens/game_design_assistant/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _UploadCall {
  const _UploadCall({
    required this.projectId,
    required this.fileName,
    this.filePath,
    this.bytes,
    this.remoteDocumentName,
  });

  final String projectId;
  final String fileName;
  final String? filePath;
  final Uint8List? bytes;
  final String? remoteDocumentName;
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService({
    required List<KnowledgeBaseFile> remoteFiles,
    required this.downloadResponses,
    this.onUpload,
  })  : _remoteFiles = List<KnowledgeBaseFile>.from(remoteFiles),
        super();

  final Map<int, FileDownloadResponse?> downloadResponses;
  final Future<bool> Function(_UploadCall call, _FakeChatApiService api)?
      onUpload;
  final List<_UploadCall> uploadCalls = <_UploadCall>[];
  List<KnowledgeBaseFile> _remoteFiles;

  List<KnowledgeBaseFile> get remoteFiles =>
      List<KnowledgeBaseFile>.unmodifiable(_remoteFiles);

  set remoteFiles(List<KnowledgeBaseFile> next) {
    _remoteFiles = List<KnowledgeBaseFile>.from(next);
  }

  @override
  Future<List<KnowledgeBaseFile>> getKnowledgeBaseFiles(
    String projectId, {
    String? passcode,
  }) async {
    return List<KnowledgeBaseFile>.from(_remoteFiles);
  }

  @override
  Future<FileDownloadResponse?> getFileDownloadUrl(
    String projectId,
    int fileId, {
    String? passcode,
  }) async {
    return downloadResponses[fileId];
  }

  @override
  Future<bool> uploadFile(
    String projectId,
    String fileName, {
    String? filePath,
    Uint8List? bytes,
    String? remoteDocumentName,
  }) async {
    final _UploadCall call = _UploadCall(
      projectId: projectId,
      fileName: fileName,
      filePath: filePath,
      bytes: bytes,
      remoteDocumentName: remoteDocumentName,
    );
    uploadCalls.add(call);
    if (onUpload != null) {
      return onUpload!(call, this);
    }
    return true;
  }
}

String _hashText(String text) {
  const int offsetBasis = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  int hash = offsetBasis;

  for (final int value in utf8.encode(text)) {
    hash ^= value;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}

Future<File> _writeManifest(
  Directory workspace,
  Map<String, dynamic> manifest,
) async {
  final File file = File(
    p.join(workspace.path, '.arcane-forge', 'sync-manifest.json'),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  return file;
}

KnowledgeBaseFile _doc({
  required int id,
  required String documentName,
  required DateTime createdAt,
  String authorityLevel = 'reference',
  bool hasStorage = true,
}) {
  return KnowledgeBaseFile(
    id: id,
    documentName: documentName,
    fileType: 'md',
    createdAt: createdAt,
    entryType: 'document',
    authorityLevel: authorityLevel,
    hasStorage: hasStorage,
  );
}

void main() {
  test(
      'pull resolves active docs, sanitizes names, skips collisions, and skips missing storage',
      () async {
    final Directory workspace = await Directory.systemTemp.createTemp(
      'kb-doc-sync-pull-test-',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    await Directory(p.join(workspace.path, 'docs')).create(recursive: true);

    final File editedLocalFile =
        File(p.join(workspace.path, 'docs', 'Design_.md'));
    await editedLocalFile.writeAsString('my local changes');
    final File manifest = await _writeManifest(
      workspace,
      <String, dynamic>{
        'version': 1,
        'projectId': 'project-1',
        'entries': <String, dynamic>{
          'Design_.md': <String, dynamic>{
            'relativePath': 'Design_.md',
            'documentName': 'Design?.md',
            'lastPulledHash': '0000000000000000',
          },
        },
      },
    );

    final DateTime now = DateTime(2026, 3, 1);
    final _FakeChatApiService fakeApi = _FakeChatApiService(
      remoteFiles: <KnowledgeBaseFile>[
        _doc(
          id: 1,
          documentName: 'Design?.md',
          createdAt: now.subtract(const Duration(days: 1)),
          authorityLevel: 'reference',
        ),
        _doc(
          id: 2,
          documentName: 'Design?.md',
          createdAt: now,
          authorityLevel: 'deprecated',
        ),
        _doc(
          id: 3,
          documentName: '../Gameplay<>Loop/Spec*.md',
          createdAt: now,
        ),
        _doc(
          id: 4,
          documentName: 'Folder/Spec.md',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        _doc(
          id: 5,
          documentName: 'Folder\\Spec.md',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        _doc(
          id: 6,
          documentName: 'No Storage.md',
          createdAt: now.subtract(const Duration(hours: 3)),
          hasStorage: false,
        ),
      ],
      downloadResponses: <int, FileDownloadResponse?>{
        1: FileDownloadResponse(
          downloadUrl: 'mock://1',
          fileName: 'Design?.md',
        ),
        3: FileDownloadResponse(
          downloadUrl: 'mock://3',
          fileName: '../Gameplay<>Loop/Spec*.md',
        ),
        4: FileDownloadResponse(
          downloadUrl: 'mock://4',
          fileName: 'Folder/Spec.md',
        ),
        5: FileDownloadResponse(
          downloadUrl: 'mock://5',
          fileName: 'Folder\\Spec.md',
        ),
      },
    );

    final Map<String, List<int>> downloadedBytes = <String, List<int>>{
      'mock://1': utf8.encode('# design from kb'),
      'mock://3': utf8.encode('# gameplay spec'),
      'mock://4': utf8.encode('# old folder spec'),
      'mock://5': utf8.encode('# newest folder spec'),
    };
    final KbDocsSyncService service = KbDocsSyncService(
      chatApiService: fakeApi,
      downloadBytes: (String url) async => downloadedBytes[url] ?? Uint8List(0),
    );

    final KbPullResult result = await service.pullKnowledgeBaseDocs(
      projectId: 'project-1',
      projectName: 'Project One',
      workspacePath: workspace.path,
    );

    expect(result.downloaded, contains('Gameplay__Loop/Spec_.md'));
    expect(result.downloaded, contains('Folder/Spec.md'));
    expect(result.downloaded.length, 2);
    expect(result.skippedCollision, contains('Design?.md'));
    expect(result.skippedCollision, contains('Folder/Spec.md'));
    expect(result.skippedNoStorage, contains('No Storage.md'));
    expect(result.failed, isEmpty);

    expect(await editedLocalFile.readAsString(), 'my local changes');

    final File gameplayFile = File(
      p.join(workspace.path, 'docs', 'Gameplay__Loop', 'Spec_.md'),
    );
    expect(await gameplayFile.exists(), isTrue);

    final File folderFile =
        File(p.join(workspace.path, 'docs', 'Folder', 'Spec.md'));
    expect(await folderFile.readAsString(), '# newest folder spec');

    final Map<String, dynamic> manifestJson =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final Map<String, dynamic> entries =
        Map<String, dynamic>.from(manifestJson['entries'] as Map);
    expect(entries.containsKey('Gameplay__Loop/Spec_.md'), isTrue);
    expect(entries.containsKey('Folder/Spec.md'), isTrue);
    expect(manifestJson['projectName'], 'Project One');
    expect(manifestJson['lastPullAt'], isNotNull);
  });

  test(
      'push uploads changed files, preserves remote names, and skips hidden files',
      () async {
    final Directory workspace = await Directory.systemTemp.createTemp(
      'kb-doc-sync-push-test-',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    final Directory docsDir =
        await Directory(p.join(workspace.path, 'docs')).create(recursive: true);
    final File changedFile = File(p.join(docsDir.path, 'existing.md'));
    final File unchangedFile = File(p.join(docsDir.path, 'unchanged.md'));
    final File newNestedFile =
        File(p.join(docsDir.path, 'new', 'local_spec.md'));
    final File hiddenFile = File(p.join(docsDir.path, '.hidden.md'));
    final File hiddenDirFile =
        File(p.join(docsDir.path, '.arcane-forge', 'ignored.md'));

    await changedFile.writeAsString('# changed');
    await unchangedFile.writeAsString('# unchanged');
    await newNestedFile.parent.create(recursive: true);
    await newNestedFile.writeAsString('# new nested file');
    await hiddenFile.writeAsString('# hidden');
    await hiddenDirFile.parent.create(recursive: true);
    await hiddenDirFile.writeAsString('# hidden dir');

    final File manifest = await _writeManifest(
      workspace,
      <String, dynamic>{
        'version': 1,
        'projectId': 'project-1',
        'projectName': 'Project One',
        'lastPullAt': '2026-03-01T00:00:00.000Z',
        'entries': <String, dynamic>{
          'existing.md': <String, dynamic>{
            'relativePath': 'existing.md',
            'documentName': 'kb/original-spec.md',
            'remoteFileId': 20,
            'lastUploadedHash': 'old-hash',
          },
          'unchanged.md': <String, dynamic>{
            'relativePath': 'unchanged.md',
            'documentName': 'unchanged.md',
            'remoteFileId': 30,
            'lastPulledHash': _hashText('# unchanged'),
          },
        },
      },
    );

    int nextRemoteId = 40;
    final _FakeChatApiService fakeApi = _FakeChatApiService(
      remoteFiles: <KnowledgeBaseFile>[
        _doc(
          id: 20,
          documentName: 'kb/original-spec.md',
          createdAt: DateTime(2026, 3, 1),
        ),
        _doc(
          id: 30,
          documentName: 'unchanged.md',
          createdAt: DateTime(2026, 3, 1, 1),
        ),
      ],
      downloadResponses: const <int, FileDownloadResponse?>{},
      onUpload: (_UploadCall call, _FakeChatApiService api) async {
        api.remoteFiles = <KnowledgeBaseFile>[
          ...api.remoteFiles,
          _doc(
            id: nextRemoteId,
            documentName: call.remoteDocumentName ?? call.fileName,
            createdAt: DateTime(2026, 3, 2, nextRemoteId - 39),
          ),
        ];
        nextRemoteId += 1;
        return true;
      },
    );

    final KbDocsSyncService service = KbDocsSyncService(
      chatApiService: fakeApi,
    );

    final KbPushResult result = await service.pushKnowledgeBaseDocs(
      projectId: 'project-1',
      projectName: 'Project One',
      workspacePath: workspace.path,
    );

    expect(result.uploaded, contains('existing.md'));
    expect(result.uploaded, contains('new/local_spec.md'));
    expect(result.uploaded.length, 2);
    expect(result.skippedUnchanged, contains('unchanged.md'));
    expect(result.skippedConflicts, isEmpty);
    expect(result.failed, isEmpty);

    expect(fakeApi.uploadCalls.length, 2);
    expect(
      fakeApi.uploadCalls.map((call) => call.remoteDocumentName),
      containsAll(<String>['kb/original-spec.md', 'new/local_spec.md']),
    );
    expect(
      fakeApi.uploadCalls.map((call) => call.fileName),
      containsAll(<String>['existing.md', 'local_spec.md']),
    );

    final Map<String, dynamic> manifestJson =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final Map<String, dynamic> entries =
        Map<String, dynamic>.from(manifestJson['entries'] as Map);
    expect(entries['existing.md']['documentName'], 'kb/original-spec.md');
    expect(entries['existing.md']['lastUploadedHash'], _hashText('# changed'));
    expect(entries['existing.md']['lastUploadedAt'], isNotNull);
    expect(entries['new/local_spec.md']['documentName'], 'new/local_spec.md');
    expect(entries['new/local_spec.md']['remoteFileId'], isNotNull);
    expect(entries.containsKey('.hidden.md'), isFalse);
    expect(entries.containsKey('.arcane-forge/ignored.md'), isFalse);
    expect(manifestJson['lastPushAt'], isNotNull);
  });

  test('push skips conflicts when the active remote file id changed', () async {
    final Directory workspace = await Directory.systemTemp.createTemp(
      'kb-doc-sync-conflict-test-',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    final Directory docsDir =
        await Directory(p.join(workspace.path, 'docs')).create(recursive: true);
    final File conflictFile = File(p.join(docsDir.path, 'conflict.md'));
    await conflictFile.writeAsString('# changed locally');

    await _writeManifest(
      workspace,
      <String, dynamic>{
        'version': 1,
        'projectId': 'project-1',
        'entries': <String, dynamic>{
          'conflict.md': <String, dynamic>{
            'relativePath': 'conflict.md',
            'documentName': 'kb/conflict.md',
            'remoteFileId': 5,
            'lastUploadedHash': 'old-hash',
          },
        },
      },
    );

    final _FakeChatApiService fakeApi = _FakeChatApiService(
      remoteFiles: <KnowledgeBaseFile>[
        _doc(
          id: 8,
          documentName: 'kb/conflict.md',
          createdAt: DateTime(2026, 3, 4),
        ),
      ],
      downloadResponses: const <int, FileDownloadResponse?>{},
    );

    final KbDocsSyncService service = KbDocsSyncService(
      chatApiService: fakeApi,
    );

    final KbPushResult result = await service.pushKnowledgeBaseDocs(
      projectId: 'project-1',
      workspacePath: workspace.path,
    );

    expect(result.uploaded, isEmpty);
    expect(result.skippedConflicts, contains('conflict.md'));
    expect(result.failed, isEmpty);
    expect(fakeApi.uploadCalls, isEmpty);
  });

  test('status reads manifest metadata for the workspace', () async {
    final Directory workspace = await Directory.systemTemp.createTemp(
      'kb-doc-sync-status-test-',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    await _writeManifest(
      workspace,
      <String, dynamic>{
        'version': 1,
        'projectId': 'project-1',
        'projectName': 'Project One',
        'lastPullAt': '2026-03-01T00:00:00.000Z',
        'lastPushAt': '2026-03-02T00:00:00.000Z',
        'entries': <String, dynamic>{
          'a.md': <String, dynamic>{
            'relativePath': 'a.md',
            'documentName': 'a.md',
          },
          'b.md': <String, dynamic>{
            'relativePath': 'b.md',
            'documentName': 'b.md',
          },
        },
      },
    );

    final KbDocsSyncService service = KbDocsSyncService(
      chatApiService: _FakeChatApiService(
        remoteFiles: <KnowledgeBaseFile>[],
        downloadResponses: const <int, FileDownloadResponse?>{},
      ),
    );

    final KbSyncStatus status = await service.getKnowledgeBaseSyncStatus(
      projectId: 'project-1',
      projectName: 'Project One',
      workspacePath: workspace.path,
    );

    expect(status.projectId, 'project-1');
    expect(status.projectName, 'Project One');
    expect(status.trackedFiles, 2);
    expect(status.lastPullAt, '2026-03-01T00:00:00.000Z');
    expect(status.lastPushAt, '2026-03-02T00:00:00.000Z');
    expect(status.kbDirectoryPath, p.join(workspace.path, 'docs'));
    expect(
      status.manifestPath,
      p.join(workspace.path, '.arcane-forge', 'sync-manifest.json'),
    );
  });
}
