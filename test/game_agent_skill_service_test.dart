import 'dart:convert';
import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/services/game_agent_skill_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory support;
  late Directory bundle;
  late GameAgentSkillService service;
  const String firstCommit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const String secondCommit = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  setUp(() {
    root = Directory.systemTemp.createTempSync('game-agent-skill-test-');
    support = Directory(p.join(root.path, 'support'));
    bundle = Directory(p.join(root.path, 'bundle'))..createSync();
    service =
        GameAgentSkillService(supportDirectoryProvider: () async => support);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
      'copies nested supporting files offline and reuses an intact installation',
      () async {
    _bundle(bundle, firstCommit);
    final InstalledGameAgentSkill installed =
        (await service.ensureInstalled(bundledSidecarDirectory: bundle))!;
    expect(installed.sourceCommit, firstCommit);
    expect(installed.searchDirectory,
        p.join(support.path, 'opencode_sidecar', 'skills', firstCommit));
    final File helper = File(p.join(
        installed.skillDirectory.path, 'scripts', 'nested', 'helper.py'));
    expect(helper.readAsStringSync(), 'print("fixture")\n');
    final DateTime stamp = DateTime(2020);
    helper.setLastModifiedSync(stamp);
    await service.ensureInstalled(bundledSidecarDirectory: bundle);
    expect(helper.lastModifiedSync(), stamp);
    expect(
        File(p.join(installed.skillDirectory.path, 'references', 'guide.md'))
            .existsSync(),
        isTrue);
  });

  test(
      'repairs changed files and unexpected files without modifying other versions',
      () async {
    _bundle(bundle, firstCommit);
    final InstalledGameAgentSkill old =
        (await service.ensureInstalled(bundledSidecarDirectory: bundle))!;
    _bundle(bundle, secondCommit);
    final InstalledGameAgentSkill current =
        (await service.ensureInstalled(bundledSidecarDirectory: bundle))!;
    final File helper = File(
        p.join(current.skillDirectory.path, 'scripts', 'nested', 'helper.py'));
    helper.writeAsStringSync('changed');
    File(p.join(current.skillDirectory.path, 'unexpected.txt'))
        .writeAsStringSync('extra');
    await service.ensureInstalled(bundledSidecarDirectory: bundle);
    expect(helper.readAsStringSync(), 'print("fixture")\n');
    expect(
        File(p.join(current.skillDirectory.path, 'unexpected.txt'))
            .existsSync(),
        isFalse);
    expect(old.skillDirectory.existsSync(), isTrue);
  });

  test('force repair replaces an intact copy', () async {
    _bundle(bundle, firstCommit);
    final InstalledGameAgentSkill installed =
        (await service.ensureInstalled(bundledSidecarDirectory: bundle))!;
    final File helper = File(p.join(installed.skillDirectory.path, 'SKILL.md'));
    helper.setLastModifiedSync(DateTime(2020));
    await service.ensureInstalled(bundledSidecarDirectory: bundle, force: true);
    expect(helper.lastModifiedSync(), isNot(DateTime(2020)));
  });

  test('returns unavailable for an older or development bundle without a skill',
      () async {
    expect(
        await service.ensureInstalled(bundledSidecarDirectory: null), isNull);
    expect(
        await service.ensureInstalled(bundledSidecarDirectory: bundle), isNull);
    expect(support.existsSync(), isFalse);
  });

  test('rejects corrupt bundle before replacing the installed skill', () async {
    _bundle(bundle, firstCommit);
    final InstalledGameAgentSkill installed =
        (await service.ensureInstalled(bundledSidecarDirectory: bundle))!;
    File(p.join(
            bundle.path, 'skills', GameAgentSkillService.skillName, 'SKILL.md'))
        .writeAsStringSync('corrupt');
    await expectLater(
        service.ensureInstalled(bundledSidecarDirectory: bundle, force: true),
        throwsFormatException);
    expect(
        File(p.join(installed.skillDirectory.path, 'SKILL.md'))
            .readAsStringSync(),
        contains('name: arcane-forge-game-agent'));
  });

  test('rejects missing supporting files and unsafe manifest paths', () async {
    for (final String unsafe in <String>[
      '../escape',
      '/absolute',
      r'..\escape',
      'C:/escape',
      'bad?name',
      'con/file'
    ]) {
      final Map<String, dynamic> manifest = _bundle(bundle, firstCommit);
      (manifest['files'] as Map<String, String>)[unsafe] = '0' * 64;
      _writeManifest(bundle, manifest);
      await expectLater(
          service.ensureInstalled(bundledSidecarDirectory: bundle),
          throwsFormatException);
    }
    final Map<String, dynamic> manifest = _bundle(bundle, firstCommit);
    (manifest['files'] as Map<String, String>).remove('references/guide.md');
    _writeManifest(bundle, manifest);
    await expectLater(service.ensureInstalled(bundledSidecarDirectory: bundle),
        throwsFormatException);
    expect(support.existsSync(), isFalse);
  });

  test('rejects source symlinks and managed storage symlinks', () async {
    if (Platform.isWindows) return;
    _bundle(bundle, firstCommit);
    final Directory skills = Directory(p.join(bundle.path, 'skills'));
    final Directory actualSkills =
        Directory(p.join(root.path, 'actual-skills'));
    skills.renameSync(actualSkills.path);
    Link(skills.path).createSync(actualSkills.path);
    await expectLater(service.ensureInstalled(bundledSidecarDirectory: bundle),
        throwsA(isA<FileSystemException>()));
    Link(skills.path).deleteSync();
    actualSkills.renameSync(skills.path);
    final Directory external = Directory(p.join(root.path, 'external'))
      ..createSync();
    Directory(p.join(support.path, 'opencode_sidecar'))
        .createSync(recursive: true);
    Link(p.join(support.path, 'opencode_sidecar', 'skills'))
        .createSync(external.path);
    await expectLater(service.ensureInstalled(bundledSidecarDirectory: bundle),
        throwsA(isA<FileSystemException>()));
    expect(external.listSync(), isEmpty);
  });

  test('discovery requires the bundled location as well as the name', () {
    final InstalledGameAgentSkill installed = InstalledGameAgentSkill(
        sourceCommit: firstCommit, skillDirectory: Directory('/managed/skill'));
    expect(
        GameAgentSkillService.isDiscovered(<dynamic>[
          <String, dynamic>{
            'name': GameAgentSkillService.skillName,
            'location': '/personal/SKILL.md'
          }
        ], installed),
        isFalse);
    expect(
        GameAgentSkillService.isDiscovered(<dynamic>[
          <String, dynamic>{
            'name': GameAgentSkillService.skillName,
            'location': p.join(installed.skillDirectory.path, 'SKILL.md')
          }
        ], installed),
        isTrue);
    expect(GameAgentSkillService.isDiscovered(null, installed), isFalse);
  });
}

