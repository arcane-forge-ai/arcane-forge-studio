import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/projects_api_service.dart';
import '../../models/member_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import 'components/invite_member_dialog.dart';

/// Screen for viewing and managing project team members
class ProjectMembersScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectMembersScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends State<ProjectMembersScreen> {
  bool _isLoading = true;
  List<ProjectMember> _members = [];
  List<PendingInvite> _pendingInvites = [];
  String? _error;
  String? _currentUserId;
  bool _isCurrentUserOwner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  ProjectsApiService _getProjectsApiService() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.userId;
    return ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = _getProjectsApiService();
      final members = await apiService.getProjectMembers(widget.projectId);

      // Determine if current user is owner
      final currentUserMember =
          members.where((m) => m.userId == _currentUserId);
      _isCurrentUserOwner =
          currentUserMember.isNotEmpty && currentUserMember.first.isOwner;

      // Load pending invites if user is owner
      List<PendingInvite> invites = [];
      if (_isCurrentUserOwner) {
        try {
          invites = await apiService.getPendingInvites(widget.projectId);
        } catch (e) {
          // Ignore error for pending invites - may not be available
          print('Could not load pending invites: $e');
        }
      }

      if (mounted) {
        setState(() {
          _members = members;
          _pendingInvites = invites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load members: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeMember(ProjectMember member) async {
    if (member.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove the project owner')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${member.displayName} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = _getProjectsApiService();
        await apiService.removeProjectMember(widget.projectId, member.userId);
        _loadData(); // Reload list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${member.displayName} removed from project')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove member: $e')),
          );
        }
      }
    }
  }

  void _showInviteDialog() {
    final apiService = _getProjectsApiService();
    showDialog(
      context: context,
      builder: (context) => InviteMemberDialog(
        projectId: widget.projectId,
        apiService: apiService,
      ),
    ).then((_) => _loadData()); // Reload after dialog closes
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Team Members'),
            Text(
              widget.projectName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_isCurrentUserOwner)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showInviteDialog,
              tooltip: 'Invite Member',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Members section
        _buildSectionHeader('Members', Icons.group, _members.length),
        const SizedBox(height: 8),
        ..._members.map((member) => _buildMemberCard(member, theme)),

        // Pending invites section (owner only)
        if (_isCurrentUserOwner && _pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
              'Pending Invites', Icons.mail_outline, _pendingInvites.length),
          const SizedBox(height: 8),
          ..._pendingInvites.map((invite) => _buildInviteCard(invite, theme)),
        ],

        // Empty state for no members besides owner
        if (_members.length == 1 && _isCurrentUserOwner) ...[
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.group_add,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No collaborators yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite team members to collaborate on this project',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Member'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(ProjectMember member, ThemeData theme) {
    final isCurrentUser = member.userId == _currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            member.displayName.isNotEmpty
                ? member.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: member.isOwner
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(member.displayName),
            if (isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '(you)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          member.isOwner
              ? 'Owner • Joined ${_formatDate(member.createdAt)}'
              : 'Collaborator • Joined ${_formatDate(member.createdAt)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.isOwner)
              Chip(
                label: const Text('Owner'),
                backgroundColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            if (_isCurrentUserOwner && !member.isOwner && !isCurrentUser)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: theme.colorScheme.error,
                onPressed: () => _removeMember(member),
                tooltip: 'Remove member',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(PendingInvite invite, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            Icons.mail_outline,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(invite.invitedEmail),
        subtitle: Text('Invited ${_formatDate(invite.createdAt)}'),
        trailing: Chip(
          label: const Text('Pending'),
          backgroundColor: Colors.orange.withOpacity(0.2),
          labelStyle: const TextStyle(
            color: Colors.orange,
            fontSize: 12,
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
