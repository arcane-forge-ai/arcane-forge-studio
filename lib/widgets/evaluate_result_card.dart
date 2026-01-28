import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/evaluate_models.dart';
import 'evaluate_greenlight_indicator.dart';
import 'evaluate_metric_item.dart';
import '../screens/evaluate/evaluate_detail_screen.dart';

/// A reusable widget for displaying an evaluation result card
/// Shows greenlight status, metrics, and reasoning summary
class EvaluateResultCard extends StatelessWidget {
  final EvaluateResponse evaluation;
  final String? title;
  final VoidCallback? onTap;

  const EvaluateResultCard({
    Key? key,
    required this.evaluation,
    this.title,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = evaluation.result;
    if (result == null) return const SizedBox.shrink();

    final defaultOnTap = onTap ??
        () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EvaluateDetailScreen(evaluation: evaluation),
              ),
            );

    return InkWell(
      onTap: defaultOnTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EvaluateGreenlightIndicator(status: result.greenlight.status),
                  Text(
                    'Completed: ${DateFormat('MMM dd, yyyy HH:mm').format(evaluation.completedAt ?? evaluation.createdAt)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  EvaluateMetricItem(
                    label: 'Knowledge Gaps',
                    value: result.gaps.length.toString(),
                    icon: Icons.error_outline,
                  ),
                  EvaluateMetricItem(
                    label: 'Risks',
                    value: result.risks.length.toString(),
                    icon: Icons.warning_amber,
                  ),
                  EvaluateMetricItem(
                    label: 'Next Steps',
                    value: result.greenlight.nextSteps.length.toString(),
                    icon: Icons.playlist_add_check,
                  ),
                ],
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Greenlight Decision',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.greenlight.reasoning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  TextButton.icon(
                    onPressed: defaultOnTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View Full Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

