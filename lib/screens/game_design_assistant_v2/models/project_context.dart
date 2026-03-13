/// Data models for Project Context / Pending Knowledge feature.

class PendingKnowledgeItem {
  final String id;
  final int projectId;
  final String sessionId;
  final int turnNumber;
  final String type;
  final String content;
  final String? originalText;
  final String? mergeAction;
  final String? targetEntryId;
  final Map<String, dynamic>? conflictMeta;
  final String status;
  final bool isUserEdited;
  final String source;
  final String createdAt;
  final String updatedAt;

  PendingKnowledgeItem({
    required this.id,
    required this.projectId,
    required this.sessionId,
    required this.turnNumber,
    required this.type,
    required this.content,
    this.originalText,
    this.mergeAction,
    this.targetEntryId,
    this.conflictMeta,
    required this.status,
    required this.isUserEdited,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PendingKnowledgeItem.fromJson(Map<String, dynamic> json) {
    return PendingKnowledgeItem(
      id: json['id'] as String,
      projectId: json['project_id'] as int,
      sessionId: json['session_id'] as String,
      turnNumber: json['turn_number'] as int? ?? 0,
      type: json['type'] as String,
      content: json['content'] as String,
      originalText: json['original_text'] as String?,
      mergeAction: json['merge_action'] as String?,
      targetEntryId: json['target_entry_id'] as String?,
      conflictMeta: json['conflict_meta'] as Map<String, dynamic>?,
      status: json['status'] as String,
      isUserEdited: json['is_user_edited'] as bool? ?? false,
      source: json['source'] as String? ?? 'hook',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  PendingKnowledgeItem copyWith({String? content, String? type}) {
    return PendingKnowledgeItem(
      id: id,
      projectId: projectId,
      sessionId: sessionId,
      turnNumber: turnNumber,
      type: type ?? this.type,
      content: content ?? this.content,
      originalText: originalText,
      mergeAction: mergeAction,
      targetEntryId: targetEntryId,
      conflictMeta: conflictMeta,
      status: status,
      isUserEdited: true,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'preference':
        return 'Preference';
      case 'decision':
        return 'Decision';
      case 'rejection':
        return 'Rejection';
      case 'domain_concept':
        return 'Domain Concept';
      default:
        return type;
    }
  }

  String get mergeActionLabel {
    switch (mergeAction) {
      case 'add':
        return 'Add';
      case 'conflict':
        return 'Conflict';
      case 'noop':
        return 'Duplicate';
      default:
        return mergeAction ?? 'Pending';
    }
  }
}

class ProjectContextEntry {
  final String id;
  final String type;
  final String content;
  final String status;
  final String sourceSessionId;
  final int sourceHistoryIndex;
  final String? originalText;
  final String createdAt;
  final String? supersededBy;

  ProjectContextEntry({
    required this.id,
    required this.type,
    required this.content,
    required this.status,
    required this.sourceSessionId,
    required this.sourceHistoryIndex,
    this.originalText,
    required this.createdAt,
    this.supersededBy,
  });

  factory ProjectContextEntry.fromJson(Map<String, dynamic> json) {
    return ProjectContextEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      sourceSessionId: json['source_session_id'] as String,
      sourceHistoryIndex: json['source_history_index'] as int? ?? 0,
      originalText: json['original_text'] as String?,
      createdAt: json['created_at'] as String,
      supersededBy: json['superseded_by'] as String?,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'preference':
        return 'Preference';
      case 'decision':
        return 'Decision';
      case 'rejection':
        return 'Rejection';
      case 'domain_concept':
        return 'Domain Concept';
      default:
        return type;
    }
  }
}

class ConfirmKnowledgeResult {
  final List<String> approved;
  final List<String> rejected;
  final List<Map<String, String>> errors;

  ConfirmKnowledgeResult({
    required this.approved,
    required this.rejected,
    required this.errors,
  });

  factory ConfirmKnowledgeResult.fromJson(Map<String, dynamic> json) {
    return ConfirmKnowledgeResult(
      approved: (json['approved'] as List?)?.cast<String>() ?? [],
      rejected: (json['rejected'] as List?)?.cast<String>() ?? [],
      errors: (json['errors'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
    );
  }

  int get totalProcessed => approved.length + rejected.length;
  bool get hasErrors => errors.isNotEmpty;
}
