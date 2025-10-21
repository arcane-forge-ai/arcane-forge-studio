class ProjectOverviewResponse {
  final int projectId;
  final GameDesignOverview gameDesign;
  final AssetCategoryOverview imageAssets;
  final AssetCategoryOverview sfxAssets;
  final AssetCategoryOverview musicAssets;
  final CodeOverview code;
  final ReleaseOverview release;
  final AnalyticsOverview analytics;
  final KnowledgeBaseOverview knowledgeBase;

  ProjectOverviewResponse({
    required this.projectId,
    required this.gameDesign,
    required this.imageAssets,
    required this.sfxAssets,
    required this.musicAssets,
    required this.code,
    required this.release,
    required this.analytics,
    required this.knowledgeBase,
  });

  factory ProjectOverviewResponse.fromJson(Map<String, dynamic> json) {
    return ProjectOverviewResponse(
      projectId: json['project_id'] as int,
      gameDesign: GameDesignOverview.fromJson(json['game_design'] as Map<String, dynamic>),
      imageAssets: AssetCategoryOverview.fromJson(json['image_assets'] as Map<String, dynamic>),
      sfxAssets: AssetCategoryOverview.fromJson(json['sfx_assets'] as Map<String, dynamic>),
      musicAssets: AssetCategoryOverview.fromJson(json['music_assets'] as Map<String, dynamic>),
      code: CodeOverview.fromJson(json['code'] as Map<String, dynamic>),
      release: ReleaseOverview.fromJson(json['release'] as Map<String, dynamic>),
      analytics: AnalyticsOverview.fromJson(json['analytics'] as Map<String, dynamic>),
      knowledgeBase: KnowledgeBaseOverview.fromJson(json['knowledge_base'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'game_design': gameDesign.toJson(),
      'image_assets': imageAssets.toJson(),
      'sfx_assets': sfxAssets.toJson(),
      'music_assets': musicAssets.toJson(),
      'code': code.toJson(),
      'release': release.toJson(),
      'analytics': analytics.toJson(),
      'knowledge_base': knowledgeBase.toJson(),
    };
  }
}

class GameDesignOverview {
  final int conversationCount;

  GameDesignOverview({required this.conversationCount});

  factory GameDesignOverview.fromJson(Map<String, dynamic> json) {
    return GameDesignOverview(
      conversationCount: json['conversation_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_count': conversationCount,
    };
  }
}

class AssetCategoryOverview {
  final int totalAssets;
  final int assetsWithGenerations;
  final int assetsWithFavorite;

  AssetCategoryOverview({
    required this.totalAssets,
    required this.assetsWithGenerations,
    required this.assetsWithFavorite,
  });

  factory AssetCategoryOverview.fromJson(Map<String, dynamic> json) {
    return AssetCategoryOverview(
      totalAssets: json['total_assets'] as int,
      assetsWithGenerations: json['assets_with_generations'] as int,
      assetsWithFavorite: json['assets_with_favorite'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_assets': totalAssets,
      'assets_with_generations': assetsWithGenerations,
      'assets_with_favorite': assetsWithFavorite,
    };
  }
}

class CodeOverview {
  final bool hasCodeMap;

  CodeOverview({required this.hasCodeMap});

  factory CodeOverview.fromJson(Map<String, dynamic> json) {
    return CodeOverview(
      hasCodeMap: json['has_code_map'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_code_map': hasCodeMap,
    };
  }
}

class ReleaseOverview {
  final bool hasGameLink;

  ReleaseOverview({required this.hasGameLink});

  factory ReleaseOverview.fromJson(Map<String, dynamic> json) {
    return ReleaseOverview(
      hasGameLink: json['has_game_link'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_game_link': hasGameLink,
    };
  }
}

class AnalyticsOverview {
  final int analysisRunsCount;

  AnalyticsOverview({required this.analysisRunsCount});

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      analysisRunsCount: json['analysis_runs_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysis_runs_count': analysisRunsCount,
    };
  }
}

class KnowledgeBaseOverview {
  final int fileCount;

  KnowledgeBaseOverview({required this.fileCount});

  factory KnowledgeBaseOverview.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseOverview(
      fileCount: json['file_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_count': fileCount,
    };
  }
}


