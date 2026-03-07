import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/v2_session_provider.dart';
import '../services/v2_api_service.dart';

class V2KnowledgeBoard extends StatefulWidget {
  const V2KnowledgeBoard({super.key});

  @override
  State<V2KnowledgeBoard> createState() => _V2KnowledgeBoardState();
}

class _V2KnowledgeBoardState extends State<V2KnowledgeBoard> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _saveError;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    if (provider.currentSession == null && !provider.hasDraftConversation) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a chat session to view context and design document.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.35),
            child: const TabBar(
              tabs: [
                Tab(text: 'Context'),
                Tab(text: 'Design Document'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildContextTab(context),
                _buildDocumentTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextTab(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final data = provider.contextData;

    if (provider.currentSession == null && provider.hasDraftConversation) {
      return const Center(
          child: Text(
              'Context will appear after the first message creates a session.'));
    }

    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.progress != null) ...[
          _sectionTitle(context, 'Progress'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: Text(
                  'Overall ${(provider.progress!.overallProgress * 100).toStringAsFixed(0)}%'),
              subtitle:
                  Text(provider.progress!.currentStage ?? 'No current stage'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (data.currentFocus != null) ...[
          _sectionTitle(context, 'Current Focus'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: Text(
                  data.currentFocus!['topic']?.toString() ?? 'Unknown topic'),
              subtitle: Text(data.currentFocus!['reason']?.toString() ?? ''),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _sectionList(
          context,
          title: 'Open Questions',
          icon: Icons.help_outline,
          color: Colors.orange,
          items: data.openQuestions,
          titleKey: 'question',
          subtitleBuilder: (m) =>
              m['priority'] == null ? null : 'Priority: ${m['priority']}',
        ),
        _sectionList(
          context,
          title: 'Established Facts',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          items: data.establishedFacts,
          titleKey: 'fact',
          subtitleBuilder: (m) => 'Category: ${m['category'] ?? 'General'}',
        ),
        _sectionList(
          context,
          title: 'Design Decisions',
          icon: Icons.gavel,
          color: Colors.blue,
          items: data.designDecisions,
          titleKey: 'decision',
          subtitleBuilder: (m) => m['rationale']?.toString(),
        ),
        if (data.openQuestions.isEmpty &&
            data.establishedFacts.isEmpty &&
            data.designDecisions.isEmpty &&
            data.currentFocus == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No context available yet for this session.'),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentTab(BuildContext context) {
    return Column(
      children: [
        _buildDocumentToolbar(context),
        Expanded(
          child: _isEditing ? _buildEditor(context) : _buildPreview(context),
        ),
      ],
    );
  }

  Widget _buildDocumentToolbar(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final canEdit = provider.currentSession != null;
    final hasDocuments = provider.documents.isNotEmpty && !provider.hasDraftConversation;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          if (hasDocuments) ...[
            DropdownButton<String?>(
              value: provider.selectedDocPath,
              hint: const Text('Select document'),
              items: provider.documents.map((doc) {
                final filePath = doc['file_path']?.toString() ?? '';
                final title = doc['title']?.toString() ?? filePath;
                return DropdownMenuItem(value: filePath, child: Text(title));
              }).toList(),
              onChanged: canEdit
                  ? (path) {
                      if (path != null) provider.selectDocument(path);
                    }
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'New document',
            onPressed: canEdit ? () => _showCreateDialog(context) : null,
          ),
          if (hasDocuments && provider.selectedDocPath != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (action) {
                if (action == 'rename') _showRenameDialog(context);
                if (action == 'delete') _confirmDelete(context);
              },
            ),
          const SizedBox(width: 8),
          ToggleButtons(
            isSelected: [!_isEditing, _isEditing],
            borderRadius: BorderRadius.circular(6),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 74),
            onPressed: canEdit && provider.selectedDocPath != null
                ? (index) {
                    setState(() {
                      if (index == 1 && !_isEditing) {
                        _editController.text = provider.selectedDocContent ?? '';
                        _saveError = null;
                      }
                      _isEditing = index == 1;
                    });
                  }
                : null,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Preview'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Edit'),
              ),
            ],
          ),
          const Spacer(),
          if (_isEditing) ...[
            if (_isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: canEdit && provider.selectedDocPath != null
                    ? () => _saveDoc(context)
                    : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      children: [
        if (_saveError != null)
          Container(
            width: double.infinity,
            color: Colors.red.withOpacity(0.1),
            padding: const EdgeInsets.all(8),
            child: Text(
              _saveError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _editController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, height: 1.45),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              hintText: 'Start writing your Game Design Document...',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final content = provider.selectedDocContent ?? '';

    if (provider.currentSession == null && provider.hasDraftConversation) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Document preview will load after the first message creates a session.'),
        ),
      );
    }

    if (provider.documents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No documents yet. Click the + button to create your first document.'),
        ),
      );
    }

    if (provider.selectedDocPath == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Please select a document from the dropdown above.'),
        ),
      );
    }

    if (content.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No content yet. Switch to Edit mode to start writing.'),
        ),
      );
    }

    return Markdown(
      data: content,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionList(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String titleKey,
    required String? Function(Map<String, dynamic>) subtitleBuilder,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title),
        ...items.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(icon, color: color),
              title: Text(item[titleKey]?.toString() ?? ''),
              subtitle: subtitleBuilder(item) == null
                  ? null
                  : Text(subtitleBuilder(item)!),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _saveDoc(BuildContext context) async {
    final sessionProvider = context.read<V2SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await sessionProvider.saveDocumentContent(_editController.text);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Document saved.')),
      );
    } on ConflictException catch (e) {
      setState(() {
        _saveError =
            'Conflict: $e The editor was reloaded with the latest version.';
        _editController.text = sessionProvider.selectedDocContent ?? '';
      });
    } catch (e) {
      setState(() {
        _saveError = 'Save failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(context);
              try {
                await context.read<V2SessionProvider>().createDocument(title);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final provider = context.read<V2SessionProvider>();
    if (provider.selectedDocPath == null) return;

    final currentDoc = provider.documents.firstWhere(
      (d) => d['file_path'] == provider.selectedDocPath,
      orElse: () => {},
    );
    final slug = currentDoc['slug']?.toString() ?? '';
    final controller =
        TextEditingController(text: currentDoc['title']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(context);
              try {
                await provider.renameDocument(slug, title);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to rename: $e')),
                  );
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final provider = context.read<V2SessionProvider>();
    if (provider.selectedDocPath == null) return;

    final currentDoc = provider.documents.firstWhere(
      (d) => d['file_path'] == provider.selectedDocPath,
      orElse: () => {},
    );
    final slug = currentDoc['slug']?.toString() ?? '';
    final title = currentDoc['title']?.toString() ?? 'this document';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deleteDocument(slug);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
