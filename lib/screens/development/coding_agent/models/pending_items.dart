import 'package:flutter/foundation.dart';

@immutable
class PendingPermission {
  const PendingPermission({
    required this.requestId,
    required this.title,
    this.sessionId,
    this.permissionId,
    this.message,
    this.status,
    this.raw,
  });

  final String requestId;
  final String title;
  final String? sessionId;
  final String? permissionId;
  final String? message;
  final String? status;
  final Map<String, dynamic>? raw;

  PendingPermission copyWith({
    String? requestId,
    String? title,
    String? sessionId,
    String? permissionId,
    String? message,
    String? status,
    Map<String, dynamic>? raw,
  }) {
    return PendingPermission(
      requestId: requestId ?? this.requestId,
      title: title ?? this.title,
      sessionId: sessionId ?? this.sessionId,
      permissionId: permissionId ?? this.permissionId,
      message: message ?? this.message,
      status: status ?? this.status,
      raw: raw ?? this.raw,
    );
  }
}

@immutable
class PendingQuestion {
  const PendingQuestion({
    required this.requestId,
    required this.prompt,
    this.options = const <String>[],
    this.status,
    this.raw,
  });

  final String requestId;
  final String prompt;
  final List<String> options;
  final String? status;
  final Map<String, dynamic>? raw;

  PendingQuestion copyWith({
    String? requestId,
    String? prompt,
    List<String>? options,
    String? status,
    Map<String, dynamic>? raw,
  }) {
    return PendingQuestion(
      requestId: requestId ?? this.requestId,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      status: status ?? this.status,
      raw: raw ?? this.raw,
    );
  }
}
