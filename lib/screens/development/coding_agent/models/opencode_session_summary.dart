import 'package:flutter/foundation.dart';

@immutable
class OpencodeSessionSummary {
  const OpencodeSessionSummary({
    required this.sessionId,
    required this.title,
    required this.updatedAt,
    this.archived = false,
  });

  final String sessionId;
  final String title;
  final DateTime updatedAt;
  final bool archived;
}
