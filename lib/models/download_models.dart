import 'package:flutter/foundation.dart';

/// Status for long-running installer operations
enum InstallerStatus {
  idle,
  downloading,
  extracting,
  completed,
  error,
}

/// Progress payload for UI updates
@immutable
class InstallerProgress {
  final InstallerStatus status;
  final double? fraction; // 0..1 when known
  final int? receivedBytes;
  final int? totalBytes;
  final String? message;

  const InstallerProgress(
    this.status, {
    this.fraction,
    this.receivedBytes,
    this.totalBytes,
    this.message,
  });
}


