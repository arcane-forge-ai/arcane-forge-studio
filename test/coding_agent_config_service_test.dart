import 'dart:convert';
import 'dart:io';

import 'package:arcane_forge/screens/development/coding_agent/models/coding_agent_config.dart';
import 'package:arcane_forge/screens/development/coding_agent/services/coding_agent_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodingAgentConfigService', () {
    late Directory supportDirectory;
    late Directory workspaceDirectory;
    late CodingAgentConfigService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      supportDirectory = Directory.systemTemp.createTempSync(
        'coding-agent-config-support-',
      );
      workspaceDirectory = Directory.systemTemp.createTempSync(
        'coding-agent-config-workspace-',
      );
      service = CodingAgentConfigService(
        supportDirectoryProvider: () async => supportDirectory,
      );
    });

    tearDown(() {
      if (supportDirectory.existsSync()) {
        supportDirectory.deleteSync(recursive: true);
      }
      if (workspaceDirectory.existsSync()) {
        workspaceDirectory.deleteSync(recursive: true);
      }
    });

    test('saves settings and secrets into app-managed config files', () async {
      final CodingAgentGlobalConfig config = CodingAgentGlobalConfig(
        selectedProviderId: 'openai',
        defaultModel: 'openai/gpt-5',
        defaultAgent: 'plan',
        providers: kDefaultCodingAgentProviderProfiles
            .map((CodingAgentProviderProfile item) {
          if (item.id != 'openai') {
            return item;
          }
          return item.copyWith(baseUrl: 'https://gateway.example/v1');
        }).toList(),
      );
      const CodingAgentSecretConfig secrets = CodingAgentSecretConfig(
        apiKeys: <String, String>{'openai': 'sk-test-123'},
      );

      await service.saveBundle(config, secrets);
      final CodingAgentConfigBundle loaded = await service.loadBundle();

      expect(loaded.config.selectedProviderId, 'openai');
      expect(loaded.config.defaultModel, 'openai/gpt-5');
      expect(loaded.config.defaultAgent, 'plan');
      expect(
        loaded.config.selectedProvider?.baseUrl,
        'https://gateway.example/v1',
      );
      expect(loaded.secrets.apiKeys['openai'], 'sk-test-123');

      final File settingsFile = await service.settingsFile();
      final File secretsFile = await service.secretsFile();

      expect(settingsFile.existsSync(), isTrue);
      expect(secretsFile.existsSync(), isTrue);

      final Map<String, dynamic> settings =
          jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> storedSecrets =
          jsonDecode(secretsFile.readAsStringSync()) as Map<String, dynamic>;

      expect(settings['selectedProviderId'], 'openai');
      expect(settings['defaultModel'], 'openai/gpt-5');
      expect(
        (storedSecrets['apiKeys'] as Map<String, dynamic>)['openai'],
        'sk-test-123',
      );
    });

    test(
      'prepares OpenCode runtime config without leaking secrets into the generated config file',
      () async {
        final CodingAgentGlobalConfig config = CodingAgentGlobalConfig(
          selectedProviderId: 'openai',
          defaultModel: 'openai/gpt-5',
          defaultAgent: 'build',
          providers: kDefaultCodingAgentProviderProfiles
              .map((CodingAgentProviderProfile item) {
            if (item.id != 'openai') {
              return item;
            }
            return item.copyWith(baseUrl: 'https://proxy.example/v1');
          }).toList(),
        );
        const CodingAgentSecretConfig secrets = CodingAgentSecretConfig(
          apiKeys: <String, String>{'openai': 'sk-secret-do-not-inline'},
        );

        await service.saveBundle(config, secrets);
        final PreparedCodingAgentConfig prepared =
            await service.prepareRuntimeConfig();

        expect(prepared.runtimeConfig.environment['AF_OPENCODE_API_KEY'],
            isNotEmpty);
        expect(prepared.runtimeConfig.selectedProviderId, 'openai');
        expect(prepared.runtimeConfig.selectedModel, 'openai/gpt-5');

        final File generatedConfig = File(prepared.configFilePath);
        expect(generatedConfig.existsSync(), isTrue);

        final String rawConfig = generatedConfig.readAsStringSync();
        final Map<String, dynamic> decoded =
            jsonDecode(rawConfig) as Map<String, dynamic>;
        final Map<String, dynamic> provider = (decoded['provider']
            as Map<String, dynamic>)['openai'] as Map<String, dynamic>;
        final Map<String, dynamic> options =
            provider['options'] as Map<String, dynamic>;

        expect(options['baseURL'], 'https://proxy.example/v1');
        expect(options['apiKey'], '{env:AF_OPENCODE_API_KEY}');
        expect(rawConfig.contains('sk-secret-do-not-inline'), isFalse);
        expect(
          Directory(p.join(workspaceDirectory.path, '.opencode')).existsSync(),
          isFalse,
        );
      },
    );
  });
}
