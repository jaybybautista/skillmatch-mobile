import '../../core/server_url.dart';
import 'chat_user.dart';

/// The one-line summary under a chat's name in the list.
class LastMessageSummary {
  const LastMessageSummary({
    required this.id,
    required this.senderId,
    required this.preview,
    required this.status,
    required this.isCall,
    required this.isSystem,
    required this.unsent,
    required this.mentionsMe,
    this.senderName,
    this.createdAt,
  });

  final int id;
  final int? senderId;
  final String? senderName;
  final String preview;
  final String status;
  final bool isCall;
  final bool isSystem;
  final bool unsent;
  final bool mentionsMe;
  final DateTime? createdAt;

  factory LastMessageSummary.fromJson(Map<String, dynamic> json) {
    return LastMessageSummary(
      id: (json['id'] as num).toInt(),
      senderId: (json['sender_id'] as num?)?.toInt(),
      senderName: json['sender_name'] as String?,
      preview: json['preview'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      isCall: json['is_call'] as bool? ?? false,
      isSystem: json['is_system'] as bool? ?? false,
      unsent: json['unsent'] as bool? ?? false,
      mentionsMe: json['mentions_me'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    );
  }
}

/// A call that is ringing or running in this conversation right now.
class ActiveCall {
  const ActiveCall({
    required this.id,
    required this.type,
    required this.status,
    required this.callerId,
    required this.joined,
  });

  final int id;
  final String type;
  final String status; // ringing | accepted
  final int callerId;

  /// Whether I am inside the call already.
  final bool joined;

  factory ActiveCall.fromJson(Map<String, dynamic> json) {
    return ActiveCall(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'audio',
      status: json['status'] as String? ?? '',
      callerId: (json['caller_id'] as num?)?.toInt() ?? 0,
      joined: json['joined'] as bool? ?? false,
    );
  }
}

/// A chat (direct or group) as `MessagingService::presentConversation`
/// shapes it for the person looking at it.
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    required this.unreadCount,
    required this.pinned,
    required this.muted,
    required this.archived,
    required this.markedUnread,
    this.lastMessage,
    this.activeCall,
    this.updatedAt,
    this.user,
    this.avatarUrl,
    this.members = const [],
    this.invited = const [],
    this.memberCount = 0,
    this.isAdmin = false,
    this.isInvited = false,
    this.invitedBy,
    this.createdBy,
  });

  final int id;
  final String type; // direct | group
  final String name;
  final int unreadCount;
  final bool pinned;
  final bool muted;
  final bool archived;
  final bool markedUnread;
  final LastMessageSummary? lastMessage;
  final ActiveCall? activeCall;
  final DateTime? updatedAt;

  /// The other person, for a direct chat.
  final ChatUser? user;

  /// Group photo, for a group.
  final String? avatarUrl;
  final List<ChatUser> members;
  final List<ChatUser> invited;
  final int memberCount;
  final bool isAdmin;

  /// I was invited and have not joined yet.
  final bool isInvited;
  final String? invitedBy;
  final int? createdBy;

  bool get isGroup => type == 'group';

  /// Bold in the list: unread messages, or marked unread by hand.
  bool get showsUnread => unreadCount > 0 || markedUnread;

  String? get displayAvatar => isGroup ? avatarUrl : user?.avatarUrl;

  String get initial => isGroup
      ? (name.isNotEmpty ? name[0].toUpperCase() : 'G')
      : (user?.initial ?? '?');

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'direct',
      name: json['name'] as String? ?? 'Chat',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      markedUnread: json['marked_unread'] as bool? ?? false,
      lastMessage: json['last_message'] is Map
          ? LastMessageSummary.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      activeCall: json['active_call'] is Map
          ? ActiveCall.fromJson(json['active_call'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal(),
      user: json['user'] is Map
          ? ChatUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      avatarUrl: resolveServerUrl(json['avatar'] as String?),
      members: [
        for (final m in (json['members'] as List? ?? const []))
          ChatUser.fromJson(m as Map<String, dynamic>),
      ],
      invited: [
        for (final m in (json['invited'] as List? ?? const []))
          ChatUser.fromJson(m as Map<String, dynamic>),
      ],
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      isAdmin: json['is_admin'] as bool? ?? false,
      isInvited: json['is_invited'] as bool? ?? false,
      invitedBy: json['invited_by'] as String?,
      createdBy: (json['created_by'] as num?)?.toInt(),
    );
  }
}

