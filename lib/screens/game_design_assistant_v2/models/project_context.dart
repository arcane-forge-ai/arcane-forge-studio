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
  final int version;
  final String etag;

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
    required this.version,
    required this.etag,
  });

  factory PendingKnowledgeItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['item_id']) as String;
    final projectIdRaw = json['project_id'];
    final sessionIdRaw = json['session_id'];
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];
    return PendingKnowledgeItem(
      id: id,
      projectId: projectIdRaw is int
          ? projectIdRaw
          : int.tryParse(projectIdRaw?.toString() ?? '') ?? 0,
      sessionId: (sessionIdRaw as String?) ?? '',
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
      createdAt: (createdAtRaw as String?) ?? '',
      updatedAt: (updatedAtRaw as String?) ?? '',
      version: json['version'] as int? ?? 1,
      etag: (json['item_etag'] ?? json['etag']) as String? ?? '',
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
      version: version,
      etag: etag,
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
  final List<String> skipped;
  final List<String> conflicts;
  final String? latestBatchEtag;
  final String? compactionStatus;
  final bool idempotentReplay;

  ConfirmKnowledgeResult({
    required this.approved,
    required this.rejected,
    required this.errors,
    this.skipped = const [],
    this.conflicts = const [],
    this.latestBatchEtag,
    this.compactionStatus,
    this.idempotentReplay = false,
  });

  factory ConfirmKnowledgeResult.fromJson(Map<String, dynamic> json) {
    final applied = (json['approved'] as List?)?.cast<String>() ??
        (json['applied_ids'] as List?)?.cast<String>() ??
        <String>[];
    final rejected = (json['rejected'] as List?)?.cast<String>() ?? <String>[];
    return ConfirmKnowledgeResult(
      approved: applied,
      rejected: rejected,
      errors: (json['errors'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      skipped: (json['skipped_ids'] as List?)?.cast<String>() ?? [],
      conflicts: (json['conflict_ids'] as List?)?.cast<String>() ?? [],
      latestBatchEtag: json['latest_batch_etag'] as String?,
      compactionStatus: json['compaction_status'] as String?,
      idempotentReplay: json['idempotent_replay'] as bool? ?? false,
    );
  }

  int get totalProcessed => approved.length + rejected.length;
  bool get hasErrors => errors.isNotEmpty;
}

class PendingKnowledgeListResponse {
  final List<PendingKnowledgeItem> items;
  final int batchVersion;
  final String batchEtag;
  final String readMode;
  final String migrationState;
  final Map<String, dynamic> migrationCoverage;
  final Map<String, dynamic> writeGate;

  PendingKnowledgeListResponse({
    required this.items,
    required this.batchVersion,
    required this.batchEtag,
    required this.readMode,
    required this.migrationState,
    required this.migrationCoverage,
    required this.writeGate,
  });

  factory PendingKnowledgeListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => PendingKnowledgeItem.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
    return PendingKnowledgeListResponse(
      items: items,
      batchVersion: json['batch_version'] as int? ?? 0,
      batchEtag: json['batch_etag'] as String? ?? '',
      readMode: json['read_mode'] as String? ?? 'dual',
      migrationState: json['migration_state'] as String? ?? 'started',
      migrationCoverage:
          Map<String, dynamic>.from(json['migration_coverage'] as Map? ?? {}),
      writeGate: Map<String, dynamic>.from(json['write_gate'] as Map? ?? {}),
    );
  }
}
