import '../../core/server_url.dart';

/// A person as the messaging API describes them: the compact shape that sits
/// on a message bubble (`presentMini`) and the fuller one on a direct chat
/// (`presentUser`). Both decode here; the extra fields are simply null on
/// the compact one.
class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    required this.initial,
    required this.role,
    this.avatarUrl,
    this.roleLabel,
    this.subtitle,
    this.online = false,
    this.lastSeenAt,
    this.memberRole,
    this.lastReadMessageId,
    this.invitedBy,
    this.profileScreen,
    this.profileParams = const {},
  });

  final int id;
  final String name;
  final String initial;
  final String role;
  final String? avatarUrl;
  final String? roleLabel;
  final String? subtitle;
  final bool online;
  final DateTime? lastSeenAt;

  /// Group membership: `admin` or `member` (null outside a group).
  final String? memberRole;
  final int? lastReadMessageId;
  final int? invitedBy;

  /// Where "Profile" goes in the app (`student_profile` + `student_id`, and
  /// so on), as `ProfileLinkService::appDestinationForUser` names them.
  final String? profileScreen;
  final Map<String, dynamic> profileParams;

  bool get isAdmin => memberRole == 'admin';

  String get firstName => name.split(' ').first;

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    // Group member rows reuse the `role` key for the membership role
    // (`admin` / `member`); everywhere else it is the account role.
    final role = json['role'] as String? ?? '';
    final isMembership = role == 'admin' || role == 'member';

    return ChatUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown',
      initial: json['initial'] as String? ?? '?',
      role: isMembership ? '' : role,
      avatarUrl: resolveServerUrl(json['avatar'] as String?),
      roleLabel: json['role_label'] as String?,
      subtitle: json['subtitle'] as String?,
      online: json['online'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      memberRole: isMembership ? role : null,
      lastReadMessageId: (json['last_read_message_id'] as num?)?.toInt(),
      invitedBy: (json['invited_by'] as num?)?.toInt(),
      profileScreen: (json['app_profile'] as Map<String, dynamic>?)?['screen'] as String?,
      profileParams: Map<String, dynamic>.from(
        (json['app_profile'] as Map<String, dynamic>?)?['params'] as Map? ?? const {},
      ),
    );
  }

  /// "Active now", "Active 5m ago", or null when they have been away a while.
  String? get activityLabel {
    if (online) return 'Active now';
    final seen = lastSeenAt;
    if (seen == null) return null;
    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return null;
  }
}
