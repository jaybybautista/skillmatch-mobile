import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/file_share.dart';
import '../../models/messaging/chat_message.dart';
import '../../models/messaging/chat_user.dart';
import '../../models/messaging/conversation.dart';
import '../../services/auth_service.dart';
import '../../services/call_manager.dart';
import '../../services/messaging_service.dart';
import 'call_screens.dart';
import 'chat_info_screen.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/message_bubble.dart';

/// One conversation: the thread, the composer, the call buttons.
///
/// Mirrors the web thread: bubbles with Sent / Delivered / Seen under my
/// last message, "Seen by" avatars in a group, time separators, load-older
/// on scroll, reply, @mentions in a group, unsend / remove for you, photo
/// and file attachments, a Join / Decline screen for a group invite, and a
/// green "call in progress" strip while a group call is live.
///
/// Without a websocket the page is re-read every 3 seconds (new messages,
/// status changes, who is typing) and merged into what is on screen.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> with WidgetsBindingObserver {
  final _service = MessagingService.instance;
  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  static const _refreshEvery = Duration(seconds: 3);

  late Conversation _conversation = widget.conversation;
  List<ChatMessage> _messages = const [];
  List<int> _typing = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  String? _error;
  Timer? _poll;
  Timer? _typingStop;
  bool _sentTyping = false;
  int _clientSeq = 0;

  ChatMessage? _replyTo;

  /// @mentions picked in the composer (id -> name), sent with the message.
  final Map<int, String> _mentions = {};

  int get _myId => context.read<AuthService>().currentUser?.id ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _poll = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _typingStop?.cancel();
    if (_sentTyping) _service.typing(_conversation.id, false);
    _composer.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /* ── Loading ─────────────────────────────────────────────────────── */

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await _service.thread(_conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = page.conversation;
        _messages = page.messages;
        _hasMore = page.hasMore;
        _typing = page.typingUserIds;
        _error = null;
        _loading = false;
      });
      _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this chat. Please check your connection.';
        _loading = false;
      });
    }
  }

  /// Re-reads the latest page and merges it: new rows are appended, rows
  /// already on screen take the server's version (status, unsend), and
  /// optimistic bubbles that have since landed are replaced by their real row.
  Future<void> _refresh() async {
    if (_loading) return;
    try {
      final page = await _service.thread(_conversation.id);
      if (!mounted) return;

      final byId = {for (final m in _messages.where((m) => !m.isLocal)) m.id: m};
      final byClient = {for (final m in _messages.where((m) => m.clientId != null)) m.clientId!: m};
      var changed = false;
      var hadNew = false;

      for (final m in page.messages) {
        if (byId.containsKey(m.id)) {
          if (byId[m.id]!.status != m.status || byId[m.id]!.unsent != m.unsent) {
            byId[m.id] = m;
            changed = true;
          }
        } else if (m.clientId != null && byClient.containsKey(m.clientId)) {
          byId[m.id] = m;
          changed = true;
        } else {
          byId[m.id] = m;
          changed = true;
          if (m.senderId != _myId) hadNew = true;
        }
      }

      // Anything on the latest page that vanished server-side (removed for
      // me elsewhere) simply stays; a reload clears it.
      final landedClientIds = {for (final m in page.messages) if (m.clientId != null) m.clientId!};
      final locals = _messages.where((m) => m.isLocal && !landedClientIds.contains(m.clientId)).toList();

      final merged = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      merged.addAll(locals);

      setState(() {
        _conversation = page.conversation;
        _typing = page.typingUserIds;
        if (changed) _messages = merged;
      });

      if (hadNew) _markRead();
    } catch (_) {
      // Next tick tries again.
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final oldest = _messages.firstWhere((m) => !m.isLocal).id;
      final page = await _service.thread(_conversation.id, beforeId: oldest);
      if (!mounted) return;
      setState(() {
        _messages = [...page.messages, ..._messages];
        _hasMore = page.hasMore;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    // Reversed list: the top of the thread is the end of the scroll extent.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadOlder();
  }

  Future<void> _markRead() async {
    if (_conversation.isInvited) return;
    final unreadFromOthers = _messages.any((m) => m.senderId != _myId && m.status != 'seen');
    if (!unreadFromOthers && _conversation.unreadCount == 0 && !_conversation.markedUnread) return;
    try {
      await _service.markRead(_conversation.id);
      _service.touchList();
    } catch (_) {}
  }

  /* ── Sending ─────────────────────────────────────────────────────── */

  void _onComposerChanged(String text) {
    // Drop mentions whose "@Name" was deleted from the text.
    _mentions.removeWhere((_, name) => !text.contains('@$name'));

    if (_conversation.isGroup && text.endsWith('@')) {
      _pickMention();
    }

    if (!_sentTyping && text.isNotEmpty) {
      _sentTyping = true;
      _service.typing(_conversation.id, true);
    }
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(seconds: 4), () {
      _sentTyping = false;
      _service.typing(_conversation.id, false);
    });
    setState(() {});
  }

  Future<void> _pickMention() async {
    final others = _conversation.members.where((m) => m.id != _myId).toList();
    if (others.isEmpty) return;

    final picked = await showModalBottomSheet<ChatUser>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text('Mention someone', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final m in others)
              ListTile(
                leading: ChatAvatar(initial: m.initial, url: m.avatarUrl, size: 36),
                title: Text(m.name),
                onTap: () => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    final text = _composer.text;
    final replaced = text.endsWith('@') ? '${text.substring(0, text.length - 1)}@${picked.name} ' : '$text@${picked.name} ';
    _mentions[picked.id] = picked.name;
    _composer.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _send({String? filePath}) async {
    final body = _composer.text.trim();
    if (body.isEmpty && filePath == null) return;

    final clientId = 'm${DateTime.now().millisecondsSinceEpoch}-${_clientSeq++}';
    final replyTo = _replyTo;
    final mentions = _mentions.keys.toList();

    final local = ChatMessage(
      id: -(_clientSeq + 1),
      conversationId: _conversation.id,
      senderId: _myId,
      type: filePath != null ? 'file' : 'text',
      body: body.isEmpty ? (filePath != null ? 'Sending attachment…' : null) : body,
      clientId: clientId,
      status: 'sending',
      unsent: false,
      createdAt: DateTime.now(),
      sending: true,
      replyTo: replyTo == null
          ? null
          : ChatQuote(
              id: replyTo.id,
              senderId: replyTo.senderId,
              senderName: replyTo.sender?.name,
              preview: replyTo.attachment?.isImage == true ? 'Photo' : (replyTo.body ?? replyTo.attachment?.name ?? ''),
              isImage: replyTo.attachment?.isImage == true,
              unsent: false,
            ),
    );

    setState(() {
      _messages = [..._messages, local];
      _replyTo = null;
      _mentions.clear();
    });
    _composer.clear();
    _typingStop?.cancel();
    if (_sentTyping) {
      _sentTyping = false;
      _service.typing(_conversation.id, false);
    }
    _jumpToBottom();

    await _deliver(local, body: body, filePath: filePath, clientId: clientId, mentions: mentions, replyTo: replyTo?.id);
  }

  Future<void> _deliver(
    ChatMessage local, {
    required String body,
    String? filePath,
    required String clientId,
    List<int> mentions = const [],
    int? replyTo,
  }) async {
    try {
      final sent = await _service.send(
        _conversation.id,
        body: body,
        filePath: filePath,
        clientId: clientId,
        mentions: mentions,
        replyTo: replyTo,
      );
      if (!mounted) return;
      setState(() {
        _messages = [for (final m in _messages) if (m.clientId == clientId) sent else m];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [for (final m in _messages) if (m.clientId == clientId) m.copyWith(sending: false, failed: true) else m];
      });
      _notify(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = [for (final m in _messages) if (m.clientId == clientId) m.copyWith(sending: false, failed: true) else m];
      });
    }
  }

  /// Retries a "Not sent" bubble with the same client id, so a message that
  /// did land the first time is not duplicated.
  Future<void> _retry(ChatMessage failed) async {
    setState(() {
      _messages = [for (final m in _messages) if (m.clientId == failed.clientId) m.copyWith(sending: true, failed: false) else m];
    });
    await _deliver(failed, body: failed.body ?? '', clientId: failed.clientId!, mentions: failed.mentions, replyTo: failed.replyTo?.id);
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose a photo'), onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(leading: const Icon(Icons.attach_file), title: const Text('Attach a file'), onTap: () => Navigator.pop(context, 'file')),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (choice == null) return;

    String? path;
    if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'zip'],
      );
      path = result?.files.single.path;
    } else {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
      );
      path = picked?.path;
    }
    if (path == null) return;
    await _send(filePath: path);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /* ── Message actions ─────────────────────────────────────────────── */

  Future<void> _messageMenu(ChatMessage m) async {
    if (m.isSystem || m.isLocal) return;
    final mine = m.senderId == _myId;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.unsent && !m.isCall)
              ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () => Navigator.pop(context, 'reply')),
            if (!m.unsent && (m.body ?? '').isNotEmpty)
              ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Copy text'), onTap: () => Navigator.pop(context, 'copy')),
            if (!m.unsent && m.attachment != null)
              ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Save attachment'), onTap: () => Navigator.pop(context, 'download')),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Remove for you'),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
            if (mine && !m.unsent && !m.isCall)
              ListTile(
                leading: const Icon(Icons.undo, color: AppColors.danger),
                title: const Text('Unsend for everyone', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(context, 'unsend'),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (action == null) return;

    try {
      switch (action) {
        case 'reply':
          setState(() => _replyTo = m);
          _focus.requestFocus();
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.body ?? ''));
          _notify('Copied.');
        case 'download':
          await _saveAttachment(m);
        case 'hide':
          await _service.hideMessage(m.id);
          setState(() => _messages = _messages.where((x) => x.id != m.id).toList());
        case 'unsend':
          final updated = await _service.unsend(m.id);
          setState(() => _messages = [for (final x in _messages) x.id == m.id ? updated : x]);
      }
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _saveAttachment(ChatMessage m) async {
    final att = m.attachment;
    if (att == null) return;
    _notify('Preparing ${att.name}…');
    try {
      final bytes = await _service.attachmentBytes(m.id);
      await shareFileBytes(bytes, att.name);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /* ── Calls ───────────────────────────────────────────────────────── */

  Future<void> _call(String type) async {
    if (CallManager.instance.inCall) {
      _notify('You are already in a call.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OutgoingCallScreen(conversation: _conversation, type: type),
      ),
    );
    _refresh();
  }

  /// Joins a group call that is already running (the green strip).
  Future<void> _joinLiveCall(ActiveCall call) async {
    try {
      final session = await _service.acceptCall(call.id);
      if (!mounted) return;
      await CallManager.instance.join(session, audioOnly: session.type == 'audio');
      _refresh();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  /* ── Invite ──────────────────────────────────────────────────────── */

  Future<void> _answerInvite(bool accept) async {
    try {
      if (accept) {
        final c = await _service.acceptInvite(_conversation.id);
        if (!mounted) return;
        setState(() => _conversation = c);
        _load();
      } else {
        await _service.declineInvite(_conversation.id);
        if (mounted) Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _openInfo() async {
    final result = await Navigator.of(context).push<ChatInfoResult>(
      MaterialPageRoute(builder: (_) => ChatInfoScreen(conversation: _conversation, messages: _messages)),
    );
    if (!mounted) return;
    if (result?.left == true || result?.deleted == true) {
      Navigator.of(context).pop();
      return;
    }
    if (result?.conversation != null) setState(() => _conversation = result!.conversation!);
    if (result?.open != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatThreadScreen(conversation: result!.open!)),
      );
    }
    _refresh();
  }

  /* ── Build ───────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final c = _conversation;
    final subtitle = c.isGroup
        ? '${c.memberCount} members'
        : (c.user?.activityLabel ?? c.user?.roleLabel ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: c.isInvited ? null : _openInfo,
          child: Row(
            children: [
              ChatAvatar(
                initial: c.initial,
                url: c.displayAvatar,
                size: 36,
                online: !c.isGroup && (c.user?.online ?? false),
                square: c.isGroup || c.user?.role == 'company',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: c.isInvited
            ? null
            : [
                IconButton(tooltip: 'Audio call', icon: const Icon(Icons.call_outlined), onPressed: () => _call('audio')),
                IconButton(tooltip: 'Video call', icon: const Icon(Icons.videocam_outlined), onPressed: () => _call('video')),
                IconButton(tooltip: 'Chat info', icon: const Icon(Icons.info_outline), onPressed: _openInfo),
              ],
      ),
      body: c.isInvited ? _inviteBody(c) : _threadBody(c),
    );
  }

  Widget _inviteBody(Conversation c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar(initial: c.initial, url: c.displayAvatar, size: 84, square: true),
            const SizedBox(height: 16),
            Text(c.name, style: AppFonts.title(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '${c.invitedBy ?? 'A member'} invited you to this group · ${c.memberCount} members',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => _answerInvite(true), child: const Text('Join group')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => _answerInvite(false), child: const Text('Decline')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _threadBody(Conversation c) {
    final live = c.activeCall;
    final showLiveStrip = live != null && live.status == 'accepted' && !live.joined && c.isGroup;

    return Column(
      children: [
        if (showLiveStrip)
          Material(
            color: const Color(0xFFEAFAF1),
            child: InkWell(
              onTap: () => _joinLiveCall(live),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk, size: 18, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${live.type == 'video' ? 'Video' : 'Audio'} call in progress',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                    ),
                    const Text('Join', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: _messageList(c)),
        _typingRow(c),
        _composerBar(c),
      ],
    );
  }

  Widget _messageList(Conversation c) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatAvatar(initial: c.initial, url: c.displayAvatar, size: 72, square: c.isGroup),
              const SizedBox(height: 12),
              Text(c.name, style: AppFonts.title(fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Say hello to start the conversation.', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    // Newest at the bottom: the list is reversed so index 0 is the latest.
    final items = _messages.reversed.toList();
    final lastMineId = _messages.lastWhere((m) => m.senderId == _myId && !m.isLocal, orElse: () => _messages.first).id;

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: items.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = items[i];
        final older = i + 1 < items.length ? items[i + 1] : null;
        final newer = i > 0 ? items[i - 1] : null;

        final showSeparator = older == null || m.createdAt.difference(older.createdAt).inMinutes >= 20;
        final mine = m.senderId == _myId;
        final firstOfRun = older == null || older.senderId != m.senderId || older.isSystem || showSeparator;
        final lastOfRun = newer == null || newer.senderId != m.senderId || newer.isSystem;

        return Column(
          children: [
            if (showSeparator)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(threadSeparator(m.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
            // Swiping a bubble to the right replies to it, like Messenger.
            SwipeToReply(
              enabled: !m.isSystem && !m.isLocal && !m.unsent && !m.isCall,
              onReply: () {
                setState(() => _replyTo = m);
                _focus.requestFocus();
              },
              child: MessageBubble(
                message: m,
                mine: mine,
                isGroup: c.isGroup,
                showSender: c.isGroup && !mine && firstOfRun,
                showAvatar: !mine && lastOfRun,
                showStatus: mine && m.id == lastMineId,
                seenBy: c.isGroup && mine && m.id == lastMineId ? _seenBy(c, m) : const [],
                myId: _myId,
                imageHeaders: _service.imageHeaders,
                onLongPress: () => _messageMenu(m),
                onRetry: m.failed ? () => _retry(m) : null,
                onCallAgain: m.isCall && m.call != null ? () => _call(m.call!.type) : null,
                onQuoteTap: m.replyTo?.id != null ? () => _scrollToMessage(m.replyTo!.id!) : null,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Members (other than me) whose read marker is past this message.
  List<ChatUser> _seenBy(Conversation c, ChatMessage m) {
    return [
      for (final member in c.members)
        if (member.id != _myId && (member.lastReadMessageId ?? 0) >= m.id) member,
    ];
  }

  void _scrollToMessage(int id) {
    final index = _messages.reversed.toList().indexWhere((m) => m.id == id);
    if (index < 0) {
      _notify('That message is further up; scroll to load it.');
      return;
    }
    // Rough: bubbles vary in height, so this lands nearby rather than exactly.
    _scroll.animateTo(
      (index * 72).toDouble().clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _typingRow(Conversation c) {
    if (_typing.isEmpty) return const SizedBox.shrink();
    String label;
    if (c.isGroup) {
      final names = [
        for (final id in _typing) c.members.where((m) => m.id == id).map((m) => m.firstName).firstOrNull ?? 'Someone',
      ];
      label = names.length == 1 ? '${names.first} is typing…' : '${names.join(' and ')} are typing…';
    } else {
      label = '${c.user?.firstName ?? 'They'} is typing…';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _composerBar(Conversation c) {
    final reply = _replyTo;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${reply.senderId == _myId ? 'yourself' : (reply.sender?.name ?? c.name)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            reply.attachment?.isImage == true ? 'Photo' : (reply.body ?? reply.attachment?.name ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyTo = null)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onPressed: _attach,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      focusNode: _focus,
                      onChanged: _onComposerChanged,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 5000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: c.isGroup ? 'Message the group… (@ to mention)' : 'Type a message…',
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Send',
                    icon: Icon(Icons.send_rounded, color: _composer.text.trim().isEmpty ? AppColors.textMuted : AppColors.primary),
                    onPressed: _composer.text.trim().isEmpty ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
