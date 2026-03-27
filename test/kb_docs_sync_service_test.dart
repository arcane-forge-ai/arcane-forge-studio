import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arcane_forge/screens/development/coding_agent/services/kb_docs_sync_service.dart';
import 'package:arcane_forge/screens/game_design_assistant/models/api_models.dart';
import 'package:arcane_forge/screens/game_design_assistant/services/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService({
    required this.files,
    required this.downloadResponses,
  }) : super();

  final List<KnowledgeBaseFile> files;
  final Map<int, FileDownloadResponse?> downloadResponses;

  @override
  Future<List<KnowledgeBaseFile>> getKnowledgeBaseFiles(
    String projectId, {
    String? passcode,
  }) async {
    return files;
  }

  @override
  Future<FileDownloadResponse?> getFileDownloadUrl(
    String projectId,
    int fileId, {
    String? passcode,
  }) async {
    return downloadResponses[fileId];
  }
}

void main() {
  test('pull resolves active docs, sanitizes names, and skips local collisions',
      () async {
    final Directory workspace = await Directory.systemTemp.createTemp(
      'kb-doc-sync-test-',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    await Directory(p.join(workspace.path, 'docs')).create(recursive: true);
    await Directory(p.join(workspace.path, '.arcane-forge')).create(
      recursive: true,
    );

    final File editedLocalFile =
        File(p.join(workspace.path, 'docs', 'Design_.md'));
    await editedLocalFile.writeAsString('my local changes');
    final File manifest = File(
      p.join(workspace.path, '.arcane-forge', 'sync-manifest.json'),
    );
    await manifest.writeAsString(
      jsonEncode(<String, dynamic>{
        'version': 1,
        'projectId': 'project-1',
        'entries': <String, dynamic>{
          'Design_.md': <String, dynamic>{
            'relativePath': 'Design_.md',
            'documentName': 'Design?.md',
            'lastPulledHash': '0000000000000000',
          },
        },
      }),
    );

    final DateTime now = DateTime(2026, 3, 1);
    final List<KnowledgeBaseFile> files = <KnowledgeBaseFile>[
      KnowledgeBaseFile(
        id: 1,
        documentName: 'Design?.md',
        fileType: 'md',
        createdAt: now.subtract(const Duration(days: 1)),
        entryType: 'document',
        authorityLevel: 'reference',
      ),
      KnowledgeBaseFile(
        id: 2,
        documentName: 'Design?.md',
        fileType: 'md',
        createdAt: now,
        entryType: 'document',
        authorityLevel: 'deprecated',
      ),
      KnowledgeBaseFile(
        id: 3,
        documentName: '../Gameplay<>Loop/Spec*.md',
        fileType: 'md',
        createdAt: now,
        entryType: 'document',
      ),
      KnowledgeBaseFile(
        id: 4,
        documentName: 'Folder/Spec.md',
        fileType: 'md',
        createdAt: now.subtract(const Duration(hours: 2)),
        entryType: 'document',
      ),
      KnowledgeBaseFile(
        id: 5,
        documentName: 'Folder\\Spec.md',
        fileType: 'md',
        createdAt: now.subtract(const Duration(hours: 1)),
        entryType: 'document',
      ),
    ];

    final _FakeChatApiService fakeApi = _FakeChatApiService(
      files: files,
      downloadResponses: <int, FileDownloadResponse?>{
        1: FileDownloadResponse(
            downloadUrl: 'mock://1', fileName: 'Design?.md'),
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
      workspacePath: workspace.path,
    );

    expect(result.downloaded, contains('Gameplay__Loop/Spec_.md'));
    expect(result.downloaded, contains('Folder/Spec.md'));
    expect(result.downloaded.length, 2);
    expect(result.skippedCollision, contains('Design?.md'));
    expect(result.skippedCollision, contains('Folder/Spec.md'));

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
        manifestJson['entries'] as Map<String, dynamic>;
    expect(entries.containsKey('Gameplay__Loop/Spec_.md'), isTrue);
    expect(entries.containsKey('Folder/Spec.md'), isTrue);
  });
}
