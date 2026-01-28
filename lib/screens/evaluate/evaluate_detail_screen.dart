import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../models/evaluate_models.dart';
import '../../constants.dart';
import '../../controllers/menu_app_controller.dart';
import '../../services/design_assistant_data_service.dart';
import '../../utils/error_handler.dart';

class EvaluateDetailScreen extends StatefulWidget {
  final EvaluateResponse evaluation;

  const EvaluateDetailScreen({
    Key? key,
    required this.evaluation,
  }) : super(key: key);

  @override
  State<EvaluateDetailScreen> createState() => _EvaluateDetailScreenState();
}

class _EvaluateDetailScreenState extends State<EvaluateDetailScreen> {

  @override
  Widget build(BuildContext context) {
    final result = widget.evaluation.result;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: result == null
          ? _buildErrorState(context)
          : Column(
              children: [
                _buildMetadataHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryHeader(context, result),
                        const SizedBox(height: 32),
                        _buildSection(
                          context,
                          title: 'Knowledge Gaps',
                          icon: Icons.error_outline,
                          content: _buildGapsList(result.gaps),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          title: 'Risk Assessment',
                          icon: Icons.warning_amber,
                          content: _buildRisksList(result.risks),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          title: 'Market Differentiation',
                          icon: Icons.auto_awesome,
                          content: _buildMarketDifferentiation(result.marketAnalysis),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          title: 'Comparable Games',
                          icon: Icons.videogame_asset,
                          content: _buildComparableGames(result.marketAnalysis),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          title: 'Next Steps & Recommendations',
                          icon: Icons.playlist_add_check,
                          content: _buildNextSteps(result.greenlight),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          SelectableText(
            'Evaluation Data Missing',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(widget.evaluation.errorMessage ?? 'This evaluation failed or contains no results.'),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, EvaluateResult result) {
    final greenlight = result.greenlight;
    Color statusColor;
    IconData statusIcon;

    switch (greenlight.status.toLowerCase()) {
      case 'green':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'yellow':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'red':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'not yet':
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      color: statusColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: SelectableText(
                    _getStatusLabel(greenlight.status),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              greenlight.reasoning,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (greenlight.blockers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const SelectableText(
                'Blockers:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...greenlight.blockers.map((blocker) => Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.block, size: 16, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            blocker,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'green':
        return 'Ready for Production';
      case 'yellow':
        return 'Conditional (Needs Attention)';
      case 'red':
        return 'Critical (Not Ready)';
      case 'not yet':
        return 'Not Ready Yet (Blockers Present)';
      default:
        return 'Unknown Status';
    }
  }

  Widget _buildSection(BuildContext context,
      {required String title, required IconData icon, required Widget content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(width: 12),
            SelectableText(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildGapsList(List<KnowledgeGap> gaps) {
    if (gaps.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SelectableText('No significant knowledge gaps identified.'),
        ),
      );
    }

    return Column(
      children: gaps
          .map((gap) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: _buildSeverityBadge(gap.severity),
                  title: SelectableText(gap.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: SelectableText('ID: ${gap.id} • Current: ${gap.currentState}', style: const TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText('What to Decide:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(gap.whatToDecide),
                          ),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText('Why It Matters:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(gap.whyItMatters),
                          ),
                          if (gap.kbEvidence.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText('Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            ...gap.kbEvidence.map((evidence) => Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SelectableText('• '),
                                      Expanded(child: SelectableText(evidence)),
                                    ],
                                  ),
                                )),
                          ],
                          // Add "Improve with AI" button
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () => _improveGapWithAI(gap),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Improve with AI'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildRisksList(List<RiskAssessment> risks) {
    if (risks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SelectableText('No critical risks identified.'),
        ),
      );
    }

    return Column(
      children: risks
          .map((risk) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: _buildSeverityBadge(risk.severity),
                  title: SelectableText(risk.risk, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: SelectableText('Category: ${risk.category}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SelectableText('Mitigation Strategy:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          SelectableText(risk.mitigation),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMarketDifferentiation(MarketAnalysis market) {
    final diff = market.differentiation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diff.unique.isNotEmpty) ...[
              _buildDifferentiationSection(
                'Unique Features',
                diff.unique,
                Colors.green,
                Icons.star,
              ),
              const Divider(height: 32),
            ],
            if (diff.genericOrExpected.isNotEmpty) ...[
              _buildDifferentiationSection(
                'Standard Features',
                diff.genericOrExpected,
                Colors.orange,
                Icons.check_circle_outline,
              ),
              const Divider(height: 32),
            ],
            if (diff.unclearOrUnproven.isNotEmpty) ...[
              _buildDifferentiationSection(
                'Unclear/Unproven',
                diff.unclearOrUnproven,
                Colors.grey,
                Icons.help_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDifferentiationSection(
    String title,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            SelectableText(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('• ', style: TextStyle(color: color)),
                  Expanded(
                    child: SelectableText(
                      item,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildComparableGames(MarketAnalysis market) {
    if (market.comparableGames.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SelectableText('No comparable games identified.'),
        ),
      );
    }

    return Column(
      children: market.comparableGames
          .map((game) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              game.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildConfidenceBadge(game.confidence),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        game.similarityReason,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color color;
    switch (confidence.toLowerCase()) {
      case 'high':
        color = Colors.green;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        confidence.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildNextSteps(GreenlightDecision greenlight) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: greenlight.nextSteps
              .map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
                        const SizedBox(width: 12),
                        Expanded(child: SelectableText(step, style: const TextStyle(fontSize: 15))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.red.shade900;
        break;
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildMetadataHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evaluation Report #${widget.evaluation.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created ${DateFormat('MMM dd, yyyy HH:mm').format(widget.evaluation.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting report as PDF...')),
                  );
                },
                icon: const Icon(Icons.download, color: Colors.white54),
                tooltip: 'Export Report',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetadataStats(context),
        ],
      ),
    );
  }

  Widget _buildMetadataStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.info_outline,
              label: 'Evaluation ID',
              value: widget.evaluation.id.toString(),
              color: Colors.blue,
            ),
            const SizedBox(width: 24),
            _buildStatItem(
              icon: Icons.calendar_today,
              label: 'Created',
              value: DateFormat('MMM dd, yyyy').format(widget.evaluation.createdAt),
              color: Colors.white70,
            ),
            if (widget.evaluation.completedAt != null) ...[
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Completed',
                value: DateFormat('MMM dd, yyyy').format(widget.evaluation.completedAt!),
                color: Colors.green,
              ),
            ],
            const SizedBox(width: 24),
            _buildStatItem(
              icon: Icons.smart_toy,
              label: 'AI Model',
              value: widget.evaluation.modelIdentifier ?? 'Unknown',
              color: Colors.purple,
            ),
            const SizedBox(width: 24),
            _buildStatItem(
              icon: Icons.code,
              label: 'Prompt Version',
              value: widget.evaluation.promptVersion ?? 'v0.1',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _improveGapWithAI(KnowledgeGap gap) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF2A2A2A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4CAF50)),
              SizedBox(height: 16),
              Text('Preparing gap improvement analysis...', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      },
    );

    try {
      // 1. Load gap improvement prompt
      String gapPrompt = "Not Available at this moment";
      try {
        gapPrompt = await rootBundle.loadString('assets/requests/gap_improvement_prompt.md');
      } catch (e) {
        // Keep default
      }
      
      // 2. Compose gap content
      final gapContent = """
Title: ${gap.title}
Severity: ${gap.severity}
Current State: ${gap.currentState}

What to Decide:
${gap.whatToDecide}

Why It Matters:
${gap.whyItMatters}

Knowledge Base Evidence:
${gap.kbEvidence.isEmpty ? 'No evidence provided' : gap.kbEvidence.map((e) => '- $e').join('\n')}
""";
      
      // 3. Compose full message
      final String composedMessage = """
=====Knowledge Gap=====
$gapContent

$gapPrompt""";
      
      // 4. Create session title
      final String sessionTitle = "${gap.title} Gap Improvement";
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // 5. Navigate to Game Design Assistant
      if (mounted) {
        final menuController = Provider.of<MenuAppController>(context, listen: false);
        menuController.changeScreen(ScreenType.gameDesignAssistant);
        
        // Store composed message data for Game Design Assistant
        DesignAssistantDataService().setComposedMessageData(composedMessage, sessionTitle);
        
        // Navigate back so menu controller can switch screens
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing gap improvement: ${ErrorHandler.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

}
