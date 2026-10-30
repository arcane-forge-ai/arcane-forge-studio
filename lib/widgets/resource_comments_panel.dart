import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/resource_comment_models.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/projects_api_service.dart';
import '../services/resource_comment_service.dart';

class ResourceCommentsPanel extends StatefulWidget {
  final String projectId;
  final ResourceCommentTarget target;
  final String title;
  final ResourceCommentService? service;
  final String? currentUserId;
  final bool? canModerate;
  final int pageSize;

  const ResourceCommentsPanel({
    super.key,
    required this.projectId,
    required this.target,
    this.title = 'Discussion',
    this.service,
    this.currentUserId,
    this.canModerate,
    this.pageSize = 50,
  });

  @override
  State<ResourceCommentsPanel> createState() => _ResourceCommentsPanelState();
}

class _ResourceCommentsPanelState extends State<ResourceCommentsPanel> {
  final TextEditingController _bodyController = TextEditingController();
  late ResourceCommentService _service;
  List<ResourceComment> _comments = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  bool _hasMore = false;
  bool _canModerate = false;
  String? _error;

  String get _currentUserId {
    if (widget.currentUserId != null) return widget.currentUserId!;
    return context.read<AuthProvider>().userId;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        ApiResourceCommentService(
          settingsProvider: context.read<SettingsProvider>(),
          authProvider: context.read<AuthProvider>(),
        );
    _canModerate = widget.canModerate ?? false;
    if (widget.canModerate == null) {
      _resolveProjectOwnerPermission();
    }
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant ResourceCommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.target.type != widget.target.type ||
        oldWidget.target.resourceId != widget.target.resourceId) {
      _comments = const [];
      _loadComments();
    }
    if (oldWidget.canModerate != widget.canModerate) {
      _canModerate = widget.canModerate ?? false;
      if (widget.canModerate == null) {
        _resolveProjectOwnerPermission();
      }
    }
  }

  Future<void> _resolveProjectOwnerPermission() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final requestedProjectId = widget.projectId;
      final project = await ProjectsApiService(
        settingsProvider: context.read<SettingsProvider>(),
        authProvider: authProvider,
      ).getProjectById(int.parse(requestedProjectId));
      if (mounted && widget.projectId == requestedProjectId) {
        setState(() => _canModerate = project.userId == authProvider.userId);
      }
    } catch (_) {
      // Permission discovery is a UI convenience. The comment API remains the
      // source of truth and will enforce every mutation.
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool append = false}) async {
    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = await _service.listComments(
        projectId: widget.projectId,
        target: widget.target,
        limit: widget.pageSize,
        offset: append ? _comments.length : 0,
      );
      if (!mounted) return;
      setState(() {
        _comments = append ? [..._comments, ...page.comments] : page.comments;
        _hasMore = page.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _addComment() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final added = await _service.addComment(
        projectId: widget.projectId,
        target: widget.target,
        body: body,
      );
      _bodyController.clear();
      if (mounted) {
        setState(() => _comments = [..._comments, added]);
      }
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editComment(ResourceComment comment) async {
    var editedBody = comment.body ?? '';
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: SizedBox(
          width: 520,
          child: TextFormField(
            key: const Key('edit-comment-input'),
            initialValue: editedBody,
            onChanged: (value) => editedBody = value,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 4000,
            decoration: const InputDecoration(
              hintText: 'Markdown is supported',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = editedBody.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBody == null || !mounted) return;

    try {
      final updated = await _service.editComment(
        projectId: widget.projectId,
        commentId: comment.id,
        body: newBody,
      );
      if (mounted) {
        setState(() {
          _comments = _comments
              .map((item) => item.id == updated.id ? updated : item)
              .toList();
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteComment(ResourceComment comment) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete comment?'),
            content: const Text(
              'The text will be removed, while the author and timestamps remain visible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      final deleted = await _service.deleteComment(
        projectId: widget.projectId,
        commentId: comment.id,
      );
      if (mounted) {
        setState(() {
          _comments = _comments
              .map((item) => item.id == deleted.id ? deleted : item)
              .toList();
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(
        'comments-${widget.target.type.wireName}-${widget.target.resourceId ?? widget.projectId}',
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        'Team discussion — not approved design truth',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : () => _loadComments(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh comments',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!, style: TextStyle(color: colorScheme.error)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _loadComments(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else ...[
            if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'No comments yet. Start the discussion for this ${widget.target.type.displayName}.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              ..._comments.map(_buildComment),
            if (_hasMore)
              Center(
                child: TextButton.icon(
                  onPressed:
                      _isLoadingMore ? null : () => _loadComments(append: true),
                  icon: _isLoadingMore
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: const Text('Load more comments'),
                ),
              ),
          ],
          Divider(height: 1, color: colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('resource-comment-input'),
                    controller: _bodyController,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment… Markdown is supported',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('submit-resource-comment'),
                  onPressed: _isSubmitting ? null : _addComment,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: const Text('Comment'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(ResourceComment comment) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAuthor = comment.createdByUserId != null &&
        comment.createdByUserId == _currentUserId;
    final canDelete = !comment.isDeleted && (isAuthor || _canModerate);
    final canEdit = !comment.isDeleted && isAuthor;
    final author = comment.authorUsername?.trim().isNotEmpty == true
        ? comment.authorUsername!
        : _shortUserId(comment.createdByUserId);

    return Container(
      key: ValueKey('resource-comment-${comment.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              author.isEmpty ? '?' : author[0].toUpperCase(),
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(author,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (isAuthor)
                      Text(
                        'You',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    if (!comment.isDeleted &&
                        comment.updatedAt.difference(comment.createdAt).abs() >
                            const Duration(seconds: 1))
                      Text(
                        'edited',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                if (comment.isDeleted)
                  Text(
                    'Comment deleted',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  MarkdownBody(
                    data: comment.body ?? '',
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium,
                      blockquoteDecoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        border: Border(
                          left:
                              BorderSide(color: colorScheme.primary, width: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              tooltip: 'Comment actions',
              onSelected: (action) {
                if (action == 'edit') _editComment(comment);
                if (action == 'delete') _deleteComment(comment);
              },
              itemBuilder: (context) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }

  String _shortUserId(String? userId) {
    if (userId == null || userId.isEmpty) return 'Unknown member';
    if (userId.length <= 8) return userId;
    return 'Member ${userId.substring(0, 8)}';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