Map<String, dynamic> _bundle(Directory bundle, String commit) {
  final Directory skill =
      Directory(p.join(bundle.path, 'skills', GameAgentSkillService.skillName));
  if (skill.existsSync()) skill.deleteSync(recursive: true);
  final Map<String, String> files = <String, String>{
    'SKILL.md':
        '---\nname: arcane-forge-game-agent\ndescription: fixture\n---\nFixture skill.\n',
    'scripts/nested/helper.py': 'print("fixture")\n',
    'references/guide.md': '# Fixture\n',
  };
  final Map<String, String> hashes = <String, String>{};
  for (final MapEntry<String, String> entry in files.entries) {
    final File file = File(p.join(skill.path, p.joinAll(entry.key.split('/'))));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
    hashes[entry.key] = sha256.convert(utf8.encode(entry.value)).toString();
  }
  final Map<String, dynamic> manifest = <String, dynamic>{
    'schemaVersion': 1,
    'skillName': GameAgentSkillService.skillName,
    'sourceRepository': GameAgentSkillService.repository,
    'sourceRef': 'main',
    'sourceCommit': commit,
    'files': hashes,
  };
  _writeManifest(bundle, manifest);
  return manifest;
}

void _writeManifest(Directory bundle, Map<String, dynamic> manifest) {
  File(p.join(bundle.path, GameAgentSkillService.manifestName))
      .writeAsStringSync(jsonEncode(manifest));
}
