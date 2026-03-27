import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WorkspaceAccessService {
  static const MethodChannel _channel = MethodChannel(
    'arcane_forge/workspace_access',
  );

  bool get _supportsSecureBookmarks => !kIsWeb && Platform.isMacOS;

  Future<String?> createSecurityBookmark(String path) async {
    if (!_supportsSecureBookmarks) {
      return null;
    }
    try {
      return await _channel
          .invokeMethod<String>('createBookmark', <String, dynamic>{
        'path': path,
      });
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> restoreSecurityBookmark(String bookmark) async {
    if (!_supportsSecureBookmarks || bookmark.trim().isEmpty) {
      return null;
    }
    try {
      return await _channel
          .invokeMethod<String>('resolveBookmark', <String, dynamic>{
        'bookmark': bookmark,
      });
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> stopSecurityBookmark(String bookmark) async {
    if (!_supportsSecureBookmarks || bookmark.trim().isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('stopBookmark', <String, dynamic>{
        'bookmark': bookmark,
      });
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }
}
