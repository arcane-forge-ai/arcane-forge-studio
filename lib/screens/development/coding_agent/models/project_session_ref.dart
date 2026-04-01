import 'package:flutter/foundation.dart';

enum ProjectPhase { planning, acting }

enum WorkflowPath { planFirst, directBuild }

ProjectPhase projectPhaseFromName(String? value) {
  return ProjectPhase.values.firstWhere(
    (phase) => phase.name == value,
    orElse: () => ProjectPhase.planning,
  );
}

WorkflowPath workflowPathFromName(String? value) {
  return WorkflowPath.values.firstWhere(
    (path) => path.name == value,
    orElse: () => WorkflowPath.planFirst,
  );
}

@immutable
class ProjectSessionRef {
  const ProjectSessionRef({
    required this.projectId,
    required this.workspacePath,
    required this.sessionId,
    required this.phase,
    this.workflowPath = WorkflowPath.planFirst,
    this.currentAgent = 'plan',
    this.selectedPlanPath,
    this.approvalReady = false,
    this.lastKnownStatus,
    this.title,
    this.titleUpdatedFromGoal = false,
    this.pendingPermissionIds = const <String>[],
    this.pendingQuestionIds = const <String>[],
  });

  final String projectId;
  final String workspacePath;
  final String sessionId;
  final ProjectPhase phase;
  final WorkflowPath workflowPath;
  final String currentAgent;
  final String? selectedPlanPath;
  final bool approvalReady;
  final String? lastKnownStatus;
  final String? title;
  final bool titleUpdatedFromGoal;
  final List<String> pendingPermissionIds;
  final List<String> pendingQuestionIds;

  ProjectSessionRef copyWith({
    String? projectId,
    String? workspacePath,
    String? sessionId,
    ProjectPhase? phase,
    WorkflowPath? workflowPath,
    String? currentAgent,
    String? selectedPlanPath,
    bool? approvalReady,
    String? lastKnownStatus,
    String? title,
    bool? titleUpdatedFromGoal,
    List<String>? pendingPermissionIds,
    List<String>? pendingQuestionIds,
  }) {
    return ProjectSessionRef(
      projectId: projectId ?? this.projectId,
      workspacePath: workspacePath ?? this.workspacePath,
      sessionId: sessionId ?? this.sessionId,
      phase: phase ?? this.phase,
      workflowPath: workflowPath ?? this.workflowPath,
      currentAgent: currentAgent ?? this.currentAgent,
      selectedPlanPath: selectedPlanPath ?? this.selectedPlanPath,
      approvalReady: approvalReady ?? this.approvalReady,
      lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
      title: title ?? this.title,
      titleUpdatedFromGoal: titleUpdatedFromGoal ?? this.titleUpdatedFromGoal,
      pendingPermissionIds: pendingPermissionIds ?? this.pendingPermissionIds,
      pendingQuestionIds: pendingQuestionIds ?? this.pendingQuestionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'projectId': projectId,
      'workspacePath': workspacePath,
      'sessionId': sessionId,
      'phase': phase.name,
      'workflowPath': workflowPath.name,
      'currentAgent': currentAgent,
      'selectedPlanPath': selectedPlanPath,
      'approvalReady': approvalReady,
      'lastKnownStatus': lastKnownStatus,
      'title': title,
      'titleUpdatedFromGoal': titleUpdatedFromGoal,
      'pendingPermissionIds': pendingPermissionIds,
      'pendingQuestionIds': pendingQuestionIds,
    };
  }

  factory ProjectSessionRef.fromJson(Map<String, dynamic> json) {
    return ProjectSessionRef(
      projectId: json['projectId'] as String? ?? '',
      workspacePath: json['workspacePath'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      phase: projectPhaseFromName(json['phase'] as String?),
      workflowPath: workflowPathFromName(json['workflowPath'] as String?),
      currentAgent: json['currentAgent'] as String? ?? 'plan',
      selectedPlanPath: json['selectedPlanPath'] as String?,
      approvalReady: json['approvalReady'] as bool? ?? false,
      lastKnownStatus: json['lastKnownStatus'] as String?,
      title: json['title'] as String?,
      titleUpdatedFromGoal: json['titleUpdatedFromGoal'] as bool? ?? false,
      pendingPermissionIds:
          (json['pendingPermissionIds'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      pendingQuestionIds:
          (json['pendingQuestionIds'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
    );
  }
}
