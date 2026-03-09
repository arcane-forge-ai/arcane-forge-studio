import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/confirmation.dart';
import '../models/message.dart';
import '../providers/v2_session_provider.dart';
import 'confirmation_card.dart';
import 'selection_card.dart';

class V2ChatPanel extends StatefulWidget {
  const V2ChatPanel({super.key});

  @override
  State<V2ChatPanel> createState() => _V2ChatPanelState();
}

class _V2ChatPanelState extends State<V2ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = context.read<V2SessionProvider>();
    final canAttemptSend =
        !provider.isSending && !provider.isLoading && provider.canUseV2;
    final text = _controller.text.trim();
    if (text.isEmpty || !canAttemptSend) return;

    _controller.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final filteredMessages = provider.messages.where((msg) {
      if (msg.role == 'system') return false;
      if (msg.role == 'tool') return false;
      if (msg.content.startsWith('[Tool]')) return false;
      if (msg.role == 'user') {
        final t = msg.content.trim().toLowerCase();
        if (t == 'confirm' || t == 'cancel' || t == '确认' || t == '取消') {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    if (provider.isSending || filteredMessages.isNotEmpty) {
      _scrollToBottom();
    }

    return Column(
      children: [
        if (provider.chatError != null)
          Material(
            color: Colors.red.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.chatError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: filteredMessages.isEmpty && !provider.isSending
              ? _buildEmptyState(context, provider)
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        filteredMessages.length + (provider.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filteredMessages.length) {
                        return _buildMessageBubble(
                          context,
                          ChatMessage(
                            role: 'assistant',
                            content: provider.streamingContent,
                            timestamp: DateTime.now(),
                            thinking: provider.thinkingContent,
                          ),
                          isStreaming: true,
                          isLastMessage: true,
                        );
                      }
                      final msg = filteredMessages[index];
                      return _buildMessageBubble(
                        context,
                        msg,
                        isLastMessage: index == filteredMessages.length - 1,
                      );
                    },
                  ),
                ),
        ),
        _buildInputBar(context, provider),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, V2SessionProvider provider) {
    String message;
    if (provider.currentSession == null && provider.hasDraftConversation) {
      message =
          'Ready for a new conversation. Session will be created when you send the first message.';
    } else if (provider.currentSession == null) {
      message = 'Select a chat from the sidebar or start a new chat.';
    } else {
      message = 'No messages yet. Start the conversation.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, V2SessionProvider provider) {
    final inputEnabled = !provider.isLoading && provider.canUseV2;
    final inputHint = !provider.canUseV2
        ? 'Sign in to use Game Design Assistant v2'
        : 'Ask about game design...';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                enabled: inputEnabled,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: inputHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: (provider.isSending ||
                      provider.isLoading ||
                      !provider.canUseV2)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(52, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: provider.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage msg, {
    bool isStreaming = false,
    bool isLastMessage = false,
  }) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);
    final provider = context.read<V2SessionProvider>();
    final hasPending = provider.pendingConfirmation != null;
    Confirmation? confirmation = hasPending ? msg.confirmation : null;
    var displayContent = msg.content;

    if (isStreaming && displayContent.isEmpty && (msg.thinking ?? '').isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Thinking...'),
            ],
          ),
        ),
      );
    }

    if (!isUser) {
      if (confirmation != null) {
        displayContent = '';
      }
      if (hasPending &&
          confirmation == null &&
          (isLastMessage || isStreaming)) {
        final parsed = _parseConfirmation(msg.content);
        if (parsed != null) {
          displayContent = parsed.cleanedContent;
          confirmation = parsed.confirmation;
        }
      }

      if (displayContent.contains('```')) {
        final jsonBlockRegex =
            RegExp(r'```(?:json)?\s*[\s\S]*?```', multiLine: true);
        final cleaned = displayContent.replaceAll(jsonBlockRegex, '').trim();
        if (cleaned.isNotEmpty) {
          displayContent = cleaned;
        } else if (confirmation != null) {
          displayContent = '';
        }
      }
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary.withOpacity(0.95)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: isUser
                ? null
                : Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((msg.thinking ?? '').isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thinking...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg.thinking!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              if (displayContent.isNotEmpty)
                isUser
                    ? Text(
                        displayContent,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : MarkdownBody(data: displayContent),
              if (confirmation != null)
                ConfirmationCard(confirmation: confirmation),
              if (msg.selection != null)
                SelectionCard(selection: msg.selection!),
            ],
          ),
        ),
      ),
    );
  }

  ({Confirmation confirmation, String cleanedContent})? _parseConfirmation(
      String content) {
    String? capturedJson;
    try {
      final jsonBlockRegex =
          RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true);
      final match = jsonBlockRegex.firstMatch(content);
      if (match != null) {
        capturedJson = match.group(1);
        if (capturedJson != null) {
          final data = jsonDecode(capturedJson) as Map<String, dynamic>;
          if (data.containsKey('plan')) {
            final plan = Map<String, dynamic>.from(data['plan'] as Map);
            final steps = (plan['steps'] as List?) ?? const [];
            final planRequiresConfirmation =
                plan['requires_confirmation'] == true ||
                    data['requires_confirmation'] == true;
            for (final rawStep in steps) {
              final step = Map<String, dynamic>.from(rawStep as Map);
              if (step['requires_confirmation'] == true ||
                  planRequiresConfirmation) {
                final args = step['args'] is Map
                    ? Map<String, dynamic>.from(step['args'] as Map)
                    : <String, dynamic>{};
                var preview = '';
                final targetPath = args['path']?.toString();
                final sectionId =
                    (args['section_id'] ?? args['section'])?.toString();
                if (args['content'] is String) {
                  preview = args['content'] as String;
                } else if (args.isNotEmpty) {
                  preview = const JsonEncoder.withIndent('  ').convert(args);
                }
                return (
                  confirmation: Confirmation(
                    state: 'pending',
                    action: step['tool']?.toString() ?? 'Unknown Action',
                    goal: step['expected']?.toString() ?? 'Execute plan step',
                    reason: plan['description']?.toString() ??
                        'Confirmation required',
                    preview: preview.isEmpty ? null : preview,
                    targetPath: targetPath,
                    sectionId: sectionId,
                    confirmText: 'Confirm',
                    cancelText: 'Cancel',
                  ),
                  cleanedContent:
                      content.replaceFirst(match.group(0)!, '').trim(),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    if (content
        .contains('The following operation requires your confirmation')) {
      try {
        final actionRegex = RegExp(r'(?:\*\*|__)?Action(?:\*\*|__)?\s*:\s*(.+)',
            caseSensitive: false);
        final matchAction = actionRegex.firstMatch(content);
        final goalRegex = RegExp(
            r'(?:\*\*|__)?Expected result(?:\*\*|__)?\s*:\s*(.+)',
            caseSensitive: false);
        final matchGoal = goalRegex.firstMatch(content);
        if (matchAction != null) {
          return (
            confirmation: Confirmation(
              state: 'pending',
              action: matchAction.group(1)?.trim() ?? 'Unknown Action',
              goal: matchGoal?.group(1)?.trim() ?? '',
              reason: 'High-risk operation requires user approval',
              preview: null,
              confirmText: 'Confirm',
              cancelText: 'Cancel',
            ),
            cleanedContent: '',
          );
        }
      } catch (_) {}
    }
    return null;
  }
}
