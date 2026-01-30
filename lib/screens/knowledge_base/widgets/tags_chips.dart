import 'package:flutter/material.dart';

/// Widget to display tags as compact chips
class TagsChips extends StatelessWidget {
  final List<String> tags;
  final int maxVisible;
  final bool compact;

  const TagsChips({
    Key? key,
    required this.tags,
    this.maxVisible = 3,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleTags = tags.take(maxVisible).toList();
    final remainingCount = tags.length - visibleTags.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visibleTags.map((tag) => _buildChip(tag, context)),
        if (remainingCount > 0)
          _buildRemainingChip(remainingCount, context),
      ],
    );
  }

  Widget _buildChip(String tag, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.blue.withOpacity(0.2)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.blue[300]
              : Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildRemainingChip(int count, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
