class GetProgressResponse {
  final double overallProgress;
  final Map<String, dynamic> stages;
  final String? currentStage;

  GetProgressResponse({
    required this.overallProgress,
    this.stages = const {},
    this.currentStage,
  });

  factory GetProgressResponse.fromJson(Map<String, dynamic> json) {
    return GetProgressResponse(
      overallProgress: (json['overall_progress'] as num?)?.toDouble() ?? 0,
      stages: Map<String, dynamic>.from(json['stages'] as Map? ?? const {}),
      currentStage: json['current_stage']?.toString(),
    );
  }
}
