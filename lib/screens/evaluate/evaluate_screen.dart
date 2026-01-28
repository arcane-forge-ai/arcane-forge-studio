import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/evaluate_provider.dart';
import '../../models/evaluate_models.dart';
import '../../constants.dart';
import '../../widgets/evaluate_result_card.dart';
import 'evaluate_detail_screen.dart';

class EvaluateScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const EvaluateScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<EvaluateScreen> createState() => _EvaluateScreenState();
}

class _EvaluateScreenState extends State<EvaluateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EvaluateProvider>().loadProjectEvaluations(int.parse(widget.projectId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<EvaluateProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadProjectEvaluations(int.parse(widget.projectId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadProjectEvaluations(int.parse(widget.projectId)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: defaultPadding),
                  if (provider.isEvaluating) _buildInProgressCard(provider.activeEvaluation!),
                  if (provider.latestEvaluation != null) ...[
                    _buildLatestResultCard(context, provider.latestEvaluation!),
                    const SizedBox(height: 32),
                  ],
                  if (!provider.isEvaluating && provider.latestEvaluation == null && provider.history.isEmpty)
                    _buildEmptyState(context, provider),
                  _buildHistorySection(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EvaluateProvider provider) {
    return Row(
      children: [
        Text(
          'Game Design Evaluation',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: provider.isEvaluating
              ? null
              : () => provider.startNewEvaluation(int.parse(widget.projectId)),
          icon: const Icon(Icons.analytics),
          label: const Text('Run New Evaluation'),
        ),
      ],
    );
  }

  Widget _buildInProgressCard(EvaluateResponse active) {
    return Card(
      margin: const EdgeInsets.only(bottom: 32),
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluation in Progress...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${active.status.toUpperCase()}',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take several minutes. Feel free to navigate away and check back later.',
                    style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestResultCard(BuildContext context, EvaluateResponse latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Result',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        EvaluateResultCard(evaluation: latest),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, EvaluateProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]
                  : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Evaluations Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Run your first evaluation to analyze your knowledge base for gaps, risks, and market fit.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => provider.startNewEvaluation(int.parse(widget.projectId)),
              icon: const Icon(Icons.analytics),
              label: const Text('Run First Evaluation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, EvaluateProvider provider) {
    if (provider.history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.history.length,
          itemBuilder: (context, index) {
            final item = provider.history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EvaluateDetailScreen(evaluation: item),
                  ),
                ),
                leading: _buildMiniStatusIcon(item.status, item.result?.greenlight.status),
                title: Text('Evaluation #${item.id}'),
                subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(item.createdAt)),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniStatusIcon(String status, String? greenlightStatus) {
    if (status != 'completed') {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Colors.grey,
        child: Icon(Icons.sync, color: Colors.white, size: 14),
      );
    }

    Color color;
    IconData icon;
    switch (greenlightStatus?.toLowerCase()) {
      case 'green':
        color = Colors.green;
        icon = Icons.check;
        break;
      case 'yellow':
        color = Colors.orange;
        icon = Icons.priority_high;
        break;
      case 'red':
        color = Colors.red;
        icon = Icons.close;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}
