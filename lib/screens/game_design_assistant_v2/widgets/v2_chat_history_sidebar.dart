import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/v2_session_provider.dart';

class V2ChatHistorySidebar extends StatelessWidget {
  const V2ChatHistorySidebar({super.key});

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _titleForSession(SessionInfo s) {
    final title = s.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final stage = s.currentStage?.trim();
    if (stage != null && stage.isNotEmpty) return stage;
    return 'Session ${s.sessionId.length > 8 ? s.sessionId.substring(0, 8) : s.sessionId}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<V2SessionProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[50],
        border: Border(
          right: BorderSide(color: colorScheme.outline.withOpacity(0.15)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: colorScheme.outline.withOpacity(0.12)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chat History',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: provider.isSessionsLoading
                          ? null
                          : () =>
                              context.read<V2SessionProvider>().loadSessions(),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.read<V2SessionProvider>().startNewChat(),
                    icon: const Icon(Icons.add_comment, size: 18),
                    label: const Text('New Chat'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (provider.isSessionsLoading && provider.sessions.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.sessionsError != null &&
                    provider.sessions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load sessions',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.sessionsError!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => context
                                .read<V2SessionProvider>()
                                .loadSessions(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (provider.sessions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No v2 chats yet. Start a new chat to create one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: provider.sessions.length,
                  itemBuilder: (context, index) {
                    final session = provider.sessions[index];
                    final isSelected =
                        provider.currentSession?.sessionId == session.sessionId;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withOpacity(0.08)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: colorScheme.primary.withOpacity(0.3))
                            : null,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          try {
                            await context
                                .read<V2SessionProvider>()
                                .selectSession(session.sessionId);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to load session: $e')),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _titleForSession(session),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(session.updatedAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if ((session.currentPillar ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  session.currentPillar!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
