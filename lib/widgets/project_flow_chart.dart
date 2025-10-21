import 'package:flutter/material.dart';
import '../models/project_overview_models.dart';
import '../utils/project_flow_helper.dart';
import '../controllers/menu_app_controller.dart';
import 'project_flow_node.dart';

class ProjectFlowChart extends StatefulWidget {
  final ProjectOverviewResponse overview;
  final Function(ScreenType) onNodeTap;

  const ProjectFlowChart({
    Key? key,
    required this.overview,
    required this.onNodeTap,
  }) : super(key: key);

  @override
  State<ProjectFlowChart> createState() => _ProjectFlowChartState();
}

class _ProjectFlowChartState extends State<ProjectFlowChart> {
  bool _showDevelopmentStages = true;

  @override
  Widget build(BuildContext context) {
    // Calculate statuses
    final gameDesignStatus = ProjectFlowHelper.getGameDesignStatus(
      widget.overview.gameDesign,
      widget.overview.knowledgeBase,
    );
    final codingStatus = ProjectFlowHelper.getCodingStatus(widget.overview.code);
    final imageStatus = ProjectFlowHelper.getAssetStatus(widget.overview.imageAssets);
    final sfxStatus = ProjectFlowHelper.getAssetStatus(widget.overview.sfxAssets);
    final musicStatus = ProjectFlowHelper.getAssetStatus(widget.overview.musicAssets);
    final releaseStatus = ProjectFlowHelper.getReleaseStatus(widget.overview.release);
    final analyticsStatus =
        ProjectFlowHelper.getAnalyticsStatus(widget.overview.analytics);

    // Determine overall development status - in progress if ANY child is in progress or completed
    final developmentStatus = _getDevelopmentStatus([
      codingStatus,
      imageStatus,
      sfxStatus,
      musicStatus,
    ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                
                if (isNarrow) {
                  return _buildNarrowLayout(
                    context,
                    gameDesignStatus,
                    developmentStatus,
                    releaseStatus,
                    analyticsStatus,
                    codingStatus,
                    imageStatus,
                    sfxStatus,
                    musicStatus,
                  );
                } else {
                  return _buildWideLayout(
                    context,
                    gameDesignStatus,
                    developmentStatus,
                    releaseStatus,
                    analyticsStatus,
                    codingStatus,
                    imageStatus,
                    sfxStatus,
                    musicStatus,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    NodeStatus gameDesignStatus,
    NodeStatus developmentStatus,
    NodeStatus releaseStatus,
    NodeStatus analyticsStatus,
    NodeStatus codingStatus,
    NodeStatus imageStatus,
    NodeStatus sfxStatus,
    NodeStatus musicStatus,
  ) {
    return Column(
      children: [
        // Main flow row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Design
            ProjectFlowNode(
              title: 'Game Design',
              subtitle: '${widget.overview.gameDesign.conversationCount} chats',
              status: gameDesignStatus,
              onTap: () => widget.onNodeTap(ScreenType.gameDesignAssistant),
            ),
            _buildArrow(),
            // Development (parent node) - clickable to toggle substages
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ProjectFlowNode(
                  title: 'Development',
                  subtitle: _getDevelopmentSubtitle(),
                  status: developmentStatus,
                  onTap: () {
                    setState(() {
                      _showDevelopmentStages = !_showDevelopmentStages;
                    });
                  },
                ),
                if (_showDevelopmentStages) ...[
                  const SizedBox(height: 12),
                  Icon(Icons.arrow_downward, color: Colors.grey[600], size: 20),
                ],
              ],
            ),
            _buildArrow(),
            // Release
            ProjectFlowNode(
              title: 'Release',
              subtitle: ProjectFlowHelper.getBooleanStatusText(releaseStatus),
              status: releaseStatus,
              onTap: () => widget.onNodeTap(ScreenType.versions),
            ),
            _buildArrow(),
            // Analytics
            ProjectFlowNode(
              title: 'Analytics',
              subtitle: '${widget.overview.analytics.analysisRunsCount} runs',
              status: analyticsStatus,
              onTap: () => widget.onNodeTap(ScreenType.feedbacks),
            ),
          ],
        ),
        // Development substages
        if (_showDevelopmentStages) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Development Stages',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      // Coding
                      ProjectFlowNode(
                        title: 'Coding',
                        subtitle: ProjectFlowHelper.getBooleanStatusText(
                            codingStatus),
                        status: codingStatus,
                        onTap: () => widget.onNodeTap(ScreenType.codeEditor),
                        width: 110,
                        height: 70,
                      ),
                      // Image
                      ProjectFlowNode(
                        title: 'Image',
                        subtitle: '(${widget.overview.imageAssets.assetsWithFavorite}/${widget.overview.imageAssets.totalAssets})',
                        status: imageStatus,
                        onTap: () => widget.onNodeTap(ScreenType.imageGenerationOverview),
                        width: 110,
                        height: 70,
                      ),
                      // Sound
                      ProjectFlowNode(
                        title: 'Sound',
                        subtitle: '(${widget.overview.sfxAssets.assetsWithFavorite}/${widget.overview.sfxAssets.totalAssets})',
                        status: sfxStatus,
                        onTap: () => widget.onNodeTap(ScreenType.sfxGenerationOverview),
                        width: 110,
                        height: 70,
                      ),
                      // Music
                      ProjectFlowNode(
                        title: 'Music',
                        subtitle: '(${widget.overview.musicAssets.assetsWithFavorite}/${widget.overview.musicAssets.totalAssets})',
                        status: musicStatus,
                        onTap: () => widget.onNodeTap(ScreenType.musicGenerationOverview),
                        width: 110,
                        height: 70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    NodeStatus gameDesignStatus,
    NodeStatus developmentStatus,
    NodeStatus releaseStatus,
    NodeStatus analyticsStatus,
    NodeStatus codingStatus,
    NodeStatus imageStatus,
    NodeStatus sfxStatus,
    NodeStatus musicStatus,
  ) {
    return Column(
      children: [
            // Game Design
            ProjectFlowNode(
              title: 'Game Design',
              subtitle: '${widget.overview.gameDesign.conversationCount} chats',
              status: gameDesignStatus,
              onTap: () => widget.onNodeTap(ScreenType.gameDesignAssistant),
              width: double.infinity,
            ),
        _buildVerticalArrow(),
        // Development label
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Development',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
          // Development substages
          if (_showDevelopmentStages)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ProjectFlowNode(
                  title: 'Coding',
                  subtitle: ProjectFlowHelper.getBooleanStatusText(codingStatus),
                  status: codingStatus,
                  onTap: () => widget.onNodeTap(ScreenType.codeEditor),
                  width: 150,
                ),
                ProjectFlowNode(
                  title: 'Image',
                  subtitle: '(${widget.overview.imageAssets.assetsWithFavorite}/${widget.overview.imageAssets.totalAssets})',
                  status: imageStatus,
                  onTap: () => widget.onNodeTap(ScreenType.imageGenerationOverview),
                  width: 150,
                ),
                ProjectFlowNode(
                  title: 'Sound',
                  subtitle: '(${widget.overview.sfxAssets.assetsWithFavorite}/${widget.overview.sfxAssets.totalAssets})',
                  status: sfxStatus,
                  onTap: () => widget.onNodeTap(ScreenType.sfxGenerationOverview),
                  width: 150,
                ),
                ProjectFlowNode(
                  title: 'Music',
                  subtitle: '(${widget.overview.musicAssets.assetsWithFavorite}/${widget.overview.musicAssets.totalAssets})',
                  status: musicStatus,
                  onTap: () => widget.onNodeTap(ScreenType.musicGenerationOverview),
                  width: 150,
                ),
              ],
            ),
        _buildVerticalArrow(),
          // Release
          if (_showDevelopmentStages) _buildVerticalArrow(),
          ProjectFlowNode(
            title: 'Release',
            subtitle: ProjectFlowHelper.getBooleanStatusText(releaseStatus),
            status: releaseStatus,
            onTap: () => widget.onNodeTap(ScreenType.versions),
            width: double.infinity,
          ),
          _buildVerticalArrow(),
          // Analytics
          ProjectFlowNode(
            title: 'Analytics',
            subtitle: '${widget.overview.analytics.analysisRunsCount} runs',
            status: analyticsStatus,
            onTap: () => widget.onNodeTap(ScreenType.feedbacks),
            width: double.infinity,
          ),
      ],
    );
  }

  Widget _buildArrow() {
    return SizedBox(
      height: 80,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          Icons.arrow_forward,
          color: Colors.grey[600],
          size: 24,
        ),
      ),
    );
  }

  Widget _buildVerticalArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Icon(
        Icons.arrow_downward,
        color: Colors.grey[600],
        size: 24,
      ),
    );
  }

  String _getDevelopmentSubtitle() {
    final totalFavorites = widget.overview.imageAssets.assetsWithFavorite +
        widget.overview.sfxAssets.assetsWithFavorite +
        widget.overview.musicAssets.assetsWithFavorite;
    final totalAssets = widget.overview.imageAssets.totalAssets +
        widget.overview.sfxAssets.totalAssets +
        widget.overview.musicAssets.totalAssets;
    return '($totalFavorites/$totalAssets)';
  }

  NodeStatus _getDevelopmentStatus(List<NodeStatus> statuses) {
    // Development is completed only if ALL children are completed
    if (statuses.every((s) => s == NodeStatus.completed)) {
      return NodeStatus.completed;
    }
    // Development is in progress if ANY child is in progress OR completed
    if (statuses.any((s) => s == NodeStatus.inProgress || s == NodeStatus.completed)) {
      return NodeStatus.inProgress;
    }
    // Development is not started only if ALL children are not started
    return NodeStatus.notStarted;
  }
}