/// A person from the "new message" / "add people" search.
class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.name,
    required this.initial,
    required this.role,
    this.roleLabel,
    this.subtitle,
    this.avatarUrl,
    this.online = false,
  });

  final int id;
  final String name;
  final String initial;
  final String role;
  final String? roleLabel;
  final String? subtitle;
  final String? avatarUrl;
  final bool online;

  factory ChatPerson.fromJson(Map<String, dynamic> json) {
    return ChatPerson(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown',
      initial: json['initial'] as String? ?? '?',
      role: json['role'] as String? ?? '',
      roleLabel: json['role_label'] as String?,
      subtitle: json['subtitle'] as String?,
      avatarUrl: resolveServerUrl(json['avatar'] as String?),
      online: json['online'] as bool? ?? false,
    );
  }
}

/// A call that is ringing for me, from `/messages/poll` or `/calls/pending`.
class PendingCall {
  const PendingCall({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.type,
    required this.status,
    required this.isGroup,
    required this.room,
    this.caller,
    this.conversationName,
  });

  final int id;
  final int conversationId;
  final int callerId;
  final String type;
  final String status;
  final bool isGroup;
  final String room;
  final ChatUser? caller;
  final String? conversationName;

  factory PendingCall.fromJson(Map<String, dynamic> json) {
    return PendingCall(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversation_id'] as num).toInt(),
      callerId: (json['caller_id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'audio',
      status: json['status'] as String? ?? 'ringing',
      isGroup: json['is_group'] as bool? ?? false,
      room: json['room'] as String? ?? '',
      caller: json['caller'] is Map
          ? ChatUser.fromJson(json['caller'] as Map<String, dynamic>)
          : null,
      conversationName: json['conversation_name'] as String?,
    );
  }
}

/// Everything the Jitsi SDK needs to put me in a room, from the `join`
/// payload of start/accept (and of meetings).
class CallJoinConfig {
  const CallJoinConfig({
    required this.domain,
    required this.room,
    required this.url,
    required this.subject,
    required this.displayName,
    this.jwt,
    this.avatarUrl,
    this.email,
  });

  final String domain;
  final String room;
  final String url;
  final String subject;
  final String displayName;
  final String? jwt;
  final String? avatarUrl;
  final String? email;

  String get serverUrl => 'https://$domain';

  factory CallJoinConfig.fromJson(Map<String, dynamic> json) {
    return CallJoinConfig(
      domain: json['domain'] as String? ?? 'meet.jit.si',
      room: json['room'] as String? ?? '',
      url: json['url'] as String? ?? '',
      subject: json['subject'] as String? ?? 'SkillMatch call',
      displayName: json['display_name'] as String? ?? 'SkillMatch user',
      jwt: json['jwt'] as String?,
      avatarUrl: json['avatar'] as String?,
      email: json['email'] as String?,
    );
  }
}

/// What start/accept hand back: the call row plus how to join it.
class CallSession {
  const CallSession({required this.callId, required this.type, required this.isGroup, required this.join});

  final int callId;
  final String type;
  final bool isGroup;
  final CallJoinConfig join;

  factory CallSession.fromJson(Map<String, dynamic> json) {
    final call = json['call'] as Map<String, dynamic>;
    return CallSession(
      callId: (call['id'] as num).toInt(),
      type: call['type'] as String? ?? 'audio',
      isGroup: call['is_group'] as bool? ?? false,
      join: CallJoinConfig.fromJson(json['join'] as Map<String, dynamic>),
    );
  }
}
