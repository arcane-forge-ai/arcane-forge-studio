import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_context.dart';
import '../providers/v2_session_provider.dart';

/// Panel showing confirmed project context entries with CRUD operations.
class ProjectContextPanel extends StatefulWidget {
  const ProjectContextPanel({super.key});

  @override
  State<ProjectContextPanel> createState() => _ProjectContextPanelState();
}

class _ProjectContextPanelState extends State<ProjectContextPanel> {
  String? _filterType;
  String? _searchQuery;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<V2SessionProvider>().loadProjectContext();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    context.read<V2SessionProvider>().loadProjectContext(
          type: _filterType,
          query: _searchQuery,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final entries = provider.projectContextEntries;
    final isLoading = provider.isProjectContextLoading;
    final error = provider.projectContextError;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with search and filter
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('项目知识库', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: '添加知识',
                onPressed: () => _showAddDialog(context, provider),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: '刷新',
                onPressed: _refresh,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 4,
            children: [
              _FilterChip(
                label: '全部',
                selected: _filterType == null,
                onSelected: () {
                  setState(() => _filterType = null);
                  _refresh();
                },
              ),
              _FilterChip(
                label: '决策',
                selected: _filterType == 'decision',
                onSelected: () {
                  setState(() => _filterType = 'decision');
                  _refresh();
                },
              ),
              _FilterChip(
                label: '偏好',
                selected: _filterType == 'preference',
                onSelected: () {
                  setState(() => _filterType = 'preference');
                  _refresh();
                },
              ),
              _FilterChip(
                label: '概念',
                selected: _filterType == 'domain_concept',
                onSelected: () {
                  setState(() => _filterType = 'domain_concept');
                  _refresh();
                },
              ),
            ],
          ),
        ),

        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(error,
                style:
                    TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),

        const SizedBox(height: 4),

        // Content
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '暂无已确认的知识条目',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _ContextEntryTile(
                  entry: entry,
                  onEdit: (content) =>
                      provider.updateProjectContextEntry(
                          entry.id, content: content),
                  onDelete: () =>
                      provider.deleteProjectContextEntry(entry.id),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, V2SessionProvider provider) {
    final contentController = TextEditingController();
    String selectedType = 'decision';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加知识条目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'decision', child: Text('决策')),
                  DropdownMenuItem(value: 'preference', child: Text('偏好')),
                  DropdownMenuItem(value: 'rejection', child: Text('否定')),
                  DropdownMenuItem(
                      value: 'domain_concept', child: Text('领域概念')),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedType = v ?? 'decision'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                  hintText: '输入知识内容...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final text = contentController.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx);
                await provider.addProjectContextEntry(
                  type: selectedType,
                  content: text,
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onSelected(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _ContextEntryTile extends StatelessWidget {
  final ProjectContextEntry entry;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  const _ContextEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  Color _typeColor() {
    switch (entry.type) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _typeColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.typeLabel,
              style: TextStyle(
                fontSize: 11,
                color: _typeColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.content,
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: entry.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑知识条目'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '输入内容...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onEdit(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
