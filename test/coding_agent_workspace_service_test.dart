import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/services/workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WorkspaceService', () {
    late WorkspaceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      service = WorkspaceService();
    });

    test('persists and loads project workspace mapping', () async {
      final Directory tempDirA = await Directory.systemTemp.createTemp(
        'coding-agent-workspace-test-a-',
      );
      final Directory tempDirB = await Directory.systemTemp.createTemp(
        'coding-agent-workspace-test-b-',
      );
      addTearDown(() async {
        if (await tempDirA.exists()) {
          await tempDirA.delete(recursive: true);
        }
        if (await tempDirB.exists()) {
          await tempDirB.delete(recursive: true);
        }
      });

      await service.setWorkspacePath('project-42', tempDirA.path);
      await service.setWorkspacePath('project-84', tempDirB.path);
      final String? loadedPathA = await service.loadWorkspacePath('project-42');
      final String? loadedPathB = await service.loadWorkspacePath('project-84');

      expect(loadedPathA, tempDirA.path);
      expect(loadedPathB, tempDirB.path);
    });

    test('creates required workspace scaffold directories', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'coding-agent-scaffold-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await service.ensureWorkspaceScaffold(tempDir.path);

      expect(Directory('${tempDir.path}/docs').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/.opencode/plans').existsSync(), isTrue);
      expect(Directory('${tempDir.path}/.arcane-forge').existsSync(), isTrue);
    });

    test('detects docs directory files', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'coding-agent-docs-check-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await service.ensureWorkspaceScaffold(tempDir.path);
      expect(await service.docsDirectoryHasFiles(tempDir.path), isFalse);

      final File sample = File('${tempDir.path}/docs/design.md');
      await sample.writeAsString('# sample');

      expect(await service.docsDirectoryHasFiles(tempDir.path), isTrue);
    });
  });
}
