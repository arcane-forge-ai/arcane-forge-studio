import 'package:flutter/material.dart';
import '../utils/project_flow_helper.dart';

class ProjectFlowNode extends StatelessWidget {
  final String title;
  final String subtitle;
  final NodeStatus status;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const ProjectFlowNode({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
    this.width = 120,
    this.height = 80,
  }) : super(key: key);

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case NodeStatus.completed:
        return Colors.green;
      case NodeStatus.inProgress:
        return Colors.orange;
      case NodeStatus.notStarted:
        return Colors.grey;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case NodeStatus.completed:
        return isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50;
      case NodeStatus.inProgress:
        return isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50;
      case NodeStatus.notStarted:
        return isDark ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final backgroundColor = _getBackgroundColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


