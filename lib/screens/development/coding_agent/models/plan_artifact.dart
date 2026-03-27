import 'package:flutter/foundation.dart';

@immutable
class PlanArtifact {
  const PlanArtifact({
    required this.relativePath,
    required this.absolutePath,
    required this.modifiedAt,
  });

  final String relativePath;
  final String absolutePath;
  final DateTime modifiedAt;
}
