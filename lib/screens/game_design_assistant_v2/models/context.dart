class GetContextResponse {
  final List<Map<String, dynamic>> establishedFacts;
  final List<Map<String, dynamic>> openQuestions;
  final List<Map<String, dynamic>> designDecisions;
  final List<String> userPreferences;
  final Map<String, dynamic> stages;
  final Map<String, dynamic>? currentFocus;

  GetContextResponse({
    this.establishedFacts = const [],
    this.openQuestions = const [],
    this.designDecisions = const [],
    this.userPreferences = const [],
    this.stages = const {},
    this.currentFocus,
  });

  factory GetContextResponse.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(dynamic raw) {
      final list = raw as List? ?? const [];
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }

    return GetContextResponse(
      establishedFacts: mapList(json['established_facts']),
      openQuestions: mapList(json['open_questions']),
      designDecisions: mapList(json['design_decisions']),
      userPreferences: (json['user_preferences'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      stages: Map<String, dynamic>.from(json['stages'] as Map? ?? const {}),
      currentFocus: json['current_focus'] == null
          ? null
          : Map<String, dynamic>.from(json['current_focus'] as Map),
    );
  }

  GetContextResponse copyWith({
    List<Map<String, dynamic>>? establishedFacts,
    List<Map<String, dynamic>>? openQuestions,
    List<Map<String, dynamic>>? designDecisions,
    List<String>? userPreferences,
    Map<String, dynamic>? stages,
    Map<String, dynamic>? currentFocus,
    bool clearCurrentFocus = false,
  }) {
    return GetContextResponse(
      establishedFacts: establishedFacts ?? this.establishedFacts,
      openQuestions: openQuestions ?? this.openQuestions,
      designDecisions: designDecisions ?? this.designDecisions,
      userPreferences: userPreferences ?? this.userPreferences,
      stages: stages ?? this.stages,
      currentFocus:
          clearCurrentFocus ? null : (currentFocus ?? this.currentFocus),
    );
  }
}
