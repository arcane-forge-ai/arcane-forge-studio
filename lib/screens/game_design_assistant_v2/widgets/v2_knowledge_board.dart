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
          ToggleButtons(
            isSelected: [!_isEditing, _isEditing],
            borderRadius: BorderRadius.circular(6),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 74),
            onPressed: canEdit
                ? (index) {
                    setState(() {
                      if (index == 1 && !_isEditing) {
                        _editController.text = provider.gddContent ?? '';
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
                onPressed: canEdit ? () => _saveGdd(context) : null,
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
    final content = provider.gddContent ?? '';

    if (provider.currentSession == null && provider.hasDraftConversation) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'GDD preview will load after the first message creates a session.'),
        ),
      );
    }

    if (content.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No design document yet. Switch to Edit mode to start writing.'),
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

  Future<void> _saveGdd(BuildContext context) async {
    final sessionProvider = context.read<V2SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await sessionProvider.saveGddContent(_editController.text);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Design document saved.')),
      );
    } on ConflictException catch (e) {
      setState(() {
        _saveError =
            'Conflict: $e The editor was reloaded with the latest version.';
        _editController.text = sessionProvider.gddContent ?? '';
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
}
