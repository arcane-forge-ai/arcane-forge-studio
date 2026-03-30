import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/models/opencode_models.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/opencode_server_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('OpencodeServerManager startup preferences', () {
    test('prefers port 4096 before the fallback range', () {
      expect(
        OpencodeServerManager.candidatePortsForTesting,
        const <int>[
          4096,
          4099,
          4100,
          4101,
          4102,
          4103,
          4104,
          4105,
          4106,
          4107,
          4108,
          4109,
          4110,
        ],
      );
    });
  });

  group('OpencodeServerManager managed sidecar detection', () {
    test('matches the app-managed print-logs serve command', () {
      expect(
        OpencodeServerManager.looksLikeManagedServeCommandForTesting(
          '/opt/homebrew/bin/opencode serve --hostname 127.0.0.1 --port 4099 --print-logs',
        ),
        isTrue,
      );
    });

    test('does not match the OpenCode desktop app process', () {
      expect(
        OpencodeServerManager.looksLikeManagedServeCommandForTesting(
          '/Applications/OpenCode.app/Contents/MacOS/OpenCode',
        ),
        isFalse,
      );
    });

    test('extracts sidecar pid from ps output line', () {
      expect(
        OpencodeServerManager.managedSidecarPidFromPsLine(
          '64344 /opt/homebrew/bin/opencode serve --hostname 127.0.0.1 --port 4099 --print-logs',
        ),
        64344,
      );
    });

    test('ignores ps output for non-managed commands', () {
      expect(
        OpencodeServerManager.managedSidecarPidFromPsLine(
          '57159 /Applications/OpenCode.app/Contents/MacOS/OpenCode',
        ),
        isNull,
      );
    });
  });

  group('OpencodeServerManager ownership stop logic', () {
    test('terminates managed pid when app owns the sidecar', () {
      expect(
        OpencodeServerManager.shouldTerminateManagedPid(
          ownsManagedProcess: true,
          managedPid: 12345,
        ),
        isTrue,
      );
    });

    test('does not terminate a healthy reused external server', () {
      expect(
        OpencodeServerManager.shouldTerminateManagedPid(
          ownsManagedProcess: false,
          managedPid: 12345,
        ),
        isFalse,
      );
    });

    test('does not terminate when owned sidecar pid is missing', () {
      expect(
        OpencodeServerManager.shouldTerminateManagedPid(
          ownsManagedProcess: true,
          managedPid: null,
        ),
        isFalse,
      );
    });
  });

  group('OpencodeServerManager binary resolution', () {
    late Directory supportDirectory;
    late Directory bundleRoot;

    setUp(() {
      supportDirectory = Directory.systemTemp.createTempSync(
        'opencode-manager-support-',
      );
      bundleRoot = Directory.systemTemp.createTempSync(
        'opencode-manager-bundle-',
      );
    });

    tearDown(() {
      if (supportDirectory.existsSync()) {
        supportDirectory.deleteSync(recursive: true);
      }
      if (bundleRoot.existsSync()) {
        bundleRoot.deleteSync(recursive: true);
      }
    });

    test('installs the packaged sidecar into app-managed storage', () async {
      final Directory packagedSidecarDirectory =
          _packagedSidecarDirectory(bundleRoot)
            ..createSync(recursive: true);
      final File packagedBinary = File(
        p.join(packagedSidecarDirectory.path, _testBinaryFileName()),
      );
      _writeVersionBinary(packagedBinary, '1.3.3');
      File(
        p.join(packagedSidecarDirectory.path, 'manifest.json'),
      ).writeAsStringSync(
        '{"version":"1.3.3","binaryName":"${_testBinaryFileName()}"}',
      );

      final OpencodeServerManager manager = OpencodeServerManager(
        supportDirectoryProvider: () async => supportDirectory,
        resolvedExecutablePathProvider: () => _resolvedExecutablePath(bundleRoot),
        environmentProvider: () => <String, String>{},
        executableFileChecker: _isTestExecutable,
        binaryVersionReader: _readTestVersion,
      );

      final diagnostics = await manager.diagnostics();

      expect(diagnostics.binaryDetected, isTrue);
      expect(diagnostics.binarySource, OpencodeBinarySource.bundledInstalled);
      expect(diagnostics.bundledVersion, '1.3.3');
      expect(diagnostics.binaryPath, isNotNull);
      expect(diagnostics.installPath, isNotNull);
      expect(diagnostics.binaryPath, startsWith(supportDirectory.path));
      expect(File(diagnostics.binaryPath!).existsSync(), isTrue);
    });

    test('bundled install prunes older versions after a successful upgrade',
        () async {
      final Directory oldVersionDirectory = Directory(
        p.join(
          supportDirectory.path,
          'opencode_sidecar',
          'bin',
          '1.2.0',
        ),
      )..createSync(recursive: true);
      _writeVersionBinary(
        File(p.join(oldVersionDirectory.path, _testBinaryFileName())),
        '1.2.0',
      );

      final Directory packagedSidecarDirectory =
          _packagedSidecarDirectory(bundleRoot)
            ..createSync(recursive: true);
      _writeVersionBinary(
        File(p.join(packagedSidecarDirectory.path, _testBinaryFileName())),
        '1.3.3',
      );
      File(
        p.join(packagedSidecarDirectory.path, 'manifest.json'),
      ).writeAsStringSync(
        '{"version":"1.3.3","binaryName":"${_testBinaryFileName()}"}',
      );

      final OpencodeServerManager manager = OpencodeServerManager(
        supportDirectoryProvider: () async => supportDirectory,
        resolvedExecutablePathProvider: () => _resolvedExecutablePath(bundleRoot),
        environmentProvider: () => <String, String>{},
        executableFileChecker: _isTestExecutable,
        binaryVersionReader: _readTestVersion,
      );

      final diagnostics = await manager.diagnostics();

      expect(diagnostics.binarySource, OpencodeBinarySource.bundledInstalled);
      expect(oldVersionDirectory.existsSync(), isFalse);
    });

    test('override path wins over the packaged sidecar', () async {
      final Directory packagedSidecarDirectory =
          _packagedSidecarDirectory(bundleRoot)
            ..createSync(recursive: true);
      _writeVersionBinary(
        File(p.join(packagedSidecarDirectory.path, _testBinaryFileName())),
        '1.3.3',
      );
      File(
        p.join(packagedSidecarDirectory.path, 'manifest.json'),
      ).writeAsStringSync(
        '{"version":"1.3.3","binaryName":"${_testBinaryFileName()}"}',
      );

      final File overrideBinary = File(
        p.join(bundleRoot.path, 'override-opencode.${Platform.isWindows ? 'exe' : 'sh'}'),
      );
      _writeVersionBinary(overrideBinary, '9.9.9');

      final OpencodeServerManager manager = OpencodeServerManager(
        supportDirectoryProvider: () async => supportDirectory,
        resolvedExecutablePathProvider: () => _resolvedExecutablePath(bundleRoot),
        environmentProvider: () => <String, String>{
          'OPENCODE_BINARY_PATH': overrideBinary.path,
        },
        executableFileChecker: _isTestExecutable,
        binaryVersionReader: _readTestVersion,
      );

      final diagnostics = await manager.diagnostics();

      expect(diagnostics.binarySource, OpencodeBinarySource.override);
      expect(diagnostics.binaryPath, overrideBinary.path);
      expect(diagnostics.installPath, isNull);
    });

    test('falls back to PATH only when no packaged sidecar exists', () async {
      final File systemBinary =
          File(p.join(bundleRoot.path, 'system-opencode.${Platform.isWindows ? 'exe' : 'sh'}'));
      _writeVersionBinary(systemBinary, '1.2.3');

      final OpencodeServerManager manager = OpencodeServerManager(
        supportDirectoryProvider: () async => supportDirectory,
        resolvedExecutablePathProvider: () => _resolvedExecutablePath(bundleRoot),
        environmentProvider: () => <String, String>{},
        systemBinaryPathResolver: () async => systemBinary.path,
        executableFileChecker: _isTestExecutable,
        binaryVersionReader: _readTestVersion,
      );

      final diagnostics = await manager.diagnostics();

      expect(diagnostics.binarySource, OpencodeBinarySource.systemPath);
      expect(diagnostics.binaryPath, systemBinary.path);
    });
  });
}

Directory _packagedSidecarDirectory(Directory bundleRoot) {
  if (Platform.isWindows) {
    return Directory(p.join(bundleRoot.path, 'opencode_sidecar'));
  }
  return Directory(
    p.join(
      bundleRoot.path,
      'Arcane Forge Studio.app',
      'Contents',
      'Resources',
      'opencode_sidecar',
    ),
  );
}

String _resolvedExecutablePath(Directory bundleRoot) {
  if (Platform.isWindows) {
    return p.join(bundleRoot.path, 'arcane_forge.exe');
  }
  return p.join(
    bundleRoot.path,
    'Arcane Forge Studio.app',
    'Contents',
    'MacOS',
    'arcane_forge',
  );
}

String _testBinaryFileName() {
  return Platform.isWindows ? 'opencode.exe' : 'opencode';
}

Future<bool> _isTestExecutable(String path) async {
  return File(path).existsSync();
}

Future<String> _readTestVersion(String binaryPath) async {
  return File(binaryPath).readAsString();
}

void _writeVersionBinary(File file, String version) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(version);
  if (!Platform.isWindows) {
    Process.runSync('/bin/chmod', <String>['755', file.path]);
  }
}
