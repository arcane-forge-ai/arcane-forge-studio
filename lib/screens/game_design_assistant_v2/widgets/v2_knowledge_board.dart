import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../providers/v2_session_provider.dart';
import '../services/v2_api_service.dart';
import 'pending_knowledge_panel.dart';
import 'project_context_panel.dart';

class _FocusDisplay {
  final String title;
  final String? subtitle;

  const _FocusDisplay({
    required this.title,
    this.subtitle,
  });
}

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

  bool _isVersionHistoryExpanded = false;
  bool _isLoadingVersions = false;
  bool _isLoadingVersionContent = false;
  bool _isDeletingVersion = false;
  int? _deletingVersionNumber;
  List<dynamic> _versions = [];
  String? _versionsFilePath;
  String? _viewingFilePath;
  int? _viewingVersionNumber;
  String? _viewingVersionContent;

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
      length: 3,
      child: Column(
        children: [
          Container(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.35),
            child: TabBar(
              tabs: [
                const Tab(text: 'Context'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Project'),
                      if (provider.hasPendingKnowledge) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${provider.pendingKnowledgeItems.length}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ] else if (provider
                          .shouldPromptSessionKnowledgeExtraction) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.priority_high,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Design Document'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildContextTab(context),
                _buildProjectContextTab(context),
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
    final focusDisplay = _buildCurrentFocusDisplay(data?.currentFocus);

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
        if (focusDisplay != null) ...[
          _sectionTitle(context, 'Current Focus'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: Text(focusDisplay.title),
              subtitle: focusDisplay.subtitle == null
                  ? null
                  : Text(focusDisplay.subtitle!),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildOpenQuestionsSection(context, provider, data.openQuestions),
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
            focusDisplay == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No context available yet for this session.'),
            ),
          ),
      ],
    );
  }

  Widget _buildOpenQuestionsSection(
    BuildContext context,
    V2SessionProvider provider,
    List<Map<String, dynamic>> questions,
  ) {
    if (questions.isEmpty) return const SizedBox.shrink();

    final canClose = provider.currentSession != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Open Questions'),
        ...questions.map((item) {
          final questionText = item['question']?.toString() ?? '';
          final priority = item['priority']?.toString();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.orange),
              title: Text(questionText),
              subtitle: priority == null ? null : Text('Priority: $priority'),
              trailing: canClose && questionText.trim().isNotEmpty
                  ? IconButton(
                      tooltip: 'Mark as resolved',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () async {
                        try {
                          await provider.closeOpenQuestion(questionText);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to close question: $e'),
                            ),
                          );
                        }
                      },
                    )
                  : null,
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildProjectContextTab(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();

    return Column(
      children: [
        // Pending knowledge panel (if any)
        if (provider.hasPendingKnowledge) const PendingKnowledgePanel(),

        // Project context entries
        const Expanded(child: ProjectContextPanel()),
      ],
    );
  }

  Widget _buildDocumentTab(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    _syncVersionViewWithSelectedDocument(provider, context);

    return Column(
      children: [
        _buildDocumentToolbar(context),
        Expanded(
          child: _isEditing ? _buildEditor(context) : _buildPreview(context),
        ),
        if (provider.selectedDocPath != null) _buildVersionHistory(context),
      ],
    );
  }

  Widget _buildDocumentToolbar(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final hasSession = provider.currentSession != null;
    final canEditCurrentDoc =
        hasSession && !_isViewingHistoricalVersion(provider);
    final documents = provider.documents
        .where((doc) => _documentPath(doc) != null)
        .toList(growable: false);
    final hasDocuments = documents.isNotEmpty;
    final selectedPath = provider.selectedDocPath;
    final dropdownValue = selectedPath != null &&
            documents.any((doc) => _documentPath(doc) == selectedPath)
        ? selectedPath
        : null;

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
              value: dropdownValue,
              hint: const Text('Select document'),
              items: documents.map((doc) {
                final filePath = _documentPath(doc)!;
                final title = _documentTitle(doc, filePath);
                return DropdownMenuItem(
                  value: filePath,
                  child: Text(title),
                );
              }).toList(),
              onChanged: hasSession
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
            onPressed: hasSession ? () => _showCreateDialog(context) : null,
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
            onPressed: canEditCurrentDoc && provider.selectedDocPath != null
                ? (index) {
                    setState(() {
                      if (index == 1 && !_isEditing) {
                        _editController.text =
                            provider.selectedDocContent ?? '';
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
                onPressed: canEditCurrentDoc && provider.selectedDocPath != null
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

  Widget _buildVersionHistory(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final theme = Theme.of(context);
    final selectedPath = provider.selectedDocPath;
    final versionsForCurrentDoc =
        _versionsFilePath == selectedPath ? _versions : const <dynamic>[];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isVersionHistoryExpanded = !_isVersionHistoryExpanded;
              });
              if (_isVersionHistoryExpanded &&
                  (_versionsFilePath != selectedPath ||
                      versionsForCurrentDoc.isEmpty)) {
                _loadVersions(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _isVersionHistoryExpanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Version History',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (provider.selectedDocVersionNumber != null)
                    Text(
                      _isViewingHistoricalVersion(provider)
                          ? 'Viewing v$_viewingVersionNumber'
                          : 'v${provider.selectedDocVersionNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_isVersionHistoryExpanded) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh versions',
                        onPressed: _isLoadingVersions
                            ? null
                            : () => _loadVersions(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isVersionHistoryExpanded) ...[
            if (_isLoadingVersions)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (versionsForCurrentDoc.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No versions found.')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: versionsForCurrentDoc.length,
                  itemBuilder: (context, index) {
                    final version = Map<String, dynamic>.from(
                        versionsForCurrentDoc[index] as Map);
                    final versionNumber =
                        (version['version_number'] as num?)?.toInt() ?? 0;
                    final source = version['source']?.toString() ?? 'unknown';
                    final createdAt = version['created_at']?.toString() ?? '';
                    final comment = version['comment']?.toString();
                    final isCurrent =
                        versionNumber == provider.selectedDocVersionNumber;
                    final isViewing = _isViewingHistoricalVersion(provider)
                        ? versionNumber == _viewingVersionNumber
                        : isCurrent;
                    final isDeleting = _isDeletingVersion &&
                        _deletingVersionNumber == versionNumber;

                    return Card(
                      elevation: isViewing ? 2 : 0,
                      color: isViewing
                          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                          : null,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        onTap: () => _viewVersion(context, versionNumber),
                        dense: true,
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle
                              : isViewing
                                  ? Icons.visibility
                                  : Icons.history,
                          size: 18,
                          color: isViewing ? theme.colorScheme.primary : null,
                        ),
                        title: Text(
                          'v$versionNumber'
                          '${isCurrent ? ' (current)' : ''}'
                          '${isViewing && !isCurrent ? ' (viewing)' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isViewing ? FontWeight.w600 : null,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatSource(source)}${comment != null ? ' - $comment' : ''}'
                          '${createdAt.isNotEmpty ? '\nUpdated: ${_formatTimestamp(createdAt)}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: isCurrent
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDeleting)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  else
                                    IconButton(
                                      tooltip: 'Delete version',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _confirmDeleteVersion(
                                        context,
                                        versionNumber,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  V2ApiService _createApiService(BuildContext context) {
    return V2ApiService(
      settingsProvider: context.read<SettingsProvider>(),
      authProvider: context.read<AuthProvider>(),
    );
  }

  Future<void> _loadVersions(BuildContext context) async {
    final provider = context.read<V2SessionProvider>();
    final filePath = provider.selectedDocPath;
    if (filePath == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final requestPath = filePath;

    setState(() {
      _isLoadingVersions = true;
    });

    try {
      final apiService = _createApiService(context);
      final versions =
          await apiService.listVersions(provider.projectId, filePath);
      if (mounted) {
        if (provider.selectedDocPath != requestPath) {
          _isLoadingVersions = false;
          return;
        }
        setState(() {
          _versions = versions;
          _versionsFilePath = requestPath;
          _isLoadingVersions = false;
        });
      }
      apiService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading versions: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingVersions = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to load versions: $e')),
        );
      }
    }
  }

  Future<void> _viewVersion(BuildContext context, int versionNumber) async {
    final provider = context.read<V2SessionProvider>();
    final filePath = provider.selectedDocPath;
    if (filePath == null) return;

    if (versionNumber == provider.selectedDocVersionNumber) {
      if (!mounted) return;
      setState(() {
        _viewingVersionNumber = null;
        _viewingVersionContent = null;
        _isLoadingVersionContent = false;
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoadingVersionContent = true;
      _viewingVersionNumber = versionNumber;
      _isEditing = false;
    });

    final apiService = _createApiService(context);
    try {
      final version = await apiService.getVersion(
          provider.projectId, filePath, versionNumber);
      final content = version['content_markdown']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _viewingVersionContent = content;
          _isLoadingVersionContent = false;
        });
        messenger.showSnackBar(SnackBar(
          content: Text('Viewing version v$versionNumber.'),
          duration: const Duration(milliseconds: 1200),
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading version content: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingVersionContent = false;
          _viewingVersionNumber = null;
          _viewingVersionContent = null;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to view version: $e')),
        );
      }
    } finally {
      apiService.dispose();
    }
  }

  void _beginEditFromHistoricalVersion(BuildContext context) {
    final versionNumber = _viewingVersionNumber;
    final content = _viewingVersionContent;
    if (versionNumber == null || content == null) return;

    setState(() {
      _editController.text = content;
      _saveError = null;
      _isEditing = true;
      _viewingVersionNumber = null;
      _viewingVersionContent = null;
      _isLoadingVersionContent = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded v$versionNumber into editor as draft. Saving creates a new version.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteVersion(
    BuildContext context,
    int versionNumber,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Version'),
        content: Text(
          'Delete version v$versionNumber from history?\n'
          'This only removes that version record and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;
    await _deleteVersion(versionNumber);
  }

  Future<void> _deleteVersion(int versionNumber) async {
    final currentContext = context;
    final provider = currentContext.read<V2SessionProvider>();
    final filePath = provider.selectedDocPath;
    if (filePath == null) return;

    final messenger = ScaffoldMessenger.of(currentContext);
    setState(() {
      _isDeletingVersion = true;
      _deletingVersionNumber = versionNumber;
    });

    final apiService = _createApiService(currentContext);
    try {
      await apiService.deleteVersion(
          provider.projectId, filePath, versionNumber);
      if (!mounted) return;
      final versions =
          await apiService.listVersions(provider.projectId, filePath);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _versionsFilePath = filePath;
        _isLoadingVersions = false;
        if (_viewingVersionNumber == versionNumber) {
          _viewingVersionNumber = null;
          _viewingVersionContent = null;
          _isLoadingVersionContent = false;
        }
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted version v$versionNumber.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete version: $e')),
      );
    } finally {
      apiService.dispose();
      if (mounted) {
        setState(() {
          _isDeletingVersion = false;
          _deletingVersionNumber = null;
        });
      }
    }
  }

  Widget _buildPreview(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final isViewingHistory = _isViewingHistoricalVersion(provider);
    final content = isViewingHistory
        ? (_viewingVersionContent ?? '')
        : (provider.selectedDocContent ?? '');

    if (provider.documents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No documents created in this session yet.'),
        ),
      );
    }

    if (provider.selectedDocPath == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Please select a document from the dropdown above.'),
        ),
      );
    }

    if (_isLoadingVersionContent) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (content.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isViewingHistory
                ? 'This historical version has no content.'
                : 'No content yet. Switch to Edit mode to start writing.',
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isViewingHistory)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing historical version v$_viewingVersionNumber (read-only).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _viewingVersionNumber = null;
                      _viewingVersionContent = null;
                    });
                  },
                  child: const Text('Back to current'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _beginEditFromHistoricalVersion(context),
                  child: const Text('Edit from this version'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Markdown(
            data: content,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  void _syncVersionViewWithSelectedDocument(
    V2SessionProvider provider,
    BuildContext context,
  ) {
    final currentPath = provider.selectedDocPath;
    if (_viewingFilePath == currentPath) return;

    _viewingFilePath = currentPath;
    _versionsFilePath = currentPath;
    _versions = [];
    _isLoadingVersions = false;
    _viewingVersionNumber = null;
    _viewingVersionContent = null;
    _isLoadingVersionContent = false;

    if (_isVersionHistoryExpanded && currentPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadVersions(context);
      });
    }
  }

  bool _isViewingHistoricalVersion(V2SessionProvider provider) {
    final viewing = _viewingVersionNumber;
    final current = provider.selectedDocVersionNumber;
    return viewing != null && current != null && viewing != current;
  }

  _FocusDisplay? _buildCurrentFocusDisplay(Map<String, dynamic>? focus) {
    if (focus == null) return null;

    final topic = _nonEmptyText(focus['topic']) ??
        _nonEmptyText(focus['title']) ??
        _nonEmptyText(focus['focus']) ??
        _nonEmptyText(focus['target']);
    final stage = _humanizeFocusToken(_nonEmptyText(focus['stage']));
    final pillar = _humanizeFocusToken(_nonEmptyText(focus['pillar']));
    final reason = _nonEmptyText(focus['reason']) ??
        _nonEmptyText(focus['note']) ??
        _nonEmptyText(focus['context']);

    if (topic != null) {
      final parts = <String>[
        if (stage != null) 'Stage: $stage',
        if (pillar != null) 'Pillar: $pillar',
        if (reason != null) reason,
      ];
      return _FocusDisplay(
        title: topic,
        subtitle: parts.isEmpty ? null : parts.join(' · '),
      );
    }

    if (stage != null || pillar != null) {
      final title =
          [if (stage != null) stage, if (pillar != null) pillar].join(' · ');
      return _FocusDisplay(title: title, subtitle: reason);
    }

    if (reason != null) {
      return _FocusDisplay(title: reason);
    }

    return null;
  }

  String? _nonEmptyText(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _humanizeFocusToken(String? value) {
    if (value == null) return null;

    final raw = value.trim();
    if (raw.isEmpty) return null;

    // Keep non-latin labels untouched (e.g. Chinese stages/pillars).
    if (!RegExp(r'^[A-Za-z0-9_\-\s]+$').hasMatch(raw)) {
      return raw;
    }

    final normalized = raw.toLowerCase();
    const stageMap = {
      'clarify': 'Clarify',
      'brainstorm': 'Brainstorm',
      'refine': 'Refine',
      'document': 'Document',
    };
    if (stageMap.containsKey(normalized)) {
      return stageMap[normalized];
    }

    final words = normalized
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .toList(growable: false);
    return words.isEmpty ? raw : words.join(' ');
  }

  String _formatSource(String source) {
    switch (source) {
      case 'ai':
        return 'AI';
      case 'user':
        return 'User';
      case 'system':
        return 'System';
      case 'restore':
        return 'Restored';
      default:
        return source;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
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
    final sessionProvider = context.read<V2SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await sessionProvider.createDocument(title);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to create: $e')),
                );
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
      (d) => _documentPath(d) == provider.selectedDocPath,
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
      (d) => _documentPath(d) == provider.selectedDocPath,
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

  String? _documentPath(Map<String, dynamic> doc) {
    final path = doc['file_path']?.toString() ??
        doc['path']?.toString() ??
        doc['document_path']?.toString() ??
        doc['filePath']?.toString() ??
        doc['documentPath']?.toString();
    if (path == null) return null;
    final trimmed = path.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _documentTitle(Map<String, dynamic> doc, String fallbackPath) {
    final title = doc['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      return fallbackPath;
    }
    return title;
  }
}
