import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_constants.dart' as app_utils;
import '../../services/projects_api_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/member_model.dart';
import '../project/project_dashboard_screen.dart';

class ProjectInvitesScreen extends StatefulWidget {
  const ProjectInvitesScreen({super.key});

  @override
  State<ProjectInvitesScreen> createState() => _ProjectInvitesScreenState();
}

class _ProjectInvitesScreenState extends State<ProjectInvitesScreen> {
  List<PendingInvite> _pendingInvites = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<int, bool> _acceptingInvites = {}; // Track which invites are being accepted

  @override
  void initState() {
    super.initState();
    _loadPendingInvites();
  }

  /// Get fresh ProjectsApiService instance with current settings
  ProjectsApiService _getProjectsApiService() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return ProjectsApiService(
      settingsProvider: settingsProvider,
      authProvider: authProvider,
    );
  }

  Future<void> _loadPendingInvites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invites = await _getProjectsApiService().getMyPendingInvites();
      setState(() {
        _pendingInvites = invites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending invites: $e');
      setState(() {
        _errorMessage = 'Failed to load invites. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite(PendingInvite invite) async {
    setState(() {
      _acceptingInvites[invite.inviteId] = true;
    });

    try {
      final success = await _getProjectsApiService().acceptEmailInvite(invite.projectId);

      if (mounted) {
        if (success) {
          final projectName = invite.projectName ?? 'Project ${invite.projectId}';
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully joined "$projectName"!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open Project',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProjectDashboardScreen(
                        projectId: invite.projectId.toString(),
                        projectName: projectName,
                      ),
                    ),
                  );
                },
              ),
            ),
          );

          // Remove the accepted invite from the list
          setState(() {
            _pendingInvites.removeWhere((i) => i.inviteId == invite.inviteId);
            _acceptingInvites.remove(invite.inviteId);
          });
        } else {
          throw Exception('Failed to accept invite');
        }
      }
    } catch (e) {
      print('Error accepting invite: $e');
      if (mounted) {
        setState(() {
          _acceptingInvites.remove(invite.inviteId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept invite: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return app_utils.DateUtils.formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withOpacity(0.8),
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Project Invites',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _pendingInvites.isEmpty
                                      ? 'You have no pending project invitations'
                                      : 'You have ${_pendingInvites.length} pending invitation${_pendingInvites.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _loadPendingInvites,
                            icon: Icon(
                              Icons.refresh,
                              color: colorScheme.primary,
                            ),
                            tooltip: 'Refresh Invites',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Invites List
                      Expanded(
                        child: _pendingInvites.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _pendingInvites.length,
                                itemBuilder: (context, index) {
                                  final invite = _pendingInvites[index];
                                  return _buildInviteCard(invite, isDark);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorWidget() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Invites',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPendingInvites,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_outline,
            size: 80,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Invites',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone invites you to a project, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(PendingInvite invite, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAccepting = _acceptingInvites[invite.inviteId] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_add,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Invite details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.projectName ?? 'Project ${invite.projectId}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (invite.projectDescription != null &&
                      invite.projectDescription!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      invite.projectDescription!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Invited ${_formatDate(invite.createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Accept button
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: isAccepting ? null : () => _acceptInvite(invite),
              icon: isAccepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isAccepting ? 'Accepting...' : 'Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

