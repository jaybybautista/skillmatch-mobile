import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/messaging/chat_message.dart';
import '../models/messaging/conversation.dart';

/// The page of a thread `/messages/conversations/{id}` returns.
class ThreadPage {
  const ThreadPage({
    required this.conversation,
    required this.messages,
    required this.hasMore,
    required this.typingUserIds,
  });

  final Conversation conversation;
  final List<ChatMessage> messages;
  final bool hasMore;
  final List<int> typingUserIds;
}

/// Talks to the messaging and call endpoints under `/api/messages`, which
/// are the same `MessagingService` / `CallService` the website uses, so a
/// chat started here is the same chat on the web.
///
/// The app has no websocket: [startPolling] asks `/messages/poll` every few
/// seconds for the unread badge and for a call that is ringing for me, and
/// the thread screen re-reads its page on its own timer.
class MessagingService extends ChangeNotifier with WidgetsBindingObserver {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final ApiClient _client = ApiClient.instance;

  /// Messages badge, shared by every screen that shows it.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// A call ringing for me right now, or null. The app-wide ringer listens.
  final ValueNotifier<PendingCall?> pendingCall = ValueNotifier<PendingCall?>(null);

  /// Bumped whenever something that changes the chat list happened here
  /// (a message sent, a chat archived...) so open lists refresh at once.
  final ValueNotifier<int> listRevision = ValueNotifier<int>(0);

  static const pollInterval = Duration(seconds: 5);

  Timer? _poll;
  bool _polling = false;
  bool _inBackground = false;

  /// Cached bearer header for `Image.network` (photos in bubbles).
  Map<String, String> _imageHeaders = const {};
  Map<String, String> get imageHeaders => _imageHeaders;

  /* ── Polling ─────────────────────────────────────────────────────── */

  void startPolling() {
    if (_polling) return;
    _polling = true;
    WidgetsBinding.instance.addObserver(this);
    _refreshHeaders();
    poll();
    _poll = Timer.periodic(pollInterval, (_) => poll());
  }

  void stopPolling() {
    _polling = false;
    _poll?.cancel();
    _poll = null;
    WidgetsBinding.instance.removeObserver(this);
    unreadCount.value = 0;
    pendingCall.value = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inBackground = state != AppLifecycleState.resumed;
    if (!_inBackground && _polling) poll();
  }

  Future<void> _refreshHeaders() async {
    final token = await TokenStorage.instance.readToken();
    _imageHeaders = token == null
        ? const {}
        : {'Authorization': 'Bearer $token', 'Accept': '*/*'};
  }

  Future<void> poll() async {
    if (_inBackground) return;
    try {
      final response = await _client.get('/messages/poll', authenticated: true);
      unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? 0;
      final call = response['call'];
      final next = call is Map<String, dynamic> ? PendingCall.fromJson(call) : null;
      if (next?.id != pendingCall.value?.id) pendingCall.value = next;
    } catch (_) {
      // A failed poll is not worth surfacing; the next tick tries again.
    }
  }

  void touchList() => listRevision.value++;

  /* ── Conversations ───────────────────────────────────────────────── */

  Future<List<Conversation>> conversations({bool archived = false}) async {
    final response = await _client.get(
      '/messages/conversations${archived ? '?archived=1' : ''}',
      authenticated: true,
    );
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
    return [
      for (final c in (response['conversations'] as List? ?? const []))
        Conversation.fromJson(c as Map<String, dynamic>),
    ];
  }

  Future<List<ChatPerson>> people(String query, {List<int> exclude = const []}) async {
    final params = <String, String>{
      'q': query,
      if (exclude.isNotEmpty) 'exclude': exclude.join(','),
    };
    final response = await _client.get(
      '/messages/people?${Uri(queryParameters: params).query}',
      authenticated: true,
    );
    return [
      for (final p in (response['people'] as List? ?? const []))
        ChatPerson.fromJson(p as Map<String, dynamic>),
    ];
  }

