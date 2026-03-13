import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_context.dart';
import '../providers/v2_session_provider.dart';

/// Inline panel showing pending knowledge items for review.
/// Displayed in the knowledge board when there are pending items.
class PendingKnowledgePanel extends StatefulWidget {
  const PendingKnowledgePanel({super.key});

  @override
  State<PendingKnowledgePanel> createState() => _PendingKnowledgePanelState();
}

class _PendingKnowledgePanelState extends State<PendingKnowledgePanel> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  void _toggleSelectAll(List<PendingKnowledgeItem> items) {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIds.addAll(items.map((i) => i.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _approveSelected(V2SessionProvider provider) async {
    if (_selectedIds.isEmpty) return;
    final decisions =
        _selectedIds.map((id) => {'id': id, 'action': 'approve'}).toList();
    await provider.confirmPendingKnowledge(decisions);
    setState(() {
      _selectedIds.clear();
      _selectAll = false;
    });
  }

  Future<void> _rejectSelected(V2SessionProvider provider) async {
    if (_selectedIds.isEmpty) return;
    final decisions =
        _selectedIds.map((id) => {'id': id, 'action': 'reject'}).toList();
    await provider.confirmPendingKnowledge(decisions);
    setState(() {
      _selectedIds.clear();
      _selectAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final items = provider.pendingKnowledgeItems;
    final isLoading = provider.isPendingKnowledgeLoading;
    final isSubmitting = provider.isPendingKnowledgeSubmitting;
    final error = provider.pendingKnowledgeError;
    final theme = Theme.of(context);

    if (items.isEmpty && !isLoading) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Pending Context Items (${items.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (items.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed:
                        isSubmitting ? null : () => _toggleSelectAll(items),
                    icon: Icon(
                      _selectAll ? Icons.deselect : Icons.select_all,
                      size: 16,
                    ),
                    label: Text(_selectAll ? 'Deselect all' : 'Select all',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),

          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(error,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            // Item list (bounded height + internal scroll to avoid overflow)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = _selectedIds.contains(item.id);
                  return _PendingItemTile(
                    item: item,
                    isSelected: isSelected,
                    onToggle: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(item.id);
                        } else {
                          _selectedIds.add(item.id);
                        }
                        _selectAll = _selectedIds.length == items.length;
                      });
                    },
                    onDelete: () => provider.deletePendingItem(item.id),
                    onEdit: (content) =>
                        provider.updatePendingItem(item.id, content: content),
                  );
                },
              ),
            ),

          // Action buttons
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        isSubmitting ? null : () => _rejectSelected(provider),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('Reject (${_selectedIds.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        isSubmitting ? null : () => _approveSelected(provider),
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: Text('Approve (${_selectedIds.length})'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingItemTile extends StatelessWidget {
  final PendingKnowledgeItem item;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const _PendingItemTile({
    required this.item,
    required this.isSelected,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  Color _typeColor(BuildContext context) {
    switch (item.type) {
      case 'decision':
        return Colors.blue;
      case 'preference':
        return Colors.green;
      case 'rejection':
        return Colors.orange;
      case 'domain_concept':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor(context).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: _typeColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.mergeAction != null &&
                          item.mergeAction != 'add') ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.mergeAction == 'conflict'
                                ? Colors.red.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.mergeActionLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: item.mergeAction == 'conflict'
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (action) {
                if (action == 'delete') {
                  onDelete();
                } else if (action == 'edit') {
                  _showEditDialog(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: item.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Context Item'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter content...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onEdit(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
