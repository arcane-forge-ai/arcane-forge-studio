import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plan_artifact.dart';
import '../models/project_metadata.dart';
import '../models/project_session_ref.dart';
import 'workspace_access_service.dart';

class WorkspaceService {
  static const String _workspacePathPrefix = 'coding_agent_workspace_path_';
  static const String _workspaceBookmarkPrefix =
      'coding_agent_workspace_bookmark_';
  static const String _lastSessionPrefix = 'coding_agent_last_session_';
  static const String _stateFileName = 'coding_agent_state.json';
  final WorkspaceAccessService _workspaceAccessService =
      WorkspaceAccessService();

  Future<String?> loadWorkspacePath(String projectId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_workspacePathPrefix$projectId');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    String resolvedPath = raw;
    final String? bookmark =
        prefs.getString('$_workspaceBookmarkPrefix$projectId');
    if (bookmark != null && bookmark.trim().isNotEmpty) {
      final String? restoredPath =
          await _workspaceAccessService.restoreSecurityBookmark(bookmark);
      if (restoredPath != null && restoredPath.trim().isNotEmpty) {
        resolvedPath = restoredPath;
      }
    } else {
      final String? createdBookmark =
          await _workspaceAccessService.createSecurityBookmark(raw);
      if (createdBookmark != null && createdBookmark.trim().isNotEmpty) {
        await prefs.setString(
          '$_workspaceBookmarkPrefix$projectId',
          createdBookmark,
        );
      }
    }

    try {
      final Directory workspace = Directory(resolvedPath);
      if (!await workspace.exists()) {
        return null;
      }
      return workspace.path;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> setWorkspacePath(String projectId, String workspacePath) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? previousBookmark = prefs.getString(
      '$_workspaceBookmarkPrefix$projectId',
    );
    if (previousBookmark != null && previousBookmark.trim().isNotEmpty) {
      await _workspaceAccessService.stopSecurityBookmark(previousBookmark);
    }

    final Directory workspace = Directory(workspacePath);
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    await ensureWorkspaceScaffold(workspace.path);

    await prefs.setString('$_workspacePathPrefix$projectId', workspace.path);
    final String? bookmark =
        await _workspaceAccessService.createSecurityBookmark(
      workspace.path,
    );
    if (bookmark != null && bookmark.trim().isNotEmpty) {
      await prefs.setString('$_workspaceBookmarkPrefix$projectId', bookmark);
    } else {
      await prefs.remove('$_workspaceBookmarkPrefix$projectId');
    }
  }

  Future<void> clearWorkspacePath(String projectId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? bookmark =
        prefs.getString('$_workspaceBookmarkPrefix$projectId');
    if (bookmark != null && bookmark.trim().isNotEmpty) {
      await _workspaceAccessService.stopSecurityBookmark(bookmark);
    }
    await prefs.remove('$_workspacePathPrefix$projectId');
    await prefs.remove('$_workspaceBookmarkPrefix$projectId');
    await prefs.remove('$_lastSessionPrefix$projectId');
  }

  Future<void> ensureWorkspaceScaffold(String workspacePath) async {
    final List<String> requiredDirectories = <String>[
      p.join(workspacePath, 'docs'),
      p.join(workspacePath, '.opencode', 'plans'),
      p.join(workspacePath, '.arcane-forge'),
    ];

    for (final String path in requiredDirectories) {
      final Directory directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  Future<void> writeFile(
    String workspacePath,
    String relativePath,
    String text,
  ) async {
    final String filePath = p.join(workspacePath, relativePath);
    final File file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(text);
  }

  Future<String> readFile(String workspacePath, String relativePath) async {
    final File file = File(p.join(workspacePath, relativePath));
    if (!await file.exists()) {
      return '';
    }
    return file.readAsString();
  }

  Future<void> copyDocs(String workspacePath, List<File> files) async {
    final Directory docsDirectory = Directory(p.join(workspacePath, 'docs'));
    if (!await docsDirectory.exists()) {
      await docsDirectory.create(recursive: true);
    }

    for (final File file in files) {
      final String fileName = p.basename(file.path);
      await file.copy(p.join(docsDirectory.path, fileName));
    }
  }

  Future<bool> docsDirectoryHasFiles(String workspacePath) async {
    final Directory docsDirectory = Directory(p.join(workspacePath, 'docs'));
    try {
      if (!await docsDirectory.exists()) {
        return false;
      }

      await for (final FileSystemEntity entry in docsDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is File) {
          return true;
        }
      }
      return false;
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> isWorkspaceAccessible(String workspacePath) async {
    try {
      final Directory workspace = Directory(workspacePath);
      if (!await workspace.exists()) {
        return false;
      }
      await for (final FileSystemEntity _ in workspace.list(
        recursive: false,
        followLinks: false,
      )) {
        break;
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<List<PlanArtifact>> listPlanArtifacts(String workspacePath) async {
    final Directory planDirectory = Directory(
      p.join(workspacePath, '.opencode', 'plans'),
    );
    if (!await planDirectory.exists()) {
      return const <PlanArtifact>[];
    }

    final List<PlanArtifact> artifacts = <PlanArtifact>[];
    await for (final FileSystemEntity entity in planDirectory.list(
      recursive: true,
    )) {
      if (entity is! File || !entity.path.endsWith('.md')) {
        continue;
      }
      final FileStat stat = await entity.stat();
      artifacts.add(
        PlanArtifact(
          relativePath: p.relative(entity.path, from: workspacePath),
          absolutePath: entity.path,
          modifiedAt: stat.modified,
        ),
      );
    }

    artifacts.sort(
      (PlanArtifact a, PlanArtifact b) => b.modifiedAt.compareTo(a.modifiedAt),
    );
    return artifacts;
  }

  Future<void> saveProject(ProjectSessionRef ref) async {
    ProjectMetadata metadata = await loadProjectMetadata(ref.projectId) ??
        ProjectMetadata.empty(
          projectId: ref.projectId,
          workspacePath: ref.workspacePath,
        );

    metadata = metadata.upsertSession(ref, setActive: true);
    await saveProjectMetadata(metadata, updateLastSelection: true);
  }

  Future<void> saveProjectMetadata(
    ProjectMetadata metadata, {
    bool updateLastSelection = false,
  }) async {
    final String? workspacePath = await loadWorkspacePath(metadata.projectId);
    if (workspacePath == null) {
      return;
    }
    await ensureWorkspaceScaffold(workspacePath);
    final File file = await _stateFile(workspacePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final String nextContents = const JsonEncoder.withIndent(
      '  ',
    ).convert(metadata.toJson());

    if (await file.exists()) {
      final String existingContents = await file.readAsString();
      if (existingContents == nextContents) {
        if (updateLastSelection && metadata.activeSessionId != null) {
          await _persistLastSelection(
            metadata.projectId,
            metadata.activeSessionId!,
          );
        }
        return;
      }
    }

    await file.writeAsString(nextContents);
    if (updateLastSelection && metadata.activeSessionId != null) {
      await _persistLastSelection(
        metadata.projectId,
        metadata.activeSessionId!,
      );
    }
  }

  Future<void> setActiveSession({
    required String projectId,
    required String sessionId,
  }) async {
    final ProjectMetadata? metadata = await loadProjectMetadata(projectId);
    if (metadata == null) {
      return;
    }
    final ProjectMetadata next = metadata.copyWith(activeSessionId: sessionId);
    await saveProjectMetadata(next, updateLastSelection: true);
  }

  Future<ProjectMetadata?> loadProjectMetadata(String projectId) async {
    final String? workspacePath = await loadWorkspacePath(projectId);
    if (workspacePath == null) {
      return null;
    }
    final Directory workspaceDirectory = Directory(workspacePath);
    if (!await workspaceDirectory.exists()) {
      return null;
    }

    await ensureWorkspaceScaffold(workspacePath);
    final File file = await _stateFile(workspacePath);
    if (!await file.exists()) {
      return ProjectMetadata.empty(
        projectId: projectId,
        workspacePath: workspacePath,
      );
    }

    final _LoadedMetadata loaded = await _loadMetadata(
      file,
      fallbackProjectId: projectId,
      fallbackWorkspacePath: workspacePath,
    );

    if (loaded.wasMigrated) {
      await saveProjectMetadata(loaded.metadata);
    }

    return loaded.metadata;
  }

  Future<ProjectSessionRef?> loadProject(
    String projectId, {
    String? sessionId,
  }) async {
    final ProjectMetadata? metadata = await loadProjectMetadata(projectId);
    if (metadata == null || metadata.sessions.isEmpty) {
      return null;
    }

    final String targetSessionId = sessionId ??
        metadata.activeSessionId ??
        metadata.sessions.first.sessionId;

    return metadata.sessionById(targetSessionId) ?? metadata.sessions.first;
  }

  Future<ProjectSessionRef?> loadLastProject() async {
    return null;
  }

  Future<void> clearLastProject() async {}

  Future<File> _stateFile(String workspacePath) async {
    return File(p.join(workspacePath, '.arcane-forge', _stateFileName));
  }

  Future<_LoadedMetadata> _loadMetadata(
    File file, {
    required String fallbackProjectId,
    required String fallbackWorkspacePath,
  }) async {
    final Map<String, dynamic> json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final int? schemaVersion = json['schemaVersion'] as int?;
    if (schemaVersion == ProjectMetadata.currentSchemaVersion &&
        json.containsKey('sessions')) {
      final ProjectMetadata metadata = ProjectMetadata.fromJson(json);
      final ProjectMetadata normalized = metadata.copyWith(
        projectId:
            metadata.projectId.isEmpty ? fallbackProjectId : metadata.projectId,
        workspacePath: metadata.workspacePath.isEmpty
            ? fallbackWorkspacePath
            : metadata.workspacePath,
      );
      return _LoadedMetadata(metadata: normalized, wasMigrated: false);
    }

    final ProjectSessionRef legacy = ProjectSessionRef.fromJson(json).copyWith(
      projectId: (json['projectId'] as String?) ?? fallbackProjectId,
      workspacePath:
          (json['workspacePath'] as String?) ?? fallbackWorkspacePath,
    );

    return _LoadedMetadata(
      metadata: ProjectMetadata.fromLegacySession(legacy),
      wasMigrated: true,
    );
  }

  Future<void> _persistLastSelection(String projectId, String sessionId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_lastSessionPrefix$projectId', sessionId);
  }
}

class _LoadedMetadata {
  const _LoadedMetadata({required this.metadata, required this.wasMigrated});

  final ProjectMetadata metadata;
  final bool wasMigrated;
}
