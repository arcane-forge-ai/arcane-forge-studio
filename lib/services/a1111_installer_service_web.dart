import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/download_models.dart';

/// Web stub for A1111InstallerService
/// Local A1111 installation is not supported on web platform
class A1111InstallerService {
  A1111InstallerService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Check if A1111 is already installed
  /// Always returns false on web (local installation not supported)
  Future<bool> isInstalled(dynamic baseDir) async {
    debugPrint('⚠️ A1111 local installation is not supported on web platform');
    return false;
  }

  /// Download and install A1111
  /// Throws UnsupportedError on web (local installation not supported)
  Future<void> downloadAndInstall({
    required String url,
    required dynamic baseDir,
    required void Function(InstallerProgress) onProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnsupportedError(
      'Local A1111 installation is not supported on web. '
      'Please use online A1111 mode which connects to a backend API.',
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