  /// Opens (or creates) the direct chat with a user.
  Future<Conversation> open(int userId) async {
    final response = await _client.post('/messages/open', {'user_id': userId}, authenticated: true);
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<ThreadPage> thread(int conversationId, {int? beforeId}) async {
    final response = await _client.get(
      '/messages/conversations/$conversationId${beforeId != null ? '?before_id=$beforeId' : ''}',
      authenticated: true,
    );
    return ThreadPage(
      conversation: Conversation.fromJson(response['conversation'] as Map<String, dynamic>),
      messages: [
        for (final m in (response['messages'] as List? ?? const []))
          ChatMessage.fromJson(m as Map<String, dynamic>),
      ],
      hasMore: response['has_more'] as bool? ?? false,
      typingUserIds: [
        for (final id in (response['typing'] as List? ?? const [])) (id as num).toInt(),
      ],
    );
  }

  Future<ChatMessage> send(
    int conversationId, {
    String? body,
    String? filePath,
    required String clientId,
    List<int> mentions = const [],
    int? replyTo,
  }) async {
    final fields = <String, String>{
      if (body != null && body.isNotEmpty) 'body': body,
      'client_id': clientId,
      if (replyTo != null) 'reply_to': '$replyTo',
    };
    for (var i = 0; i < mentions.length; i++) {
      fields['mentions[$i]'] = '${mentions[i]}';
    }

    final response = await _client.postMultipart(
      '/messages/conversations/$conversationId',
      fields: fields,
      filePath: filePath,
      fileFieldName: filePath != null ? 'attachment' : null,
      authenticated: true,
    );
    touchList();
    return ChatMessage.fromJson(response['message'] as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) async {
    final response = await _client.post('/messages/conversations/$conversationId/read', {}, authenticated: true);
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
  }

  Future<void> typing(int conversationId, bool typing) async {
    try {
      await _client.post('/messages/conversations/$conversationId/typing', {'typing': typing}, authenticated: true);
    } catch (_) {
      // Purely cosmetic.
    }
  }

  Future<ChatMessage> unsend(int messageId) async {
    final response = await _client.delete('/messages/$messageId', authenticated: true);
    touchList();
    return ChatMessage.fromJson(response['message'] as Map<String, dynamic>);
  }

  Future<void> hideMessage(int messageId) async {
    await _client.delete('/messages/$messageId/me', authenticated: true);
  }

  Future<List<int>> attachmentBytes(int messageId) async {
    final response = await _client.getBytes('/messages/attachments/$messageId?download=1', authenticated: true);
    return response.bodyBytes;
  }

  /* ── Per-chat preferences ────────────────────────────────────────── */

  /// [pref]: pin | mute | archive | unread (each toggles).
  Future<Conversation> setPreference(int conversationId, String pref) async {
    final response = await _client.post('/messages/conversations/$conversationId/prefs/$pref', {}, authenticated: true);
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<void> deleteForMe(int conversationId) async {
    final response = await _client.delete('/messages/conversations/$conversationId', authenticated: true);
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
    touchList();
  }

  /* ── Groups ──────────────────────────────────────────────────────── */

  Future<Conversation> createGroup(String name, List<int> userIds) async {
    final response = await _client.post('/messages/groups', {'name': name, 'user_ids': userIds}, authenticated: true);
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<Conversation> renameGroup(int conversationId, String name) async {
    final response = await _client.patch('/messages/conversations/$conversationId', {'name': name}, authenticated: true);
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<Conversation> addMembers(int conversationId, List<int> userIds) async {
    final response = await _client.post('/messages/conversations/$conversationId/members', {'user_ids': userIds}, authenticated: true);
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  /// Removes someone (admin) or leaves myself. Returns null when I left.
  Future<Conversation?> removeMember(int conversationId, int userId) async {
    final response = await _client.delete('/messages/conversations/$conversationId/members/$userId', authenticated: true);
    touchList();
    final conv = response['conversation'];
    return conv is Map<String, dynamic> ? Conversation.fromJson(conv) : null;
  }

  Future<Conversation> setAdmin(int conversationId, int userId, bool admin) async {
    final response = await _client.post('/messages/conversations/$conversationId/members/$userId/admin', {'admin': admin}, authenticated: true);
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<Conversation> acceptInvite(int conversationId) async {
    final response = await _client.post('/messages/conversations/$conversationId/invite/accept', {}, authenticated: true);
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  Future<void> declineInvite(int conversationId) async {
    await _client.post('/messages/conversations/$conversationId/invite/decline', {}, authenticated: true);
    touchList();
  }

  Future<Conversation> setGroupPhoto(int conversationId, String filePath) async {
    final response = await _client.postMultipart(
      '/messages/conversations/$conversationId/avatar',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'avatar',
      authenticated: true,
    );
    touchList();
    return Conversation.fromJson(response['conversation'] as Map<String, dynamic>);
  }

  /* ── Calls ───────────────────────────────────────────────────────── */

  Future<CallSession> startCall(int conversationId, String type) async {
    final response = await _client.post('/messages/conversations/$conversationId/calls', {'type': type}, authenticated: true);
    return CallSession.fromJson(response);
  }

  Future<CallSession> acceptCall(int callId) async {
    final response = await _client.post('/messages/calls/$callId/accept', {}, authenticated: true);
    pendingCall.value = null;
    return CallSession.fromJson(response);
  }

  Future<void> declineCall(int callId) async {
    pendingCall.value = null;
    await _client.post('/messages/calls/$callId/decline', {}, authenticated: true);
  }

  Future<void> cancelCall(int callId) async {
    await _client.post('/messages/calls/$callId/cancel', {}, authenticated: true);
  }

  Future<void> endCall(int callId) async {
    await _client.post('/messages/calls/$callId/end', {}, authenticated: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    unreadCount.dispose();
    pendingCall.dispose();
    listRevision.dispose();
    super.dispose();
  }
}
