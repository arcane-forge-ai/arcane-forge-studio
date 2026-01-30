/// Models for Evaluate API responses and results
import 'dart:convert';

String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is List) return value.join('\n');
  return value.toString();
}

class EvaluateResponse {
  final int id;
  final int projectId;
  final String status;
  final EvaluateResult? result;
  final String? errorMessage;
  final String? promptVersion;
  final String? modelIdentifier;
  final DateTime createdAt;
  final DateTime? completedAt;

  EvaluateResponse({
    required this.id,
    required this.projectId,
    required this.status,
    this.result,
    this.errorMessage,
    this.promptVersion,
    this.modelIdentifier,
    required this.createdAt,
    this.completedAt,
  });

  factory EvaluateResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Parse result - it could be a JSON string or already parsed object
      EvaluateResult? parsedResult;
      if (json['result'] != null) {
        if (json['result'] is String) {
          // Parse JSON string
          final resultString = json['result'] as String;
          final resultJson = jsonDecode(resultString) as Map<String, dynamic>;
          parsedResult = EvaluateResult.fromJson(resultJson);
        } else if (json['result'] is Map) {
          parsedResult = EvaluateResult.fromJson(json['result'] as Map<String, dynamic>);
        }
      }

      return EvaluateResponse(
        id: json['id'] as int,
        projectId: json['project_id'] as int,
        status: _parseString(json['status']) ?? 'pending',
        result: parsedResult,
        errorMessage: _parseString(json['error_message']),
        promptVersion: _parseString(json['prompt_version']),
        modelIdentifier: _parseString(json['model_identifier']),
        createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'].toString())
            : null,
      );
    } catch (e) {
      print('Error parsing EvaluateResponse: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'status': status,
      'result': result?.toJson(),
      'error_message': errorMessage,
      'prompt_version': promptVersion,
      'model_identifier': modelIdentifier,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class EvaluateResult {
  final List<KnowledgeGap> gaps;
  final List<RiskAssessment> risks;
  final MarketAnalysis marketAnalysis;
  final GreenlightDecision greenlight;

  EvaluateResult({
    required this.gaps,
    required this.risks,
    required this.marketAnalysis,
    required this.greenlight,
  });

  factory EvaluateResult.fromJson(Map<String, dynamic> json) {
    try {
      return EvaluateResult(
        gaps: (json['gaps'] as List? ?? [])
            .map((gap) => KnowledgeGap.fromJson(gap as Map<String, dynamic>))
            .toList(),
        risks: (json['risks'] as List? ?? [])
            .map((risk) => RiskAssessment.fromJson(risk as Map<String, dynamic>))
            .toList(),
        // Try both 'market_snapshot' and 'market_analysis' for backwards compatibility
        marketAnalysis: (json['market_snapshot'] ?? json['market_analysis']) != null
            ? MarketAnalysis.fromJson((json['market_snapshot'] ?? json['market_analysis']) as Map<String, dynamic>)
            : MarketAnalysis(differentiation: MarketDifferentiation(unique: [], genericOrExpected: [], unclearOrUnproven: []), comparableGames: []),
        greenlight: json['greenlight'] != null
            ? GreenlightDecision.fromJson(json['greenlight'] as Map<String, dynamic>)
            : GreenlightDecision(status: 'yellow', blockers: [], reasoningList: [], toReachNextStatus: []),
      );
    } catch (e) {
      print('Error parsing EvaluateResult: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'gaps': gaps.map((gap) => gap.toJson()).toList(),
      'risks': risks.map((risk) => risk.toJson()).toList(),
      'market_snapshot': marketAnalysis.toJson(),
      'greenlight': greenlight.toJson(),
    };
  }
}

class KnowledgeGap {
  final String id;
  final String title;
  final String severity; // e.g., low, medium, high, critical
  final List<String> kbEvidence;
  final String currentState;
  final String whatToDecide;
  final String whyItMatters;

  KnowledgeGap({
    required this.id,
    required this.title,
    required this.severity,
    required this.kbEvidence,
    required this.currentState,
    required this.whatToDecide,
    required this.whyItMatters,
  });

  // Helper getters for UI compatibility
  String get description => whatToDecide;
  String get recommendation => whyItMatters;

  factory KnowledgeGap.fromJson(Map<String, dynamic> json) {
    return KnowledgeGap(
      id: _parseString(json['id']) ?? '',
      title: _parseString(json['title']) ?? '',
      severity: _parseString(json['severity']) ?? 'medium',
      kbEvidence: List<String>.from(
          (json['kb_evidence'] as List?)?.map((e) => e.toString()) ?? []),
      currentState: _parseString(json['current_state']) ?? '',
      whatToDecide: _parseString(json['what_to_decide']) ?? '',
      whyItMatters: _parseString(json['why_it_matters']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'severity': severity,
      'kb_evidence': kbEvidence,
      'current_state': currentState,
      'what_to_decide': whatToDecide,
      'why_it_matters': whyItMatters,
    };
  }
}

class RiskAssessment {
  final String category;
  final String risk;
  final String severity; // e.g., low, medium, high
  final String mitigation;

  RiskAssessment({
    required this.category,
    required this.risk,
    required this.severity,
    required this.mitigation,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      category: _parseString(json['category']) ?? '',
      risk: _parseString(json['risk']) ?? '',
      severity: _parseString(json['severity']) ?? 'medium',
      mitigation: _parseString(json['mitigation']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'risk': risk,
      'severity': severity,
      'mitigation': mitigation,
    };
  }
}

class ComparableGame {
  final String title;
  final String confidence;
  final String similarityReason;

  ComparableGame({
    required this.title,
    required this.confidence,
    required this.similarityReason,
  });

  factory ComparableGame.fromJson(Map<String, dynamic> json) {
    return ComparableGame(
      title: _parseString(json['title']) ?? '',
      confidence: _parseString(json['confidence']) ?? '',
      similarityReason: _parseString(json['similarity_reason']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'confidence': confidence,
      'similarity_reason': similarityReason,
    };
  }
}

class MarketDifferentiation {
  final List<String> unique;
  final List<String> genericOrExpected;
  final List<String> unclearOrUnproven;

  MarketDifferentiation({
    required this.unique,
    required this.genericOrExpected,
    required this.unclearOrUnproven,
  });

  factory MarketDifferentiation.fromJson(Map<String, dynamic> json) {
    return MarketDifferentiation(
      unique: List<String>.from(
          (json['unique'] as List?)?.map((e) => e.toString()) ?? []),
      genericOrExpected: List<String>.from(
          (json['generic_or_expected'] as List?)?.map((e) => e.toString()) ?? []),
      unclearOrUnproven: List<String>.from(
          (json['unclear_or_unproven'] as List?)?.map((e) => e.toString()) ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unique': unique,
      'generic_or_expected': genericOrExpected,
      'unclear_or_unproven': unclearOrUnproven,
    };
  }
}

class MarketAnalysis {
  final MarketDifferentiation differentiation;
  final List<ComparableGame> comparableGames;

  MarketAnalysis({
    required this.differentiation,
    required this.comparableGames,
  });

  // Helper getters for UI compatibility
  String get targetAudience => 'See comparable games and differentiation';
  List<String> get competitors => comparableGames.map((g) => g.title).toList();
  String get marketOpportunity => differentiation.unique.join(', ');
  String get overallMarketSentiment => '${comparableGames.length} comparable games identified';

  factory MarketAnalysis.fromJson(Map<String, dynamic> json) {
    return MarketAnalysis(
      differentiation: json['differentiation'] != null
          ? MarketDifferentiation.fromJson(json['differentiation'] as Map<String, dynamic>)
          : MarketDifferentiation(unique: [], genericOrExpected: [], unclearOrUnproven: []),
      comparableGames: (json['comparable_games'] as List? ?? [])
          .map((game) => ComparableGame.fromJson(game as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'differentiation': differentiation.toJson(),
      'comparable_games': comparableGames.map((g) => g.toJson()).toList(),
    };
  }
}

class GreenlightDecision {
  final String status; // green, yellow, red, "Not Yet"
  final List<String> blockers;
  final List<String> reasoningList;
  final List<String> toReachNextStatus;

  GreenlightDecision({
    required this.status,
    required this.blockers,
    required this.reasoningList,
    required this.toReachNextStatus,
  });

  // Helper getters for UI compatibility
  String get reasoning => reasoningList.join('\n');
  List<String> get nextSteps => toReachNextStatus;

  factory GreenlightDecision.fromJson(Map<String, dynamic> json) {
    return GreenlightDecision(
      status: _parseString(json['status']) ?? 'yellow',
      blockers: List<String>.from(
          (json['blockers'] as List?)?.map((e) => e.toString()) ?? []),
      reasoningList: List<String>.from(
          (json['reasoning'] as List?)?.map((e) => e.toString()) ?? []),
      toReachNextStatus: List<String>.from(
          (json['to_reach_next_status'] as List?)?.map((e) => e.toString()) ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'blockers': blockers,
      'reasoning': reasoningList,
      'to_reach_next_status': toReachNextStatus,
    };
  }
}

class EvaluateHistoryResponse {
  final int projectId;
  final List<EvaluateResponse> evaluations;

  EvaluateHistoryResponse({
    required this.projectId,
    required this.evaluations,
  });

  factory EvaluateHistoryResponse.fromJson(Map<String, dynamic> json) {
    try {
      return EvaluateHistoryResponse(
        projectId: json['project_id'] as int,
        evaluations: (json['evaluations'] as List? ?? [])
            .map((e) => EvaluateResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      print('Error parsing EvaluateHistoryResponse: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'evaluations': evaluations.map((e) => e.toJson()).toList(),
    };
  }
}

