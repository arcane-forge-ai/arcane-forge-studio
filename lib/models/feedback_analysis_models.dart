/// Models for feedback analysis API responses

class FeedbackAnalysisResult {
  final String runId;
  final String status;
  final List<FeedbackCluster> clusters;
  final List<FeedbackOpportunity> opportunities;
  final List<MutationBrief> mutationBriefs;

  FeedbackAnalysisResult({
    required this.runId,
    required this.status,
    required this.clusters,
    required this.opportunities,
    required this.mutationBriefs,
  });

  factory FeedbackAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FeedbackAnalysisResult(
      runId: json['run_id'] as String,
      status: json['status'] as String,
      clusters: (json['clusters'] as List)
          .map((cluster) => FeedbackCluster.fromJson(cluster))
          .toList(),
      opportunities: (json['opportunities'] as List)
          .map((opportunity) => FeedbackOpportunity.fromJson(opportunity))
          .toList(),
      mutationBriefs: (json['mutation_briefs'] as List)
          .map((brief) => MutationBrief.fromJson(brief))
          .toList(),
    );
  }
}

class FeedbackCluster {
  final int id;
  final int projectId;
  final String runId;
  final String name;
  final int count;
  final double? negPct;
  final String? example;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  FeedbackCluster({
    required this.id,
    required this.projectId,
    required this.runId,
    required this.name,
    required this.count,
    this.negPct,
    this.example,
    this.metadata = const {},
    required this.createdAt,
  });

  factory FeedbackCluster.fromJson(Map<String, dynamic> json) {
    return FeedbackCluster(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      runId: json['run_id'] as String,
      name: json['name'] as String,
      count: json['count'] as int,
      negPct: json['neg_pct']?.toDouble(),
      example: json['example'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'run_id': runId,
      'name': name,
      'count': count,
      'neg_pct': negPct,
      'example': example,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ClusterListResponse {
  final List<FeedbackCluster> clusters;
  final int total;
  final int limit;
  final int offset;

  ClusterListResponse({
    required this.clusters,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ClusterListResponse.fromJson(Map<String, dynamic> json) {
    return ClusterListResponse(
      clusters: (json['clusters'] as List)
          .map((cluster) => FeedbackCluster.fromJson(cluster))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}

class FeedbackOpportunity {
  final int id;
  final int projectId;
  final String runId;
  final String statement;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  FeedbackOpportunity({
    required this.id,
    required this.projectId,
    required this.runId,
    required this.statement,
    this.metadata = const {},
    required this.createdAt,
  });

  factory FeedbackOpportunity.fromJson(Map<String, dynamic> json) {
    return FeedbackOpportunity(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      runId: json['run_id'] as String,
      statement: json['statement'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'run_id': runId,
      'statement': statement,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OpportunityListResponse {
  final List<FeedbackOpportunity> opportunities;
  final int total;
  final int limit;
  final int offset;

  OpportunityListResponse({
    required this.opportunities,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory OpportunityListResponse.fromJson(Map<String, dynamic> json) {
    return OpportunityListResponse(
      opportunities: (json['opportunities'] as List)
          .map((opportunity) => FeedbackOpportunity.fromJson(opportunity))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}

class MutationBrief {
  final int id;
  final int projectId;
  final String runId;
  final String title;
  final String? rationale;
  final List<String>? changes;
  final int? impact;
  final int? effort;
  final String? novelty;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  MutationBrief({
    required this.id,
    required this.projectId,
    required this.runId,
    required this.title,
    this.rationale,
    this.changes,
    this.impact,
    this.effort,
    this.novelty,
    this.metadata = const {},
    required this.createdAt,
  });

  factory MutationBrief.fromJson(Map<String, dynamic> json) {
    return MutationBrief(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      runId: json['run_id'] as String,
      title: json['title'] as String,
      rationale: json['rationale'] as String?,
      changes:
          json['changes'] != null ? List<String>.from(json['changes']) : null,
      impact: json['impact'] as int?,
      effort: json['effort'] as int?,
      novelty: json['novelty'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'run_id': runId,
      'title': title,
      'rationale': rationale,
      'changes': changes,
      'impact': impact,
      'effort': effort,
      'novelty': novelty,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MutationBriefListResponse {
  final List<MutationBrief> mutationBriefs;
  final int total;
  final int limit;
  final int offset;

  MutationBriefListResponse({
    required this.mutationBriefs,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory MutationBriefListResponse.fromJson(Map<String, dynamic> json) {
    return MutationBriefListResponse(
      mutationBriefs: (json['mutation_briefs'] as List)
          .map((brief) => MutationBrief.fromJson(brief))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}

