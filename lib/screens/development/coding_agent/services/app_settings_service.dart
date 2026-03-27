import 'package:shared_preferences/shared_preferences.dart';

import '../models/opencode_app_settings.dart';

class AppSettingsService {
  static const String _autoStartSidecarKey = 'settings_auto_start_sidecar';
  static const String _defaultPermissionModeKey =
      'settings_default_permission_mode';
  static const String _defaultModelKey = 'settings_default_model';
  static const String _defaultAgentKey = 'settings_default_agent';

  Future<OpencodeAppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return OpencodeAppSettings(
      autoStartSidecar: prefs.getBool(_autoStartSidecarKey) ?? true,
      defaultPermissionMode: defaultPermissionModeFromName(
        prefs.getString(_defaultPermissionModeKey),
      ),
      defaultModel: prefs.getString(_defaultModelKey) ?? '',
      defaultAgent: prefs.getString(_defaultAgentKey) ?? '',
    );
  }

  Future<void> save(OpencodeAppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartSidecarKey, settings.autoStartSidecar);
    await prefs.setString(
      _defaultPermissionModeKey,
      settings.defaultPermissionMode.name,
    );
    await prefs.setString(_defaultModelKey, settings.defaultModel);
    await prefs.setString(_defaultAgentKey, settings.defaultAgent);
  }
}
