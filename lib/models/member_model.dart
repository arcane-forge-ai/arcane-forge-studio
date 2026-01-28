/// Data models for project team collaboration.

/// Represents a member of a project.
class ProjectMember {
  final String userId;
  final String? username;
  final String? email;
  final bool isOwner;
  final DateTime createdAt;

  ProjectMember({
    required this.userId,
    this.username,
    this.email,
    required this.isOwner,
    required this.createdAt,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    // API returns 'role' ("owner" | "collaborator") and 'joined_at'
    final role = json['role'] as String?;
    return ProjectMember(
      userId: json['user_id'] ?? '',
      username: json['username'],
      email: json['email'],
      isOwner: role == 'owner',
      createdAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'is_owner': isOwner,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Display name: prefer username, fallback to email, then userId
  String get displayName => username ?? email ?? userId;
}

/// Represents a pending email invitation to join a project.
class PendingInvite {
  final int inviteId;
  final int projectId;
  final String? projectName;
  final String? projectDescription;
  final String invitedEmail;
  final String? invitedUserId;
  final String status; // 'pending' or 'accepted'
  final DateTime createdAt;

  PendingInvite({
    required this.inviteId,
    required this.projectId,
    this.projectName,
    this.projectDescription,
    required this.invitedEmail,
    this.invitedUserId,
    required this.status,
    required this.createdAt,
  });

  factory PendingInvite.fromJson(Map<String, dynamic> json) {
    return PendingInvite(
      inviteId: json['invite_id'] ?? 0,
      projectId: json['project_id'] ?? 0,
      projectName: json['project_name'],
      projectDescription: json['project_description'],
      invitedEmail: json['invited_email'] ?? '',
      invitedUserId: json['invited_user_id'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invite_id': inviteId,
      'project_id': projectId,
      'project_name': projectName,
      'project_description': projectDescription,
      'invited_email': invitedEmail,
      'invited_user_id': invitedUserId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
}

/// Response from accepting an invite or redeeming an invite link.
class InviteAcceptResponse {
  final int projectId;
  final String projectName;
  final String role; // "owner" | "collaborator"
  final bool alreadyMember;

  InviteAcceptResponse({
    required this.projectId,
    required this.projectName,
    required this.role,
    required this.alreadyMember,
  });

  factory InviteAcceptResponse.fromJson(Map<String, dynamic> json) {
    return InviteAcceptResponse(
      projectId: json['project_id'] ?? 0,
      projectName: json['project_name'] ?? '',
      role: json['role'] ?? 'collaborator',
      alreadyMember: json['already_member'] ?? false,
    );
  }
}

/// Response from creating an email invite
class EmailInviteResponse {
  final int inviteId;
  final int projectId;
  final String invitedEmail;
  final String? invitedUserId;
  final String status;
  final DateTime createdAt;

  EmailInviteResponse({
    required this.inviteId,
    required this.projectId,
    required this.invitedEmail,
    this.invitedUserId,
    required this.status,
    required this.createdAt,
  });

  factory EmailInviteResponse.fromJson(Map<String, dynamic> json) {
    return EmailInviteResponse(
      inviteId: json['invite_id'] ?? 0,
      projectId: json['project_id'] ?? 0,
      invitedEmail: json['invited_email'] ?? '',
      invitedUserId: json['invited_user_id'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Returns true if the user exists and can accept immediately
  bool get isReady => status == 'ready';
}
