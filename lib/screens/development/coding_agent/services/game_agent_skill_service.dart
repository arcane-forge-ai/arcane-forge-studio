import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class InstalledGameAgentSkill {
  const InstalledGameAgentSkill({
    required this.sourceCommit,
    required this.skillDirectory,
  });

  final String sourceCommit;
  final Directory skillDirectory;
  String get searchDirectory => skillDirectory.parent.path;
}

/// Installs only the application's bundled skill; no network or global writes.
class GameAgentSkillService {
  GameAgentSkillService({
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory;

  static const String skillName = 'arcane-forge-game-agent';
  static const String manifestName = 'skill-manifest.json';
  static const String repository =
      'https://github.com/arcane-forge-ai/arcane-forge-agent-kit';
  final Future<Directory> Function() _supportDirectoryProvider;

  Future<InstalledGameAgentSkill?> ensureInstalled({
    required Directory? bundledSidecarDirectory,
    bool force = false,
  }) async {
    if (bundledSidecarDirectory == null) return null;
    final File manifestFile =
        File(p.join(bundledSidecarDirectory.path, manifestName));
    if (!await manifestFile.exists()) {
      if (await Directory(p.join(bundledSidecarDirectory.path, 'skills'))
          .exists()) {
        throw const FormatException('Bundled skill metadata is missing.');
      }
      return null;
    }
    if (await FileSystemEntity.type(manifestFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException(
          'Bundled skill metadata must be a regular file.');
    }
    final dynamic decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bundled skill metadata must be an object.');
    }
    final String commit = '${decoded['sourceCommit'] ?? ''}';
    if (decoded['schemaVersion'] != 1 ||
        decoded['skillName'] != skillName ||
        decoded['sourceRepository'] != repository ||
        decoded['sourceRef'] is! String ||
        (decoded['sourceRef'] as String).trim().isEmpty ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
      throw const FormatException('Bundled skill metadata is invalid.');
    }
    final dynamic entries = decoded['files'];
    if (entries is! Map<String, dynamic> || entries.isEmpty) {
      throw const FormatException('Bundled skill file hashes are missing.');
    }
    final Map<String, String> hashes = <String, String>{};
    final Set<String> portableNames = <String>{};
    for (final MapEntry<String, dynamic> entry in entries.entries) {
      if (!_safeRelativePath(entry.key) ||
          entry.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.value as String) ||
          !portableNames.add(entry.key.toLowerCase())) {
        throw const FormatException(
            'Bundled skill contains an unsafe file entry.');
      }
      hashes[entry.key] = entry.value as String;
    }
    if (!hashes.containsKey('SKILL.md') ||
        !hashes.keys.any((String name) => name.startsWith('scripts/')) ||
        !hashes.keys.any((String name) => name.startsWith('references/'))) {
      throw const FormatException('Bundled skill is missing supporting files.');
    }
    final Directory source = Directory(
      p.join(bundledSidecarDirectory.path, 'skills', skillName),
    );
    await _verifyDirectory(source, hashes);
    final String skillText =
        await File(p.join(source.path, 'SKILL.md')).readAsString();
    if (!RegExp(r'^---\r?\n').hasMatch(skillText) ||
        !RegExp(r'^name:\s*arcane-forge-game-agent\s*$', multiLine: true)
            .hasMatch(skillText)) {
      throw const FormatException(
          'Bundled SKILL.md has an invalid skill name.');
    }

    final Directory support = await _supportDirectoryProvider();
    final Directory managed =
        Directory(p.join(support.path, 'opencode_sidecar', 'skills'));
    await _createManagedDirectory(support, managed);
    final Directory version = Directory(p.join(managed.path, commit));
    await _createManagedDirectory(managed, version);
    final Directory target = Directory(p.join(version.path, skillName));
    if (!force) {
      try {
        await _verifyDirectory(target, hashes);
        return InstalledGameAgentSkill(
            sourceCommit: commit, skillDirectory: target);
      } on FileSystemException {
        // Missing or changed installations are repaired from the shipped copy.
      } on FormatException {
        // Hash and file-set mismatches are repaired without changing other versions.
      }
    }

    final Directory staging = await version.createTemp('.install-');
    try {
      for (final String name in hashes.keys) {
        final File destination =
            File(p.join(staging.path, p.joinAll(name.split('/'))));
        await destination.parent.create(recursive: true);
        await File(p.join(source.path, p.joinAll(name.split('/'))))
            .copy(destination.path);
      }
      await _verifyDirectory(staging, hashes);
      final FileSystemEntityType targetType =
          await FileSystemEntity.type(target.path, followLinks: false);
      if (targetType == FileSystemEntityType.link) {
        await Link(target.path).delete();
      } else if (targetType == FileSystemEntityType.directory) {
        await target.delete(recursive: true);
      } else if (targetType != FileSystemEntityType.notFound) {
        await File(target.path).delete();
      }
      await staging.rename(target.path);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
    return InstalledGameAgentSkill(
        sourceCommit: commit, skillDirectory: target);
  }

  static bool isDiscovered(dynamic response, InstalledGameAgentSkill skill) {
    if (response is! List) return false;
    final String expected = p.join(skill.skillDirectory.path, 'SKILL.md');
    return response.any((dynamic entry) =>
        entry is Map &&
        entry['name'] == skillName &&
        entry['location'] is String &&
        p.equals(
            p.normalize(entry['location'] as String), p.normalize(expected)));
  }

  static bool _safeRelativePath(String value) {
    if (value.isEmpty ||
        value.contains('\\') ||
        value.contains(':') ||
        RegExp(r'[\x00-\x1f<>"|?*]').hasMatch(value) ||
        value.startsWith('/')) {
      return false;
    }
    return value.split('/').every((String part) =>
        part.isNotEmpty &&
        part != '.' &&
        part != '..' &&
        !part.endsWith('.') &&
        !part.endsWith(' ') &&
        !RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                caseSensitive: false)
            .hasMatch(part));
  }

  Future<void> _createManagedDirectory(Directory base, Directory target) async {
    await base.create(recursive: true);
    if (await FileSystemEntity.type(base.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException(
          'Managed skill storage must be a directory.');
    }
    String current = base.path;
    for (final String part
        in p.split(p.relative(target.path, from: base.path))) {
      current = p.join(current, part);
      final FileSystemEntityType type =
          await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        await Directory(current).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const FileSystemException(
            'Managed skill storage contains a symbolic link or file.');
      }
    }
  }

  Future<void> _verifyDirectory(
      Directory directory, Map<String, String> hashes) async {
    // Reject links in every source ancestor below the bundled sidecar as well.
    if (await FileSystemEntity.type(directory.parent.path,
                followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw const FileSystemException(
          'Skill folder is missing or is a symbolic link.');
    }
    final Set<String> found = <String>{};
    await for (final FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      final FileSystemEntityType type =
          await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) continue;
      if (type != FileSystemEntityType.file) {
        throw const FormatException(
            'Skill folders cannot contain symbolic links.');
      }
      final String name = p
          .relative(entity.path, from: directory.path)
          .split(p.separator)
          .join('/');
      if (!hashes.containsKey(name) ||
          sha256.convert(await File(entity.path).readAsBytes()).toString() !=
              hashes[name]) {
        throw FormatException(
            'Skill file failed integrity verification: $name');
      }
      found.add(name);
    }
    if (found.length != hashes.length) {
      throw const FormatException('Skill folder is missing files.');
    }
  }
}
