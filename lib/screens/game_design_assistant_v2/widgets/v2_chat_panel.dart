import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/confirmation.dart';
import '../models/message.dart';
import '../providers/v2_session_provider.dart';
import '../utils/chat_input_ui_state.dart';
import '../utils/stream_locale.dart';
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
  Timer? _selectionExpiryTicker;
  static const double _autoScrollThreshold = 72;
  bool _isNearBottom = true;
  bool _scrollScheduled = false;
  bool _hasAutoScrollBaseline = false;
  int _lastMessageCount = 0;
  int _lastStreamRenderVersion = 0;
  bool _lastIsSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollPosition);
    _selectionExpiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _selectionExpiryTicker?.cancel();
    _scrollController.removeListener(_handleScrollPosition);
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
    _isNearBottom = true;
    provider.sendMessage(text);
    _scrollToBottom();
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    _isNearBottom = distanceToBottom <= _autoScrollThreshold;
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollScheduled = false;
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _syncAutoScrollState(
    V2SessionProvider provider,
    int messageCount,
  ) {
    final hasNewMessage = messageCount != _lastMessageCount;
    final streamUpdated = provider.isSending &&
        (provider.streamRenderVersion != _lastStreamRenderVersion ||
            provider.isSending != _lastIsSending);
    final sendingStateChanged = provider.isSending != _lastIsSending;
    final shouldScroll = !_hasAutoScrollBaseline ||
        ((hasNewMessage || streamUpdated || sendingStateChanged) &&
            _isNearBottom);

    if (shouldScroll) {
      _scrollToBottom(animated: _hasAutoScrollBaseline);
    }

    _hasAutoScrollBaseline = true;
    _lastMessageCount = messageCount;
    _lastStreamRenderVersion = provider.streamRenderVersion;
    _lastIsSending = provider.isSending;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final isBlockingSessionSwitch = provider.isSessionSelectionLoading;
    final inputState = resolveChatInputUiState(
      canUseV2: provider.canUseV2,
      isLoading: provider.isLoading,
      isLoadingSessionSelection: isBlockingSessionSwitch,
      hasExpiredPendingSelection: provider.hasExpiredPendingSelection,
    );
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

    _syncAutoScrollState(provider, filteredMessages.length);

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
          child: Stack(
            children: [
              Positioned.fill(
                child: filteredMessages.isEmpty &&
                        !provider.isSending &&
                        !isBlockingSessionSwitch
                    ? _buildEmptyState(context, provider)
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredMessages.length +
                              (provider.isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filteredMessages.length) {
                              final bubble = _buildMessageBubble(
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
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeOut,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                        opacity: animation, child: child),
                                child: KeyedSubtree(
                                  key: ValueKey<int>(
                                      provider.streamRenderVersion),
                                  child: bubble,
                                ),
                              );
                            }
                            final msg = filteredMessages[index];
                            return _buildMessageBubble(
                              context,
                              msg,
                              isLastMessage:
                                  index == filteredMessages.length - 1,
                            );
                          },
                        ),
                      ),
              ),
              if (isBlockingSessionSwitch)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.74),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading chat session...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildInputBar(context, provider, inputState),
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

  Widget _buildInputBar(
    BuildContext context,
    V2SessionProvider provider,
    ChatInputUiState inputState,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: inputState.loadingLabel == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey<String>(inputState.loadingLabel!),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(inputState.loadingLabel!)),
                        ],
                      ),
                    ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    enabled: inputState.enabled,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: inputState.hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (provider.isSending || !inputState.enabled)
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
    final streamStatusTip = isStreaming ? provider.streamStatusTip : null;

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
              if (streamStatusTip != null && streamStatusTip.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.secondaryContainer.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    streamStatusTip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              if (msg.isPartial)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    localizedPartialHint(displayContent),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
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
