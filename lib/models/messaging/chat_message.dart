import '../../core/api_config.dart';
import 'chat_user.dart';

/// A file or photo on a message. The API's relative link points at the web
/// route, which needs a browser session; the app reads the same file through
/// `/api/messages/attachments/{message}` with its bearer token instead.
class ChatAttachment {
  const ChatAttachment({
    required this.messageId,
    required this.name,
    required this.size,
    required this.mime,
    required this.isImage,
  });

  final int messageId;
  final String name;
  final int size;
  final String? mime;
  final bool isImage;

  String get url => '${ApiConfig.baseUrl}/messages/attachments/$messageId';
  String get downloadUrl => '$url?download=1';

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ChatAttachment.fromJson(int messageId, Map<String, dynamic> json) {
    return ChatAttachment(
      messageId: messageId,
      name: json['name'] as String? ?? 'Attachment',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mime: json['mime'] as String?,
      isImage: json['is_image'] as bool? ?? false,
    );
  }
}

/// The quoted original above a reply.
class ChatQuote {
  const ChatQuote({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.preview,
    required this.isImage,
    required this.unsent,
  });

  final int? id;
  final int? senderId;
  final String? senderName;
  final String preview;
  final bool isImage;
  final bool unsent;

  String? get imageUrl =>
      isImage && id != null ? '${ApiConfig.baseUrl}/messages/attachments/$id' : null;

  factory ChatQuote.fromJson(Map<String, dynamic> json) {
    return ChatQuote(
      id: (json['id'] as num?)?.toInt(),
      senderId: (json['sender_id'] as num?)?.toInt(),
      senderName: json['sender_name'] as String?,
      preview: json['preview'] as String? ?? '',
      isImage: json['is_image'] as bool? ?? false,
      unsent: json['unsent'] as bool? ?? false,
    );
  }
}

/// The call a `type = call` message records.
class ChatCallInfo {
  const ChatCallInfo({
    required this.id,
    required this.type,
    required this.status,
    required this.callerId,
    required this.isGroup,
    this.duration,
  });

  final int id;
  final String type; // audio | video
  final String status; // ringing | accepted | ended | declined | missed
  final int callerId;
  final bool isGroup;
  final int? duration;

  factory ChatCallInfo.fromJson(Map<String, dynamic> json) {
    return ChatCallInfo(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'audio',
      status: json['status'] as String? ?? '',
      callerId: (json['caller_id'] as num?)?.toInt() ?? 0,
      isGroup: json['is_group'] as bool? ?? false,
      duration: (json['duration'] as num?)?.toInt(),
    );
  }

  /// "Video call · 3m 12s", "Missed audio call" — same wording as the web.
  String label() {
    final kind = '${isGroup ? 'group ' : ''}${type == 'video' ? 'video call' : 'audio call'}';
    switch (status) {
      case 'ended':
        return '${_capitalize(kind)} · ${formatDuration(duration ?? 0)}';
      case 'declined':
        return 'Declined $kind';
      case 'missed':
        return 'Missed $kind';
      default:
        return _capitalize(kind);
    }
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}m${s > 0 ? ' ${s}s' : ''}';
    return '${m ~/ 60}h ${m % 60}m';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// One row of a thread, as `MessagingService::presentMessage` shapes it.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.status,
    required this.unsent,
    required this.createdAt,
    this.sender,
    this.body,
    this.clientId,
    this.mentions = const [],
    this.replyTo,
    this.attachment,
    this.call,
    this.deliveredAt,
    this.seenAt,
    this.sending = false,
    this.failed = false,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final ChatUser? sender;

  /// text | image | file | call | system
  final String type;
  final String? body;
  final String? clientId;
  final List<int> mentions;
  final ChatQuote? replyTo;
  final ChatAttachment? attachment;
  final ChatCallInfo? call;

  /// sending | sent | delivered | seen
  final String status;
  final DateTime? deliveredAt;
  final DateTime? seenAt;
  final bool unsent;
  final DateTime createdAt;

  /// Local-only flags for an optimistic bubble that has not (or could not)
  /// reach the server.
  final bool sending;
  final bool failed;

  bool get isSystem => type == 'system';
  bool get isCall => type == 'call';
  bool get isLocal => id < 0;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    return ChatMessage(
      id: id,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      sender: json['sender'] is Map
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String?,
      clientId: json['client_id'] as String?,
      mentions: [
        for (final m in (json['mentions'] as List? ?? const [])) (m as num).toInt(),
      ],
      replyTo: json['reply_to'] is Map
          ? ChatQuote.fromJson(json['reply_to'] as Map<String, dynamic>)
          : null,
      attachment: json['attachment'] is Map
          ? ChatAttachment.fromJson(id, json['attachment'] as Map<String, dynamic>)
          : null,
      call: json['call'] is Map
          ? ChatCallInfo.fromJson(json['call'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String? ?? 'sent',
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      seenAt: DateTime.tryParse(json['seen_at'] as String? ?? ''),
      unsent: json['unsent'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  ChatMessage copyWith({bool? sending, bool? failed}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      sender: sender,
      type: type,
      body: body,
      clientId: clientId,
      mentions: mentions,
      replyTo: replyTo,
      attachment: attachment,
      call: call,
      status: status,
      deliveredAt: deliveredAt,
      seenAt: seenAt,
      unsent: unsent,
      createdAt: createdAt,
      sending: sending ?? this.sending,
      failed: failed ?? this.failed,
    );
  }
}
