import '../models/project_overview_models.dart';

enum NodeStatus {
  completed,
  inProgress,
  notStarted,
}

class ProjectFlowHelper {
  /// Determine Game Design status
  /// Green: conversation_count > 0 AND file_count > 0
  /// Orange: either conversation_count > 0 OR file_count > 0
  /// Gray: both are 0
  static NodeStatus getGameDesignStatus(
    GameDesignOverview gameDesign,
    KnowledgeBaseOverview knowledgeBase,
  ) {
    final hasConversations = gameDesign.conversationCount > 0;
    final hasFiles = knowledgeBase.fileCount > 0;

    if (hasConversations && hasFiles) {
      return NodeStatus.completed;
    } else if (hasConversations || hasFiles) {
      return NodeStatus.inProgress;
    } else {
      return NodeStatus.notStarted;
    }
  }

  /// Determine asset category status
  /// Green: all assets have favorites AND total_assets > 0
  /// Orange: has some assets with generations
  /// Gray: no generations
  static NodeStatus getAssetStatus(AssetCategoryOverview assets) {
    if (assets.totalAssets > 0 &&
        assets.assetsWithFavorite == assets.totalAssets) {
      return NodeStatus.completed;
    } else if (assets.assetsWithGenerations > 0) {
      return NodeStatus.inProgress;
    } else {
      return NodeStatus.notStarted;
    }
  }

  /// Determine coding status
  /// Green: has code map
  /// Gray: no code map
  static NodeStatus getCodingStatus(CodeOverview code) {
    return code.hasCodeMap ? NodeStatus.completed : NodeStatus.notStarted;
  }

  /// Determine release status
  /// Green: has game link
  /// Gray: no game link
  static NodeStatus getReleaseStatus(ReleaseOverview release) {
    return release.hasGameLink ? NodeStatus.completed : NodeStatus.notStarted;
  }

  /// Determine analytics status
  /// Green: has analysis runs
  /// Gray: no analysis runs
  static NodeStatus getAnalyticsStatus(AnalyticsOverview analytics) {
    return analytics.analysisRunsCount > 0
        ? NodeStatus.completed
        : NodeStatus.notStarted;
  }

  /// Get display text for a node count
  static String getNodeCountText(NodeStatus status, int count) {
    if (status == NodeStatus.notStarted) {
      return 'Not Started';
    }
    return count.toString();
  }

  /// Get display text for boolean status (code, release)
  static String getBooleanStatusText(NodeStatus status) {
    switch (status) {
      case NodeStatus.completed:
        return 'Done';
      case NodeStatus.notStarted:
        return 'Not Started';
      default:
        return 'In Progress';
    }
  }
}


