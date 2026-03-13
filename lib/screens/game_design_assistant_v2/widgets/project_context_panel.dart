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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<V2SessionProvider>().loadProjectContext();
    });
  }

  void _refresh() {
    context.read<V2SessionProvider>().loadProjectContext();
  }

  Future<void> _extractToProjectContext(V2SessionProvider provider) async {
    final result = await provider.extractSessionKnowledge();
    if (!mounted) return;

    final error = provider.pendingKnowledgeError;
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Extraction failed: $error')),
      );
      return;
    }

    final pendingCount = (result?['pending_count'] as num?)?.toInt() ?? 0;
    final message = pendingCount > 0
        ? 'Extracted $pendingCount context item(s) to Pending Context Items.'
        : 'No new context found to extract.';
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Project Context', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Add entry',
                onPressed: () => _showAddDialog(context, provider),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                tooltip: 'Extract to Project Context',
                onPressed: provider.currentSession == null ||
                        provider.isPendingKnowledgeLoading
                    ? null
                    : () => _extractToProjectContext(provider),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _refresh,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(error,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No confirmed context entries yet.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  if (provider.currentSession != null)
                    OutlinedButton.icon(
                      onPressed: provider.isPendingKnowledgeLoading
                          ? null
                          : () => _extractToProjectContext(provider),
                      icon: provider.isPendingKnowledgeLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: const Text('Extract to Project Context'),
                    ),
                ],
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
                  onEdit: (content) => provider
                      .updateProjectContextEntry(entry.id, content: content),
                  onDelete: () => provider.deleteProjectContextEntry(entry.id),
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
          title: const Text('Add Context Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'decision', child: Text('Decision')),
                  DropdownMenuItem(
                      value: 'preference', child: Text('Preference')),
                  DropdownMenuItem(
                      value: 'rejection', child: Text('Rejection')),
                  DropdownMenuItem(
                      value: 'domain_concept', child: Text('Domain Concept')),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedType = v ?? 'decision'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  hintText: 'Enter context content...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
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
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
        title: const Text('Edit Knowledge Entry'),
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
