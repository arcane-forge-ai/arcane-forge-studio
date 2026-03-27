import 'package:flutter/foundation.dart';

import 'project_session_ref.dart';

@immutable
class ProjectMetadata {
  const ProjectMetadata({
    required this.schemaVersion,
    required this.projectId,
    required this.workspacePath,
    required this.sessions,
    this.activeSessionId,
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String projectId;
  final String workspacePath;
  final String? activeSessionId;
  final List<ProjectSessionRef> sessions;

  bool get hasSessions => sessions.isNotEmpty;

  ProjectSessionRef? get activeSession {
    if (sessions.isEmpty) {
      return null;
    }
    if (activeSessionId != null) {
      for (final ProjectSessionRef session in sessions) {
        if (session.sessionId == activeSessionId) {
          return session;
        }
      }
    }
    return sessions.first;
  }

  ProjectSessionRef? sessionById(String sessionId) {
    for (final ProjectSessionRef session in sessions) {
      if (session.sessionId == sessionId) {
        return session;
      }
    }
    return null;
  }

  ProjectMetadata copyWith({
    int? schemaVersion,
    String? projectId,
    String? workspacePath,
    String? activeSessionId,
    List<ProjectSessionRef>? sessions,
  }) {
    return ProjectMetadata(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      projectId: projectId ?? this.projectId,
      workspacePath: workspacePath ?? this.workspacePath,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      sessions: sessions ?? this.sessions,
    );
  }

  ProjectMetadata upsertSession(
    ProjectSessionRef nextSession, {
    bool setActive = true,
  }) {
    final List<ProjectSessionRef> merged = <ProjectSessionRef>[
      for (final ProjectSessionRef session in sessions)
        if (session.sessionId != nextSession.sessionId) session,
      nextSession,
    ];

    merged.sort((ProjectSessionRef a, ProjectSessionRef b) {
      if (a.sessionId == activeSessionId) {
        return -1;
      }
      if (b.sessionId == activeSessionId) {
        return 1;
      }
      return b.sessionId.compareTo(a.sessionId);
    });

    return copyWith(
      schemaVersion: currentSchemaVersion,
      activeSessionId: setActive ? nextSession.sessionId : activeSessionId,
      sessions: merged,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'projectId': projectId,
      'workspacePath': workspacePath,
      'activeSessionId': activeSessionId,
      'sessions': sessions
          .map((ProjectSessionRef session) => session.toJson())
          .toList(),
    };
  }

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) {
    final List<ProjectSessionRef> sessions =
        (json['sessions'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic raw) {
              if (raw is! Map<String, dynamic>) {
                return null;
              }
              return ProjectSessionRef.fromJson(raw);
            })
            .whereType<ProjectSessionRef>()
            .toList();

    return ProjectMetadata(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      projectId: json['projectId'] as String? ?? '',
      workspacePath: json['workspacePath'] as String? ?? '',
      activeSessionId: json['activeSessionId'] as String?,
      sessions: sessions,
    );
  }

  factory ProjectMetadata.fromLegacySession(ProjectSessionRef legacy) {
    return ProjectMetadata(
      schemaVersion: currentSchemaVersion,
      projectId: legacy.projectId,
      workspacePath: legacy.workspacePath,
      activeSessionId: legacy.sessionId,
      sessions: <ProjectSessionRef>[legacy],
    );
  }

  factory ProjectMetadata.empty({
    required String projectId,
    required String workspacePath,
  }) {
    return ProjectMetadata(
      schemaVersion: currentSchemaVersion,
      projectId: projectId,
      workspacePath: workspacePath,
      activeSessionId: null,
      sessions: const <ProjectSessionRef>[],
    );
  }
}
